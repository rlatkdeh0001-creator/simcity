extends SceneTree
const Grid = preload("res://core/power_grid.gd")
const Flow = preload("res://core/power_flow.gd")
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
func consumers() -> Array:
 return [{"id":1,"position":Vector2(80,100),"demand_kw":100.0},{"id":2,"position":Vector2(250,100),"demand_kw":140.0}]
func wire(grid,points: Array) -> Dictionary:
 return grid.add_wire(PackedVector2Array(points))
func run():
 for method in ["test_network","test_delivery","test_trade","test_billing","test_visual_independence"]:
  if call(method)!=true: verify(false,method+" completes")
 if await test_ui()!=true: verify(false,"UI test completes")
 print("RESULT %d/%d power checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
func test_network() -> bool:
 var g := Grid.new()
 g.add_plant(Vector2(64,128),300)
 verify(not g.solve(consumers()).consumers[1].powered,"source without constructed line cannot supply")
 verify(not wire(g,[Vector2(100,100),Vector2(200,100)]).ok,"wire cannot start from arbitrary unconnected ground")
 verify(not wire(g,[Vector2(64,128),Vector2(401,128)]).ok,"wire outside map rejected")
 var points := PackedVector2Array([Vector2(64,128),Vector2(256,128)])
 verify(g.add_wire(points,false).ok and g.wires.is_empty(),"wire preview does not change grid")
 var result: Dictionary=g.add_wire(points)
 points[1]=Vector2(300,300)
 verify(result.ok and g.wires[0].points[-1]==Vector2(256,128),"wire owns copied geometry")
 g.rebuild()
 var service := g.nodes.filter(func(n):return n.service and not g.adjacency[n.id].is_empty())
 verify(service.size()==7,"192m wire has source plus six 32m supply points")
 var spacing_ok := true
 for i in range(1,service.size()): spacing_ok=spacing_ok and is_equal_approx(service[i].position.distance_to(service[i-1].position),32)
 verify(spacing_ok,"supply-point spacing is exactly 32 metres")
 var near := [{"id":5,"position":Vector2(160,192),"demand_kw":1.0},{"id":6,"position":Vector2(160,192.01),"demand_kw":1.0}]
 var state: Dictionary=g.solve(near)
 verify(state.consumers[5].powered and not state.consumers[6].connected,"64m radial supply boundary is exact")
 var short: Dictionary=wire(g,[Vector2(256,128),Vector2(274,128)])
 verify(short.ok and short.wire.samples.size()==2 and not short.wire.samples[-1].service,"partial terminal does not create extra supply radius")
 var bent: Dictionary=wire(g,[Vector2(64,128),Vector2(64,150),Vector2(64,200)])
 verify(bent.ok and bent.wire.samples.any(func(p):return p.position==Vector2(64,150) and not p.service),"bend retains visual route geometry without extra service point")
 return true
func test_delivery() -> bool:
 var g := Grid.new()
 var source := g.add_plant(Vector2(64,128),300)
 var built: Dictionary=wire(g,[Vector2(64,128),Vector2(256,128)])
 var state: Dictionary=g.solve(consumers())
 verify(state.consumers[1].powered and state.consumers[2].powered,"near and far consumers receive power simultaneously before any visual arrival")
 verify(is_equal_approx(state.groups.filter(func(x):return x.demand_kw>0)[0].demand_kw,240),"overlapping supply circles do not count consumers twice")
 g.set_output(source,120)
 state=g.solve(consumers())
 verify(is_equal_approx(state.consumers[1].ratio,.5) and is_equal_approx(state.consumers[2].ratio,.5),"insufficient isolated grid shares power proportionally instead of arrival ordering")
 g.remove_plant(source)
 state=g.solve(consumers())
 verify(not state.consumers[1].powered and not state.consumers[2].powered,"removing source removes delivery immediately")
 g.add_plant(Vector2(64,128),300)
 g.remove_wire(built.wire.id)
 verify(not g.solve(consumers()).consumers[2].powered,"removing wire disconnects distant consumers immediately")
 var branch := Grid.new()
 branch.add_plant(Vector2(64,128),300)
 wire(branch,[Vector2(64,128),Vector2(256,128)])
 var bw: Dictionary=wire(branch,[Vector2(160,128),Vector2(160,256)])
 var load := [{"id":9,"position":Vector2(160,300),"demand_kw":20.0}]
 verify(branch.solve(load).consumers[9].powered,"branch from existing supply point carries power")
 branch.remove_wire(bw.wire.id)
 verify(not branch.solve(load).consumers[9].powered,"branch deletion removes its supply")
 return true
func test_trade() -> bool:
 var g := Grid.new()
 g.add_plant(Vector2(64,200),300)
 wire(g,[Vector2(64,200),Vector2(200,200),Vector2(400,200)])
 var state: Dictionary=g.solve([{"id":1,"position":Vector2(200,220),"demand_kw":100.0}],INF,1)
 verify(state.import_kw==0 and is_equal_approx(state.export_kw,200),"local consumption is served before automatic surplus export")
 verify(is_equal_approx(state.revenue_doth,.24),"developed neighbor export tariff 0.0012 doth/kWh")
 var source: Dictionary=g.plants[0]
 g.set_output(source.id,0)
 state=g.solve([{"id":1,"position":Vector2(200,220),"demand_kw":1500.0}],INF,1)
 verify(is_equal_approx(state.import_kw,1500) and state.consumers[1].powered,"imports fill shortage without proposed contract cap")
 verify(is_equal_approx(state.cost_doth,4.05),"developed import tariff 0.0027 doth/kWh")
 var imp := Grid.new()
 wire(imp,[Vector2(0,200),Vector2(200,200)])
 state=imp.solve([{"id":1,"position":Vector2(160,200),"demand_kw":100}],INF,1)
 verify(state.consumers[1].powered and is_equal_approx(state.cost_doth,.3),"neighbor alone can supply city at peer tariff 0.003")
 wire(imp,[Vector2(192,200),Vector2(200,200),Vector2(200,0)])
 state=imp.solve([{"id":1,"position":Vector2(160,200),"demand_kw":100}],INF,1)
 verify(state.groups.filter(func(x):return x.import_kw>0)[0].trade_port.development=="highly_developed" and is_equal_approx(state.cost_doth,.24),"connected import uses cheapest advanced neighbor")
 var self_source := imp.add_plant(Vector2(160,200),300)
 state=imp.solve([{"id":1,"position":Vector2(160,200),"demand_kw":100}],INF,1)
 verify(state.import_kw==0 and state.export_kw==200 and is_equal_approx(state.revenue_doth,.3),"export uses highest buying price and does not simultaneously import same grid")
 imp.set_output(self_source,0)
 state=imp.solve([{"id":1,"position":Vector2(160,200),"demand_kw":100}],.12,1)
 verify(is_equal_approx(state.import_kw,50) and is_equal_approx(state.cost_doth,.12),"funds budget curtails import when money is insufficient")
 verify(imp.solve([{"id":1,"position":Vector2(160,200),"demand_kw":100}],0,1).import_kw==0,"empty funds cannot import for free")
 return true
func fixture_city() -> RefCounted:
 var c := City.new()
 c.power.add_wire(PackedVector2Array([Vector2(0,80),Vector2(80,80)]))
 c.buildings.append({"id":1,"x":18,"y":18,"size":2,"zone":"residential","level":1,"power_demand_kw":100.0})
 return c
func test_billing() -> bool:
 var c=fixture_city()
 var before: int=c.funds
 c.advance_power(720)
 verify(c.funds==before-216 and absf(c.power.pending_doth)<.000001,"720 hours at 100kW and peer rate costs 216 doth")
 verify(is_equal_approx(c.power.imported_kwh,72000),"meter integrates kW times hours into kWh")
 var tiny=fixture_city()
 tiny.advance_power(.001)
 verify(tiny.funds==50000 and is_equal_approx(tiny.power.pending_doth,-.0003),"fractional doth is carried without per-frame rounding")
 var a=fixture_city()
 var b=fixture_city()
 for i in range(30): a.advance_power(1.0/30)
 for i in range(60): b.advance_power(1.0/60)
 verify(a.funds==b.funds and is_equal_approx(a.power.pending_doth,b.power.pending_doth) and is_equal_approx(a.power.imported_kwh,b.power.imported_kwh),"30/60 update rates have same energy and money totals")
 var poor=fixture_city()
 poor.funds=1
 poor.advance_power(100)
 verify(poor.funds==0 and poor.power.pending_doth>=-.000001 and poor.power.imported_kwh<=333.334,"import cannot create debt without an approved debt rule")
 verify(poor.power_state().import_kw==0,"zero remaining balance stops future import")
 return true
func test_visual_independence() -> bool:
 var g := Grid.new()
 g.add_plant(Vector2(64,128),300)
 wire(g,[Vector2(64,128),Vector2(256,128)])
 var state: Dictionary=g.solve(consumers())
 var copy := state.duplicate(true)
 for t in [0.0,1.0,100.0,10000.0]:
  Flow.markers(state,t)
  Flow.markers(state,t,1000,.05)
 verify(state==copy,"animation calls cannot mutate supply, meters or finances")
 var before: Dictionary=g.solve(consumers()).duplicate(true)
 Flow.markers(before,0)
 verify(before.consumers[2].powered,"far consumer is powered before first marker arrives")
 var routes := {"routes":[{"points":PackedVector2Array([Vector2(0,0),Vector2(64,0)]),"length":64.0}]}
 verify(Flow.markers(routes,.9,64,10).size()==1 and Flow.markers(routes,1.1,64,10).is_empty(),"display marker vanishes at endpoint without lingering or looping")
 return true
func test_ui() -> bool:
 var main=load("res://main.tscn").instantiate()
 root.add_child(main)
 current_scene=main
 main.city.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)]))
 var plant: Dictionary=main.city.add_power_plant(Vector2(20,40),300)
 verify(plant.ok,"player can place prototype generator beside road")
 main.find_children("PowerTabButton","Button",true,false)[0].pressed.emit()
 verify(main.power_overlay.tab_open and main.power_overlay.panel.visible,"power tab opens actual game controls")
 main.mode="power_wire"
 var source: Vector2=main.city.power.plants[0].position
 var click := InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=main.screen(source/4)
 main._unhandled_input(click)
 var motion := InputEventMouseMotion.new()
 motion.position=main.screen(source/4+Vector2(32,0))
 main._unhandled_input(motion)
 click.pressed=false
 click.position=motion.position
 main._unhandled_input(click)
 verify(main.city.power.wires.size()==1,"mouse drag commits underground wire from blue source")
 verify(main.city.power.add_wire(PackedVector2Array([source,source+Vector2(0,32)])).ok,"underground line can overlap terrain without depth parameter")
 var raw: Dictionary=main.city.power_state()
 main.power_overlay.show_flow=false
 main.power_overlay.show_ranges=false
 main.power_overlay.visual_paused=true
 main.power_overlay.visual_time=10000
 verify(main.city.power_state()==raw,"UI animation/range controls do not alter simulation state")
 var id: int=main.city.power.wires[0].id
 main.city.power.remove_wire(id)
 main.power_overlay.refresh()
 verify(not main.city.power.wires.any(func(w):return w.id==id),"live wire removal updates game state")
 main.queue_free()
 await process_frame
 return true
