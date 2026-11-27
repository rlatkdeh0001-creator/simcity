extends RefCounted
## Worker-only fixed-step operations. Persisted state contains primitives, not Curve/scene objects.
const Planner=preload("res://core/transit_line_planner.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
const STEP:=1.0/30.0
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/transit_operation_config.json"))
var signature:int=0
var plans:Dictionary={}
var conflict_zones:Array=[]
func rebuild(city):
 var key:int=hash([city.transit_routes,city.roads,city.public_facilities.lots,city.transit_lines])
 if key==signature:return
 signature=key;plans.clear()
 conflict_zones.clear()
 for x:Dictionary in Crossover.owned(city).values():conflict_zones.append(Crossover.conflict_zone(x))
 for line:Dictionary in city.transit_lines:
  if line.kind!="bus":plans[line.id]=Planner.new().rail_plan(city,line)
func advance(city,seconds:float):
 if seconds<=0:return
 rebuild(city)
 var state:Dictionary=city.transit_state
 var keep:Dictionary={}
 for line:Dictionary in city.transit_lines:keep[line.id]=true
 for id:Variant in state.trains.keys():
  if not keep.has(id):state.trains.erase(id)
 for id:Variant in state.lines.keys():
  if not keep.has(id):state.lines.erase(id)
 var accumulator:float=state.get("accumulator",0.0)+seconds
 while accumulator+0.0000001>=STEP:
  state.seconds+=STEP
  for line:Dictionary in city.transit_lines:
   if line.kind=="bus":continue
   var plan:Dictionary=plans.get(line.id,{})
   var train:Dictionary=state.trains.get(line.id,{})
   if not plan.get("ok",false):
    # A cut path stops the consist where it is; once rejoined it restarts from the line start.
    if not train.is_empty():train.restart=true
    state.lines[line.id]={"status":"blocked"};continue
   if not train.is_empty() and (train.get("restart",false) or train.plan!=plan):
    if train.get("restart",false) or route_changed(train.plan,plan):
     # Route path changed (any reason): the same consist, its load and counters kept,
     # goes back to the first stop of the new path. It is placed there by the spawn
     # rule below (clear first stop, else waiting and not drawn) and leaves on headway.
     train.merge({"plan":plan.duplicate(true),"distance":0.0,"speed":0.0,"next_stop":1,"target":float(plan.stops[1].distance),"departure_pending":true,"visible":[]},true)
     train.erase("restart")
    else:
     # Same path and stops in new track pieces (e.g. a branch laid on the line): it keeps
     # running where it is; only the per-segment route IDs of the new plan are taken over.
     train.plan=plan.duplicate(true)
   if train.is_empty() or train.visible.is_empty():
    var moved:=not train.is_empty()
    if not moved:train={"plan":plan.duplicate(true),"distance":0.0,"speed":0.0,"next_stop":1,"target":float(plan.stops[1].distance),"dwell_until":state.seconds+line.dwell_seconds,"departures":0,"departure_pending":true,"last_departure":-INF,"kind":line.kind,"visible":[]}
    var initial:=poses(line.id,train)
    if not clear(initial,state.trains,line.id,conflict_zones):state.lines[line.id]={"status":"waiting"};continue
    if moved:train.dwell_until=maxf(state.seconds+line.dwell_seconds,ceil(state.seconds/line.headway_seconds)*line.headway_seconds)
    train.visible=initial;state.trains[line.id]=train
   state.lines[line.id]={"status":"dwelling" if state.seconds<train.dwell_until else "running","departures":train.departures}
   if state.seconds<train.dwell_until:continue
   var remaining:float=train.target-train.distance
   if remaining<.0001:
    train.speed=0.0;train.next_stop=(train.next_stop+1)%plan.stops.size()
    var lap:float=floor(train.distance/plan.length)
    train.target=lap*plan.length+float(plan.stops[train.next_stop].distance)
    if train.target<=train.distance+.001:train.target+=plan.length
    train.dwell_until=state.seconds+line.dwell_seconds
    if train.next_stop==1:
     train.dwell_until=maxf(train.dwell_until,ceil(state.seconds/line.headway_seconds)*line.headway_seconds);train.departure_pending=true
    continue
   var target:float=minf(float(config[line.kind+"_speed_mps"]),sqrt(2*float(config.rail_braking_mps2)*remaining))
   var speed:float=move_toward(train.speed,target,float(config.rail_acceleration_mps2 if target>train.speed else config.rail_braking_mps2)*STEP)
   var old:float=train.distance
   train.distance+=minf(remaining,speed*STEP)
   var candidate:=poses(line.id,train)
   if clear(candidate,state.trains,line.id,conflict_zones):
    train.visible=candidate;train.speed=speed
    if train.get("departure_pending",false) and train.distance>old:
     train.departures+=1;train.last_departure=state.seconds;train.departure_pending=false
   else:train.distance=old;train.speed=0.0;state.lines[line.id].status="waiting"
  accumulator-=STEP
 state.accumulator=accumulator
 state.visible=[]
 for train:Dictionary in state.trains.values():state.visible.append_array(train.visible.duplicate(true))
 advance_buses(city,seconds)
## Route change (user rule 2026-11-19, cities-claude definition): a line's route changed only when
## the line its consist runs (positions) or its stop order changed, or when its plan turns blocked or
## runs again. Track pieces split or merged under the same path (a branch laid on the line) are no
## change. advance() and the edit warning (main.gd guard_route_edit) both decide with this function.
const PATH_EPS:=0.01
static func route_changed(before:Dictionary,after:Dictionary)->bool:
 if before.get("ok",false)!=after.get("ok",false):return true
 if not after.get("ok",false):return false
 if str(before.get("kind",""))!=str(after.get("kind","")) or bool(before.get("turnback",false))!=bool(after.get("turnback",false)):return true
 if before.stops.size()!=after.stops.size():return true
 for i in range(before.stops.size()):
  if int(before.stops[i].id)!=int(after.stops[i].id) or absf(float(before.stops[i].distance)-float(after.stops[i].distance))>PATH_EPS:return true
 var a:Array=before.legs if before.get("turnback",false) else [before]
 var b:Array=after.legs if after.get("turnback",false) else [after]
 if a.size()!=b.size():return true
 for i in range(a.size()):
  var p:=corners(a[i].points);var q:=corners(b[i].points)
  if p.size()!=q.size():return true
  for k in range(p.size()):
   if p[k].distance_to(q[k])>PATH_EPS:return true
 return false
## The polyline without repeated points and without points on the straight run between neighbours.
static func corners(points:PackedVector2Array)->PackedVector2Array:
 var kept:=PackedVector2Array()
 for p:Vector2 in points:
  if not kept.is_empty() and kept[kept.size()-1].distance_to(p)<=PATH_EPS:continue
  if kept.size()>=2 and Geometry2D.get_closest_point_to_segment(kept[kept.size()-1],kept[kept.size()-2],p).distance_to(kept[kept.size()-1])<=PATH_EPS:kept[kept.size()-1]=p
  else:kept.append(p)
 return kept
## Plain copy of every input rail_plan reads, to plan an edit before it is applied.
static func draft(city)->Dictionary:
 return {"transit_routes":city.transit_routes.duplicate(),"transit_lines":city.transit_lines.duplicate(true),"public_facilities":{"lots":city.public_facilities.lots.duplicate()},"road_pavement":city.road_pavement,"junction_pavement":city.junction_pavement}
## Edit warning: IDs of the rail, metro and freight lines with a consist whose route changes when the
## city becomes `after` (a draft()).
static func reset_lines(city,after:Dictionary)->Array:
 var ids:Array=[]
 var planner=Planner.new()
 for line:Dictionary in after.transit_lines:
  if line.kind=="bus" or city.transit_state.trains.get(line.id,{}).is_empty():continue
  var before:Dictionary={}
  for row:Dictionary in city.transit_lines:
   if row.id==line.id:before=planner.rail_plan(city,row)
  if route_changed(before,planner.rail_plan(after,line)):ids.append(line.id)
 return ids
## The draft of a stop edit (same plan rules as update_transit_line). null when nothing would
## re-plan (bus, unchanged stops, unknown line) or the new stops are rejected.
static func line_edit_draft(city,id:int,stops:Array)->Variant:
 var after:=draft(city)
 for i in range(after.transit_lines.size()):
  var line:Dictionary=after.transit_lines[i]
  if line.id!=id:continue
  if line.kind=="bus" or line.stops==stops:return null
  var edited:Dictionary=line.duplicate(true);edited.stops=stops.duplicate()
  edited.erase("turnback");edited.erase("terminal_ports")
  if edited.kind in ["rail","metro"]:edited.allow_turnback=true
  if not Planner.new().rail_plan(after,edited).get("ok",false):return null
  after.transit_lines[i]=edited
  return after
 return null
var bus_network
var bus_simulation
var bus_key:int=0
static func bus_topology_key(city)->int:
 # Match TrafficNetwork/Junctions/Profile inputs and stable stop host lookup.
 # Preserve array order: lane IDs and curb branches are allocated in that order.
 var roads:Array=[]
 for road:Dictionary in city.roads:
  roads.append([road.parcel_id,road.points,road.kind,road.lanes,road.width,road.get("major_side",1)])
 var stops:Array=[]
 for lot:Dictionary in city.public_facilities.lots:
  if lot.get("public_asset_id","")!="bus-stop-01":continue
  # All bus stops matter, not only scheduled ones: each can split the lane graph.
  # Include invalid bindings too so loss/restoration of a host remains detectable.
  stops.append([lot.id,lot.get("front_road_id",-1),lot.get("road_direction",0),lot.position,lot.front_direction])
 return hash([roads,stops])
func advance_buses(city,seconds:float):
 var state:Dictionary=city.transit_state
 var lines:Array=city.transit_lines.filter(func(line):return line.kind=="bus")
 var ids:Array=lines.map(func(line):return line.id)
 var saved:Dictionary=state.bus
 if saved.has("vehicles"):
  saved.vehicles=saved.vehicles.filter(func(vehicle):return vehicle.line_id in ids)
 var key:int=bus_topology_key(city)
 if not saved.get("vehicles",[]).is_empty() and saved.get("topology_key",key)!=key:
  for line:Dictionary in lines:state.lines[line.id]={"status":"blocked"}
  var retained:Array=saved.get("visible",[]).filter(func(pose):return pose.line_id in ids)
  state.visible.append_array(retained.duplicate(true));return
 if bus_network==null or key!=bus_key:
  bus_network=preload("res://core/scheduled_bus_network.gd").new();bus_network.build_city(city);bus_key=key
  bus_simulation=preload("res://core/scheduled_bus_simulation.gd").new(bus_network)
 bus_simulation.restore(saved)
 # Purge deleted line reservations as well as body occupancy.
 var vehicle_ids:Array=bus_simulation.vehicles.map(func(vehicle):return vehicle.id)
 for junction:Variant in bus_simulation.reservations.keys():
  if not bus_simulation.reservations[junction] in vehicle_ids:bus_simulation.reservations.erase(junction)
 for line:Dictionary in lines:
  var plan:Dictionary=bus_network.line_plan(line.stops)
  if not plan.ok:state.lines[line.id]={"status":"blocked"};continue
  var found:=false
  for vehicle:Dictionary in bus_simulation.vehicles:
   if vehicle.line_id==line.id:found=true
  if not found:
   var asset:Dictionary={}
   for item:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json")).vehicles:
    if item.id=="bus-city-01":asset=item.duplicate(true);break
   asset.max_speed=config.bus_speed_mps
   found=not bus_simulation.spawn_line(asset,plan,line).is_empty()
  state.lines[line.id]={"status":"running" if found else "waiting"}
 bus_simulation.update(seconds)
 var visible:Array=[]
 for vehicle:Dictionary in bus_simulation.vehicles:
  var pose:Dictionary={"id":"bus:%d"%vehicle.id,"line_id":vehicle.line_id,"asset_id":vehicle.asset_id,"position":bus_simulation.position(vehicle),"heading":bus_simulation.heading(vehicle),"height_m":0.0,"kind":"bus","length_m":vehicle.length,"width_m":2.5}
  visible.append(pose)
  state.lines[vehicle.line_id]={"status":"dwelling" if vehicle.at_stop else "running","departures":vehicle.departures,"stops_served":vehicle.stops_served}
 state.bus=bus_simulation.checkpoint();state.bus.topology_key=key;state.bus.visible=visible
 state.visible.append_array(visible.duplicate(true))
static func consist(kind:String)->Array:
 if kind=="metro":return [["subway-car-01",16.0],["subway-car-01",16.0],["subway-car-01",16.0],["subway-car-01",16.0]]
 if kind=="freight":return [["train-loco-freight-01",10.0],["train-flatcar-01",8.0],["train-flatcar-01",8.0]]
 return [["train-loco-01",10.0],["train-passenger-01",11.0],["train-passenger-01",11.0]]
static func poses(id:int,train:Dictionary)->Array:
 var cars:Array=consist(train.kind);var length:=0.0
 for car:Array in cars:length+=car[1]
 var offset:float=length/2;var result:Array=[]
 var leg:Dictionary=train.plan
 var position:float=train.distance
 var is_turnback:bool=train.plan.get("turnback",false)
 var reversed:=false
 if is_turnback:
  var phase:=fposmod(position,float(train.plan.length))
  var forward:Dictionary=train.plan.legs[0]
  reversed=phase>=forward.length
  leg=train.plan.legs[int(reversed)]
  position=phase-float(forward.length) if reversed else phase
 for i in range(cars.size()):
  var car:Array=cars[i]
  var car_offset:=offset-float(car[1])/2
  var pose:=Planner.sample_leg(leg,position+(-car_offset if reversed else car_offset)) if is_turnback else Planner.sample(leg,position+car_offset)
  pose.merge({"id":"%d:%d"%[id,i],"line_id":id,"asset_id":car[0],"length_m":car[1],"width_m":3.0,"kind":train.kind,"height_m":-12.7 if train.kind=="metro" else 0.0})
  result.append(pose);offset-=float(car[1])
  if train.kind=="freight" and i==1:
   var cargo:Dictionary=pose.duplicate(true);cargo.id=str(pose.id)+":cargo";cargo.asset_id="container-20ft-01";cargo.height_m=1.2;cargo.cargo=true;result.append(cargo)
 return result
static func body(pose:Dictionary)->PackedVector2Array:
 var along:Vector2=pose.heading*(float(pose.length_m)/2+1.0)
 var side:=Vector2(-pose.heading.y,pose.heading.x)*float(pose.width_m)/2
 var p:Vector2=pose.position
 return PackedVector2Array([p-along-side,p+along-side,p+along+side,p-along+side])
static func clear(candidate:Array,trains:Dictionary,own:int,zones:Array=[])->bool:
 var claimed:Array=[]
 for zone:Dictionary in zones:
  if _occupies_zone(candidate,zone):claimed.append(zone)
 for id:Variant in trains:
  if id==own:continue
  for zone:Dictionary in claimed:
   if _occupies_zone(trains[id].visible,zone):return false
  for other:Dictionary in trains[id].visible:
   if other.get("cargo",false):continue
   for pose:Dictionary in candidate:
    if pose.get("cargo",false) or absf(float(pose.height_m)-float(other.height_m))>2:continue
    if pose.position.distance_to(other.position)>(pose.length_m+other.length_m)/2+4:continue
    if not Geometry2D.intersect_polygons(body(pose),body(other)).is_empty():return false
 return true
static func _occupies_zone(poses:Array,zone:Dictionary)->bool:
 for pose:Dictionary in poses:
  if pose.get("cargo",false) or (pose.kind=="metro")!=(zone.kind=="metro"):continue
  if pose.position.distance_squared_to(zone.center)>pow(float(pose.length_m)/2+10,2):continue
  if not Geometry2D.intersect_polygons(body(pose),zone.polygon).is_empty():return true
 return false
