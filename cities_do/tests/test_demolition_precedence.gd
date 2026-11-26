extends SceneTree

const City=preload("res://core/city_model.gd")
const CROSSING:=Vector2(56,52)
const COVERED:=Vector2(69,88)
const DECK_OVER_RAIL:=Vector2(82,52)
var checks:=0
var failures:=0
var game
var ids:Dictionary={}

func _initialize():run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)

func settle():
 await process_frame
 await process_frame

func key(code:Key):
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.pressed=down
  root.push_input(event,true)
 await settle()

func mouse(position:Vector2,button:=0,down:=false):
 var event:InputEventMouse
 if button==0:event=InputEventMouseMotion.new()
 else:
  var click:=InputEventMouseButton.new();click.button_index=button;click.pressed=down;event=click
 event.position=position;event.global_position=position
 root.push_input(event,true)

func click(button:Control):
 var point:=button.get_global_rect().get_center()
 mouse(point);mouse(point,MOUSE_BUTTON_LEFT,true);mouse(point,MOUSE_BUTTON_LEFT,false)
 await settle()

func tool(name:String):
 await click(game.find_child(name,true,false))

func train_tab():
 await tool("Bottom_transport")
 await click(game.transport_tabs.get_child(2))

func view_is(below:bool)->bool:
 return game.mode=="demolish" and game.transit_view.underground==below and game.transit_view.metro_layer.visible==below

func hover_at(cell:Vector2,height:float)->Dictionary:
 mouse(game.transit_view.screen_point(cell,height))
 return game.demolition_hover

func expect(cell:Vector2,height:float,kind:String,id:int,label:String):
 var hit:=hover_at(cell,height)
 check(hit.get("kind","")==kind and hit.get("id",-1)==id,
  "%s (got %s#%s)"%[label,hit.get("kind","none"),hit.get("id",-1)])

func fixture():
 var city=City.new(128,114);city.funds=100000000
 var surface_road:Dictionary=city.add_road(PackedVector2Array([Vector2(56,32),Vector2(56,66)]))
 var surface_rail:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(18,52),Vector2(102,52)]))
 var road_tunnel:Dictionary=city.add_elevated_road(PackedVector2Array([Vector2(8,88),Vector2(40,88),Vector2(94,88)]),PackedFloat64Array([0,-10,-10]))
 # Author an existing equal-depth crossing without relaxing current construction clearance.
 var rail_city=City.new(128,114);rail_city.funds=100000000
 var rail_tunnel:Dictionary=rail_city.add_transit_route(PackedVector2Array([Vector2(69,10),Vector2(69,82),Vector2(69,104)]),"rail",true,PackedFloat64Array([0,-10,-10]))
 var offset:=Vector2.ONE*(10*sqrt(1.5)/4)
 # An elevated road covers the ground rail in screen space at a point away from the level crossing.
 var deck:Dictionary=city.add_elevated_road(PackedVector2Array([Vector2(75,52)+offset,Vector2(98,52)+offset]),PackedFloat64Array([10,10]))
 var results:=[surface_road,surface_rail,road_tunnel,rail_tunnel,deck]
 check(results.all(func(item):return item.ok),"road/rail fixtures: %s"%str(results.map(func(item):return item.get("reason",""))))
 if failures:return null
 var buried:Dictionary=rail_tunnel.route.duplicate(true)
 buried.id=int(surface_rail.route.id)+1
 city.transit_routes.append(buried)
 ids={"road":city.roads[0].parcel_id,"rail":surface_rail.route.id,"tunnel":road_tunnel.new_roads[0].parcel_id,"buried":buried.id,"deck":deck.new_roads[0].parcel_id}
 return city

func run():
 root.size=Vector2i(1600,900)
 var city=fixture()
 if city==null:finish();return
 game=load("res://main.tscn").instantiate();game.city=city;game.paused=true
 root.add_child(game);current_scene=game
 await settle()
 game.map_zoom=.75
 game.origin=Vector2(715,365)-game.transit_view.project_point(Vector2(56,68))*game.map_zoom
 await settle()

 await tool("BulldozerButton")
 check(view_is(false),"initial bulldozer opens on the surface")
 expect(CROSSING,0,"transit_route",ids.rail,"initial surface tie keeps default rail")
 await key(KEY_PAGEDOWN)
 expect(COVERED,-10,"road",ids.tunnel,"initial covered tie keeps default road tunnel")

 await tool("Bottom_road")
 await key(KEY_PAGEDOWN)
 check(game.mode=="road" and game.transit_view.underground,"road tool enters the underground view")
 await tool("BulldozerButton")
 check(view_is(true),"road to bulldozer retains underground view")
 expect(COVERED,-10,"road",ids.tunnel,"road tool wins a covered tie")
 check(hover_at(CROSSING,0).is_empty(),"road preference never picks a hidden surface road")
 await key(KEY_PAGEUP)
 expect(CROSSING,0,"road",ids.road,"road tool wins a ground tie after PgUp")

 await tool("Bottom_road")
 await tool("Bottom_build")
 await tool("BulldozerButton")
 expect(CROSSING,0,"transit_route",ids.rail,"unrelated category clears prior road preference")

 await train_tab()
 await tool("Tool_rail")
 await key(KEY_PAGEDOWN)
 check(game.mode=="rail" and game.transit_view.underground,"rail tool enters the underground view")
 await tool("BulldozerButton")
 check(view_is(true),"rail to bulldozer retains underground view")
 expect(COVERED,-10,"transit_route",ids.buried,"rail tool wins a covered tie")
 check(hover_at(CROSSING,0).is_empty(),"rail preference never picks a hidden surface route")
 await key(KEY_PAGEUP)
 expect(CROSSING,0,"transit_route",ids.rail,"rail tool wins a ground tie")
 expect(DECK_OVER_RAIL,0,"road",ids.deck,"higher deck still wins over preferred ground rail")

 await train_tab()
 var controls:Control=game.find_child("RailHeightControls",true,false)
 await click(controls.mode_buttons[-10])
 await tool("BulldozerButton")
 await key(KEY_PAGEDOWN)
 expect(COVERED,-10,"transit_route",ids.buried,"rail height control directly before bulldozer prefers rail")
 await train_tab()
 await click(game.find_child("RailHeightControls",true,false).mode_buttons[0])
 await click(game.drawer_box.get_child(-1))
 await tool("BulldozerButton")
 await key(KEY_PAGEDOWN)
 expect(COVERED,-10,"road",ids.tunnel,"closing the rail tray does not leave a stale rail height preference")

 await train_tab()
 await tool("Facility_train-station-01")
 check(game.mode=="public_placement","train station placement is active before the bulldozer")
 await tool("BulldozerButton")
 await key(KEY_PAGEDOWN)
 expect(COVERED,-10,"transit_route",ids.buried,"train station placement directly before bulldozer prefers rail")
 await train_tab()
 await tool("Tool_rail")
 await tool("Bottom_build")
 await tool("BulldozerButton")
 await key(KEY_PAGEDOWN)
 expect(COVERED,-10,"road",ids.tunnel,"unrelated category clears prior rail preference")

 # Real press/release uses the same equal-height choice as hover, not the default rail.
 await tool("Bottom_road")
 await tool("BulldozerButton")
 await key(KEY_PAGEUP)
 var point:Vector2=game.transit_view.screen_point(CROSSING,0)
 mouse(point);mouse(point,MOUSE_BUTTON_LEFT,true)
 check(game.demolition_press.get("id",-1)==ids.road and game.demolition_press.get("kind","")=="road","viewport press locks the preferred road")
 mouse(point,MOUSE_BUTTON_LEFT,false)
 await settle()
 check(not city.roads.any(func(record):return record.parcel_id==ids.road) and not city.get_transit_route(ids.rail).is_empty(),"viewport release removes only the preferred road")
 finish()

func finish():
 if game!=null and game.city.simulation!=null:game.city.simulation.shutdown()
 print("DEMOLITION_PRECEDENCE checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
