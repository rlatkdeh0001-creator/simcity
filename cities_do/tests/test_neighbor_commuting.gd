extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize():
	var path := "res://core/neighbor_commuting.gd"
	check(FileAccess.file_exists(path), "daily hidden neighbor component exists")
	if failures > 0:
		finish()
		return
	var component = load(path).new()
	var exchange := {"neighbors":[{"id":"a","edge":"y_min","development":"peer","channels":{}}]}
	check(component.refresh_day(0, 1000, exchange), "initial daily refresh")
	var initial: Dictionary = component.snapshot()
	check(initial.neighbors.size() == 1 and initial.neighbors.a.population == 500, "peer multiplier .5")
	check(not component.refresh_day(0, 9000, exchange), "same day does not grow")
	check(component.snapshot() == initial, "same-day stats identical")
	check(not component.refresh_day(-1, 1000, exchange), "past day rejected")
	check(component.refresh_day(1, 2000, exchange), "next day refresh")
	check(component.snapshot().neighbors.a.population == 510, "provisional daily growth towards peer target")
	check(component.has_method("plan"), "deterministic two-way planner exists")
	if not component.has_method("plan"):
		finish()
		return
	var local := local_fixture(["work-1"],["home-1"],100,90)
	var routes := [{"neighbor_id":"a","local_id":"work-1","direction":"inbound","mode":"road","reachable":true,"route_id":"entry-work"}, {"neighbor_id":"a","local_id":"home-1","direction":"outbound","mode":"road","reachable":true,"route_id":"home-exit"}]
	check(component.plan(exchange, local, routes).inbound == 0, "no connection means zero despite explicit route")
	exchange.neighbors[0].channels = {"road":{"connected":true}}
	var planned: Dictionary = component.plan(exchange, local, routes)
	check(planned.inbound == 24 and planned.outbound == 30, "two-way capacities from daily unemployed and vacancies")
	check(planned.has("inbound_reservations") and planned.has("outbound_assignments"), "C# slot and individual external-employment contract")
	if not planned.has("inbound_reservations"):
		finish()
		return
	check(planned.local_vacancies_remaining == 76 and planned.local_unemployed_remaining == 60, "directional accounting")
	check(planned.residential_vacancy_reduction == 24, "inbound residential demand input")
	check(component.plan(exchange, local, routes) == planned, "repeated plan does not consume daily supply twice")
	check(component.snapshot().neighbors.a.unemployed == 24, "planning never mutates base daily stats")
	check(component.plan(exchange, local, []).inbound == 0, "open channel alone is not reachable local route")
	exchange.neighbors[0].channels = {"power":{"connected":true},"water":{"connected":true}}
	check(component.plan(exchange, local, routes).flows.is_empty(), "utility connection not commuting")
	test_routing(component, local, routes)
	test_real_connections()
	load("res://tests/test_neighbor_commuting_contract.gd").run(self)
	check(component.has_method("trips_for_flow") and component.has_method("export_state"), "trip and persistence API exists")
	if component.has_method("trips_for_flow") and component.has_method("export_state"):
		test_trips_and_state(component, local, routes)
	finish()

func test_routing(component, local: Dictionary, road_routes: Array):
	var town := {"id":"a", "edge":"y_min", "channels":{"road":{"connected":true},"rail":{"connected":true},"metro":{"connected":true}}}
	var exchange := {"neighbors":[town]}
	var routes := road_routes.duplicate(true)
	for mode in ["metro", "rail"]:
		routes.append({"neighbor_id":"a","local_id":"work-1","direction":"inbound","mode":mode,"reachable":true,"route_id":mode+"-route", "station_id":mode+"-station"})
	check(component.plan(exchange,local,routes).flows[0].mode == "road", "station access defaults false")
	routes[2].station_access = true
	check(component.plan(exchange,local,routes).flows[0].mode == "metro", "reachable metro preferred to road")
	routes[3].station_access = true
	check(component.plan(exchange,local,routes).flows[0].mode == "rail", "reachable rail preferred to road")
	routes[3].reachable = false
	check(component.plan(exchange,local,routes).flows[0].mode == "metro", "unreachable rail falls back to reachable metro")
	routes[2].reachable = false
	check(component.plan(exchange,local,routes).flows[0].mode == "road", "unreachable stations fall back road")
	var duplicate_local := local.duplicate(true)
	duplicate_local.workplaces.append(local.workplaces[0].duplicate())
	duplicate_local.unemployed.append(local.unemployed[0].duplicate())
	check(component.plan(exchange,duplicate_local,routes) == component.plan(exchange,local,routes), "duplicate source rows not double allocated")
	var saved: Dictionary = component.snapshot()
	saved.neighbors.a.population = 999999
	check(component.snapshot().neighbors.a.population == 510, "daily snapshot detached")

func test_real_connections():
	var regional = load("res://core/regional_exchange.gd")
	var component = load("res://core/neighbor_commuting.gd").new()
	var roads := [{"points":PackedVector2Array([Vector2(20,20),Vector2(20,0)])}]
	var exchange: Dictionary = regional.evaluate(100,100,roads,[])
	component.refresh_day(0,10000,exchange)
	var local := local_fixture(["w1","w2"],["h1","h2"],600,1000)
	var routes := []
	for town in exchange.neighbors:
		for id in ["w1","w2","h1","h2"]:
			routes.append({"neighbor_id":town.id,"local_id":id,"direction":"inbound" if id.begins_with("w") else "outbound","mode":"road","reachable":true,"route_id":str(town.id)+id})
	var plan: Dictionary = component.plan(exchange,local,routes)
	check(plan.inbound == 768 and plan.outbound == 960, "actual RegionalExchange y_min only with no arbitrary channel cap")
	var both: Dictionary = regional.evaluate(100,100,roads + [{"points":PackedVector2Array([Vector2(50,50),Vector2(100,50)])}],[])
	var expanded: Dictionary = component.plan(both,local,routes)
	check(expanded.inbound == 1200 and expanded.outbound == 1000, "multiple neighbors share finite local capacity in both directions")
	check(component.plan(regional.evaluate(100,100,[],[]),local,routes).flows.is_empty(), "last road removal invalidates same-day commuting")
	var reversed := both.duplicate(true)
	reversed.neighbors.reverse()
	var reverse_local := local.duplicate(true)
	reverse_local.workplaces.reverse()
	reverse_local.unemployed.reverse()
	routes.reverse()
	check(component.plan(reversed,reverse_local,routes) == expanded, "permuted input deterministic")
	var rail_only: Dictionary = regional.evaluate(100,100,[],[{"kind":"rail","points":PackedVector2Array([Vector2(20,20),Vector2(20,0)])}])
	check(component.plan(rail_only,local,routes).inbound == 0, "actual rail boundary cannot create station access")
	var corner: Dictionary = regional.evaluate(100,100,[{"points":PackedVector2Array([Vector2(20,20),Vector2.ZERO])}],[])
	check(component.plan(corner,local,routes).flows.is_empty(), "actual corner terminal rejected")

func test_trips_and_state(component, local: Dictionary, routes: Array):
	var exchange := {"neighbors":[{"id":"a","edge":"y_min","channels":{"road":{"connected":true}}}]}
	var plan: Dictionary = component.plan(exchange,local,routes)
	var trips: Array = component.trips_for_flow(plan.flows[0])
	check(trips.size() == plan.flows[0].count, "one logical record per commuter, not per sampled car")
	check(trips.all(func(t): return t.departure_hour >= 29 and t.departure_hour <= 33 and t.late_after_hour == t.departure_hour + 4), "05-09 absolute day hours and departure+4 lateness")
	check(trips[0].home_id == "neighbor:a:homes" and trips[0].workplace_id == "work-1" and trips[0].neighbor_edge == "y_min", "trip endpoints edge and mode preserved")
	check(component.trips_for_flow(plan.flows[0],2,3) == trips.slice(2,5), "paged trips identical, no hidden cap")
	var state: Dictionary = component.export_state()
	var clone = load("res://core/neighbor_commuting.gd").new()
	check(clone.import_state(JSON.parse_string(JSON.stringify(state))), "state JSON roundtrip import")
	check(clone.snapshot() == component.snapshot() and clone.plan(exchange,local,routes) == plan, "restored exact daily stats and plan")
	check(clone.trips_for_flow(plan.flows[0]) == trips, "restored deterministic departure times")
	check(not clone.refresh_day(1,99999,exchange), "import preserves daily cadence")
	state.neighbors.a.population = -1
	check(not clone.import_state(state) and clone.snapshot() == component.snapshot(), "invalid import rejected atomically")
	check(component.has_method("presentation_record"), "traffic presentation hook exists")
	if component.has_method("presentation_record"):
		var hook: Dictionary = component.presentation_record(trips[0],0)
		check(hook.kind == "boundary_car" and hook.origin == "neighbor_boundary" and hook.destination == "work-1", "inbound boundary-entry car hook")
		var returning: Dictionary = component.presentation_record(trips[0],0,true)
		check(returning.origin == "work-1" and returning.destination == "neighbor_boundary", "return boundary-exit car hook")
		check(component.presentation_record(trips[0],1001).display == false and component.presentation_record(trips[0],1010).display, "existing 1000/10000 tier sampling")
		check(component.presentation_record(trips[0],10001,true,true).display, "tracked commuter always visible")

func finish():
	print("NEIGHBOR_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func local_fixture(work_ids: Array, home_ids: Array, slots_per_workplace: int, people: int) -> Dictionary:
	var local := {"workplaces":[],"unemployed":[]}
	for id in work_ids:
		var slots := []
		for stage in range(5): slots.append(slots_per_workplace / 5)
		local.workplaces.append({"id":id,"zone":"commercial","free_slots":slots})
	for i in range(people): local.unemployed.append({"id":"person-%04d" % i,"home_id":home_ids[i % home_ids.size()],"education":i % 5})
	return local
