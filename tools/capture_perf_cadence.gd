extends SceneTree
const City=preload("res://core/city_model.gd")
var game
var output:=""
var stage:="before"
var comparisons:Array=[]
func _initialize():run.call_deferred()
func settle():
 for i in range(8):await process_frame
func fixture():
 var city=City.new(100,100,20261114)
 for y in [28,48,68]:assert(city.add_road(PackedVector2Array([Vector2(24,y),Vector2(72,y)])).ok)
 for x in [28,48,68]:assert(city.add_road(PackedVector2Array([Vector2(x,24),Vector2(x,72)])).ok)
 for parcel in city.zoning_grid.parcels.values():
  if parcel.v!=0 or parcel.u%4!=0:continue
  city.add_building_at(parcel.center)
  if city.buildings.size()>=24:break
 assert(city.buildings.size()==24)
 return city
func measure()->Dictionary:
 var warm:=Time.get_ticks_usec()+1000000
 while Time.get_ticks_usec()<warm:await RenderingServer.frame_post_draw
 var start:=Time.get_ticks_usec();var previous:=start;var times:Array[float]=[]
 while Time.get_ticks_usec()-start<4000000:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
 var seconds:float=(previous-start)/1000000.0;times.sort()
 return {"fps":times.size()/seconds,"frames":times.size(),"seconds":seconds,"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[int(times.size()*.95)]}
func compare_opaque_buildings(before:Image,after:Image)->Dictionary:
 var checked:=0;var changed:=0;var error:=0.0
 for building in game.city.buildings:
  var visual:Dictionary=game.building_visual(building)
  if visual.is_empty():continue
  var rect:Rect2=visual.rect;var source:Image=visual.image
  var clipped:Rect2=rect.intersection(Rect2(Vector2.ZERO,Vector2(after.get_size())))
  for y in range(ceili(clipped.position.y),floori(clipped.end.y)):
   for x in range(ceili(clipped.position.x),floori(clipped.end.x)):
    var uv:Vector2=(Vector2(x+.5,y+.5)-rect.position)/rect.size
    var pixel:=Vector2i(uv*Vector2(source.get_size()))
    if source.get_pixelv(pixel).a<.995:continue
    var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
    var difference:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))*255
    checked+=1;error+=difference
    if difference>8:changed+=1
 return {"opaque_building_pixels":checked,"changed_over_8":changed,"mean_max_channel_error":error/maxi(1,checked),"matching_fraction":1.0-float(changed)/maxi(1,checked)}
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
  if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
 assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 game=load("res://main.tscn").instantiate();game.city=fixture();game.paused=true;root.add_child(game);current_scene=game;await settle()
 assert(game.traffic.rebuild(game.city.roads));game.traffic.seed_traffic();game.traffic.simulation.paused=true
 game.mode="select";game.drawer.hide();game.map_zoom=.9;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(48,48));game.queue_redraw();await settle()
 var deadline:=Time.get_ticks_msec()+30000
 while game.building_views.busy or not game.building_views.queue.is_empty():
  assert(Time.get_ticks_msec()<deadline,"building image cache did not settle");await process_frame
 var results:Array=[]
 for name in ["normal","zoning","zoom-out"]:
  if name!="normal":game.select_category("build")
  game.map_zoom=.35 if name=="zoom-out" else .9;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(48,48));game.queue_redraw();await settle()
  var sample:Dictionary=await measure();sample.scenario=name;sample.zoom=game.map_zoom;results.append(sample)
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(output.path_join(stage+"-"+name+".png"))==OK)
  if stage=="after":
   var comparison:=compare_opaque_buildings(Image.load_from_file(output.path_join("before-"+name+".png")),image);comparison.scenario=name;comparisons.append(comparison)
   assert(comparison.opaque_building_pixels>100 and comparison.matching_fraction>.99,"Building placement/occlusion differs from baseline: "+str(comparison))
  print("PERF %s %s FPS %.3f"%[stage,name,sample.fps])
 var file:=FileAccess.open(output.path_join(stage+".json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"stage":stage,"viewport":"1920x1080","vsync":false,"method":"same fixed seed city; 24 buildings, 6 roads; stopped vehicles and paused city; 1s warmup + 4s wall-time/scenario","roads":game.city.roads.size(),"buildings":game.city.buildings.size(),"vehicles":game.traffic.simulation.vehicles.size(),"city_geometry":var_to_str(game.city.buildings),"samples":results},"  "));file.close()
 if stage=="after":
  file=FileAccess.open(output.path_join("actor-comparison.json"),FileAccess.WRITE);file.store_string(JSON.stringify(comparisons,"  "));file.close()
 game.queue_free();await process_frame;print("PERF_CAPTURE_PASS "+stage);quit()
