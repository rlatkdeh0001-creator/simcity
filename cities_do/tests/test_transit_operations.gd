extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://core/city_model.gd").new(120,120,42)
 city.population_enabled=false;city.happiness_enabled=false
 check(city.has_method("create_transit_line"),"placed stops have an explicit operating-line command")
 city=load("res://tests/transit_operations_fixture.gd").rail_city()
 var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 check(city.create_transit_line("rail",stops).ok,"explicit line accepts placed rail stations")
 check(ResourceLoader.exists("res://core/transit_line_planner.gd"),"directed continuous network planner exists")
 if ResourceLoader.exists("res://core/transit_line_planner.gd"):
  var planner=load("res://core/transit_line_planner.gd").new()
  var plan:Dictionary=planner.rail_plan(city,city.transit_lines[0])
  check(plan.get("ok",false),"stations resolve through real curved turnaround network")
  if plan.get("ok",false):
   check(plan.points[0].distance_to(plan.points[-1])<.001,"operating loop is continuous")
   check(plan.stops.size()==2,"both placed station centres are scheduled")
   check(absf(plan.points[0].y-city.public_facilities.lots[0].internal_points[0].y*4)>1.99,"train follows offset right track not centre ribbon")
  city.remove_transit_route(city.transit_routes[-1].id)
  check(not planner.rail_plan(city,city.transit_lines[0]).get("ok",false),"existing loop line does not silently migrate when the loop is demolished")
 city=load("res://tests/transit_operations_fixture.gd").rail_city()
 city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id),{"dwell_seconds":1.0})
 var Adapter=load("res://core/city_simulation_worker.gd")
 var worker=Adapter.new();worker.boot(Adapter.capture(city))
 var result:Dictionary=worker.run_step({"base_tick":0,"base_revision":0},float(city.config.development_interval_seconds),1)
 check(result.has("transit_state"),"worker publishes scheduled transit state")
 if result.has("transit_state"):
  check(result.transit_state.visible.size()==3,"32 metre train consists of locomotive and two real cars")
  var first:Dictionary=result.transit_state.duplicate(true)
  for i in range(2,21):result=worker.run_step({"base_tick":i-1,"base_revision":0},float(city.config.development_interval_seconds),i)
  check(result.transit_state.visible!=first.visible,"accepted logical ticks move full consist")
  check(city.transit_state.visible.is_empty(),"detached operation cannot mutate main model")
  var restored=Adapter.new();restored.boot(Adapter.capture(worker.city))
  var next:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},float(city.config.development_interval_seconds),1)
  result=worker.run_step({"base_tick":20,"base_revision":0},float(city.config.development_interval_seconds),21)
  check(next.transit_state==result.transit_state,"checkpoint continuation exactly deterministic")
  worker.city.remove_transit_route(worker.city.transit_routes[-1].id)
  var before:Dictionary=result.transit_state.duplicate(true)
  result=worker.run_step({"base_tick":21,"base_revision":0},float(city.config.development_interval_seconds),22)
  check(result.transit_state.visible==before.visible,"removed route freezes vehicle in place, never respawns or teleports")
  check(result.transit_state.lines[1].status=="blocked","invalid route is explicitly blocked")
 for kind:String in ["rail","metro","freight"]:
  var sample_city=load("res://tests/transit_operations_fixture.gd").rail_city("metro" if kind=="metro" else "rail")
  var ids:Array=sample_city.public_facilities.lots.map(func(lot):return lot.id)
  sample_city.create_transit_line(kind,ids,{"dwell_seconds":2.0,"headway_seconds":60.0})
  var operation=load("res://core/transit_operations.gd").new()
  operation.advance(sample_city,1.0)
  var initial:Dictionary=sample_city.transit_state.duplicate(true)
  check(initial.visible.size()==(4 if kind in ["metro","freight"] else 3),"full original consist inventory "+kind)
  var total:=0.0
  for pose:Dictionary in initial.visible:
   if not pose.get("cargo",false):total+=pose.length_m
  check(total==({"rail":32.0,"metro":64.0,"freight":26.0}[kind]),"physical consist length "+kind)
  operation.advance(sample_city,1.0)
  check(sample_city.transit_state.visible==initial.visible,"full dwell before departure "+kind)
  var last_departure:float=-INF;var departures:=0;var bounded:=true;var dwelled:=false;var schedule:=true
  for step in range(130):
   var previous_distance:float=sample_city.transit_state.trains[1].distance
   operation.advance(sample_city,2.0)
   var train:Dictionary=sample_city.transit_state.trains[1]
   if train.distance-previous_distance>32.01:bounded=false
   if sample_city.transit_state.lines[1].status=="dwelling":dwelled=true
   if train.departures>departures:
    if train.last_departure-last_departure<59.9:schedule=false
    last_departure=train.last_departure;departures=train.departures
  check(bounded,"no distance jumps through curves or turnaround "+kind)
  check(dwelled and departures>=2,"repeated stops and physical return operation "+kind)
  check(schedule,"scheduled minimum headway between repeated terminal departures "+kind)
  sample_city.remove_transit_route(sample_city.transit_routes[-1].id)
  var replacement:Dictionary=sample_city.create_transit_line(kind,ids)
  check(not replacement.ok if kind=="freight" else replacement.ok and replacement.line.get("turnback",false),"passenger open lines use P5 while freight retains loop routing "+kind)
  sample_city.remove_transit_route(sample_city.transit_routes[-1].id)
  check(not sample_city.create_transit_line(kind,ids).ok,"disconnected player line rejected before allocation "+kind)
 print("TRANSIT_OPERATIONS checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
