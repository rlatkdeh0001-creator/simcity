extends "res://core/traffic_simulation.gd"
## Reuses ACC, fixed-step integration, exit blocking and junction reservation ownership.
## Differences: exact centre-point endpoints (curb/boundary), short access spurs,
## spatially protected starts, and immediate occupancy/reservation removal on arrival.
func spawn(asset: Dictionary, route: Array, progress: float = 0.0, loop: bool = false) -> Dictionary:
 if route.is_empty() or loop:return {}
 for i in range(route.size()):
  if route[i]<0 or route[i]>=network.lanes.size():return {}
  if i+1<route.size() and not route[i+1] in network.lanes[route[i]].next:return {}
 var length := float(asset.length_m)
 var starting_junction: int = network.lanes[route[0]].get("junction",-1)
 if starting_junction>=0 and reservations.has(starting_junction):return {}
 var position: Vector2 = network.sample(route[0],progress)
 for other in vehicles:
  if position.distance_to(network.sample(other.lane,other.progress)) < (length+other.length)*.5+2.0:return {}
 var vehicle := {"id":next_id,"asset_id":asset.id,"length":length,"route":route.duplicate(),"route_index":0,"lane":route[0],"progress":progress,"speed":0.0,"loop":false,"max_speed":float(asset.get("max_speed",14.0)),"accel":2.2,"brake":4.0,"min_gap":2.0,"time_gap":1.5,"arrived":false,"state":"stopped","distance":0.0,"clearing":{}}
 next_id += 1
 vehicles.append(vehicle)
 if starting_junction>=0:reservations[starting_junction]=vehicle.id
 return vehicle
func _receiving_clear(vehicle: Dictionary, connector: Dictionary, occupancy: Dictionary) -> bool:
 if network.lanes[connector.to].get("role","")=="sink":
  return occupancy.get(connector.to,[]).is_empty()
 return super._receiving_clear(vehicle,connector,occupancy)
func _constraint(vehicle: Dictionary, occupancy: Dictionary) -> Dictionary:
 var best := {"gap":INF,"speed":0.0}
 var lane_id: int = vehicle.lane
 var progress: float = vehicle.progress
 var travelled := 0.0
 var index: int = vehicle.route_index
 for hop in range(vehicle.route.size()+1):
  for other in occupancy.get(lane_id,[]):
   if other.id==vehicle.id:continue
   if hop==0 and other.progress<=progress:continue
   var gap: float = travelled+other.progress-progress-(vehicle.length+other.length)*.5
   if gap<best.gap:best={"gap":gap,"speed":other.speed}
   break
  if signals.has(lane_id) and signals[lane_id].red:
   var distance: float = travelled+signals[lane_id].progress-progress-vehicle.length*.5
   if distance>=-.0001 and distance<best.gap:best={"gap":maxf(0,distance),"speed":0.0}
  var next_index := index+1
  if next_index<vehicle.route.size():
   var following: Dictionary = network.lanes[vehicle.route[next_index]]
   var junction: int = following.get("junction",-1)
   if junction>=0 and reservations.get(junction,-1)!=vehicle.id:
    # Short departure spurs are stop lines at the curb, never a negative interval.
    var gap: float = travelled+network.lanes[lane_id].length-progress-vehicle.length*.5
    if gap<best.gap:best={"gap":maxf(0,gap),"speed":0.0}
  travelled += float(network.lanes[lane_id].length)-progress
  progress=0.0; index+=1
  if index>=vehicle.route.size():
   var terminal_gap: float = travelled+vehicle.min_gap
   if terminal_gap<best.gap:best={"gap":terminal_gap,"speed":0.0}
   break
  lane_id=int(vehicle.route[index])
 return best
func _advance(vehicle: Dictionary, distance: float):
 vehicle.progress += distance
 while vehicle.progress>network.lanes[vehicle.lane].length and vehicle.route_index+1<vehicle.route.size():
  vehicle.progress -= float(network.lanes[vehicle.lane].length)
  var junction: int = network.lanes[vehicle.lane].get("junction",-1)
  if junction>=0:vehicle.clearing[junction]=vehicle.distance-vehicle.progress
  vehicle.route_index+=1;vehicle.lane=int(vehicle.route[vehicle.route_index])
  var entered: int = network.lanes[vehicle.lane].get("junction",-1)
  if entered>=0:waiting.erase(str(vehicle.id)+":"+str(entered))
 if vehicle.route_index==vehicle.route.size()-1 and network.lanes[vehicle.lane].length-vehicle.progress<.02:
  vehicle.progress=minf(vehicle.progress,network.lanes[vehicle.lane].length)
  vehicle.arrived=true
func remove_vehicle(id: int):
 for i in range(vehicles.size()-1,-1,-1):
  if vehicles[i].id==id:vehicles.remove_at(i)
 for junction in reservations.keys():
  if reservations[junction]==id:reservations.erase(junction)
 for key in waiting.keys():
  if str(key).begins_with(str(id)+":"):waiting.erase(key)
