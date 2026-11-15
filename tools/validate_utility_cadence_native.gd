extends "res://tests/test_utility_cadence.gd"

func motion(p:Vector2):
 var event:=InputEventMouseMotion.new();event.position=p;event.global_position=p;root.push_input(event,true)
func run():
 root.size=Vector2i(1920,1080);root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
 var city=fixture();city.population_enabled=false;city.power.remove_wire(city.power.wires[0].id)
 var game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game)
 for i in range(6):await process_frame
 game.select_category("power");game.activate_tool("power_wire");game.map_zoom=1.3;game.origin=Vector2.ZERO;game.origin=Vector2(960,340)-game.screen((city.power.ports[0].position/4+Vector2(24,50))/2);game.queue_redraw()
 for i in range(4):await process_frame
 var first:Vector2=city.power.ports[0].position/4;var last:=Vector2(24,50)
 motion(game.screen(first))
 var press:=InputEventMouseButton.new();press.position=game.screen(first);press.global_position=press.position;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true);await process_frame
 motion(game.screen(last));await process_frame
 var release:=InputEventMouseButton.new();release.position=game.screen(last);release.global_position=release.position;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release,true)
 for i in range(3):await process_frame

 assert(city.power.wires.size()==1 and city.utilities.power_dirty and city.power_calls==1 and not city.buildings[0].has_power)
 game.paused=false;var end:=Time.get_ticks_msec()+3000
 while not city.buildings[0].has_power and Time.get_ticks_msec()<end:await RenderingServer.frame_post_draw
 assert(city.buildings[0].has_power and city.power_calls==2 and city.utilities.elapsed>=48 and city.utilities.elapsed<51)
 print("NATIVE_UTILITY_PASS real_mouse_wire=1 deferred_service_game_seconds=",city.utilities.elapsed," power_calculations=",city.power_calls," water_calculations=",city.water_calls," screenshots=0")
 game.queue_free();await process_frame;quit()
