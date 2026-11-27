extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
static func fixture(lanes:int):
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 for pair in [[Vector2(10,20),Vector2(90,20)],[Vector2(90,20),Vector2(90,80)],[Vector2(90,80),Vector2(10,80)],[Vector2(10,80),Vector2(10,20)]]:
  assert(city.add_road(PackedVector2Array(pair),"local",true,lanes).ok)
 var curb:float=city.RoadProfile.asphalt_width(city.roads[0])/2
 for p:Vector2 in [Vector2(35,20+curb),Vector2(65,80-curb)]:assert(city.public_facilities.place("bus-stop-01",p).ok)
 return city
func test_unrelated_facilities():
 var city=fixture(4)
 var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 check(city.create_transit_line("bus",stops,{"dwell_seconds":1.0}).ok,"topology fixture line created")
 var operation=load("res://core/transit_operations.gd").new()
 operation.advance(city,3.0)
 check(city.transit_state.bus.vehicles.size()==1 and city.transit_state.bus.vehicles[0].distance>0,"topology fixture has an actually running bus")
 var original:Dictionary=city.transit_state.bus.duplicate(true)
 var roads:Array=city.roads.duplicate(true)
 var park:Dictionary=city.public_facilities.place("park-plaza-4x4",Vector2(50,26),0,true)
 check(park.ok,"unrelated park placed through real facility API")
 if not park.ok:return
 for edit:String in ["add","mutation","remove","non_topology_metadata"]:
  if edit=="mutation":
   park.record.capacity["test_metadata"]=17
   park.record.effect_enabled=not park.record.effect_enabled
   city._simulation_world_changed()
  elif edit=="remove":check(city.public_facilities.remove(park.record.id),"unrelated park removed through real facility API")
  elif edit=="non_topology_metadata":
   city.public_facilities.lots[0].capacity["test_metadata"]=23
   city.roads[0]["test_metadata"]=true
   roads=city.roads.duplicate(true)
   city._simulation_world_changed()
  var distance:float=city.transit_state.bus.vehicles[0].distance
  operation.advance(city,.5)
  var bus:Dictionary=city.transit_state.bus.vehicles[0]
  check(city.transit_state.lines[1].status=="running" and bus.distance>distance,"running bus continues after park "+edit)
  check(city.roads==roads and city.transit_state.bus.topology_key==original.topology_key and bus.route==original.vehicles[0].route and bus.id==original.vehicles[0].id,"park "+edit+" preserves road graph, topology and occupied route")
func test_occupied_topology_freeze():
 var city=fixture(4)
 city.create_transit_line("bus",city.public_facilities.lots.map(func(lot):return lot.id),{"dwell_seconds":1.0})
 var operation=load("res://core/transit_operations.gd").new()
 operation.advance(city,3.0)
 var stop:Dictionary=city.public_facilities.lots[0]
 var changes:Dictionary={"front_road_id":-1,"road_direction":-int(stop.road_direction),"position":stop.position+Vector2(1,0),"front_direction":-stop.front_direction}
 for field:String in changes:
  var old:Variant=stop[field]
  var frozen:Dictionary=city.transit_state.bus.duplicate(true)
  stop[field]=changes[field];city._simulation_world_changed()
  operation.advance(city,.5)
  check(city.transit_state.lines[1].status=="blocked" and city.transit_state.bus==frozen and city.transit_state.visible==frozen.visible,"occupied bus freezes exactly on stop "+field)
  stop[field]=old;city._simulation_world_changed()
  operation.advance(city,.5)
  check(city.transit_state.lines[1].status=="running" and city.transit_state.bus.vehicles[0].distance>frozen.vehicles[0].distance,"same topology restoration resumes without relocation "+field)
 var frozen:Dictionary=city.transit_state.bus.duplicate(true)
 var selection:Dictionary=city.road_demolition_selection(city.roads[0].parcel_id,Vector2(35,20))
 check(city.demolish_road_selection(selection).ok,"actual occupied host road demolished")
 operation.advance(city,.5)
 check(city.transit_state.lines[1].status=="blocked" and city.transit_state.bus==frozen and city.transit_state.visible==frozen.visible,"host road removal freezes occupied bus and reservations")
 var Adapter=load("res://core/city_simulation_worker.gd")
 var restored=Adapter.new();restored.boot(Adapter.capture(city))
 var result:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},float(city.config.development_interval_seconds),1)
 check(result.transit_state.lines[1].status=="blocked" and result.transit_state.bus==frozen and result.transit_state.visible==frozen.visible,"checkpoint retains occupied invalid-road freeze")
func run():
 test_unrelated_facilities()
 test_occupied_topology_freeze()
 check(ResourceLoader.exists("res://core/scheduled_bus_network.gd"),"scheduled stops use real road lane graph")
 if ResourceLoader.exists("res://core/scheduled_bus_network.gd"):
  for lanes:int in [2,3,4,5,6,7,8]:
   var city=fixture(lanes)
   var network=load("res://core/scheduled_bus_network.gd").new()
   check(network.build_city(city),"road graph builds "+str(lanes))
   var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
   var plan:Dictionary=network.line_plan(stops)
   check(plan.get("ok",false),"actual returning lane route "+str(lanes))
   if plan.get("ok",false):
    var Sim=load("res://core/scheduled_bus_simulation.gd")
    var sim=Sim.new(network)
    var line:Dictionary={"id":1,"dwell_seconds":30.0,"headway_seconds":60.0}
    var bus:Dictionary=sim.spawn_line({"id":"bus-city-01","length_m":10.8,"max_speed":12.0},plan,line)
    var car_route:Array=plan.route.duplicate();var car_progress:float=plan.stops[0].progress-20
    if lanes in [2,4,6]:
     var pocket:Dictionary=network.lanes[plan.stops[0].lane]
     for candidate:Dictionary in network.lanes:
      if candidate.id!=pocket.id and candidate.get("road",-1)==pocket.road and candidate.next==pocket.next and not candidate.get("bus_pocket",false):car_route[0]=candidate.id;car_progress=3.0;break
    if lanes in [2,4,6]:
     var overlap_plan:Array=car_route.duplicate()
     var probe=Sim.new(network)
     var first:Dictionary=probe.spawn({"id":"bus-city-01","length_m":10.8,"width_m":2.5},plan.route,8.0,true)
     var overlap:Dictionary=probe.spawn({"id":"bus-city-01","length_m":10.8,"width_m":2.5},overlap_plan,8.0,true)
     check(not first.is_empty() and overlap.is_empty(),"shared curb approach forbids different-lane body overlap "+str(lanes))
     var merge_sim=Sim.new(network)
     var merging:Dictionary=merge_sim.spawn({"id":"bus-city-01","length_m":10.8,"width_m":2.5,"max_speed":8.0},plan.route,plan.stops[0].progress,true)
     var passing:Dictionary=merge_sim.spawn({"id":"car-sedan-03","length_m":4.5,"width_m":1.8,"max_speed":12.0},car_route,8.0,true)
     var safe:bool=not merging.is_empty() and not passing.is_empty()
     if safe:
      merging.speed=8.0;passing.speed=12.0
      for step in range(90):
       merge_sim.update(1.0/30.0)
       if merge_sim.overlaps(merging,passing):safe=false
     check(safe,"physical curb merge does not overlap through car "+str(lanes))
    var car:Dictionary=sim.spawn({"id":"car-sedan-03","length_m":4.5,"width_m":1.8,"max_speed":12.0},car_route,car_progress,true)
    check(not car.is_empty(),"real following car can spawn "+str(lanes))
    if not car.is_empty():
     sim.update(10)
     check(bus.distance<.001,"scheduled bus dwells without creeping "+str(lanes))
     check(car.distance>35 if lanes in [2,4,6] else car.distance<14,"shoulder permits through traffic / running-lane stop queues follower "+str(lanes))
    for stop:Dictionary in plan.stops:
     var lane:Dictionary=network.lanes[stop.lane]
     check(lane.get("bus_pocket",false)==(lanes in [2,4,6]),"curb pocket only on approved shoulder profiles "+str(lanes))
    city.create_transit_line("bus",stops,{"dwell_seconds":1.0})
    var Adapter=load("res://core/city_simulation_worker.gd")
    var worker=Adapter.new();worker.boot(Adapter.capture(city))
    var result:Dictionary={}
    for i in range(1,13):result=worker.run_step({"base_tick":i-1,"base_revision":0},float(city.config.development_interval_seconds),i)
    check(result.transit_state.visible.size()==1,"worker actually operates a bus "+str(lanes))
    if result.transit_state.visible.size()==1:
     check(result.transit_state.bus.vehicles[0].distance>0,"bus moves via fixed ACC steps "+str(lanes))
     var restored=Adapter.new();restored.boot(Adapter.capture(worker.city))
     var next:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},float(city.config.development_interval_seconds),1)
     result=worker.run_step({"base_tick":12,"base_revision":0},float(city.config.development_interval_seconds),13)
     check(result.transit_state==next.transit_state,"bus ACC/reservation checkpoint exact "+str(lanes))
     var frozen:Array=result.transit_state.visible.duplicate(true)
     worker.city.public_facilities.lots[0].front_road_id=-1
     result=worker.run_step({"base_tick":13,"base_revision":0},float(city.config.development_interval_seconds),14)
     check(result.transit_state.visible==frozen and result.transit_state.lines[1].status=="blocked","invalid host freezes retained bus, no relocation "+str(lanes))
     check(not worker.city.create_transit_line("bus",stops).ok,"invalid-host stop cannot start another line "+str(lanes))
     worker.city.remove_transit_line(1)
     result=worker.run_step({"base_tick":14,"base_revision":0},float(city.config.development_interval_seconds),15)
     check(result.transit_state.visible.is_empty() and result.transit_state.bus.vehicles.is_empty(),"line removal clears body and reservations "+str(lanes))
 print("SCHEDULED_BUSES checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
