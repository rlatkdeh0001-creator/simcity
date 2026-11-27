extends SceneTree

const City=preload("res://core/city_model.gd")
const Profile=preload("res://core/road_profile.gd")
const BusNetwork=preload("res://core/scheduled_bus_network.gd")
const Operations=preload("res://core/transit_operations.gd")
const Worker=preload("res://core/city_simulation_worker.gd")
const Stop:="bus-stop-01"
var checks:=0
var failures:=0

func _initialize():run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)

func new_city():
 var city=City.new(120,120,42)
 city.population_enabled=false;city.happiness_enabled=false
 return city

func segment(city,a:Vector2,b:Vector2,lanes:int,direction:int)->Dictionary:
 return city.add_road(PackedVector2Array([a,b]),"local",true,lanes,true,false,1,{},direction)

func test_right_curb():
 for lanes:int in [1,2,3,4]:
  for heading:int in [1,-1]:
   var tag:="%d lanes heading %d"%[lanes,heading]
   var city=new_city()
   var middle:=Vector2(60,40)
   check(segment(city,middle-Vector2(48*heading,0),middle+Vector2(48*heading,0),lanes,1).ok,"place road: "+tag)
   if city.roads.is_empty():continue
   var road:Dictionary=city.roads[0]
   var right:=Vector2(0,heading)
   var edges:=Profile.asphalt_edges(road)
   var left:Dictionary=city.public_facilities.preview(Stop,middle+right*edges.x)
   check(not left.ok and left.code=="sidewalk","left click cannot snap across the road: "+tag)
   var right_stop:Dictionary=city.public_facilities.place(Stop,middle+right*edges.y,0,true)
   check(right_stop.ok,"right sidewalk accepts stop: "+tag)
   if not right_stop.ok:continue
   var original:Dictionary=right_stop.record.duplicate(true)
   check(original.position.is_equal_approx(middle+right*edges.y) and original.front_direction==-right and original.road_direction==1,"signed curb and frontage: "+tag)
   check(city.demolish_road_unit(road.parcel_id,middle-Vector2(16*heading,0)).ok,"split the directed host: "+tag)
   if city.roads.size()!=2:continue
   check(city.roads[1].parcel_id!=original.front_road_id,"stop is on the new fragment: "+tag)
   original.front_road_id=city.roads[1].parcel_id
   check(city.public_facilities.lots[0]==original,"fixed curb rebinds without moving: "+tag)

func ring(lanes:int,direction:int):
 var city=new_city()
 var corners:=[Vector2(16,20),Vector2(104,20),Vector2(104,100),Vector2(16,100)]
 for i in range(4):
  check(segment(city,corners[i],corners[(i+1)%4],lanes,direction).ok,"construct loop segment %d"%i)
 return city

func stop_on(city,x:float,y:float,side:int)->Dictionary:
 var edge:=Profile.asphalt_edges(city.roads[0]).y
 return city.public_facilities.place(Stop,Vector2(x,y+edge*side))

func test_directed_plans():
 for lanes:int in [1,2,3,4]:
  var city=ring(lanes,1)
  if city.roads.size()!=4:continue
  var a:=stop_on(city,40,20,1);var b:=stop_on(city,80,100,-1)
  check(a.ok and b.ok,"place two scheduled curbs: %d"%lanes)
  if not a.ok or not b.ok:continue
  var ids:=[a.record.id,b.record.id]
  var network=BusNetwork.new()
  check(network.build_city(city),"build directed bus network: %d"%lanes)
  var plan:=network.line_plan(ids)
  check(plan.ok,"directed loop has a valid schedule: %d"%lanes)
  if not plan.ok:continue
  var legal:=true
  for lane_id:int in plan.route:
   var lane:Dictionary=network.lanes[lane_id]
   if lane.road>=0 and lane.direction!=1:legal=false
  check(legal,"schedule excludes all reverse running lanes: %d"%lanes)
  var berth:Dictionary=network.lanes[plan.stops[0].lane]
  check(berth.index==lanes-1 and berth.get("bus_pocket",false)==(lanes!=3),"only the outer lane or its right shoulder serves the stop: %d"%lanes)
  var car_route:Array=plan.route.duplicate()
  for lane:Dictionary in network.lanes:
   if berth.get("bus_pocket",false) and lane.id!=berth.id and lane.next==berth.next and lane.road==berth.road:car_route[0]=lane.id;break
  var sim=preload("res://core/scheduled_bus_simulation.gd").new(network)
  var bus:Dictionary=sim.spawn_line({"id":"bus-city-01","length_m":10.8},plan,{"id":1,"headway_seconds":60.0,"dwell_seconds":30.0})
  var car_start:float=3.0 if berth.get("bus_pocket",false) else float(plan.stops[0].progress)-20.0
  var car:Dictionary=sim.spawn({"id":"car-sedan-03","length_m":4.5,"width_m":1.8},car_route,car_start,true)
  check(not bus.is_empty() and not car.is_empty(),"bus and its follower spawn on real directed geometry: %d"%lanes)
  if bus.is_empty() or car.is_empty():continue
  sim.update(10.0)
  check(bus.distance<.001 and (car.distance>35.0 if lanes!=3 else car.distance<14.0),"shoulder bypasses dwelling bus, unshouldered outer lane queues: %d"%lanes)
  var made:Dictionary=city.create_transit_line("bus",ids,{"dwell_seconds":1.0})
  check(made.ok,"author directed bus line: %d"%lanes)
  if not made.ok:continue
  Operations.new().advance(city,3.0)
  check(city.transit_state.visible.size()==1 and city.transit_state.visible[0].heading.dot(Vector2.RIGHT)>.99 and city.transit_state.bus.vehicles[0].distance>0,"operations advance the bus in the authored direction: %d"%lanes)
 var open=new_city()
 check(segment(open,Vector2(16,20),Vector2(104,20),3,1).ok,"construct one-way road without a return")
 if open.roads.is_empty():return
 var a:=stop_on(open,40,20,1);var b:=stop_on(open,80,20,1)
 check(a.ok and b.ok,"both open-road stops physically valid")
 if not a.ok or not b.ok:return
 var network=BusNetwork.new();network.build_city(open)
 var from:Dictionary=network.stops[a.record.id];var to:Dictionary=network.stops[b.record.id]
 check(from.lane==to.lane and from.progress<to.progress,"reverse request is on the same directed lane with decreasing chainage")
 var next_id:int=open.next_transit_line_id;var state:Dictionary=open.transit_state.duplicate(true)
 var rejected:Dictionary=open.create_transit_line("bus",[b.record.id,a.record.id])
 check(not rejected.ok and rejected.code=="unreachable_line" and open.transit_lines.is_empty(),"wrong-way request rejects without creating a service")
 check(open.next_transit_line_id==next_id and open.transit_state==state,"wrong-way validation leaves IDs and runtime state untouched")

func test_topology_direction():
 var city=new_city()
 check(segment(city,Vector2(16,20),Vector2(104,20),3,0).ok,"build a legacy-compatible road for the topology key")
 if city.roads.is_empty():return
 var road:Dictionary=city.roads[0]
 var old_key:=hash([[[road.parcel_id,road.points,road.kind,road.lanes,road.width,road.get("major_side",1)]],[]])
 check(Operations.bus_topology_key(city)==old_key,"two-way topology key remains compatible with saved occupied routes")
 # Equal points, IDs, and width: isolate the signed profile input without mutating live roads.
 var draft:={"roads":[road.duplicate(true)],"public_facilities":{"lots":[]}}
 draft.roads[0].travel_dir=1
 var forward:=Operations.bus_topology_key(draft)
 draft.roads[0].travel_dir=-1
 check(forward!=old_key and forward!=Operations.bus_topology_key(draft),"topology key distinguishes flow even when no other road input changed")

func test_occupied_replacement(detour:bool,reverse:bool=true):
 var city=ring(4,0)
 if city.roads.size()!=4:return
 var a:=stop_on(city,40,20,1);var b:=stop_on(city,80,100,-1)
 check(a.ok and b.ok,"place stops away from the replaced segment")
 if not a.ok or not b.ok:return
 var made:Dictionary=city.create_transit_line("bus",[a.record.id,b.record.id],{"dwell_seconds":1.0})
 check(made.ok,"create occupied replacement fixture")
 if not made.ok:return
 var id:int=made.line.id
 var operations=Operations.new();operations.advance(city,3.0)
 var frozen:Dictionary=city.transit_state.bus.duplicate(true)
 check(frozen.vehicles.size()==1 and frozen.vehicles[0].distance>0,"bus is moving before road is cut")
 if frozen.vehicles.is_empty():return
 var old_vehicle:int=frozen.vehicles[0].id
 check(city.demolish("road",city.roads[1].parcel_id).ok,"remove the southbound leg of the occupied route")
 operations.advance(city,0.5)
 check(city.transit_state.bus==frozen and city.transit_state.lines[id].status=="blocked","demolition alone still freezes the occupied bus exactly")
 var Adapter=preload("res://core/city_simulation_worker.gd")
 var worker=Adapter.new();worker.boot(Adapter.capture(city))
 var north:=Vector2(104,20);var south:=Vector2(104,100)
 check(segment(city,south if reverse else north,north if reverse else south,4,1).ok,"replace severed leg with one-way flow, reversed=%s"%reverse)
 if detour:
  for pair:Array in [[north,Vector2(114,20)],[Vector2(114,20),Vector2(114,100)],[Vector2(114,100),south]]:
   check(segment(city,pair[0],pair[1],4,1).ok,"build a legal alternate directed leg")
 var network=BusNetwork.new();network.build_city(city)
 check(network.line_plan(made.line.stops).ok==(detour or not reverse),"line planner respects the actual replacement flow")
 var delta:={"base_tick":0,"base_revision":0,"world":{"roads":city.roads,"public_lots":city.public_facilities.lots}}
 var result:Dictionary=worker.run_step(delta,float(city.config.development_interval_seconds),1)
 check(result.get("ok",false),"restored worker accepts the real replacement world")
 if not result.get("ok",false):return
 if not reverse:
  check(result.transit_state.bus==frozen and result.transit_state.lines[id].status=="blocked","same-flow replacement does not override the occupied-graph freeze")
  return
 var vehicles:Array=result.transit_state.bus.vehicles
 check(vehicles.size()==int(detour) and vehicles.all(func(vehicle):return vehicle.id!=old_vehicle),"obsolete bus removed; legal branch only spawns on the new plan")
 if not detour:
  check(result.transit_state.visible.is_empty() and result.transit_state.lines[id].status=="blocked" and result.transit_state.bus.reservations.is_empty(),"unreachable replacement leaves a blocked line but no stale bus pose or reservations")
 elif vehicles.size()==1 and vehicles[0].id!=old_vehicle:
  var restored=Adapter.new();restored.boot(Adapter.capture(worker.city))
  for tick:int in range(2,5):
   result=worker.run_step({"base_tick":tick-1,"base_revision":0},float(city.config.development_interval_seconds),tick)
   var copy:Dictionary=restored.run_step({"base_tick":tick-2,"base_revision":0},float(city.config.development_interval_seconds),tick-1)
   check(result.transit_state==copy.transit_state,"replanned bus checkpoint continues exactly at tick %d"%tick)
  check(result.transit_state.bus.vehicles[0].distance>vehicles[0].distance,"replanned bus moves after replacement")

func test_legacy_occupied_replacement(adapter,detour:bool,observe_cut:bool,reverse:bool=true,drop_frozen_provenance:bool=false):
 var city=ring(4,0)
 if city.roads.size()!=4:return
 var a:=stop_on(city,40,20,1);var b:=stop_on(city,80,100,-1)
 check(a.ok and b.ok,"place legacy fixture stops away from the replaced leg")
 if not a.ok or not b.ok:return
 var made:Dictionary=city.create_transit_line("bus",[a.record.id,b.record.id],{"dwell_seconds":1.0})
 check(made.ok,"create legacy fixture line")
 if not made.ok:return
 var id:int=made.line.id
 Operations.new().advance(city,3.0)
 var checkpoint:Dictionary=Worker.capture(city)
 var legacy:Dictionary=checkpoint.model.values.transit_state.bus
 check(legacy.vehicles.size()==1 and legacy.vehicles[0].distance>0 and legacy.erase("route_paths"),"checkpoint represents a moving pre-E4a bus without provenance")
 if legacy.vehicles.is_empty():return
 var old_vehicle:int=legacy.vehicles[0].id
 var worker=adapter.new()
 check(worker.boot(checkpoint).ok,"boot the occupied pre-E4a checkpoint")
 # No unchanged tick before the first edited world is accepted.
 check(city.demolish("road",city.roads[1].parcel_id).ok,"demolish the legacy itinerary's southbound leg")
 var seconds:float=city.config.development_interval_seconds
 if observe_cut:
  var cut:Dictionary=worker.run_step({"base_tick":0,"base_revision":0,"world":{"roads":city.roads,"public_lots":city.public_facilities.lots}},seconds,1)
  check(cut.get("ok",false),"accept legacy demolition as its own worker step")
  if not cut.get("ok",false):return
  var cut_bus:Dictionary=cut.transit_state.bus.duplicate(true)
  cut_bus.erase("route_paths")
  check(cut_bus==legacy and cut.transit_state.visible==legacy.visible and cut.transit_state.lines[id].status=="blocked","demolition-only preserves all frozen legacy operations state")
  var restored=adapter.new();var cut_checkpoint:Dictionary=Worker.capture(worker.city)
  if drop_frozen_provenance:cut_checkpoint.model.values.transit_state.bus.erase("route_paths")
  check(restored.boot(cut_checkpoint).ok,"restore a frozen checkpoint before rebuilding")
  worker=restored
 var north:=Vector2(104,20);var south:=Vector2(104,100)
 check(segment(city,south if reverse else north,north if reverse else south,4,1).ok,"rebuild legacy route leg, reversed=%s"%reverse)
 if detour:
  for pair:Array in [[north,Vector2(114,20)],[Vector2(114,20),Vector2(114,100)],[Vector2(114,100),south]]:
   check(segment(city,pair[0],pair[1],4,1).ok,"build legitimate detour for legacy service")
 var result:Dictionary=worker.run_step({"base_tick":0,"base_revision":0,"world":{"roads":city.roads,"public_lots":city.public_facilities.lots}},seconds,1)
 check(result.get("ok",false),"accept legacy fixture replacement world")
 if not result.get("ok",false):return
 var bus:Dictionary=result.transit_state.bus
 if drop_frozen_provenance:
  check(bus==legacy and result.transit_state.visible==legacy.visible and result.transit_state.lines[id].status=="blocked","already-frozen legacy checkpoint without the old graph does not guess from the replacement")
 elif not reverse:
  var retained:=bus.duplicate(true);retained.erase("route_paths")
  check(retained==legacy and result.transit_state.visible==legacy.visible and result.transit_state.lines[id].status=="blocked","legacy same-flow rebuild preserves the occupied freeze")
 elif detour:
  check(bus.vehicles.size()==1 and bus.vehicles[0].id!=old_vehicle and result.transit_state.lines[id].status!="blocked","legacy opposite-flow rebuild respawns only on the legal detour (cut observed=%s)"%observe_cut)
 else:
  check(bus.vehicles.is_empty() and result.transit_state.visible.is_empty() and result.transit_state.lines[id].status=="blocked","legacy opposite-flow rebuild without a detour blocks without a stale bus")

func test_legacy_unrelated_facility(adapter):
 var city=ring(4,0)
 if city.roads.size()!=4:return
 var a:=stop_on(city,40,20,1);var b:=stop_on(city,80,100,-1)
 check(a.ok and b.ok,"place legacy fixture stops before the unrelated edit")
 if not a.ok or not b.ok:return
 var made:Dictionary=city.create_transit_line("bus",[a.record.id,b.record.id],{"dwell_seconds":1.0})
 check(made.ok,"create service for legacy unrelated-edit fixture")
 if not made.ok:return
 Operations.new().advance(city,3.0)
 var checkpoint:Dictionary=Worker.capture(city);var legacy:Dictionary=checkpoint.model.values.transit_state.bus
 check(legacy.vehicles.size()==1 and legacy.vehicles[0].distance>0 and legacy.erase("route_paths"),"save occupied legacy bus before any unrelated edit")
 if legacy.vehicles.is_empty():return
 var worker=adapter.new();check(worker.boot(checkpoint).ok,"boot occupied legacy checkpoint for unrelated edit")
 var park:Dictionary=city.public_facilities.place("park-plaza-4x4",Vector2(60,26),0,true)
 check(park.ok,"place real unrelated park after the legacy checkpoint")
 if not park.ok:return
 var result:Dictionary=worker.run_step({"base_tick":0,"base_revision":0,"world":{"public_lots":city.public_facilities.lots}},float(city.config.development_interval_seconds),1)
 check(result.get("ok",false),"accept the park edit as the first worker step")
 if not result.get("ok",false):return
 var bus:Dictionary=result.transit_state.bus
 check(bus.topology_key==legacy.topology_key and bus.vehicles.size()==1 and bus.vehicles[0].id==legacy.vehicles[0].id and bus.vehicles[0].distance>legacy.vehicles[0].distance and bus.vehicles[0].route==legacy.vehicles[0].route,"unrelated park preserves the legacy bus itinerary and normal movement")

func test_legacy_checkpoints(adapter):
 test_legacy_occupied_replacement(adapter,true,false)
 test_legacy_occupied_replacement(adapter,false,false)
 test_legacy_occupied_replacement(adapter,true,true)
 test_legacy_occupied_replacement(adapter,false,true,false)
 test_legacy_occupied_replacement(adapter,true,true,true,true)
 test_legacy_unrelated_facility(adapter)

func test_running_traffic_rebuild():
 var city=new_city()
 var west:=Vector2(16,20);var east:=Vector2(104,20)
 check(segment(city,west,east,3,0).ok,"ordinary traffic starts on a real two-way road")
 if city.roads.is_empty():return
 var traffic=preload("res://core/traffic_controller.gd").new()
 root.add_child(traffic)
 check(traffic.rebuild(city.roads),"controller builds the initial lane graph")
 traffic.seed_traffic();traffic.update(2.0)
 check(traffic.running and not traffic.simulation.vehicles.is_empty() and traffic.simulation.vehicles.all(func(car):return car.distance>0.0),"seeded ordinary traffic is actually moving before the edit")
 traffic.simulation.paused=true
 var old_bridge:WeakRef=weakref(traffic.bridge)
 check(city.demolish("road",city.roads[0].parcel_id).ok,"demolish the only road while traffic is running")
 check(traffic.has_method("refresh_roads"),"running controller accepts committed road topology edits")
 if not traffic.has_method("refresh_roads"):traffic.free();return
 traffic.refresh_roads(city.roads)
 check(not traffic.running and traffic.simulation==null and old_bridge.get_ref()==null,"empty rebuild clears stale vehicles and lane actors")
 check(segment(city,east,west,3,1).ok,"rebuild the road as westbound only")
 traffic.refresh_roads(city.roads)
 check(traffic.running and not traffic.simulation.vehicles.is_empty(),"active traffic resumes automatically on a usable graph")
 if traffic.running:
  check(traffic.simulation.paused,"rebuilding through an empty graph preserves an explicit pause")
  traffic.simulation.paused=false;traffic.update(2.0)
  var lawful:=true
  for car:Dictionary in traffic.simulation.vehicles:
   if car.distance<=0 or traffic.simulation.heading(car).dot(Vector2.LEFT)<.99:lawful=false
  check(lawful,"replacement vehicles move west with no stale routes or immobile stragglers")
 traffic.stop();traffic.refresh_roads(city.roads)
 check(not traffic.running,"explicit stop stays off after edits")
 traffic.free()

func run():
 test_right_curb()
 test_directed_plans()
 test_topology_direction()
 test_occupied_replacement(false)
 test_occupied_replacement(true)
 test_occupied_replacement(false,false)
 test_legacy_checkpoints(Worker)
 test_running_traffic_rebuild()
 print("ONE_WAY_BUSES checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
