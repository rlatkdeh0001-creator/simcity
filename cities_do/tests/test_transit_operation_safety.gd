extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://tests/test_scheduled_buses.gd").fixture(4)
 check(city.add_road(PackedVector2Array([Vector2(90,50),Vector2(65,50)]),"local",true,4).ok,"real T junction fixture")
 var network=load("res://core/scheduled_bus_network.gd").new();network.build_city(city)
 var ids:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 var plan:Dictionary=network.line_plan(ids)
 check(plan.ok,"scheduled road loop is reachable across T junction")
 if plan.ok:
  check(plan.route.any(func(id):return network.lanes[id].get("junction",-1)>=0),"route actually includes reserved turn connector")
  var sim=load("res://core/scheduled_bus_simulation.gd").new(network)
  var bus:Dictionary=sim.spawn_line({"id":"bus-city-01","length_m":10.8,"width_m":2.5,"max_speed":12.0},plan,{"id":1,"dwell_seconds":2.0,"headway_seconds":60.0})
  var reserved:=false;var moved:=false;var bounded:=true;var headway:=true;var last:float=-INF;var departures:=0
  for i in range(7800):
   var old:float=bus.distance
   sim.update(1.0/30)
   if not sim.reservations.is_empty():reserved=true
   if bus.distance>200:moved=true
   if bus.distance-old>.401:bounded=false
   if bus.departures>departures:
    if bus.last_departure-last<59.9:headway=false
    last=bus.last_departure;departures=bus.departures
  check(reserved and moved,"actual ACC bus takes and clears junction reservations")
  check(bounded,"bus follows continuous geometry with bounded motion")
  check(headway and departures>=2 and bus.stops_served>=4,"bus repeats stops with terminal headway")
 city=load("res://tests/transit_operations_fixture.gd").rail_city()
 ids=city.public_facilities.lots.map(func(lot):return lot.id)
 var branch:=PackedVector2Array()
 for i in range(41):
  var t:float=i/40.0;branch.append(Vector2(50+40*t,60.5+10*t*t))
 check(city.add_transit_route(branch,"rail").ok,"actual smooth endpoint-to-interior rail branch")
 var planner=load("res://core/transit_line_planner.gd").new()
 plan=planner.rail_plan(city,{"kind":"rail","stops":ids})
 check(plan.ok,"directed graph retains reachable line through physical junction")
 check(planner.outgoing.values().any(func(list):return list.size()>=3),"graph contains real branch node")
 city.transit_routes.reverse()
 check(planner.rail_plan(city,{"kind":"rail","stops":ids}).ok,"junction routing independent of insertion order")
 city.create_transit_line("rail",ids,{"dwell_seconds":1.0});city.create_transit_line("rail",ids,{"dwell_seconds":1.0})
 var operation=load("res://core/transit_operations.gd").new()
 var safe:=true;var queued:=false;var multiple:=false
 for i in range(120):
  operation.advance(city,1.0)
  var trains:Dictionary=city.transit_state.trains
  if trains.size()<2:queued=true
  else:
   multiple=true
   if not operation.clear(trains[1].visible,trains,1):safe=false
 check(queued and multiple,"occupied departure holds next train until real clearance")
 check(safe,"full consists do not overlap on shared track")
 var before:int=city.next_transit_line_id
 check(not city.create_transit_line("rail",[ids[0],ids[0]]).ok and city.next_transit_line_id==before,"invalid line does not consume ID")
 check(not city.validate_transit_lines([{"id":"bad"}]).is_empty(),"malformed transport rejected without Variant comparison error")
 city=load("res://tests/transit_operations_fixture.gd").rail_city()
 city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id),{"dwell_seconds":1.0})
 operation=load("res://core/transit_operations.gd").new();operation.advance(city,10)
 var departed:int=city.transit_state.trains[1].departures
 city.transit_state.trains[1].speed=0.0 # A stopped checkpoint within a leg, not a new terminal dispatch.
 operation.advance(city,.1)
 check(city.transit_state.trains[1].departures==departed,"restart within a leg does not invent another departure")
 print("TRANSIT_OPERATION_SAFETY checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
