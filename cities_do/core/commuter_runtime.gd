extends RefCounted
## Worker-owned. Canonical macro bookings account every person independently of ACC shadows.
## No scene Nodes, live city mutation, wage changes or wall clock.
const Routes = preload("res://core/commuter_routes.gd")
const Micro = preload("res://core/commuter_micro.gd")
const HZ := 30
const STATE_KEYS := ["tick","credit","records","groups","heap","sequence","lane_next","gate_next","loads","load_events","hourly_demand","pending","fades","parking","tracked","applied","ordinal_next","totals"]
const MICRO_KEYS := ["vehicles","reservations","waiting","signals","paused","elapsed","accumulator","next_id","safety_clamps"]
var routes = Routes.new()
var micro
var config: Dictionary
var catalog := []
var tick := 0
var credit := 0.0
var records := {}
var groups := {}
var heap := []
var sequence := 0
var lane_next := {}
var gate_next := {}
var loads := {}
var load_events := {}
var hourly_demand := {}
var pending := []
var fades := []
var parking := {}
var tracked := {}
var applied := {}
var ordinal_next := 1
var totals := {"persons":0,"departed":0,"arrived":0,"late":0,"returned":0,"unreachable":0,"logical_legs":0,"physical_arrivals":0}
func _init(parameters: Dictionary = {}):
 config=JSON.parse_string(FileAccess.get_file_as_string("res://core/commuter_config.json"));config.merge(parameters,true)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
 for asset in data.vehicles:
  if asset.category=="civilian":catalog.append(asset.duplicate(true))
func prepare_world(city) -> Dictionary:
 if not records.is_empty():return {"ok":false,"reason":"active_world_requires_explicit_replan"}
 var world: Dictionary
 if city is Dictionary:world=city.duplicate(true)
 else:
  world={"width":city.width,"height":city.height,"roads":city.roads.duplicate(true),"buildings":city.buildings.duplicate(true)}
  for row in world.buildings:row["polygon"]=city.footprint(row).duplicate()
 var ok: bool=routes.prepare(world)
 if ok:micro=Micro.new(routes.network)
 return {"ok":ok,"errors":routes.errors.duplicate(),"lane_count":routes.network.lanes.size()}
func prove_route(spec: Dictionary) -> Dictionary:return routes.prove(spec)
func validate_route(route: Dictionary) -> bool:return routes.validate(route)
func set_game_seconds(value: float) -> bool:
 if not records.is_empty() or value<0 or not is_finite(value):return false
 tick=int(round(value*HZ));credit=0;return true
func now() -> float:return float(tick)/HZ
static func display_ordinal(ordinal: int) -> bool:
 return ordinal>=1 and (ordinal<=1000 or (ordinal<=10000 and ordinal%10==0) or (ordinal>10000 and ordinal%100==0))
func apply_plan(component, plan: Dictionary) -> Dictionary:
 if micro==null:return {"ok":false,"reason":"prepare_world_first"}
 var count:=0;var blocked:=0;var duplicates:=0
 var flows: Array=plan.get("flows",[]).duplicate(true)
 flows.sort_custom(func(a,b):return str(a.id)<str(b.id))
 var fresh_groups:=[]
 for flow in flows:
  var flow_id:=str(flow.get("id",""))
  if applied.has(flow_id):duplicates+=1;continue
  if flow_id.is_empty() or int(flow.get("count",-1))<0:return {"ok":false,"reason":"invalid_flow"}
  var proof:=prove_route(flow.get("route",{})) if flow.get("mode","road")=="road" else {"reachable":false,"reason":"transit_not_enabled"}
  applied[flow_id]=true
  var trips: Array=component.trips_for_flow(flow)
  var base_ordinal:=int(flow.get("population_ordinal_start",ordinal_next))
  for trip in trips:
   var id:=str(trip.id)
   if records.has(id):continue
   var ordinal:=int(trip.get("population_ordinal",base_ordinal+int(trip.ordinal)))
   ordinal_next=maxi(ordinal_next,ordinal+1)
   var departure: float=float(trip.departure_hour)*3600.0
   var record: Dictionary=trip.duplicate(true)
   record.merge({"proof":proof,"population_ordinal":ordinal,"status":"scheduled","returning":false,"departure_tick":int(round(departure*HZ)),"deadline_tick":int(round(float(trip.late_after_hour)*3600*HZ)),"arrival_tick":-1,"return_arrival_tick":-1,"late":false,"asset_id":catalog[(ordinal-1)%catalog.size()].id,"segments":[],"physical_done":false},true)
   records[id]=record;totals.persons+=1;count+=1
   if not proof.get("reachable",false) or departure<now():
    record.status="unreachable";totals.unreachable+=1;blocked+=1;continue
   var key:=flow_id+":"+str(record.departure_tick)
   if not groups.has(key):groups[key]={"ids":[],"tick":record.departure_tick,"flow_id":flow_id};fresh_groups.append(key)
   groups[key].ids.append(id)
   _push(record.deadline_tick+1,"deadline",id)
   for returning in [false,true]:
    var itinerary: Dictionary=proof.return_route if returning else proof.outbound
    var bucket:=int(floor(float(trip.departure_hour)+(float(config.shift_game_hours) if returning else 0.0)))
    for lane in itinerary.lanes:
     var demand_key:=str(bucket)+":"+str(lane)
     hourly_demand[demand_key]=int(hourly_demand.get(demand_key,0))+1
 for key in fresh_groups:_push(groups[key].tick,"depart_group",key)
 return {"ok":true,"added":count,"unreachable":blocked,"duplicate_flows":duplicates}
func advance(accepted_game_seconds: float,busy: bool=false) -> Dictionary:
 if busy or accepted_game_seconds<=0 or not is_finite(accepted_game_seconds):return stats()
 credit+=accepted_game_seconds*HZ
 var steps:=int(floor(credit+.0000001));credit-=steps
 var target:=tick+steps
 while tick<target:
  _events_due();_try_spawn()
  if micro.vehicles.is_empty() and pending.is_empty():
   var jump:=target
   if not heap.is_empty():jump=mini(jump,maxi(tick+1,int(heap[0].tick)))
   tick=jump;_prune_fades();continue
  _sync_micro_congestion()
  micro.update(1.0/HZ);tick+=1
  _collect_physical_arrivals();_prune_fades()
 _events_due()
 return stats()
func _events_due():
 while not heap.is_empty() and int(heap[0].tick)<=tick:
  var event: Dictionary=_pop()
  match str(event.kind):
   "depart_group":
    for id in groups[event.data].ids:_depart(id,false)
   "return":_depart(str(event.data),true)
   "deadline":
    var record: Dictionary=records[str(event.data)]
    if int(record.arrival_tick)<0 and record.status!="unreachable" and not record.late:
     record.late=true;totals.late+=1
   "arrive":_arrive(str(event.data.id),bool(event.data.returning))
   "load":
    var key:=str(event.data)
    var change: Dictionary=load_events[key]
    var lane: int=change.lane
    loads[lane].entered+=change.entered;loads[lane].exited+=change.exited
    loads[lane].active+=change.entered-change.exited;load_events.erase(key)
func _depart(id: String,returning: bool):
 var record: Dictionary=records[id]
 if returning and record.status!="at_destination":return
 if not returning and record.status!="scheduled":return
 record.returning=returning;record.status="returning" if returning else "travelling"
 if returning and str(record.direction)=="inbound":_park_delta(record,-1)
 if not returning:totals.departed+=1
 totals.logical_legs+=1
 var route: Dictionary=record.proof.return_route if returning else record.proof.outbound
 var time:=tick+int(ceil(float(config.route_start_allowance_game_seconds)*HZ))
 var segments:=[]
 var bucket:=int(floor(now()/3600.0))
 for lane_id in route.lanes:
  var lane: Dictionary=routes.network.lanes[lane_id]
  var volume:=int(hourly_demand.get(str(bucket)+":"+str(lane_id),0))
  var ratio:=float(volume)/float(config.lane_capacity_vehicles_per_game_hour)
  var factor:=1.0+float(config.bpr_alpha)*pow(ratio,float(config.bpr_power))
  var speed:=minf(float(config.macro_speed_m_per_game_second),float(lane.speed_limit))/factor
  var enter:=maxi(time,int(lane_next.get(lane_id,0)))
  var junction: int=lane.get("junction",-1)
  if junction>=0:enter=maxi(enter,int(gate_next.get(junction,0)))
  var leave:=enter+maxi(1,int(ceil(float(lane.length)/maxf(.00001,speed)*HZ)))
  lane_next[lane_id]=enter+int(ceil(float(config.lane_headway_game_seconds)*factor*HZ))
  if junction>=0:gate_next[junction]=leave+int(ceil(float(config.junction_clearance_game_seconds)*HZ))
  segments.append({"lane":lane_id,"enter":enter,"leave":leave,"length_m":float(lane.length)})
  if not loads.has(lane_id):loads[lane_id]={"booked":0,"entered":0,"exited":0,"active":0}
  loads[lane_id].booked+=1
  _load_event(enter,lane_id,1,0);_load_event(leave,lane_id,0,1);time=leave
 record.segments=segments;record["road_arrival_tick"]=time
 if (record.direction=="inbound") != returning:time+=int(ceil(float(record.proof.frontage.walk_m)/float(config.walking_speed_m_per_game_second)*HZ))
 record["leg_arrival_tick"]=time
 _push(time,"arrive",{"id":id,"returning":returning})
 if (bool(config.display_enabled) and display_ordinal(record.population_ordinal)) or tracked.has(str(record.person_id)):pending.append({"id":id,"returning":returning,"promoted":false})
func _arrive(id: String,returning: bool):
 var record: Dictionary=records[id]
 if returning:
  record.status="home";record.return_arrival_tick=tick;totals.returned+=1
 else:
  record.status="at_destination";record.arrival_tick=tick;totals.arrived+=1
  if tick>int(record.deadline_tick) and not record.late:record.late=true;totals.late+=1
  var home_time:=maxi(tick,record.departure_tick+int(ceil(float(config.shift_game_hours)*3600*HZ)))
  _push(home_time,"return",id)
 if (record.direction=="inbound") != returning:_park_delta(record,1)
func _park_delta(record: Dictionary,amount: int):
 var key:=str(record.proof.local_id)
 parking[key]=maxi(0,int(parking.get(key,0))+amount)
func _try_spawn():
 for i in range(pending.size()-1,-1,-1):
  var request: Dictionary=pending[i]
  var record: Dictionary=records[request.id]
  var occupied:=false
  for other in micro.vehicles:
   if str(other.trip_id)==str(request.id):occupied=true;break
  if occupied:continue
  var route: Array=(record.proof.return_route if request.returning else record.proof.outbound).lanes.duplicate()
  var progress:=0.0
  if request.promoted:
   var pose:=logical_pose(str(request.id))
   if pose.is_empty():pending.remove_at(i);continue
   var index: int=route.find(pose.lane)
   if index<0:pending.remove_at(i);continue
   route=route.slice(index);progress=pose.progress
  var asset: Dictionary=catalog.filter(func(a):return a.id==record.asset_id)[0].duplicate()
  asset.max_speed=float(config.max_speed_m_per_game_second)
  var car: Dictionary=micro.spawn(asset,route,progress)
  if car.is_empty():continue
  car["trip_id"]=str(request.id);car["person_id"]=record.person_id;car["returning"]=request.returning;car["population_ordinal"]=record.population_ordinal
  pending.remove_at(i)
func _collect_physical_arrivals():
 for car in micro.vehicles.duplicate():
  if not car.arrived:continue
  var sample:=_sample_car(car)
  sample["fade_start_tick"]=tick;sample["fade_end_tick"]=tick+int(ceil(float(config.fade_game_seconds)*HZ))
  if sample.fade_end_tick>tick:fades.append(sample)
  micro.remove_vehicle(car.id);totals.physical_arrivals+=1;records[car.trip_id].physical_done=true
func _sync_micro_congestion():
 # Same UNSAMPLED hourly demand and BPR factor as canonical road bookings.
 for car in micro.vehicles:
  var row: Dictionary=records[car.trip_id]
  var hour: int=int(row.departure_hour)+(int(config.shift_game_hours) if car.returning else 0)
  var volume: int=int(hourly_demand.get(str(hour)+":"+str(car.lane),0))
  var ratio: float=float(volume)/float(config.lane_capacity_vehicles_per_game_hour)
  var factor: float=1.0+float(config.bpr_alpha)*pow(ratio,float(config.bpr_power))
  car.max_speed=float(config.max_speed_m_per_game_second)/factor
func _prune_fades():
 for i in range(fades.size()-1,-1,-1):
  if int(fades[i].fade_end_tick)<=tick:fades.remove_at(i)
func set_tracked(person_id,enabled: bool=true):
 var key:=str(person_id)
 if enabled:tracked[key]=true
 else:tracked.erase(key)
 if not enabled:return
 for id in records:
  var record: Dictionary=records[id]
  if str(record.person_id)!=key or not record.status in ["travelling","returning"]:continue
  var exists:=false
  for car in micro.vehicles:
   if str(car.trip_id)==id:exists=true
  for request in pending:
   if str(request.id)==id:exists=true
  if not exists:pending.append({"id":id,"returning":record.returning,"promoted":true})
 _try_spawn()
func logical_pose(id: String) -> Dictionary:
 if not records.has(id):return {}
 var record: Dictionary=records[id]
 if not record.status in ["travelling","returning"]:return {}
 for segment in record.segments:
  if tick<=int(segment.leave):
   var fraction:=clampf(float(tick-int(segment.enter))/maxf(1,float(int(segment.leave)-int(segment.enter))),0,1)
   var progress:=fraction*float(segment.length_m)
   return {"lane":segment.lane,"progress":progress,"position_m":routes.network.sample(segment.lane,progress),"heading":routes.network.tangent(segment.lane,progress),"waiting":tick<int(segment.enter)}
 return {}
func _sample_car(car: Dictionary) -> Dictionary:
 var heading: Vector2=micro.heading(car)
 var angle: int=(int(round(rad_to_deg(wrapf(heading.angle()-deg_to_rad(45),0,TAU))/45))*45)%360
 return {"id":car.id,"trip_id":car.trip_id,"person_id":car.person_id,"asset_id":car.asset_id,"sprite_path":"res://assets/vehicles/sprites/%s/%03d.png" % [car.asset_id,angle],"lane":car.lane,"route":car.route.duplicate(),"route_index":car.route_index,"progress":car.progress,"speed":car.speed,"position_m":micro.position(car),"heading":heading,"returning":car.returning,"tracked":tracked.has(str(car.person_id)),"logical_status":records[car.trip_id].status,"alpha":1.0}
func visible_snapshot() -> Dictionary:
 var samples:=[]
 if micro!=null:
  for car in micro.vehicles:samples.append(_sample_car(car))
 for original in fades:
  var sample: Dictionary=original.duplicate(true)
  sample.alpha=clampf(float(int(sample.fade_end_tick)-tick)/maxf(1,float(int(sample.fade_end_tick)-int(sample.fade_start_tick))),0,1)
  sample["fade_only"]=true;samples.append(sample)
 return {"version":1,"game_seconds":now(),"vehicles":samples,"tracked":tracked.duplicate(true)}
func stats() -> Dictionary:
 var result: Dictionary=totals.duplicate(true)
 result.merge({"game_seconds":now(),"active_micro":micro.vehicles.size() if micro!=null else 0,"pending_micro":pending.size(),"event_groups":groups.size(),"road_load":loads.duplicate(true),"roadside_occupancy":parking.duplicate(true),"reservation_count":micro.reservations.size() if micro!=null else 0,"fade_count":fades.size()},true)
 return result
func logical_snapshot() -> Dictionary:
 var logical_totals: Dictionary=totals.duplicate(true);logical_totals.erase("physical_arrivals")
 var logical_records: Dictionary=records.duplicate(true)
 for row in logical_records.values():row.erase("physical_done")
 return {"tick":tick,"records":logical_records,"totals":logical_totals,"loads":loads.duplicate(true),"parking":parking.duplicate(true)}
func _less(a: Dictionary,b: Dictionary) -> bool:return int(a.tick)<int(b.tick) if int(a.tick)!=int(b.tick) else int(a.sequence)<int(b.sequence)
func _push(at: int,kind: String,data):
 sequence+=1;heap.append({"tick":at,"sequence":sequence,"kind":kind,"data":data})
 var i:=heap.size()-1
 while i>0:
  var parent: int=(i-1)/2
  if not _less(heap[i],heap[parent]):break
  var temp=heap[parent];heap[parent]=heap[i];heap[i]=temp;i=parent
func _pop() -> Dictionary:
 var top: Dictionary=heap[0]
 var last=heap.pop_back()
 if heap.is_empty():return top
 heap[0]=last
 var i:=0
 while i*2+1<heap.size():
  var child:=i*2+1
  if child+1<heap.size() and _less(heap[child+1],heap[child]):child+=1
  if not _less(heap[child],heap[i]):break
  var temp=heap[i];heap[i]=heap[child];heap[child]=temp;i=child
 return top
func _load_event(at: int,lane: int,entered: int,exited: int):
 var key:=str(at)+":"+str(lane)
 if not load_events.has(key):load_events[key]={"lane":lane,"entered":0,"exited":0};_push(at,"load",key)
 load_events[key].entered+=entered;load_events[key].exited+=exited
func export_state() -> Dictionary:
 var state:={"version":1,"world":routes.world.duplicate(true),"config":config.duplicate(true)}
 for key in STATE_KEYS:
  var value=get(key);state[key]=value.duplicate(true) if value is Dictionary or value is Array else value
 var physical:={}
 if micro!=null:
  for key in MICRO_KEYS:
   var value=micro.get(key);physical[key]=value.duplicate(true) if value is Dictionary or value is Array else value
 state["micro"]=physical
 return state
func import_state(state: Dictionary) -> bool:
 if state.get("version")!=1 or not state.get("world") is Dictionary or not state.get("micro") is Dictionary:return false
 var candidate=get_script().new(state.get("config",{}))
 if not candidate.prepare_world(state.world).ok:return false
 for key in STATE_KEYS:
  if not state.has(key):return false
  var value=state[key];candidate.set(key,value.duplicate(true) if value is Dictionary or value is Array else value)
 for record in candidate.records.values():
  if not record is Dictionary or not record.has("status"):return false
  if record.get("proof",{}).get("reachable",false):
   if not candidate.validate_route(record.proof.outbound) or not candidate.validate_route(record.proof.return_route):return false
 for car in state.micro.get("vehicles",[]):
  if not car is Dictionary or not candidate.records.has(car.get("trip_id","")):return false
  for lane in car.get("route",[]):
   if not lane is int or lane<0 or lane>=candidate.routes.network.lanes.size():return false
 for key in MICRO_KEYS:
  if not state.micro.has(key):return false
  var value=state.micro[key];candidate.micro.set(key,value.duplicate(true) if value is Dictionary or value is Array else value)
 routes=candidate.routes;micro=candidate.micro;config=candidate.config;catalog=candidate.catalog
 for key in STATE_KEYS:set(key,candidate.get(key))
 return true
