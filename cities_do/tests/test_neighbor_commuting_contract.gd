extends RefCounted

static func run(test):
	var script = load("res://core/neighbor_commuting.gd")
	var c = script.new()
	var exchange := {"neighbors":[{"id":"n","edge":"x_max","channels":{"road":{"connected":true}}}]}
	c.refresh_day(2,1000,exchange)
	var routes := [{"neighbor_id":"n","local_id":7,"direction":"inbound","mode":"road","reachable":true,"route_id":"w"},{"neighbor_id":"n","local_id":9,"direction":"outbound","mode":"road","reachable":true,"route_id":"h"}]
	var local := {"workplaces":[{"workplace_id":7,"free_slots":[0,0,0,0,100]}],"unemployed":[{"person_id":42,"home_id":9,"education":0},{"person_id":43,"home_id":9,"education":4}]}
	var p: Dictionary = c.plan(exchange,local,routes)
	test.check(p.has("inbound_reservations"),"numeric production planner contract exists")
	if not p.has("inbound_reservations"): return
	test.check(p.inbound == 9,"only education 3/4 qualify for stage4 uniform budget")
	test.check(p.inbound_reservations[0].workplace_id is int and p.inbound_reservations[0].workplace_id == 7,"numeric workplace IDs retained")
	test.check(p.outbound == 2 and p.outbound_assignments[0].person_id is int,"one assignment per numeric person")
	for assignment in p.outbound_assignments:
		var education := 0 if assignment.person_id == 42 else 4
		test.check(absi(education-assignment.stage)<=1,"outbound education compatibility")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/neighbor_commuting_config.json"))
	cfg.education_distribution = [1,0,0,0,0]
	var narrow = script.new(cfg)
	narrow.refresh_day(2,1000,exchange)
	test.check(narrow.plan(exchange,local,routes).inbound == 0,"config distribution prevents impossible stage4 workers")
	var incumbent := {"workplaces":[{"workplace_id":7,"free_slots":[0,0,0,0,91]}],"inbound":[{"workplace_id":7,"stage":4,"count":9}],"unemployed":[{"person_id":42,"home_id":9,"education":0}],"outbound":[{"person_id":43,"home_id":9,"education":4,"neighbor_id":"n","stage":4}]}
	var retained: Dictionary = c.plan(exchange,incumbent,routes)
	test.check(retained.inbound == p.inbound and retained.outbound == p.outbound,"whole replacement restores previous inbound capacity and outbound people")
	test.check(retained.outbound_assignments.any(func(a):return a.person_id==43 and a.stage==4),"valid external incumbent retains job stage")
	test.check(c.plan({"neighbors":[]},incumbent,routes).flows.is_empty(),"removed neighbor never leaves a stale plan")
	var original: Dictionary = c.snapshot()
	var state: Dictionary = c.export_state()
	for mutate in [func(s):s.day=2.5,func(s):s.neighbors.n.unemployed=999,func(s):s.neighbors.n.population_exact="bad",func(s):s.neighbors.n.utilities.power.consumed=-1,func(s):s.config.education_distribution=[-1,1,1,1,1],func(s):s.neighbors.n.edge="unknown",func(s):s.neighbors.n.erase("labor"),func(s):s.version=999,func(s):s.neighbors.n.id=17,func(s):s.neighbors.n.utilities.power.unit=17,func(s):s.config.wages_by_stage=[30,-1,55,75,100]]:
		var bad: Dictionary = state.duplicate(true)
		mutate.call(bad)
		test.check(not c.import_state(bad) and c.snapshot()==original,"malformed import rejected without mutation")
	var clone = script.new()
	test.check(clone.import_state(JSON.parse_string(JSON.stringify(state))) and clone.export_state()==state,"full config and state roundtrip")
	var trip: Dictionary = c.trips_for_flow(p.flows[0],0,1)[0]
	test.check(trip.workplace_id is int and trip.departure_hour>=53 and trip.departure_hour<=57,"trip keeps numeric endpoint and absolute day")
	test.check(c.trips_for_flow(p.flows[0],-1,2).is_empty() and c.trips_for_flow(p.flows[0],99999,2).is_empty(),"invalid or exhausted trip page empty")
	for item in [[1000,true],[1001,false],[1010,true],[10000,true],[10001,false],[10100,true]]:
		test.check(c.presentation_record(trip,item[0]).display==item[1],"presentation tier boundary %s"%item[0])
	var preserve_exchange := exchange.duplicate(true)
	preserve_exchange.neighbors[0].vacancy_education_distribution = [0,1,1,0,0]
	var preserve_local := {"outbound":[{"person_id":1,"home_id":9,"education":0,"neighbor_id":"removed","stage":0},{"person_id":2,"home_id":9,"education":2,"neighbor_id":"n","stage":1}]}
	var blocked = script.new()
	blocked.refresh_day(2,1000,preserve_exchange)
	# Consume all but one slot of stage1 with existing stage1 incumbents, while
	# the first lost-job applicant can only take stage1 and must not steal it.
	for i in range(3,17): preserve_local.outbound.append({"person_id":i,"home_id":9,"education":2,"neighbor_id":"n","stage":1})
	var stable: Dictionary = blocked.plan(preserve_exchange,preserve_local,routes)
	test.check(stable.outbound_assignments.filter(func(a):return a.person_id!=1).all(func(a):return a.stage==1),"lost-job rematch never steals a valid incumbent slot")
	var huge = script.new()
	huge.refresh_day(0,3000000,exchange)
	var huge_plan: Dictionary = huge.plan(exchange,{"workplaces":[{"workplace_id":7,"free_slots":[0,0,0,0,50000]}]},routes)
	test.check(huge_plan.flows[0].count>10000 and huge.trips_for_flow(huge_plan.flows[0],10000,7).size()==7,"paged logical commuters continue beyond display cap")
	for scenario in range(25):
		var trial := {"workplaces":[],"unemployed":[]}
		var trial_routes := []
		for w in range(3):
			var slots := []
			for stage in range(5): slots.append((scenario*7+w*3+stage*11)%13)
			trial.workplaces.append({"workplace_id":w+1,"free_slots":slots})
			trial_routes.append({"neighbor_id":"n","local_id":w+1,"direction":"inbound","mode":"road","reachable":true,"route_id":"w%d"%w})
		for i in range(45): trial.unemployed.append({"person_id":i+100,"home_id":9,"education":(i*3+scenario)%5})
		trial_routes.append(routes[1])
		var answer: Dictionary = c.plan(exchange,trial,trial_routes)
		var reservation_count := 0
		var person_ids := {}
		var good := true
		for reservation in answer.inbound_reservations:
			reservation_count += reservation.count
			good = good and reservation.count<=trial.workplaces[reservation.workplace_id-1].free_slots[reservation.stage]
		for assignment in answer.outbound_assignments:
			good = good and not person_ids.has(assignment.person_id) and absi(int(trial.unemployed[assignment.person_id-100].education)-assignment.stage)<=1
			person_ids[assignment.person_id] = true
		for flow in answer.flows: good = good and absi(int(flow.education)-int(flow.stage))<=1
		good = good and reservation_count==answer.inbound and person_ids.size()==answer.outbound and answer.inbound<=24 and answer.outbound<=30
		for value in answer.neighbors.n.unemployed_by_education: good = good and value>=0
		for value in answer.neighbors.n.vacancies_by_stage: good = good and value>=0
		test.check(good,"finite education/slot/person conservation scenario %d"%scenario)
		trial.workplaces.reverse()
		trial.unemployed.reverse()
		trial_routes.reverse()
		test.check(c.plan(exchange,trial,trial_routes)==answer,"canonical assignment scenario %d"%scenario)
	var before: Dictionary = c.export_state()
	c.presentation_record(trip,10001,true,true)
	test.check(before==c.export_state(),"presentation is pure")
	var homeless := {"unemployed":[{"person_id":1,"home_id":-1,"education":0}]}
	var bad_routes: Array = routes.duplicate(true)
	bad_routes.append({"neighbor_id":"n","local_id":-1,"direction":"outbound","mode":"road","reachable":true,"route_id":"invalid"})
	test.check(c.plan(exchange,homeless,bad_routes).outbound==0,"homeless cannot get external assignment")
