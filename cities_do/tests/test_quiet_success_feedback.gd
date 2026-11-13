extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func press(game,point: Vector2):
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=game.screen(point);return event
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);await process_frame
 game.map_zoom=.75;game.origin=Vector2(850,20);game.road_drawer.set_kind("legacy")
 game.message="previous error";game.drawing=true;game.stroke=PackedVector2Array([Vector2(20,30),Vector2(40,30)]);game.finish_road()
 verify(game.city.roads.size()==1 and game.message.is_empty(),"successful legacy road construction clears status instead of showing a completion notice")
 game.city.add_road(PackedVector2Array([Vector2(10,70),Vector2(40,70)]))
 game.mode="demolish";game.message="previous error";game._unhandled_input(press(game,Vector2(25.3,30)))
 verify(game.city.roads.size()==2,"road demolition press is preview-only until release")
 var release: InputEventMouseButton=press(game,Vector2(25.3,30));release.pressed=false;game._unhandled_input(release)
 verify(game.city.roads.size()==1 and game.message.is_empty(),"actual demolition release clears the success HUD while removing the full selected span")
 var diagnostic: Dictionary=game.city.demolish("road",game.city.roads[0].parcel_id)
 verify(diagnostic.ok and diagnostic.reason=="철거 완료","internal model success diagnostics are preserved; suppression is presentation-only")
 game.drawing=true;game.stroke=PackedVector2Array();game.finish_road()
 verify(not game.message.is_empty(),"failed construction continues to expose its actionable error")
 game.city=City.new(100,100);game.city.add_road(PackedVector2Array([Vector2(10,30.5),Vector2(90,30.5)]))
 game.power_overlay.tab_open=true;game.mode="power_plant";game.power_overlay.handle_input(press(game,Vector2(20,27)))
 verify(game.city.power.plants.size()==1 and game.power_overlay.instruction.text.is_empty(),"successful power facility placement has no success notice")
 game.water_overlay.tab_open=true;game.mode="water_supply";game.water_overlay.handle_input(press(game,Vector2(40,27)))
 verify(game.city.water.facilities.size()==1 and game.water_overlay.instruction.text.is_empty(),"successful water facility placement has no success notice")
 game.city.add_power_plant(Vector2(60,27));game.power_overlay.drawing=true;game.power_overlay.stroke=PackedVector2Array([game.city.power.plants[0].position,game.city.power.plants[1].position]);game.power_overlay.finish_wire()
 verify(game.city.power.wires.size()==1 and game.power_overlay.instruction.text.is_empty(),"successful underground wire construction has no completion notice")
 game.city.add_water_facility(Vector2(70,27),"sewage",2400);game.water_overlay.drawing=true;game.water_overlay.stroke=PackedVector2Array([game.city.water.facilities[0].position,game.city.water.facilities[1].position]);game.water_overlay.finish_pipe()
 verify(game.city.water.geometry.wires.size()==1 and game.water_overlay.instruction.text.is_empty(),"successful paired water/sewage construction has no completion notice")
 game.power_overlay.drawing=true;game.power_overlay.stroke=PackedVector2Array();game.power_overlay.finish_wire()
 verify(not game.power_overlay.instruction.text.is_empty(),"wire failure messages remain available")
 game.toggle_traffic();verify(game.traffic.running,"traffic fixture starts the actual lane simulation")
 game.toggle_traffic();verify(not game.traffic.running and game.message.is_empty(),"stopping traffic has no success-state announcement")
 var added: Dictionary=game.city.add_building(30,27);verify(added.ok,"growth fixture uses a genuinely placeable roadside building")
 if added.ok:
  game.selected=added.building.id;added.building.score=game.city.config.score_threshold;game.activate_tool("upgrade")
  verify(added.building.level>1 and game.message.is_empty(),"internal developer growth still operates without a success-count message")
 game.queue_free();await process_frame
 print("RESULT %d/%d quiet success feedback checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
