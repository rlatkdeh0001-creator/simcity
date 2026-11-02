extends SceneTree
const City = preload("res://core/city_model.gd")
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, name_value: String):
 checks+=1
 if value: print("PASS "+name_value)
 else:
  failed+=1
  push_error("FAIL "+name_value)
func fixture() -> RefCounted:
 var city := City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]))
 city.add_building(24,26)
 city.add_power_plant(Vector2(16,26),300)
 city.add_water_facility(Vector2(40,26),"water",1000)
 city.add_water_facility(Vector2(70,26),"sewage",2400)
 city.power.add_wire(PackedVector2Array([Vector2(68,108),Vector2(284,108)]))
 city.water.add_pipe(PackedVector2Array([Vector2(164,108),Vector2(284,108)]))
 return city
func sizes(city) -> Dictionary:
 return {"building":city.buildings.size(),"road":city.roads.size(),"power_plant":city.power.plants.size(),"power_wire":city.power.wires.size(),"water_facility":city.water.facilities.size(),"water_pipe":city.water.geometry.wires.size()}
func run():
 if test_model()!=true: verify(false,"model checks finish")
 if test_roads()!=true: verify(false,"road checks finish")
 if await test_ui()!=true: verify(false,"UI checks finish")
 print("RESULT %d/%d demolition checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
func test_model() -> bool:
 for kind in ["building","road","power_plant","power_wire","water_facility","water_pipe"]:
  var city=fixture()
  var before := sizes(city)
  var id: int={"building":city.buildings[0].id,"road":city.roads[0].parcel_id,"power_plant":city.power.plants[0].id,"power_wire":city.power.wires[0].id,"water_facility":city.water.facilities[0].id,"water_pipe":city.water.geometry.wires[0].id}[kind]
  var result: Dictionary=city.demolish(kind,id)
  var after := sizes(city)
  var exact: bool=result.ok and after[kind]==before[kind]-1
  for other in before:
   if other!=kind: exact=exact and after[other]==before[other]
  verify(exact,"shared demolition removes only the selected "+kind)
  verify(city.funds==50000,"no invented charge or refund for "+kind)
  verify(not city.demolish(kind,id).ok,"already removed "+kind+" is safe")
 var city=fixture()
 var before := sizes(city)
 verify(not city.demolish("invalid",1).ok and sizes(city)==before,"unknown target cannot delete anything")
 var building_id: int=city.buildings[0].id
 city.demolish("building",building_id)
 verify(not city.power_state().consumers.has(building_id) and not city.water_state().consumers.has(building_id),"demolished building leaves both utility demand lists immediately")
 return true
func test_roads() -> bool:
 var city := City.new(100,100)
 for y in [20,50,80]: city.add_road(PackedVector2Array([Vector2(10,y),Vector2(45,y)]))
 var built := {}
 for parcel in city.zoning_grid.parcels.values():
  if parcel.frame.road_index!=1: continue
  var result: Dictionary=city.add_building_at(parcel.center)
  if result.ok:
   built=result.building
   break
 verify(not built.is_empty(),"road-local building created on surviving road")
 if built.is_empty():return false
 var old_frame: String=built.frame.id
 var old_shape: PackedVector2Array=city.footprint(built)
 city.demolish("road",0)
 verify(city.zoning_grid.frames.has(old_frame) and city.footprint(built)==old_shape,"removing an earlier road preserves remaining road-local frame and building position")
 verify(city.parcel_placement_error(built.frame,built.u,built.v,2,built.id)=="","surviving building retains valid zoning frontage")
 verify(not city.zoning_grid.frames.values().any(func(frame):return frame.road_index==0),"deleted road leaves no phantom placement tiles")
 city.add_road(PackedVector2Array([Vector2(60,20),Vector2(90,20)]))
 verify(city.roads[-1].parcel_id==3,"road IDs are not reused after demolition")
 var single := City.new(100,100)
 single.add_road(PackedVector2Array([Vector2(10,20),Vector2(40,20)]))
 single.add_building(20,17)
 single.demolish("road",0)
 verify(single.zoning_grid.count()==0 and single.buildings.size()==1,"last road removal clears revealed tiles without deleting other buildings")
 return true
func press(scene, cell: Vector2):
 var click := InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=scene.screen(cell)
 scene._unhandled_input(click)
func test_ui() -> bool:
 root.size=Vector2i(1280,820)
 var scene=load("res://bottom_ui_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 await process_frame
 await process_frame
 var saved_tiles: int=scene.city.zoning_grid.count()
 verify(saved_tiles>0 and scene.visible_zoning_parcels().is_empty(),"placement tiles hidden by default without deleting zoning data")
 verify(scene.NAMES.build=="구획","construction tab renamed to zoning")
 for category in ["build","road"]:
  scene.select_category(category)
  verify(not scene.visible_zoning_parcels().is_empty(),"placement tiles visible in "+category+" tab")
 for category in ["power","water","environment","park","transport","other"]:
  scene.select_category(category)
  verify(scene.visible_zoning_parcels().is_empty(),"placement tiles hidden in "+category+" tab")
 verify(scene.city.zoning_grid.count()==saved_tiles,"switching tabs preserves all parcel geometry")
 verify(scene.bulldozer.get_global_rect().position.x>scene.categories[-1].get_global_rect().end.x,"one bulldozer button sits to the right of category toolbar")
 scene.select_category("road")
 scene.bulldozer.pressed.emit()
 verify(scene.mode=="demolish" and not scene.drawer.visible and scene.visible_zoning_parcels().is_empty(),"bulldozer activates shared tool and hides tiles and drawer")
 var before: int=scene.city.buildings.size()
 press(scene,Vector2(26,26))
 verify(scene.city.buildings.size()==before-1 and scene.mode=="demolish","one map click demolishes one actual building and keeps tool active")
 var blank: Dictionary=scene.demolition_target(scene.screen(Vector2(2,2)))
 verify(blank.is_empty(),"empty map space is not a demolition target")
 scene.select_category("water")
 verify(not scene.drawer_box.get_children().any(func(child):return child is Button and "erase" in child.name),"water tab has no separate demolition tool")
 scene.bulldozer.pressed.emit()
 var pipe_count: int=scene.city.water.geometry.wires.size()
 press(scene,Vector2(50,61))
 verify(scene.city.water.geometry.wires.size()==pipe_count-1 and scene.city.roads.size()==6,"visible paired pipe selected over overlapping road and both channels removed together")
 scene.select_category("power")
 verify(not scene.drawer_box.get_children().any(func(child):return child is Button and "erase" in child.name),"power tab has no separate demolition tool")
 scene.bulldozer.pressed.emit()
 var road_target: Dictionary=scene.demolition_target(scene.screen(Vector2(50,61)))
 verify(road_target.get("kind","")=="road","hidden water pipe cannot intercept a road click in power view")
 var escape := InputEventKey.new()
 escape.pressed=true
 escape.keycode=KEY_ESCAPE
 scene._unhandled_key_input(escape)
 verify(scene.mode!="demolish" and not scene.bulldozer.button_pressed,"escape cancels bulldozer mode")
 for building in scene.city.buildings.duplicate(): scene.city.demolish("building",building.id)
 scene.fit_preview()
 verify(is_finite(scene.map_zoom) and scene.origin.is_finite(),"camera remains usable after all buildings are demolished")
 scene.queue_free()
 await process_frame
 return true
