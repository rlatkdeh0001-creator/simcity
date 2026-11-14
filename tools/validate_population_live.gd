extends "D:/project/simcity/tools/capture_zoning_mesh_perf.gd"
const Model=preload("res://core/city_model.gd")
class LiveCity extends "res://core/city_model.gd":
 var society_max_us:=0
 func advance_society(seconds:float)->void:
  var start:=Time.get_ticks_usec();super.advance_society(seconds);society_max_us=maxi(society_max_us,Time.get_ticks_usec()-start)
func key(code:int,pressed:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;root.push_input(event,true)
func renderer_at(commit:String):
 var text:Array=[];assert(OS.execute("git",["-C","D:/project/simcity","show",commit+":cities_do/core/cached_world_renderer.gd"],text,true)==0)
 var script:=GDScript.new();script.source_code=text[0];assert(script.reload()==OK);return script
func live_city():
 var city=LiveCity.new(100,100,20261114)
 for y in [28,48,68]:assert(city.add_road(PackedVector2Array([Vector2(24,y),Vector2(72,y)])).ok)
 for x in [28,48,68]:assert(city.add_road(PackedVector2Array([Vector2(x,24),Vector2(x,72)])).ok)
 for parcel in city.zoning_grid.parcels.values():
  if parcel.v!=0 or parcel.u%2!=0:continue
  var result:Dictionary=city.add_building_at(parcel.center)
  if result.ok and city.buildings.size()==60:break
 assert(city.buildings.size()==60)
 for i in range(120):
  var h:Dictionary={"id":i+1,"home_id":city.buildings[i/2].id};city.population.households.append(h)
  for j in range(2):city.population.add_person(h,(i*2+j)%5,30,"native-validation")
 city.population.next_household=121;city.population.sync(city.buildings)
 for id in city.zoning_grid.parcels.keys().slice(0,32):city.zone_designations[id]="residential"
 assert(city.population.people.size()==240);return city
func pose():
 game.mode="select";game.drawer.hide();game.map_zoom=.9;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(48,48));game.queue_redraw()
func run():
 var folder:="D:/project/simcity/docs/population-optimization-validation"
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 game=load("res://main.tscn").instantiate();game.city=fixture();game.paused=true;root.add_child(game);current_scene=game;await settle()
 assert(game.traffic.rebuild(game.city.roads));game.traffic.seed_traffic();game.traffic.simulation.paused=true
 var basic:Array=[]
 for commit in ["2ea4105","28ebcc7"]:
  var previous=game.world_renderer;game.remove_child(previous);previous.free()
  game.world_renderer=renderer_at(commit).new();game.add_child(game.world_renderer);game.world_renderer.setup(game);pose();await settle()
  var sample:Dictionary=await measure();sample.renderer=commit;basic.append(sample);print("BASIC_FPS ",JSON.stringify(sample))
 game.queue_free();await process_frame
 game=load("res://main.tscn").instantiate();game.city=live_city();game.paused=true;root.add_child(game);current_scene=game;pose();await settle()
 var warm:=Time.get_ticks_msec()+1000
 while Time.get_ticks_msec()<warm:await RenderingServer.frame_post_draw
 game.paused=false;game.simulation_speed=1
 var prior:=Time.get_ticks_usec();var begin:=prior;var frames:Array=[];var phase:=-1;var active:=-1;var keys:Array=[KEY_D,KEY_S,KEY_A,KEY_W];var changes:=0;var old_origin:Vector2=game.origin
 while Time.get_ticks_usec()-begin<30e6:
  var next_phase:=int((Time.get_ticks_usec()-begin)/2e6)
  if next_phase!=phase:
   if active!=-1:key(active,false)
   active=keys[next_phase%4];key(active,true);phase=next_phase
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append((now-prior)/1000.0);prior=now
  if game.origin!=old_origin:changes+=1;old_origin=game.origin
 if active!=-1:key(active,false)
 var live:Dictionary=summarize(frames);live.frame_ms=frames;live.population=game.city.population.people.size();live.camera_moving_frames=changes;live.game_seconds=game.city.clock.game_seconds;live.society_max_ms=game.city.society_max_us/1000.0
 assert(live.population>=240 and changes>100 and live.game_seconds>=700 and Engine.get_frames_drawn()>100)
 var file:=FileAccess.open(folder.path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"basic_paused_same_fixture":basic,"live_unpaused_30_seconds":live,"viewport":"1920x1080","vsync":false,"screenshots_requested":false},"  "));file.close()
 print("LIVE_30_SECONDS population=",live.population," moving_frames=",changes," max_ms=",live.max_ms," p99_ms=",live.p99_ms," society_max_ms=",live.society_max_ms)
 game.queue_free();await process_frame;print("NATIVE_POPULATION_PASS");quit()
