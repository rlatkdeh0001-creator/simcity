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
 for method in ["test_geometry","test_service","test_exchange","test_metering","test_tariffs","test_flow","test_city"]:
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
func billing_city() -> RefCounted:
 var c := City.new()
 c.water.add_pipe(PackedVector2Array([Vector2(0,80),Vector2(144,80)]))
 c.buildings.append({"id":1,"x":18,"y":18,"size":2,"zone":"residential","level":1,"water_demand_m3_day":100.0})
 return c
func test_tariffs() -> bool:
 var g := Grid.new()
 pipe(g,[Vector2(0,200),Vector2(256,200)])
 var demand := [{"id":1,"position":Vector2(160,200),"demand_m3_day":100.0}]
 var quote: Dictionary=g.solve(demand,INF,1)
 verify(is_equal_approx(quote.water_purchase_doth,5) and is_equal_approx(quote.sewage_disposal_doth,3.2),"peer tariffs charge imported m3 and disposed sewage m3 separately")
 verify(is_equal_approx(quote.cost_doth,8.2) and quote.revenue_doth==0,"one day peer water and sewage totals 8.2 doth")
 pipe(g,[Vector2(192,200),Vector2(200,200),Vector2(200,0)])
 quote=g.solve(demand,INF,1)
 verify(is_equal_approx(quote.water_purchase_doth,4) and is_equal_approx(quote.sewage_disposal_doth,2.4),"advanced neighbor gives cheaper water and treatment")
 var active: Dictionary=quote.groups.filter(func(group):return group.water_import>0)[0]
 verify(active.water_import_port.development=="highly_developed" and active.sewage_export_port.development=="highly_developed","each import and disposal selects cheapest connected neighbor")
 var plant: int=g.add_facility(Vector2(160,200),"water",300)
 quote=g.solve(demand,INF,1)
 verify(quote.water_import_m3_day==0 and is_equal_approx(quote.water_sales_doth,5),"surplus water uses highest export price peer 0.025 per m3")
 verify(quote.groups.filter(func(group):return group.water_export>0)[0].water_export_port.development=="peer","water import and export may choose different neighbors")
 var sales=billing_city()
 sales.funds=0
 sales.water.add_facility(Vector2(64,80),"water",300)
 sales.advance_water(1)
 verify(sales.funds==1 and is_equal_approx(sales.water.pending_doth,.8),"current water export revenue can pay disposal even with zero opening cash")
 var fresh: Dictionary=g.tariffs.duplicate(true)
 fresh.peer.water_import=.06
 verify(Grid.valid_tariffs(fresh),"tariff configuration accepts editable nonnegative rates")
 fresh.peer.water_import=-1
 verify(not Grid.valid_tariffs(fresh),"negative tariff rejected before it can generate money")
 g.set_capacity(plant,0)
 g.tariffs.peer.water_import=0
 quote=g.solve(demand,0,1)
 verify(quote.water_import_m3_day==100 and quote.sewage_export_m3_day==0,"zero water price is free but unpaid sewage treatment still stops")
 var c=billing_city()
 c.advance_water(30)
 verify(c.funds==49754 and absf(c.water.pending_doth)<.000001,"100 m3 per day and 80 sewage for 30 days costs exactly 246 doth")
 verify(is_equal_approx(c.water.imported_water_m3,3000) and is_equal_approx(c.water.exported_sewage_m3,2400),"billed volume equals actual metered trade")
 var small=billing_city()
 small.advance_water(.001)
 verify(small.funds==50000 and is_equal_approx(small.water.pending_doth,-.0082),"small water and sewage charges carry fractional doth")
 var a=billing_city()
 var b=billing_city()
 for i in range(30): a.advance_water(1.0/30)
 for i in range(60): b.advance_water(1.0/60)
 verify(a.funds==b.funds and is_equal_approx(a.water.pending_doth,b.water.pending_doth) and is_equal_approx(a.water.imported_water_m3,b.water.imported_water_m3),"30 and 60 updates settle equal money and water volume")
 var poor=billing_city()
 poor.funds=1
 var state: Dictionary=poor.advance_water(1)
 verify(poor.funds==0 and absf(poor.water.pending_doth)<.000001 and state.cost_doth<=1.000001,"insufficient cash cannot create water debt")
 verify(is_equal_approx(state.water_supplied_m3_day,20) and state.sewage_export_m3_day==0,"cash shortage prioritizes drinking water then reports untreated sewage")
 var shared=billing_city()
 shared.funds=1
 shared.power.pending_doth=-.8
 state=shared.advance_water(1)
 verify(state.cost_doth<=.200001 and shared.utility_balance()<.000001,"water cannot spend money already owed to electricity")
 var electricity=billing_city()
 electricity.funds=1
 electricity.water.pending_doth=-.9
 electricity.power.add_wire(PackedVector2Array([Vector2(0,80),Vector2(144,80)]))
 electricity.buildings[0].power_demand_kw=100.0
 var power_state: Dictionary=electricity.advance_power(1)
 verify(power_state.cost_doth<=.100001 and electricity.utility_balance()<.000001,"electricity cannot spend money already owed to water")
 var display=billing_city()
 var prior_funds: int=display.funds
 var prior: Dictionary=display.water_state()
 Flow.markers(prior,100,1000,.1)
 display.water_state()
 verify(display.funds==prior_funds and display.water.pending_doth==0,"queries and fluid animation cannot charge twice")
 var disconnection=billing_city()
 var pipe_id: int=disconnection.water.geometry.wires[0].id
 disconnection.water.remove_pipe(pipe_id)
 disconnection.advance_water(30)
 verify(disconnection.funds==50000 and disconnection.water.pending_doth==0,"disconnected network cannot bill phantom water or sewage")
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
 verify(c.funds==funds+17 and is_equal_approx(c.water.pending_doth,.9264) and c.power.imported_kwh==0,"water trade settles its own tariff without electricity billing")
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
