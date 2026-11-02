extends SceneTree
const Topology = preload("res://core/road_junctions.gd")
const Network = preload("res://core/traffic_network.gd")
const Simulation = preload("res://core/traffic_simulation.gd")
const City = preload("res://core/city_model.gd")
const Bridge = preload("res://core/road_generator_traffic.gd")
var checks := 0
var failed := 0
var asset := {"id":"car-hatch-01","length_m":4.0,"max_speed":14.0}
func _initialize(): run.call_deferred()
func verify(value: bool, label: String):
 checks+=1
 if value:print("PASS "+label)
 else:
  failed+=1
  push_error("FAIL "+label)
func road(points: Array, count: int = 2) -> Dictionary:
 return {"points":PackedVector2Array(points),"lanes":count,"width":float(count),"kind":"local"}
func roads() -> Array:
 return [road([Vector2(10,50),Vector2(90,50)]),road([Vector2(50,10),Vector2(50,90)])]
func cross_network() -> RefCounted:
 var network := Network.new()
 network.build(roads())
 return network
func edge_lane(network, endpoint: Vector2, incoming: bool) -> int:
 for lane in network.lanes:
  if lane.junction>=0:continue
  var point: Vector2=lane.start if incoming else lane.end
  if point.distance_to(endpoint*4)<.01:return lane.id
 return -1
func path(network, first: Vector2, last: Vector2) -> Array:
 return network.route(edge_lane(network,first,true),edge_lane(network,last,false))
func run():
 for method in ["test_topology","test_footprints","test_routes","test_reservations","test_long_vehicle","test_exit_and_queue","test_timing"]:
  if call(method)!=true:verify(false,method+" finishes")
 if await test_bridge()!=true:verify(false,"bridge finishes")
 print("RESULT %d/%d junction checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
func test_topology() -> bool:
 var data: Dictionary=Topology.analyze(roads())
 verify(data.junctions.size()==1 and data.junctions[0].arms.size()==4,"X crossing creates one four-arm junction")
 verify(data.sections.size()==4 and data.errors.is_empty(),"both crossing roads split into four derived sections")
 var fractional: Dictionary=Topology.analyze([road([Vector2(10.2222,50.12345),Vector2(90.8989,50.12345)]),road([Vector2(50.12345,10.1111),Vector2(50.12345,90.7878)])])
 verify(fractional.junctions.size()==1 and fractional.sections.size()==4,"fractional freehand crossing shares a node despite floating point rounding")
 var tee := [roads()[0],road([Vector2(50,10),Vector2(50,50)])]
 data=Topology.analyze(tee)
 verify(data.junctions.size()==1 and data.junctions[0].arms.size()==3 and data.sections.size()==3,"T endpoint joins interior of the through road")
 data=Topology.analyze([road([Vector2(10,50),Vector2(50,50)]),road([Vector2(50,50),Vector2(50,90)])])
 verify(data.junctions.size()==1 and data.junctions[0].arms.size()==2,"separate right-angle road endpoints form a turn junction")
 data=Topology.analyze([road([Vector2(10,50),Vector2(50,50),Vector2(90,50)]),road([Vector2(50,10),Vector2(50,50),Vector2(50,90)])])
 verify(data.junctions.size()==1 and data.sections.size()==4,"crossing at sampled vertices is deduplicated")
 data=Topology.analyze([road([Vector2(10,10),Vector2(90,90)]),road([Vector2(10,90),Vector2(90,10)])])
 verify(data.junctions.size()==1 and data.junctions[0].position.distance_to(Vector2(50,50))<.001,"diagonal crossing uses real world intersection")
 data=Topology.analyze([road([Vector2(10,10),Vector2(90,90),Vector2(10,90),Vector2(90,10)])])
 verify(data.junctions.size()==1 and data.sections.size()==3,"self crossing polyline forms a junction without splitting its construction object")
 data=Topology.analyze([road([Vector2(10,50),Vector2(90,50)]),road([Vector2(20,50),Vector2(70,50)])])
 verify(not data.errors.is_empty(),"collinear duplicate overlap stays rejected")
 var city := City.new(100,100)
 city.add_road(roads()[0].points)
 city.add_road(roads()[1].points)
 verify(city.junctions.size()==1 and city.roads.size()==2,"city caches real junctions while retaining two selectable road objects")
 city.demolish("road",city.roads[1].parcel_id)
 verify(city.junctions.is_empty() and city.roads.size()==1,"removing crossing road removes the junction")
 return true
func test_footprints() -> bool:
 var city := City.new(100,100)
 city.add_road(roads()[0].points)
 city.add_road(roads()[1].points)
 verify(not city.add_building(51,47).ok,"building cannot occupy filled junction corner outside old straight ribbons")
 verify(not city.add_power_plant(Vector2(51,47)).ok,"utility footprint also respects junction pavement")
 var corner_clear := true
 for parcel in city.zoning_grid.parcels.values():
  for junction in city.junctions:
   corner_clear=corner_clear and not city.Parcels.overlap(parcel.polygon,Topology.patch(junction))
 verify(corner_clear,"placement tiles exclude the actual junction footprint")
 var occupied := City.new(100,100)
 occupied.add_road(roads()[0].points)
 var house: Dictionary=occupied.add_building(51,47)
 verify(house.ok,"corner lot was valid before crossing road existed")
 var before: int=occupied.roads.size()
 var preview: Dictionary=occupied.add_road(roads()[1].points,"local",false)
 verify(not preview.ok and occupied.roads.size()==before and occupied.junctions.is_empty(),"new intersection cannot pave over an existing corner building even in preview")
 return true
func test_routes() -> bool:
 var network=cross_network()
 var connectors: Array=network.lanes.filter(func(lane):return lane.junction>=0)
 verify(connectors.size()==12,"two-lane X has 12 directed straight left and right connectors")
 for goal in [Vector2(90,50),Vector2(50,10),Vector2(50,90)]:
  var route := path(network,Vector2(10,50),goal)
  verify(route.size()==3 and network.lanes[route[1]].junction==0,"west approach routes through junction to "+str(goal))
 verify(path(network,Vector2(10,50),Vector2(10,50)).is_empty(),"U-turn into incoming carriageway is not invented")
 var continuous := true
 var forward := true
 for connector in connectors:
  continuous=continuous and network.sample(connector.from,network.lanes[connector.from].length).distance_to(network.sample(connector.id,0))<.01
  continuous=continuous and network.sample(connector.id,connector.length).distance_to(network.sample(connector.to,0))<.01
  forward=forward and network.tangent(connector.from,network.lanes[connector.from].length).dot(network.tangent(connector.to,0))>-.95
 verify(continuous,"turn curves meet source and receiving lanes without teleportation")
 verify(forward,"connector graph never links an oncoming U-turn")
 var points_valid := true
 for connector in connectors:
  for step in range(30):points_valid=points_valid and network.sample(connector.id,connector.length*step/29).is_finite()
 verify(points_valid,"all baked junction curve positions are finite")
 var mixed := Network.new()
 verify(mixed.build([road([Vector2(10,50),Vector2(90,50)],4),road([Vector2(50,10),Vector2(50,90)])]),"four-lane and two-lane intersection builds")
 verify(path(mixed,Vector2(10,50),Vector2(50,90)).size()==3,"mixed-width intersection routes into narrower receiving road")
 var tee := Network.new()
 tee.build([roads()[0],road([Vector2(50,10),Vector2(50,50)])])
 verify(path(tee,Vector2(50,10),Vector2(90,50)).size()==3,"T junction routes from branch onto through road")
 var sim := Simulation.new(network)
 verify(sim.spawn(asset,[-1]).is_empty(),"invalid route index rejected before lane access")
 var connector: Dictionary=connectors[0]
 verify(sim.spawn(asset,[connector.id,connector.to],3).is_empty(),"vehicles cannot spawn already inside an unreserved junction")
 return true
func test_reservations() -> bool:
 var network=cross_network()
 var sim := Simulation.new(network)
 var pairs := [[Vector2(10,50),Vector2(90,50)],[Vector2(90,50),Vector2(10,50)],[Vector2(50,10),Vector2(50,90)],[Vector2(50,90),Vector2(50,10)]]
 for pair in pairs:
  var route := path(network,pair[0],pair[1])
  sim.spawn(asset,route,network.lanes[route[0]].length-18)
 verify(sim.vehicles.size()==4,"four opposing approaches spawn correctly")
 var safe := true
 var passed := {}
 for tick in range(30*45):
  sim.update(1.0/30)
  var inside := 0
  for vehicle in sim.vehicles:
   if network.lanes[vehicle.lane].junction>=0:
    inside+=1
    passed[vehicle.id]=true
   elif vehicle.clearing.has(0) and vehicle.distance-float(vehicle.clearing[0])<vehicle.length/2+vehicle.min_gap:inside+=1
  safe=safe and inside<=1
 verify(safe,"conflicting vehicles never share intersection or rear-clearance region")
 verify(passed.size()==4,"all four approaches eventually pass without starvation")
 verify(sim.vehicles.all(func(vehicle):return vehicle.arrived),"all four cars reach their routed destination")
 return true
func test_long_vehicle() -> bool:
 var network=cross_network()
 var sim := Simulation.new(network)
 var truck := asset.duplicate()
 truck.length_m=12.0
 var pairs := [[Vector2(10,50),Vector2(50,90)],[Vector2(50,10),Vector2(10,50)]]
 for pair in pairs:
  var route := path(network,pair[0],pair[1])
  sim.spawn(truck,route,network.lanes[route[0]].length-22)
 var safe := true
 var cleared := false
 for i in range(30*40):
  sim.update(1.0/30)
  var protected := 0
  for vehicle in sim.vehicles:
   if network.lanes[vehicle.lane].junction==0:protected+=1
   elif vehicle.clearing.has(0) and vehicle.distance-float(vehicle.clearing[0])<vehicle.length/2+vehicle.min_gap:
    protected+=1
    cleared=true
  safe=safe and protected<=1
 verify(safe and cleared,"12m vehicles retain exclusive reservation until their rear clears")
 verify(sim.vehicles.size()==2 and sim.vehicles.all(func(vehicle):return vehicle.arrived),"long vehicles complete two conflicting turns")
 return true
func test_exit_and_queue() -> bool:
 var network=cross_network()
 var route := path(network,Vector2(10,50),Vector2(90,50))
 var sim := Simulation.new(network)
 var blocker: Dictionary=sim.spawn(asset,[route[-1]],4)
 blocker.max_speed=0
 var arriving: Dictionary=sim.spawn(asset,route,network.lanes[route[0]].length-12)
 for i in range(30*12):sim.update(1.0/30)
 verify(arriving.lane==route[0] and arriving.speed<.05,"blocked receiving lane prevents entry and box blocking")
 sim.vehicles.erase(blocker)
 for i in range(30*15):sim.update(1.0/30)
 verify(arriving.route_index>0,"clearing receiving lane releases waiting approach")
 var queue := Simulation.new(network)
 var follower: Dictionary=queue.spawn(asset,route,network.lanes[route[0]].length-24)
 var leader: Dictionary=queue.spawn(asset,route,network.lanes[route[0]].length-10)
 for i in range(30*18):queue.update(1.0/30)
 verify(leader.route_index>0 and follower.route_index>0,"front vehicle is admitted before lower-ID follower behind it")
 var red := Simulation.new(network)
 var first: Dictionary=red.spawn(asset,route,network.lanes[route[0]].length-12)
 red.signals[route[0]]={"progress":network.lanes[route[0]].length,"red":true}
 for i in range(180):red.update(1.0/30)
 verify(first.route_index==0 and red.reservations.is_empty(),"manual red stop does not reserve and block the junction")
 return true
func test_timing() -> bool:
 var network=cross_network()
 var a := Simulation.new(network)
 var b := Simulation.new(network)
 var route := path(network,Vector2(10,50),Vector2(50,90))
 a.spawn(asset,route,network.lanes[route[0]].length-18)
 b.spawn(asset,route,network.lanes[route[0]].length-18)
 for i in range(30*15):a.update(1.0/30)
 for i in range(60*15):b.update(1.0/60)
 verify(a.vehicles[0].lane==b.vehicles[0].lane and is_equal_approx(a.vehicles[0].progress,b.vehicles[0].progress),"30/60 rendering rates produce identical junction movement")
 return true
func test_bridge() -> bool:
 var network=cross_network()
 var sim := Simulation.new(network)
 var route := path(network,Vector2(10,50),Vector2(50,10))
 var car: Dictionary=sim.spawn(asset,route,network.lanes[route[0]].length-15)
 var bridge := Bridge.new()
 root.add_child(bridge)
 bridge.setup(network)
 var agrees := true
 var turned := false
 for i in range(30*15):
  sim.update(1.0/30)
  bridge.sync(sim.vehicles)
  turned=turned or car.route_index>0
  var actual: Vector3=bridge.actors[car.id].global_position
  agrees=agrees and Vector2(actual.x,actual.z).distance_to(sim.position(car))<.03
 verify(agrees and turned,"actual RoadLaneAgent follows selected junction turn curve")
 bridge.queue_free()
 await process_frame
 return true
