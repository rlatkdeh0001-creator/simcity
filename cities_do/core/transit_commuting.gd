extends RefCounted
## Worker-side passenger routing. Physical access and operating lines are separate proofs.
const Graph=preload("res://core/transit_access_graph.gd")
const Planner=preload("res://core/transit_line_planner.gd")
const Regional=preload("res://core/regional_exchange.gd")
static func point(record:Dictionary)->Vector2:
 if record.has("position"):return record.position
 if record.has("polygon"):
  var p:=Vector2.ZERO
  for v:Vector2 in record.polygon:p+=v
  if not record.polygon.is_empty():return p/record.polygon.size()
 if record.has("frame"):return record.frame.origin+record.frame.along*(record.u+record.size/2.0)+record.frame.outward*(record.v+record.size/2.0)
 return Vector2(record.x+record.size/2.0,record.y+record.size/2.0)
static func stop_key(id:int)->String:return "stop:%d"%id
static func building_key(id:int)->String:return "building:%d"%id
static func request(city,key:String,record:Dictionary)->Dictionary:
 # Revalidate the physical frontage, including restored/stale host IDs.
 var host:int=int(record.get("front_road_id",-1))
 var polygon:PackedVector2Array=record.get("polygon",city.footprint(record) if record.has("zone") else PackedVector2Array())
 var valid:=false
 if not polygon.is_empty():
  for candidate:Dictionary in preload("res://core/building_frontage.gd").candidates(polygon,city.roads,city.config.road_access_distance):
   if candidate.road==host:valid=true;break
 return {"key":key,"host":host if valid else -1,"point":point(record)}
func routes(city,exchange:Dictionary,context:Dictionary)->Array:
 var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/transit_commuting_config.json"))
 var lots:Dictionary={};var requests:Array=[];var paths:Array=[]
 var stations:Array=city.public_facilities.lots.filter(func(lot):return lot.get("internal_kind","") in ["rail","metro"] or lot.get("public_asset_id","")=="bus-stop-01")
 stations.sort_custom(func(a,b):return a.id<b.id)
 for lot:Dictionary in stations:lots[int(lot.id)]=lot;requests.append(request(city,stop_key(lot.id),lot))
 for building:Dictionary in city.buildings:requests.append(request(city,building_key(building.id),building))
 for road:Dictionary in city.roads:
  if road.kind=="local":paths.append({"id":road.parcel_id,"points":road.points,"height":road.get("elevation_m",0.0)})
 var walk=Graph.new();walk.build(paths,requests)
 var walking:Dictionary={}
 for id:int in lots:walking[id]=walk.distances(stop_key(id))
 var lines:Array=city.transit_lines.duplicate(true);lines.sort_custom(func(a,b):return a.id<b.id)
 var edges:Dictionary={};var served:Dictionary={}
 for line:Dictionary in lines:
  if not line.get("enabled",true) or line.kind=="freight":continue
  var plan:Dictionary={}
  if line.kind=="bus":
   var network=preload("res://core/scheduled_bus_network.gd").new();network.build_city(city);plan=network.line_plan(line.stops)
   if plan.get("ok",false):
    var cumulative:Array=[0.0]
    for lane:int in plan.route:cumulative.append(float(cumulative[-1])+float(network.lanes[lane].length))
    plan.length=cumulative[-1]
    for stop:Dictionary in plan.stops:stop.distance=float(cumulative[stop.route_index])+float(stop.progress)
   # Operations discards deleted lines' vehicles later in this same worker step.
   # Only surviving occupancy can freeze the current bus topology, not a removed line.
   var bus_ids:Array=lines.filter(func(current):return current.kind=="bus").map(func(current):return current.id)
   if city.transit_state.bus.get("vehicles",[]).any(func(vehicle):return vehicle.line_id in bus_ids) and city.transit_state.bus.get("topology_key",0)!=preload("res://core/transit_operations.gd").bus_topology_key(city):continue
  else:
   plan=Planner.new().rail_plan(city,line)
   var train:Dictionary=city.transit_state.trains.get(line.id,{})
   if not train.is_empty() and train.plan!=plan:continue
  if not plan.get("ok",false):continue
  # P3 rail loops carry passengers in stop order, including the physical return leg.
  for i in range(line.stops.size()):
   var a:int=line.stops[i];var b:int=line.stops[(i+1)%line.stops.size()]
   if not lots.has(a) or not lots.has(b):continue
   if not served.has(a):served[a]=[]
   served[a].append(line.kind)
   var length:float=0.0
   if line.kind!="bus":length=fposmod(float(plan.stops[(i+1)%line.stops.size()].distance)-float(plan.stops[i].distance),float(plan.length))
   else:length=_bus_distance(plan,i)
   add_edge(edges,a,b,{"kind":line.kind,"line_id":line.id,"from_stop":a,"to_stop":b,"distance_m":length})
 for a:int in served:
  for b:int in served:
   if a==b:continue
   var distance:float=walking[a].get(stop_key(b),INF)
   if distance<=float(config.walk_transfer_metres):add_edge(edges,a,b,{"kind":"walk","from_stop":a,"to_stop":b,"distance_m":distance})
 var endpoints:Dictionary={}
 for row:Dictionary in context.workplaces:endpoints[row.workplace_id]="inbound"
 var homes:Dictionary={}
 for row:Dictionary in context.unemployed+context.outbound:
  if int(row.home_id)>=0:homes[row.home_id]=true
 var result:Array=[]
 for mode:String in ["rail","metro"]:
  var rail_paths:Array=[];var rail_requests:Array=[];var terminals:Array=[]
  for route:Dictionary in city.transit_routes:
   if route.kind!=mode:continue
   rail_paths.append({"id":route.id,"points":route.points})
   for pair:Array in [[0,1],[route.points.size()-1,route.points.size()-2]]:
    var edge:String=Regional.endpoint_edge(route.points[pair[0]],route.points[pair[1]],city.width,city.height)
    if edge.is_empty():continue
    var key:String="boundary:%d:%d"%[route.id,pair[0]]
    terminals.append({"key":key,"edge":edge,"point":route.points[pair[0]]})
    rail_requests.append({"key":key,"host":route.id,"point":route.points[pair[0]],"max_offset_m":0.001})
  for id:int in served:
   var lot:Dictionary=lots[id]
   if lot.get("internal_kind","")!=mode or not mode in served[id]:continue
   var internal:PackedVector2Array=lot.internal_points
   for route:Dictionary in city.transit_routes:
    if int(route.get("station_id",-1))==id:rail_requests.append({"key":stop_key(id),"host":route.id,"point":(internal[0]+internal[-1])/2,"max_offset_m":0.001})
  var rail=Graph.new();rail.build(rail_paths,rail_requests)
  for terminal:Dictionary in terminals:
   var access:Dictionary=rail.rail_distances(terminal.key)
   for town:Dictionary in exchange.neighbors:
    if town.edge!=terminal.edge or not town.channels[mode].connected:continue
    for id:int in endpoints:result.append_array(_choices(id,"inbound",town,mode,terminal,access,served,edges,walking,config))
    for id:int in homes:result.append_array(_choices(id,"outbound",town,mode,terminal,access,served,edges,walking,config))
 return result
static func add_edge(edges:Dictionary,a:int,b:int,leg:Dictionary):
 if not edges.has(a):edges[a]=[]
 edges[a].append({"target":b,"leg":leg})
func _choices(id:int,direction:String,town:Dictionary,mode:String,terminal:Dictionary,access:Dictionary,served:Dictionary,edges:Dictionary,walking:Dictionary,config:Dictionary)->Array:
 var result:Array=[]
 for station:int in served:
  if not mode in served[station] or not access.has(stop_key(station)):continue
  var journeys:Dictionary=_journeys(station,edges,direction=="outbound")
  for end:int in journeys:
   var distance:float=walking[end].get(building_key(id),INF)
   if distance>float(config.walk_access_metres):continue
   var journey:Dictionary=journeys[end]
   var legs:Array=journey.legs.duplicate(true)
   var feeder:Dictionary={"kind":mode,"regional":true,"boundary":terminal.point,"station_id":station,"distance_m":access[stop_key(station)]}
   var foot:Dictionary={"kind":"walk","station_id":end,"building_id":id,"distance_m":distance}
   if direction=="inbound":legs.push_front(feeder);legs.append(foot)
   else:legs.reverse();legs.push_front(foot);legs.append(feeder)
   result.append({"neighbor_id":str(town.id),"local_id":id,"direction":direction,"mode":mode,"reachable":true,"station_access":true,"station_id":station,"distance_m":float(access[stop_key(station)])+float(journey.distance)+distance,"route_id":"%s/%s/%s/%d/%d/%d/%s"%[town.id,mode,terminal.key,station,end,id,JSON.stringify(legs)],"boundary":terminal.point,"legs":legs})
 return result
func _journeys(start:int,edges:Dictionary,reverse:bool)->Dictionary:
 var adjacency:Dictionary={}
 for a:int in edges:
  for edge:Dictionary in edges[a]:
   if reverse:add_edge(adjacency,edge.target,a,edge.leg)
   else:add_edge(adjacency,a,edge.target,edge.leg)
 var best:Dictionary={start:{"distance":0.0,"legs":[],"tie":""}};var pending:Array=[start];var done:Dictionary={}
 while not pending.is_empty():
  pending.sort_custom(func(a,b):return best[a].distance<best[b].distance if best[a].distance!=best[b].distance else a<b)
  var current:int=pending.pop_front()
  if done.has(current):continue
  done[current]=true
  for edge:Dictionary in adjacency.get(current,[]):
   var cost:float=best[current].distance+float(edge.leg.distance_m)
   var tie:String=best[current].tie+JSON.stringify(edge.leg)
   var next:int=edge.target
   if done.has(next):continue
   if best.has(next) and (cost>best[next].distance or (cost==best[next].distance and tie>=best[next].tie)):continue
   var legs:Array=best[current].legs.duplicate(true);legs.append(edge.leg.duplicate(true))
   best[next]={"distance":cost,"legs":legs,"tie":tie};pending.append(next)
 return best
static func _bus_distance(plan:Dictionary,index:int)->float:
 return fposmod(float(plan.stops[(index+1)%plan.stops.size()].distance)-float(plan.stops[index].distance),float(plan.length))
