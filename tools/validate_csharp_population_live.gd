extends "D:/project/simcity/tools/validate_population_live.gd"
func run():
 create_timer(55).timeout.connect(func():push_error("Native validation deadline");quit(1))
 var folder:="D:/project/simcity/docs/csharp-population-validation"
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var city=live_city();var workplace:Dictionary={}
 for parcel in city.zoning_grid.parcels.values():
  var result:Dictionary=city.add_building_at(parcel.center,"commercial")
  if result.ok:workplace=city.buildings[-1];break
 assert(not workplace.is_empty());city.population.sync(city.buildings);city.population.release_compatibility_views()
 game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game);current_scene=game;pose();await settle()
 assert(game.city.population.backend_name()=="CSharp" and not game.city.population.get("_views"))
 var center:=Vector2(workplace.x+workplace.size*.5,workplace.y+workplace.size*.5)
 game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(center);game.queue_redraw();await settle()
 var anchor:Vector2=game.screen(center);var point:=Vector2(-1,-1)
 for y in range(-100,24,4):
  for x in range(-100,104,4):
   var candidate:Vector2=anchor+Vector2(x,y)
   if game.pick_rendered_building(candidate).get("id",-1)==workplace.id:point=candidate;break
  if point.x>=0:break
 assert(point.x>=0);motion(point);button(point,true);await settle();button(point,false);await settle()
 assert(game.selected==workplace.id and game.labor_panel.visible and not game.city.population.get("_views"),"selected=%s target=%s panel=%s views=%s mode=%s hovered=%s"%[game.selected,workplace.id,game.labor_panel.visible,game.city.population.get("_views"),game.mode,root.gui_get_hovered_control()])
 assert(game.labor_rings.work==game.city.population.workplace_info(workplace.id))
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
 var live:Dictionary=summarize(frames);live.frame_ms=frames;live.stats=game.city.population.stats();live.camera_moving_frames=changes;live.game_seconds=game.city.clock.game_seconds;live.society_max_ms=game.city.society_max_us/1000.0
 assert(live.stats.population>=240 and changes>100 and live.game_seconds>=700 and Engine.get_frames_drawn()>100)
 assert(not game.city.population.get("_views") and root.get_texture().get_size()==Vector2(1920,1080))
 var file:=FileAccess.open(folder.path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"live":live,"viewport":"1920x1080","vsync":false,"native_workplace_mouse_selection":true,"managed_production_storage":true,"screenshots_requested":false},"  "));file.close()
 print("CSHARP_NATIVE_PASS ",JSON.stringify({"stats":live.stats,"frames":live.frames,"moving_frames":changes,"game_seconds":live.game_seconds,"max_ms":live.max_ms,"p99_ms":live.p99_ms,"society_max_ms":live.society_max_ms}))
 game.queue_free();await process_frame;quit()
