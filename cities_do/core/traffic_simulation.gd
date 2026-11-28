extends RefCounted
## Deterministic traffic state; no scene, rendering or physics-body dependency.
## ACC safe-speed formula adapted from kristofsw/city-traffic-sim (MIT).
## Copyright 2026 Kristof Sweerts; see res://licenses/city-traffic-sim-MIT.txt.
const FIXED_STEP := 1.0 / 30.0
var network
var vehicles: Array[Dictionary] = []
var reservations := {} # junction ID -> vehicle ID; retained until rear clearance.
var waiting := {}
var signals := {} # lane ID -> {progress in metres, red}. A controlled stop line.
var paused := false
var elapsed := 0.0
var accumulator := 0.0
var next_id := 1
var safety_clamps := 0

func _init(lane_network):
	network = lane_network

func spawn(asset: Dictionary, route: Array, progress: float = 0.0, loop: bool = false) -> Dictionary:
	if route.is_empty(): return {}
	for lane in route:
		if lane < 0 or lane >= network.lanes.size(): return {}
	if network.lanes[route[0]].get("junction",-1)>=0 or network.lanes[route[-1]].get("junction",-1)>=0:return {}
	for i in range(route.size()-1):
		if not route[i+1] in network.lanes[route[i]].next: return {}
	if loop and not route[0] in network.lanes[route[-1]].next: return {}
	var length := float(asset.length_m)
	var lane_id := int(route[0])
	if progress < length/2 or progress > network.lanes[lane_id].length-length/2: return {}
	for other in vehicles:
		if other.lane != lane_id: continue
		var separation: float = absf(other.progress-progress)
		if network.lanes[lane_id].closed:
			separation = minf(separation, float(network.lanes[lane_id].length)-separation)
		if separation < (length+other.length)/2+2.0: return {}
	var vehicle := {"id":next_id,"asset_id":asset.id,"length":length,"route":route.duplicate(),
		"route_index":0,"lane":lane_id,"progress":progress,"speed":0.0,"loop":loop,
		"max_speed":float(asset.get("max_speed", 14.0)),"accel":2.2,"brake":4.0,"min_gap":2.0,
		"time_gap":1.5,"arrived":false,"state":"stopped","distance":0.0,"clearing":{}}
	next_id += 1
	vehicles.append(vehicle)
	return vehicle

func update(delta: float):
	if paused or delta <= 0 or not is_finite(delta): return
	accumulator += delta
	while accumulator + 0.0000001 >= FIXED_STEP:
		_tick(FIXED_STEP)
		accumulator -= FIXED_STEP

func _tick(delta: float):
	elapsed += delta
	var occupancy := {}
	for vehicle in vehicles:
		if not occupancy.has(vehicle.lane): occupancy[vehicle.lane] = []
		occupancy[vehicle.lane].append(vehicle)
	for lane_id in occupancy:
		occupancy[lane_id].sort_custom(func(a,b): return a.progress < b.progress)
	_reserve_junctions(occupancy)
	var moves := []
	for vehicle in vehicles:
		var constraint := _constraint(vehicle, occupancy)
		var target := minf(vehicle.max_speed, network.lanes[vehicle.lane].speed_limit)
		if vehicle.arrived: target = 0.0
		var upcoming := _next_connector(vehicle)
		if not upcoming.is_empty():
			var distance_to_turn: float=maxf(0,network.lanes[vehicle.lane].length-vehicle.progress)
			target=minf(target,sqrt(upcoming.speed_limit*upcoming.speed_limit+2*vehicle.brake*distance_to_turn))
		if constraint.gap < INF:
			var room := maxf(0, constraint.gap-vehicle.min_gap)
			# ACC time-gap control plus stopping-distance bound.
			target = minf(target, maxf(0, constraint.speed+(constraint.gap-vehicle.min_gap)/vehicle.time_gap))
			target = minf(target, sqrt(constraint.speed*constraint.speed+2.0*vehicle.brake*room))
		var speed := move_toward(float(vehicle.speed), target, float(vehicle.accel if target > vehicle.speed else vehicle.brake)*delta)
		var distance := speed*delta
		# Simultaneous decisions use a snapshot. This conservative bound guarantees
		# that the follower cannot enter the leader's old protected body interval.
		if constraint.gap < INF and distance > maxf(0, constraint.gap-vehicle.min_gap):
			distance = maxf(0, constraint.gap-vehicle.min_gap)
			speed = distance/delta
			safety_clamps += 1
		moves.append({"distance":distance,"speed":speed,"target":target})
	_commit_moves(moves)

func _commit_moves(moves: Array):
	for i in range(vehicles.size()):
		_apply_move(vehicles[i], moves[i])

func _apply_move(vehicle: Dictionary, move: Dictionary):
	vehicle.speed = move.speed
	vehicle.distance += move.distance
	_advance(vehicle, move.distance)
	vehicle.state = "arrived" if vehicle.arrived else ("stopped" if vehicle.speed < 0.05 else ("braking" if move.target < vehicle.speed else "driving"))

func _on_junction_entry(vehicle: Dictionary, junction: int):
	waiting.erase(str(vehicle.id) + ":" + str(junction))

func _next_connector(vehicle: Dictionary) -> Dictionary:
	var next_index: int=vehicle.route_index+1
	if next_index>=vehicle.route.size():
		if not vehicle.loop:return {}
		next_index=0
	var lane: Dictionary=network.lanes[vehicle.route[next_index]]
	return lane if lane.get("junction",-1)>=0 else {}

func _receiving_clear(vehicle: Dictionary, connector: Dictionary, occupancy: Dictionary) -> bool:
	var destination: Dictionary=network.lanes[connector.to]
	var room: float=destination.length-vehicle.min_gap
	for other in occupancy.get(destination.id,[]):
		if other.id!=vehicle.id:room=minf(room,other.progress-other.length/2)
	return room>=vehicle.length+vehicle.min_gap*2

func _short_pair_second(vehicle: Dictionary, first: Dictionary) -> Dictionary:
	if first.is_empty():
		return {}
	var middle: Dictionary = network.lanes[first.to]
	# Use the ordinary empty-receiver limit, not transient congestion or node spacing.
	if middle.length - vehicle.min_gap >= vehicle.length + 2.0 * vehicle.min_gap:
		return {}
	var route: Array = vehicle.route
	var start: int = vehicle.route_index
	if route.size() < 4 or (not vehicle.loop and start + 4 >= route.size()):
		return {}
	var second: Dictionary = network.lanes[route[(start + 3) % route.size()]]
	var exit_id: int = route[(start + 4) % route.size()]
	if route[(start + 2) % route.size()] != middle.id or middle.get("junction", -1) >= 0 \
		or second.get("junction", -1) < 0 or second.junction == first.junction \
		or second.from != middle.id or second.to != exit_id \
		or network.lanes[exit_id].get("junction", -1) >= 0:
		return {}
	return second

func _short_pair_clear(vehicle: Dictionary, first: Dictionary, second: Dictionary, occupancy: Dictionary) -> bool:
	if not occupancy.get(first.to, []).is_empty():
		return false
	# This is a two-junction policy, not a recursive grant through a short chain.
	# Require final storage even for subclasses that allow a short terminal sink.
	var exit: Dictionary = network.lanes[second.to]
	var room_needed: float = vehicle.length + 2.0 * vehicle.min_gap
	if exit.length - vehicle.min_gap < room_needed or not _receiving_clear(vehicle, second, occupancy):
		return false
	for lane_id in [first.id, first.to, second.id]:
		if signals.get(lane_id, {}).get("red", false):
			return false
	var exit_signal: Dictionary = signals.get(second.to, {})
	if exit_signal.get("red", false) and exit_signal.progress < room_needed:
		return false
	if vehicle.has("stop_distance"):
		var to_first: float = network.lanes[vehicle.lane].length - vehicle.progress
		var to_rear_clear: float = to_first + first.length + network.lanes[first.to].length + second.length \
			+ vehicle.length * 0.5 + vehicle.min_gap
		var to_stop: float = vehicle.stop_distance - vehicle.distance
		if to_stop >= to_first - vehicle.length * 0.5 and to_stop < to_rear_clear:
			return false
	return true

func _short_pair_step(vehicle: Dictionary, pair: Dictionary) -> int:
	# A four-lane loop can wrap directly back onto the approach as its exit.
	if vehicle.clearing.has(pair.second):
		return 4
	return posmod(int(vehicle.route_index) - int(pair.approach), vehicle.route.size())

func _rear_clearing(vehicle: Dictionary, junction: int) -> bool:
	return vehicle.clearing.has(junction) and vehicle.distance - float(vehicle.clearing[junction]) < vehicle.length / 2.0 + vehicle.min_gap

func _refresh_short_pair(vehicle: Dictionary, occupancy: Dictionary):
	if not vehicle.has("short_pair"):
		return
	var pair: Dictionary = vehicle.short_pair
	var step := _short_pair_step(vehicle, pair)
	if step >= 4 and not _rear_clearing(vehicle, pair.second):
		# Keep the receiving-lane claim until the accepted rear clears the second.
		vehicle.erase("short_pair")
	elif step == 0 and vehicle.progress + vehicle.length * 0.5 < network.lanes[vehicle.lane].length:
		var first := _next_connector(vehicle)
		var second := _short_pair_second(vehicle, first)
		if vehicle.arrived or _red_ahead(vehicle) or reservations.get(pair.first) != vehicle.id \
			or reservations.get(pair.second) != vehicle.id or first.get("junction") != pair.first \
			or second.get("junction") != pair.second or not _short_pair_clear(vehicle, first, second, occupancy):
			# Still outside: a new blockage cancels both grants together.
			for junction in [pair.first, pair.second]:
				if reservations.get(junction) == vehicle.id:
					reservations.erase(junction)
			vehicle.erase("short_pair")

func _red_ahead(vehicle: Dictionary) -> bool:
	if not signals.has(vehicle.lane) or not signals[vehicle.lane].red:return false
	return signals[vehicle.lane].progress>=vehicle.progress+vehicle.length/2-.0001

func _reserve_junctions(occupancy: Dictionary):
	var by_id := {}
	for vehicle in vehicles:
		by_id[vehicle.id]=vehicle
		_refresh_short_pair(vehicle, occupancy)
	for junction in reservations.keys():
		var owner: Dictionary=by_id.get(reservations[junction],{})
		if owner.is_empty():
			reservations.erase(junction)
			continue
		var pair: Dictionary = owner.get("short_pair", {})
		if not pair.is_empty() and _short_pair_step(owner, pair) < 3 \
			and (junction == pair.second or (junction == pair.first and owner.route_index == pair.approach)):
			# Protect the downstream connector even before it is the immediate next lane.
			continue
		var inside: bool=network.lanes[owner.lane].get("junction",-1)==junction
		var clearing := _rear_clearing(owner, junction)
		var next := _next_connector(owner)
		var approaching: bool=not next.is_empty() and next.junction==junction and not owner.arrived and not _red_ahead(owner)
		if not inside and not clearing and not approaching:reservations.erase(junction)
	var candidates := []
	for vehicle in vehicles:
		for junction in vehicle.clearing.keys():
			if vehicle.distance-float(vehicle.clearing[junction])>=vehicle.length/2+vehicle.min_gap:vehicle.clearing.erase(junction)
		if vehicle.has("short_pair") and _short_pair_step(vehicle, vehicle.short_pair) < 3:continue
		var connector := _next_connector(vehicle)
		if connector.is_empty() or vehicle.arrived or _red_ahead(vehicle):continue
		var queue: Array=occupancy.get(vehicle.lane,[])
		if not queue.is_empty() and queue[-1].id!=vehicle.id:continue
		var remaining: float=network.lanes[vehicle.lane].length-vehicle.progress
		if remaining>maxf(14,vehicle.speed*2+vehicle.length):continue
		var key := str(vehicle.id)+":"+str(connector.junction)
		if not waiting.has(key):waiting[key]=elapsed
		candidates.append({"vehicle":vehicle,"connector":connector,"since":waiting[key]})
	candidates.sort_custom(func(a,b):return a.vehicle.id<b.vehicle.id if is_equal_approx(a.since,b.since) else a.since<b.since)
	for candidate in candidates:
		var vehicle: Dictionary = candidate.vehicle
		var first: Dictionary = candidate.connector
		var junction: int = first.junction
		if reservations.has(junction):continue
		if _receiving_clear(vehicle, first, occupancy):
			reservations[junction] = vehicle.id
			continue
		# Do not overwrite the previous pair's live receiving-space claim.
		if vehicle.has("short_pair"):continue
		var second := _short_pair_second(vehicle, first)
		if second.is_empty() or reservations.has(second.junction) or not _short_pair_clear(vehicle, first, second, occupancy):
			continue
		reservations[junction] = vehicle.id
		reservations[second.junction] = vehicle.id
		vehicle.short_pair = {"approach": vehicle.route_index, "first": junction, "second": second.junction}

func _constraint(vehicle: Dictionary, occupancy: Dictionary) -> Dictionary:
	var best := {"gap":INF,"speed":0.0}
	var lane_id: int = vehicle.lane
	var progress: float = vehicle.progress
	var travelled := 0.0
	var index: int = vehicle.route_index
	# Look across the next lane boundary and the seam of a closed loop.
	for hop in range(vehicle.route.size()+1):
		var candidates: Array = occupancy.get(lane_id, [])
		for other in candidates:
			if other.id == vehicle.id: continue
			if hop == 0 and other.progress <= progress: continue
			var gap: float = travelled+other.progress-progress-(vehicle.length+other.length)/2.0
			if gap < best.gap:
				best = {"gap":gap,"speed":other.speed}
			break
		if signals.has(lane_id) and signals[lane_id].red:
			var line: float = signals[lane_id].progress
			var distance: float = travelled+line-progress-vehicle.length/2
			# Already committed past the line: never snap a vehicle backwards.
			if distance >= -0.0001 and distance < best.gap: best = {"gap":maxf(0,distance),"speed":0.0}
		var following_index := index+1
		if following_index>=vehicle.route.size():following_index=0 if vehicle.loop else -1
		if following_index>=0:
			var following: Dictionary=network.lanes[vehicle.route[following_index]]
			var junction: int=following.get("junction",-1)
			if junction>=0 and reservations.get(junction,-1)!=vehicle.id:
				var gap: float=travelled+network.lanes[lane_id].length-progress-vehicle.length/2
				if gap<best.gap:best={"gap":maxf(0,gap),"speed":0.0}
		travelled += float(network.lanes[lane_id].length)-progress
		progress = 0.0
		index += 1
		if index >= vehicle.route.size():
			if vehicle.loop: index = 0
			else:
				var terminal_gap: float = travelled-vehicle.length/2
				if terminal_gap < best.gap: best = {"gap":terminal_gap,"speed":0.0}
				break
		lane_id = int(vehicle.route[index])
	return best

func _advance(vehicle: Dictionary, distance: float):
	vehicle.progress += distance
	while vehicle.progress > network.lanes[vehicle.lane].length:
		vehicle.progress -= float(network.lanes[vehicle.lane].length)
		var junction: int=network.lanes[vehicle.lane].get("junction",-1)
		if junction>=0:vehicle.clearing[junction]=vehicle.distance-vehicle.progress
		vehicle.route_index += 1
		if vehicle.route_index >= vehicle.route.size(): vehicle.route_index = 0
		vehicle.lane = int(vehicle.route[vehicle.route_index])
		var entered: int=network.lanes[vehicle.lane].get("junction",-1)
		if entered>=0:_on_junction_entry(vehicle,entered)
	if not vehicle.loop and vehicle.route_index == vehicle.route.size()-1:
		var remaining: float = network.lanes[vehicle.lane].length-vehicle.progress-vehicle.length/2-vehicle.min_gap
		if remaining < 0.02 and vehicle.speed < 0.05:
			vehicle.arrived = true

func position(vehicle: Dictionary) -> Vector2:
	return network.sample(vehicle.lane, vehicle.progress)

func heading(vehicle: Dictionary) -> Vector2:
	return network.tangent(vehicle.lane, vehicle.progress)
