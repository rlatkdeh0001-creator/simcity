extends "D:/project/simcity/tools/validate_population_live.gd"
## All timings are test-only. Wall intervals and CPU work share the SAME process-frame index.
class Trace extends RefCounted:
 var enabled:=false
 var frame:Dictionary={}
 var rows:Array=[]
 var post_at:=0
 func begin():
  if not enabled:return
  var now:=Time.get_ticks_usec()
  if not frame.is_empty():
   frame.wall_us=now-int(frame.begin_us);frame.after_draw_us=now-post_at if post_at else 0;rows.append(frame)
  frame={"frame":Engine.get_process_frames(),"begin_us":now};post_at=0
 func post():
  if enabled and not frame.is_empty():post_at=Time.get_ticks_usec();frame.to_postdraw_us=post_at-int(frame.begin_us)
  if enabled and not frame.is_empty():frame.render_setup_us=RenderingServer.get_frame_setup_time_cpu()*1000
 func add(label:String,start:int):
  if enabled and not frame.is_empty():frame[label]=int(frame.get(label,0))+Time.get_ticks_usec()-start
class TimedPopulation extends "res://core/population.gd":
 var trace
 func advance(seconds:float,buildings:Array)->void:
  var t:=Time.get_ticks_usec();super.advance(seconds,buildings);trace.add("population_advance_us",t)
 func sync(buildings:Array)->void:
  var t:=Time.get_ticks_usec();super.sync(buildings);trace.add("population_sync_us",t)
 func match_jobs()->void:
  var t:=Time.get_ticks_usec();super.match_jobs();trace.add("population_jobs_us",t)
 func demand(buildings:Array)->Dictionary:
  var t:=Time.get_ticks_usec();var result:=super.demand(buildings);trace.add("population_demand_us",t);return result
class TimedCity extends "res://core/city_model.gd":
 var trace
 var legacy_utilities:=false
 func advance_society(seconds:float)->void:
  var t:=Time.get_ticks_usec();super.advance_society(seconds);trace.add("society_us",t)
 func advance_development(seconds:float)->Array[Dictionary]:
  var t:=Time.get_ticks_usec();var result:=super.advance_development(seconds);trace.add("development_us",t);return result
 func advance_utilities(seconds:float)->Dictionary:
  var t:=Time.get_ticks_usec()
  var result:Dictionary={"power":advance_power(seconds*Clock.SCALE/3600),"water":advance_water(seconds*Clock.SCALE/86400)} if legacy_utilities else super.advance_utilities(seconds)
  trace.add("utilities_us",t);return result
 func power_state()->Dictionary:
  var t:=Time.get_ticks_usec();var result:=super.power_state();trace.add("power_solve_us",t);return result
 func water_state()->Dictionary:
  var t:=Time.get_ticks_usec();var result:=super.water_state();trace.add("water_solve_us",t);return result
class TimedGame extends "res://bottom_ui.gd":
 var trace
 func _process(delta:float):
  var t:=Time.get_ticks_usec();super._process(delta);trace.add("root_process_us",t)
 func _draw():
  var t:=Time.get_ticks_usec();super._draw();trace.add("root_draw_us",t)
 func building_draw_order()->Array:
  var t:=Time.get_ticks_usec();var result:=super.building_draw_order();trace.add("building_order_us",t);return result
class TimedRenderer extends "res://core/cached_world_renderer.gd":
 var trace
 func _process(delta:float):
  var t:=Time.get_ticks_usec();super._process(delta);trace.add("world_process_us",t)
 func synchronize():
  var t:=Time.get_ticks_usec();super.synchronize();trace.add("world_sync_us",t)
 func paint(canvas:CanvasItem,kind:String):
  var t:=Time.get_ticks_usec();super.paint(canvas,kind);trace.add("paint_"+kind+"_us",t)
 func fallback(canvas:CanvasItem,record:Dictionary,anchor:Vector2):
  var t:=Time.get_ticks_usec();super.fallback(canvas,record,anchor);trace.add("fallback_us",t)
class TimedCamera extends "res://core/keyboard_camera.gd":
 var trace
 func _process(delta:float):
  var t:=Time.get_ticks_usec();super._process(delta);trace.add("keyboard_us",t)
func traced_city(trace):
 var city=TimedCity.new(100,100,20261114);city.trace=trace;city.population=TimedPopulation.new(20261114);city.population.trace=trace
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
func run():
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var trace:=Trace.new();game=TimedGame.new();game.trace=trace;game.city=traced_city(trace);game.paused=true;root.add_child(game);current_scene=game
 game.city.legacy_utilities="--legacy-utilities" in OS.get_cmdline_user_args()
 var old=game.world_renderer;game.remove_child(old);old.free();game.world_renderer=TimedRenderer.new();game.world_renderer.trace=trace;game.add_child(game.world_renderer);game.world_renderer.setup(game)
 old=game.keyboard_camera;game.remove_child(old);old.free();game.keyboard_camera=TimedCamera.new(game);game.keyboard_camera.trace=trace;game.add_child(game.keyboard_camera)
 print("TRACE_READY");pose();await settle();var warm:=Time.get_ticks_msec()+1000
 while Time.get_ticks_msec()<warm:await RenderingServer.frame_post_draw
 var initial_sprite_cache:int=game.building_views.cache.size()
 process_frame.connect(trace.begin);RenderingServer.frame_post_draw.connect(trace.post);game.paused=false;game.simulation_speed=1
 var start:=Time.get_ticks_usec();var phase:=-1;var active:=-1;var keys:Array=[KEY_D,KEY_S,KEY_A,KEY_W];var changes:=0;var previous:Vector2=game.origin
 print("TRACE_START");trace.enabled=true
 while Time.get_ticks_usec()-start<45e6:
  var next_phase:=int((Time.get_ticks_usec()-start)/2e6)
  if next_phase!=phase:
   var t:=Time.get_ticks_usec()
   if active!=-1:key(active,false)
   active=keys[next_phase%4];key(active,true);trace.add("input_us",t);phase=next_phase
  await RenderingServer.frame_post_draw
  if game.origin!=previous:changes+=1;previous=game.origin
 if active!=-1:key(active,false)
 print("TRACE_END rows=",trace.rows.size());trace.enabled=false;game.paused=true
 var frames:Array=[]
 for row in trace.rows:frames.append(float(row.wall_us)/1000)
 var result:Dictionary=summarize(frames);result.rows=trace.rows;result.population=game.city.population.people.size();result.camera_moving_frames=changes;result.game_seconds=game.city.clock.game_seconds;result.vehicle_count=0 if game.traffic.simulation==null else game.traffic.simulation.vehicles.size();result.traffic_running=game.traffic.running;result.sprite_cache=game.building_views.cache.size();result.sprite_busy=game.building_views.busy
 result.legacy_utilities=game.city.legacy_utilities;result.initial_sprite_cache=initial_sprite_cache
 var folder:="D:/project/simcity/docs/frame-spike-validation";DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder.path_join("legacy-trace.json" if game.city.legacy_utilities else "trace.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
 assert(result.population>=240 and changes>100 and result.rows.size()>1000)
 print("FRAME_TRACE_PASS rows=",trace.rows.size()," population=",result.population," moving=",changes," max_ms=",result.max_ms," p99_ms=",result.p99_ms)
 game.queue_free();await process_frame;quit()
