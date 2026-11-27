extends SceneTree
const City=preload("res://core/city_model.gd")
var game
var output:="D:/project/simcity/docs/zoning-mesh-validation"
var stage:="before"
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
 assert(city.buildings.size()==24);return city
func summarize(times:Array)->Dictionary:
 var sorted:Array=times.duplicate();sorted.sort();var total:=0.0
 for value in times:total+=value
 return {"fps":times.size()*1000.0/total,"frames":times.size(),"median_ms":sorted[sorted.size()/2],"p99_ms":sorted[mini(sorted.size()-1,int(sorted.size()*.99))],"max_ms":sorted[-1]}
func measure():
 var deadline:=Time.get_ticks_msec()+1000
 while Time.get_ticks_msec()<deadline:await RenderingServer.frame_post_draw
 var start:=Time.get_ticks_usec();var prior:=start;var samples:Array=[]
 while Time.get_ticks_usec()-start<4e6:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();samples.append((now-prior)/1000.0);prior=now
 return summarize(samples)
func motion(point:Vector2):
 var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;root.push_input(event,true)
func button(point:Vector2,pressed:bool):
 var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
 assert(stage in ["before","after"])
 DirAccess.make_dir_recursive_absolute(output);root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 game=load("res://main.tscn").instantiate();game.city=fixture();game.paused=true;root.add_child(game);current_scene=game;await settle()
 if stage=="before":
  var source:Array=[]
  assert(OS.execute("git",["-C","D:/project/simcity","show","2ea4105:cities_do/core/cached_world_renderer.gd"],source,true)==0)
  var baseline:=GDScript.new();baseline.source_code=source[0];assert(baseline.reload()==OK)
  var previous_renderer=game.world_renderer;game.remove_child(previous_renderer);previous_renderer.free()
  game.world_renderer=baseline.new();game.add_child(game.world_renderer);game.world_renderer.setup(game);await settle()
 assert(game.traffic.rebuild(game.city.roads));game.traffic.seed_traffic();game.traffic.simulation.paused=true
 game.mode="select";game.drawer.hide();var results:Array=[]
 for scenario in ["normal","zoning","zoom-out"]:
  if scenario!="normal":game.select_category("build")
  game.map_zoom=.35 if scenario=="zoom-out" else .9;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(48,48));game.queue_redraw();await settle()
  var sample:Dictionary=await measure();sample.scenario=scenario;results.append(sample)
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(output.path_join(stage+"-"+scenario+".png"))==OK)
  print("ZONING_PERF ",stage," ",scenario," ",sample)
 game.map_zoom=.9;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(48,48));game.activate_tool("build_commercial");await settle()
 var eligible:Array=game.city.zoning_grid.parcels.values().filter(func(p):return p.v==0 and p.center.y>60 and p.center.x>30 and p.center.x<40)
 assert(not eligible.is_empty());var parcel:Dictionary=eligible[0];var first:Vector2=parcel.center;var last:Vector2=first+parcel.frame.along*28+parcel.frame.outward*3
 motion(game.screen(first));await settle();var frames:Array=[]
 var zoning_mesh=game.world_renderer.zones
 var mesh_generation:int=zoning_mesh.geometry_generation if zoning_mesh.has_method("update_palette") else 0
 var previous:=Time.get_ticks_usec();button(game.screen(first),true)
 for step in range(120):
  motion(game.screen(first.lerp(last,float(step)/119)));await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
 button(game.screen(last),false)
 for i in range(3):
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
 assert(game.city.zone_designations.size()>0 and not game.zoning_drag)
 if zoning_mesh.has_method("update_palette"):
  assert(zoning_mesh.geometry_generation==mesh_generation)
  for id in game.city.zone_designations:assert(zoning_mesh.palette_pixel(id).is_equal_approx(Color(game.ZONE_COLORS.commercial,.5)))
 game.activate_tool("select");await settle();await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(output.path_join(stage+"-painted.png"))==OK)
 var drag:=summarize(frames);drag.frame_ms=frames;drag.painted_cells=game.city.zone_designations.size();print("ZONING_DRAG ",stage," max_ms=",drag.max_ms)
 var state:={"stage":stage,"viewport":"1920x1080","vsync":false,"paused":true,"fixture_geometry":var_to_str([game.city.roads,game.city.buildings]),"parcel_count":game.city.zoning_grid.count(),"samples":results,"drag":drag,"drag_mesh_generation":mesh_generation,"chunk_count":zoning_mesh.blocks.size() if zoning_mesh.has_method("update_palette") else 0}
 var file:=FileAccess.open(output.path_join(stage+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 game.queue_free();await process_frame;print("ZONING_MESH_CAPTURE_PASS "+stage);quit()
