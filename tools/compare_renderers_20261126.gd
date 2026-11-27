extends "capture_perf_cadence.gd"
## The same authored fixed-seed city as the prior render-cadence measurement.
## Only the CLI rendering method varies. No production or project settings changes.
const FRAMEBUFFER := Vector2i(1920,1080)
const WARM_US := 1000000
const SAMPLE_US := 4000000

func require(ok:bool, message:String)->bool:
 if not ok:printerr("FAIL RENDERER_COMPARE ",message)
 return ok

func finish(code:int):
 if is_instance_valid(game):
  game.queue_free()
  await process_frame
 quit(code)

func fingerprint(value:Variant)->String:
 var digest:=HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 digest.update(var_to_bytes(value))
 return digest.finish().hex_encode()

func camera(cell:Vector2,zoom:float,screen_position:Vector2):
 game.map_zoom=zoom
 game.origin=screen_position-game.world_renderer.iso(cell)*zoom
 game.refresh()

func frames()->Dictionary:
 var until:=Time.get_ticks_usec()+WARM_US
 while Time.get_ticks_usec()<until:await RenderingServer.frame_post_draw
 var start:=Time.get_ticks_usec()
 var previous:=start
 var durations:Array[int]=[]
 while previous-start<SAMPLE_US:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec()
  durations.append(now-previous)
  previous=now
 var sorted:=durations.duplicate();sorted.sort()
 return {"frames":durations.size(),"elapsed_usec":previous-start,"frame_usec":durations,
  "average_ms":float(previous-start)/durations.size()/1000.0,
  "p95_ms":float(sorted[ceili(sorted.size()*.95)-1])/1000.0}

func capture(path:String,tag:String)->bool:
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 return require(image.get_size()==FRAMEBUFFER and image.save_png(path.path_join(tag+".png"))==OK,"could not save native "+tag)

func run():
 var args:=OS.get_cmdline_user_args()
 var out:=""
 var check_only:=args.has("--fixture-check")
 for arg:String in args:
  if arg.begins_with("--evidence-dir="):out=arg.trim_prefix("--evidence-dir=")
 var method:=RenderingServer.get_current_rendering_method()
 var driver:=RenderingServer.get_current_rendering_driver_name()
 print("RENDERER_COMPARE_ACTIVE method=",method," driver=",driver)
 if not require(DisplayServer.get_name()!="headless" and root.size==FRAMEBUFFER and DisplayServer.window_get_size()==FRAMEBUFFER,"expected a native 1920x1080 framebuffer"):
  await finish(1);return
 if not check_only:
  if not require(not out.is_empty() and DirAccess.make_dir_recursive_absolute(out)==OK,"new output directory required"):
   await finish(1);return
  for name:String in ["city.png","building.png","frames.json"]:
   if not require(not FileAccess.file_exists(out.path_join(name)),"destination already exists: "+name):
    await finish(1);return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 if not require(DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"VSync was not disabled"):
  await finish(1);return
 game=load("res://main.tscn").instantiate()
 game.city=fixture();game.paused=true;root.add_child(game);current_scene=game
 await settle()
 if not require(game.traffic.rebuild(game.city.roads),"historical fixture traffic cannot build"):
  await finish(1);return
 game.traffic.seed_traffic();game.traffic.simulation.paused=true
 game.mode="select";game.drawer.hide()
 camera(Vector2(48,48),.9,Vector2(960,410));await settle()
 var city=game.city
 var cars:Array=game.traffic.simulation.vehicles
 if not require(city.roads.size()==6 and city.buildings.size()==24 and cars.size()==24,"historical fixture was not 6 roads, 24 buildings, 24 paused cars"):
  await finish(1);return
 var deadline:=Time.get_ticks_msec()+30000
 while game.building_views.busy or not game.building_views.queue.is_empty():
  if not require(Time.get_ticks_msec()<deadline,"building SubViewports did not settle"):
   await finish(1);return
  await process_frame
 var target:Dictionary={}
 var target_cell:=Vector2.ZERO
 var nearest:=INF
 for row:Dictionary in city.buildings:
  var asset:Dictionary=city.catalog.get_asset(row.asset_id)
  if city.supports_static_sprite(row) or not asset.has("model"):continue
  var cell:Vector2=city.Parcels.bounds(city.footprint(row)).get_center()
  var distance:=cell.distance_squared_to(Vector2(48,48))
  if (target.is_empty() or distance<nearest) and not game.building_views.view(asset,city.front_direction(row)).is_empty():
   target=row;target_cell=cell;nearest=distance
 if not require(not target.is_empty(),"expected a real building model composed through SubViewport"):
  await finish(1);return
 var layout:=fingerprint([city.roads,city.buildings,cars.map(func(car):return [car.id,car.get("asset"),car.get("route"),car.get("progress")]),game.map_zoom,game.origin])
 print("RENDERER_COMPARE_FIXTURE sha256=",layout," target=",target.id," asset=",target.asset_id," cell=",target_cell)
 var result:Dictionary={}
 if not check_only:
  result=await frames()
  if not await capture(out,"city"):
   await finish(1);return
 camera(target_cell,4.5,Vector2(960,510));await settle()
 var visual:Dictionary=game.building_visual(target)
 if not require(not visual.is_empty() and (visual.image as Image).get_used_rect().has_area(),"close-up model texture is missing or transparent"):
  await finish(1);return
 if not check_only:
  if not await capture(out,"building"):
   await finish(1);return
  result.merge({"method":method,"driver":driver,"layout_sha256":layout,"seed":20261114,"roads":city.roads.size(),
   "buildings":city.buildings.size(),"vehicles":cars.size(),"width":FRAMEBUFFER.x,"height":FRAMEBUFFER.y,
   "vsync":false,"city_zoom":.9,"close_zoom":4.5,"close_building":target.id,"close_asset":target.asset_id,
   "close_cell":[target_cell.x,target_cell.y]})
  var file:=FileAccess.open(out.path_join("frames.json"),FileAccess.WRITE)
  if not require(file!=null,"cannot write frames.json"):
   await finish(1);return
  file.store_string(JSON.stringify(result,"  "));file.close()
  print("RENDERER_COMPARE_RESULT average_ms=",result.average_ms," p95_ms=",result.p95_ms," frames=",result.frames)
 print("RENDERER_COMPARE_PASS ",method)
 await finish(0)
