extends "res://core/traffic_simulation.gd"
## Scheduled buses add body collision protection to ordinary ACC and reservations.
var _proposed_entries:Array[int]=[]
func footprint(vehicle:Dictionary)->PackedVector2Array:
 var p:Vector2=position(vehicle);var h:Vector2=heading(vehicle)
 var a:Vector2=h*(float(vehicle.length)/2+.05);var b:=Vector2(-h.y,h.x)*(float(vehicle.get("width",2.5))/2+.025)
 return PackedVector2Array([p-a-b,p+a-b,p+a+b,p-a+b])
func overlaps(a:Dictionary,b:Dictionary)->bool:
 if position(a).distance_to(position(b))>(a.length+b.length)/2+4:return false
 return not Geometry2D.intersect_polygons(footprint(a),footprint(b)).is_empty()
func spawn(asset:Dictionary,route:Array,progress:float=0.0,loop:bool=false)->Dictionary:
 if route.is_empty():return {}
 var candidate:Dictionary={"lane":route[0],"progress":progress,"length":float(asset.length_m),"width":float(asset.get("width_m",2.5))}
 for other:Dictionary in vehicles:
  if _blocks_pair_exit(candidate,other) or overlaps(candidate,other):return {}
 var result:Dictionary=super.spawn(asset,route,progress,loop)
 if not result.is_empty():result.width=candidate.width
 return result
func _blocks_pair_exit(candidate:Dictionary,owner:Dictionary)->bool:
 if not owner.has("short_pair"):return false
 var pair:Dictionary=owner.short_pair
 if reservations.get(pair.second,-1)!=owner.id:return false
 if _short_pair_step(owner,pair)>=4 and not _rear_clearing(owner,pair.second):return false
 var exit_id:int=owner.route[(int(pair.approach)+4)%owner.route.size()]
 # Match the exit-room test at grant time. A newly dispatched body's rear
 # must leave room for the owner's front when its rear clears the connector.
 return candidate.lane==exit_id and candidate.progress-candidate.length/2.0<owner.length+2.0*owner.min_gap
func _constraint(vehicle:Dictionary,occupancy:Dictionary)->Dictionary:
 var constraint:Dictionary=super._constraint(vehicle,occupancy)
 if vehicle.has("stop_distance"):
  var gap:float=maxf(0.0,float(vehicle.stop_distance)-float(vehicle.distance))+float(vehicle.min_gap)
  if gap<constraint.gap:constraint={"gap":gap,"speed":0.0}
 return constraint
func _tick(delta:float):
 for vehicle:Dictionary in vehicles:
  if not vehicle.has("schedule"):continue
  if vehicle.stop_distance-vehicle.distance<.02 and vehicle.speed<.05:
   if not vehicle.get("at_stop",false):
    vehicle.at_stop=true;vehicle.dwell_until=elapsed+vehicle.dwell_seconds;vehicle.stops_served+=1
    if vehicle.stop_index==0:vehicle.dwell_until=maxf(vehicle.dwell_until,ceil(elapsed/vehicle.headway_seconds)*vehicle.headway_seconds)
   if elapsed+delta>=vehicle.dwell_until:
    vehicle.at_stop=false
    if vehicle.stop_index==0:vehicle.departures+=1;vehicle.last_departure=elapsed
    vehicle.stop_index=(vehicle.stop_index+1)%vehicle.schedule.size()
    var target:float=vehicle.schedule[vehicle.stop_index]
    var lap:float=floor(vehicle.stop_distance/vehicle.cycle_length)
    target+=lap*vehicle.cycle_length
    if target<=vehicle.stop_distance+.001:target+=vehicle.cycle_length
    vehicle.stop_distance=target
 super._tick(delta)
func _commit_moves(moves:Array):
 # Shared pocket diverges/merges are different lane IDs over the same pavement.
 # Arbitration is already accepted. Propose only motion; a body veto must not
 # roll back the pair token or commit tentative entry/rear-clearance effects.
 for i in range(vehicles.size()):
  var vehicle:Dictionary=vehicles[i]
  var proposed:Dictionary=vehicle.duplicate(true)
  _apply_move(proposed,moves[i])
  var allowed:=true
  for j in range(vehicles.size()):
   if i!=j and overlaps(proposed,vehicles[j]):allowed=false;break
  if allowed:
   vehicle.clear();vehicle.merge(proposed,true)
   for junction:int in _proposed_entries:super._on_junction_entry(vehicle,junction)
  else:vehicle.speed=0.0;vehicle.state="stopped"
  _proposed_entries.clear()
func _on_junction_entry(_vehicle:Dictionary,junction:int):
 _proposed_entries.append(junction)
func spawn_line(asset:Dictionary,plan:Dictionary,line:Dictionary)->Dictionary:
 var vehicle:Dictionary=spawn(asset,plan.route,float(plan.stops[0].progress),true)
 if vehicle.is_empty():return {}
 var offsets:Array=[];var total:=0.0
 for lane:int in plan.route:offsets.append(total);total+=float(network.lanes[lane].length)
 var schedule:Array=[]
 for stop:Dictionary in plan.stops:schedule.append(float(offsets[stop.route_index])+float(stop.progress)-float(plan.stops[0].progress))
 vehicle.merge({"line_id":line.id,"schedule":schedule,"cycle_length":total,"stop_distance":0.0,"stop_index":0,"at_stop":true,"dwell_until":elapsed+line.dwell_seconds,"dwell_seconds":line.dwell_seconds,"headway_seconds":line.headway_seconds,"stops_served":1,"departures":0,"last_departure":-1.0})
 return vehicle
func checkpoint()->Dictionary:
 return {"vehicles":vehicles.duplicate(true),"reservations":reservations.duplicate(true),"waiting":waiting.duplicate(true),"signals":signals.duplicate(true),"elapsed":elapsed,"accumulator":accumulator,"next_id":next_id,"safety_clamps":safety_clamps}
func restore(state:Dictionary):
 for key:String in ["vehicles","reservations","waiting","signals","elapsed","accumulator","next_id","safety_clamps"]:
  if not state.has(key):continue
  if key=="vehicles":vehicles.assign(state[key].duplicate(true))
  else:set(key,state[key])
