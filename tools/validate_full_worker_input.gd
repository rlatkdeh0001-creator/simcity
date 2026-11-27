extends SceneTree
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;push_error(label)
func _initialize():run.call_deferred()
func click(position:Vector2):
 var down:=InputEventMouseButton.new();down.position=position;down.global_position=position;down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true
 root.push_input(down);await process_frame
 var up:=InputEventMouseButton.new();up.position=position;up.global_position=position;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
 root.push_input(up);await process_frame
func run():
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.paused=true
 await process_frame;await process_frame
 var city=game.city;var sim=city.simulation
 while not sim.is_ready():await process_frame
 check(DisplayServer.get_name()!="headless" and root.visible,"actual graphical game window is visible")
 sim.worker.SetValidationGate(true);city.advance_society(2)
 var clock_before:float=city.clock.game_seconds
 var police_button:Button=game.categories.filter(func(button):return button.name=="Bottom_police")[0]
 await click(police_button.get_global_rect().get_center())
 var slot_ids:Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("slot_id")).map(func(n):return n.get_meta("slot_id"))
 check(slot_ids.has("police.small"),"real viewport category mouse press/release works while worker is gated")
 var zoom_before:float=game.map_zoom
 var wheel:=InputEventMouseButton.new();wheel.position=Vector2(600,200);wheel.global_position=wheel.position;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
 root.push_input(wheel);await process_frame
 check(game.map_zoom!=zoom_before,"camera wheel remains interactive while simulation is busy")
 check(sim.worker.IsBusy() and city.clock.game_seconds==clock_before,"busy worker keeps published logical time frozen during UI input")
 var response:Dictionary=city.add_road(PackedVector2Array([Vector2(10,30),Vector2(50,30)]))
 check(response.get("queued",false) and city.roads.is_empty(),"structural editor intent queues without allocating a road while busy")
 sim.worker.SetValidationGate(false);sim.validation_publish();sim.resume();city.advance_society(2);sim.validation_publish()
 check(city.roads.size()==1 and sim.queued_edit_count()==0,"queued structural edit replays at the next boundary and reaches worker")
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_size()==Vector2(root.size),"native viewport rendered the actual game at requested window dimensions")
 game.queue_free();await process_frame
 print("FULL_WORKER_NATIVE_INPUT checks=%d failed=%d no_screenshots=true"%[checks,failed])
 quit(1 if failed else 0)
