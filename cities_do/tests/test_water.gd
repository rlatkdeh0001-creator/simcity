extends SceneTree
const Grid = preload("res://core/water_grid.gd")
const Flow = preload("res://core/water_flow.gd")
const City = preload("res://core/city_model.gd")
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, label: String):
 checks+=1
 if value: print("PASS "+label)
 else:
  failed+=1
  push_error("FAIL "+label)
func pipe(grid, points: Array, commit: bool = true) -> Dictionary:
 return grid.add_pipe(PackedVector2Array(points),commit)
func consumers() -> Array:
 return [{"id":1,"position":Vector2(96,150),"demand_m3_day":100.0},{"id":2,"position":Vector2(256,150),"demand_m3_day":140.0}]
func fixture() -> RefCounted:
 var g := Grid.new()
 g.add_facility(Vector2(64,128),"water",240)
 g.add_facility(Vector2(256,128),"sewage",192)
 pipe(g,[Vector2(64,128),Vector2(256,128)])
 return g
func run():
 for method in ["test_geometry","test_service","test_exchange","test_metering","test_flow","test_city"]:
  if call(method)!=true: verify(false,method+" completes")
 if await test_ui()!=true: verify(false,"UI completes")
 if await test_demo()!=true: verify(false,"demo completes")
 print("RESULT %d/%d water checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
func test_geometry() -> bool:
 var g := Grid.new()
 verify(g.add_facility(Vector2(64,128),"invalid",100)==-1,"unknown facility rejected")
 verify(g.add_facility(Vector2(64,128),"water",-1)==-1,"negative capacity rejected")
 verify(g.add_facility(Vector2(INF,0),"water",100)==-1,"nonfinite facility rejected")
 g.add_facility(Vector2(64,128),"water",240)
 verify(g.solve(consumers()).water_supplied_m3_day==0,"facility alone without constructed pipes cannot supply")
 verify(not pipe(g,[Vector2(100,100),Vector2(200,100)]).ok,"paired pipes require a real anchor")
 verify(not pipe(g,[Vector2(64,128),Vector2(500,128)]).ok,"out of bounds pipe rejected")
 var result: Dictionary=pipe(g,[Vector2(64,128),Vector2(256,128)],false)
 verify(result.ok and g.geometry.wires.is_empty(),"preview creates neither channel")
 var points := PackedVector2Array([Vector2(64,128),Vector2(256,128)])
 result=g.add_pipe(points)
 points[-1]=Vector2(300,300)
 verify(result.ok and g.geometry.wires.size()==1 and g.geometry.wires[0].points[-1]==Vector2(256,128),"one owned geometry atomically constructs both channels")
 g.geometry.rebuild()
 var service: Array=g.geometry.nodes.filter(func(n):return n.service and not g.geometry.adjacency[n.id].is_empty())
 verify(service.size()==7 and service[1].position.distance_to(service[0].position)==32,"shared supply and collection points spaced 32m")
 var radial := [{"id":3,"position":Vector2(160,192),"demand_m3_day":1},{"id":4,"position":Vector2(160,192.01),"demand_m3_day":1}]
 var state: Dictionary=g.solve(radial)
 verify(state.consumers[3].has_water and not state.consumers[4].connected,"64m supply boundary in world metres")
 var branch: Dictionary=pipe(g,[Vector2(160,128),Vector2(160,256)])
 verify(g.solve([{"id":5,"position":Vector2(160,300),"demand_m3_day":10}]).consumers[5].has_water,"paired branch extends service")
 g.remove_pipe(branch.wire.id)
 verify(not g.solve([{"id":5,"position":Vector2(160,300),"demand_m3_day":10}]).consumers[5].has_water,"branch removal stops distant supply")
 g.remove_pipe(result.wire.id)
 verify(g.solve(consumers()).water_supplied_m3_day==0 and g.geometry.wires.is_empty(),"removal atomically disconnects both pipes")
 return true
func test_service() -> bool:
 var g=fixture()
 var state: Dictionary=g.solve(consumers())
 verify(state.consumers[1].has_water and state.consumers[2].has_water,"near and far buildings get simultaneous water before marker arrival")
 verify(state.consumers[1].has_sewage and state.consumers[2].has_sewage,"both buildings receive simultaneous sewage service")
 verify(is_equal_approx(state.water_supplied_m3_day,240) and is_equal_approx(state.sewage_generated_m3_day,192),"supply counted once and 80 percent returns as sewage")
 verify(is_equal_approx(state.sewage_treated_m3_day,192) and state.unhandled_sewage_m3_day==0,"treated water remains sewage output and never becomes drinking production")
 g.set_capacity(g.facilities[0].id,120)
 state=g.solve(consumers())
 verify(is_equal_approx(state.consumers[1].water_ratio,.5) and is_equal_approx(state.consumers[2].water_ratio,.5),"insufficient water shared proportionally regardless of distance")
 verify(is_equal_approx(state.sewage_generated_m3_day,96),"sewage follows actual delivered water not unmet demand")
 g.set_capacity(g.facilities[0].id,240)
 g.set_capacity(g.facilities[1].id,96)
 state=g.solve(consumers())
 verify(is_equal_approx(state.consumers[1].sewage_ratio,.5) and is_equal_approx(state.consumers[2].sewage_ratio,.5) and is_equal_approx(state.unhandled_sewage_m3_day,96),"sewage bottleneck reported without silently deleting waste")
 verify(state.consumers[1].has_water and not state.consumers[1].has_sewage,"drinking service and sewage treatment are separate states")
 g.remove_facility(g.facilities[1].id)
 state=g.solve(consumers())
 verify(state.water_supplied_m3_day==240 and state.sewage_treated_m3_day==0,"removing treatment facility leaves water intact but stops treatment")
 verify(not g.set_capacity(g.facilities[0].id,NAN),"nonfinite capacity update rejected")
 g.remove_facility(g.facilities[0].id)
 verify(g.solve(consumers()).water_supplied_m3_day==0,"removing last water source stops supply immediately")
 return true
func test_exchange() -> bool:
 var g=fixture()
 var link: Dictionary=pipe(g,[Vector2(256,128),Vector2(400,128),Vector2(400,200)])
 g.set_capacity(g.facilities[0].id,100)
 g.set_capacity(g.facilities[1].id,64)
 var state: Dictionary=g.solve(consumers())
 verify(is_equal_approx(state.water_import_m3_day,140) and state.water_supplied_m3_day==240,"neighbor automatically imports water deficit")
 verify(is_equal_approx(state.sewage_treated_m3_day,64) and is_equal_approx(state.sewage_export_m3_day,128),"sewage remaining after local treatment is sent to neighbor")
 verify(state.consumers[1].has_sewage and state.unhandled_sewage_m3_day==0,"external disposal can complete sewer service")
 g.set_capacity(g.facilities[0].id,300)
 state=g.solve(consumers())
 verify(state.water_import_m3_day==0 and is_equal_approx(state.water_export_m3_day,60),"internal water consumption precedes surplus export")
 g.remove_pipe(link.wire.id)
 state=g.solve(consumers())
 verify(state.water_export_m3_day==0 and state.sewage_export_m3_day==0 and state.unhandled_sewage_m3_day>0,"boundary disconnection stops both exchanges")
 var external := Grid.new()
 pipe(external,[Vector2(0,200),Vector2(256,200)])
 state=external.solve([{"id":1,"position":Vector2(160,200),"demand_m3_day":10000}])
 verify(state.water_import_m3_day==10000 and state.sewage_export_m3_day==8000,"neighbor-only system supplies and collects without invented contract quota")
 return true
func test_metering() -> bool:
 var g=fixture()
 var before: Dictionary=g.solve(consumers())
 g.solve(consumers())
 verify(g.supplied_m3==0 and g.treated_m3==0,"queries do not meter water twice")
 g.advance(consumers(),.5)
 verify(is_equal_approx(g.supplied_m3,120) and is_equal_approx(g.treated_m3,96),"rates times game days meter actual m3")
 g.advance(consumers(),-1)
 verify(g.supplied_m3==120,"negative time cannot reverse volume meters")
 var a=fixture()
 var b=fixture()
 for i in range(30): a.advance(consumers(),1.0/30)
 for i in range(60): b.advance(consumers(),1.0/60)
 verify(is_equal_approx(a.supplied_m3,b.supplied_m3) and is_equal_approx(a.treated_m3,b.treated_m3),"30 and 60 updates produce same supply and treatment volumes")
 verify(before.water_supplied_m3_day==g.solve(consumers()).water_supplied_m3_day,"metering does not change network capacities")
 return true
func test_flow() -> bool:
 var g=fixture()
 var state: Dictionary=g.solve(consumers())
 var copy := state.duplicate(true)
 var direction_water := true
 for route in state.water_routes: direction_water=direction_water and route.points[0]==Vector2(64,128)
 var direction_sewage := true
 for route in state.sewage_routes: direction_sewage=direction_sewage and route.points[-1]==Vector2(256,128)
 verify(not state.water_routes.is_empty() and direction_water,"blue flow travels from water source toward consumers")
 verify(not state.sewage_routes.is_empty() and direction_sewage,"brown flow travels from consumers toward treatment sink")
 for seconds in [0.0,.5,10.0,10000.0]:
  Flow.markers(state,seconds)
  Flow.markers(state,seconds,1000,.05)
 verify(state==copy and g.supplied_m3==0,"flow speed and calls never mutate supply treatment trade or volume")
 verify(Flow.contour(Vector2.ZERO,5,0)!=Flow.contour(Vector2.ZERO,5,1),"fluid circle visibly squashes and ripples over time")
 var contour := Flow.contour(Vector2.ZERO,5,10)
 verify(contour.size()==24 and contour[0].is_finite(),"wobble remains a finite bounded circular contour")
 var route := {"water_routes":[{"points":PackedVector2Array([Vector2.ZERO,Vector2(48,0)]),"length":48.0}]}
 verify(Flow.markers(route,.9,48,10).size()==1 and Flow.markers(route,1.1,48,10).is_empty(),"fluid markers disappear at route end")
 verify(state.consumers[2].has_water and state.consumers[2].has_sewage,"both services already active at animation time zero")
 return true
func test_city() -> bool:
 var c := City.new(100,100)
 c.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)]))
 var facility: Dictionary=c.add_water_facility(Vector2(20,40),"water",1000)
 verify(facility.ok,"water prototype facility placed beside normal road")
 verify(not c.add_water_facility(Vector2(20,40),"sewage",1000).ok,"facilities cannot overlap")
 verify(not c.add_power_plant(Vector2(20,40),300).ok,"water facility blocks overlapping generator")
 verify(not c.add_building(20,40).ok,"water facility blocks overlapping housing")
 verify(not c.add_road(PackedVector2Array([Vector2(10,41),Vector2(40,41)])).ok,"roads cannot cut through water facilities")
 c.add_building(32,40)
 pipe(c.water,[Vector2(84,164),Vector2(400,164),Vector2(400,200)])
 var funds: int=c.funds
 c.advance_water(1)
 verify(c.buildings[0].has_water and c.buildings[0].has_sewage,"city exposes independent building water and sewage flags")
 verify(c.funds==funds and c.power.imported_kwh==0,"unapproved water prices are not charged or sent through electricity billing")
 var exchange: Dictionary=c.regional_exchange()
 verify(exchange.neighbors.any(func(n):return n.channels.water.connected and n.channels.sewage.connected),"paired boundary pipe registers both regional channels")
 c.water.remove_pipe(c.water.geometry.wires[0].id)
 verify(not c.regional_exchange().neighbors.any(func(n):return n.channels.water.connected or n.channels.sewage.connected),"removing paired terminal closes both regional channels")
 return true
func test_ui() -> bool:
 var main=load("res://main.tscn").instantiate()
 root.add_child(main)
 current_scene=main
 main.city.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)]))
 var facility: Dictionary=main.city.add_water_facility(Vector2(20,40),"water",300)
 main.find_children("PowerTabButton","Button",true,false)[0].pressed.emit()
 main.find_children("WaterTabButton","Button",true,false)[0].pressed.emit()
 verify(main.water_overlay.tab_open and not main.power_overlay.tab_open and main.mode=="water_pipe","water tab opens paired tools and closes power overlay")
 var start: Vector2=main.city.water.facilities[0].position
 var click := InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=main.screen(start/4)
 main._unhandled_input(click)
 var motion := InputEventMouseMotion.new()
 motion.position=main.screen(start/4+Vector2(32,0))
 main._unhandled_input(motion)
 click.pressed=false
 click.position=motion.position
 main._unhandled_input(click)
 verify(main.city.water.geometry.wires.size()==1,"mouse drag creates one paired pipe in actual game")
 var state: Dictionary=main.city.water_state()
 main.water_overlay.show_flow=false
 main.water_overlay.visual_paused=true
 main.water_overlay.visual_time=10000
 main.water_overlay.update_state(10)
 verify(main.city.water_state()==state,"UI hiding and pausing fluid effects do not change service")
 main.find_children("PowerTabButton","Button",true,false)[0].pressed.emit()
 verify(not main.water_overlay.tab_open and main.power_overlay.tab_open,"switching back to power closes water overlay")
 main.queue_free()
 await process_frame
 return true
func test_demo() -> bool:
 var demo=load("res://water_demo.tscn").instantiate()
 root.add_child(demo)
 current_scene=demo
 verify(demo.city.buildings.size()==6 and demo.city.water.facilities.size()==2,"live demo has six valid consumers and two validated facilities")
 var state: Dictionary=demo.city.water_state()
 verify(state.water_supplied_m3_day==240 and is_equal_approx(state.sewage_treated_m3_day,192),"demo domestic button provides actual water and treatment")
 demo.find_children("Scenario_import","Button",true,false)[0].pressed.emit()
 state=demo.city.water_state()
 verify(state.water_import_m3_day==140 and is_equal_approx(state.sewage_export_m3_day,128),"demo import button enables real two-way neighbor exchange")
 demo.set_scenario("off")
 verify(demo.city.water_state().water_supplied_m3_day==0,"demo cut scenario actually removes pipes")
 demo.set_scenario("domestic")
 verify(demo.city.water_state().water_supplied_m3_day==240,"reconnecting demo restores supply")
 demo.queue_free()
 await process_frame
 return true
