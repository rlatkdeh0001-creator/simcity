extends Node3D
## Runtime bridge: uses the unmodified upstream RoadLane + RoadLaneAgent.
## Visual city roads remain in the existing 2D renderer.
var network
var manager: RoadManager
var road_lanes: Array[RoadLane] = []
var actors := {}
var agents := {}
var last_progress := {}
var last_lane := {}
var agent_moves := 0

func setup(lane_network):
	network = lane_network
	manager = RoadManager.new()
	manager.name = "TrafficRoadManager"
	add_child(manager)
	for data in network.lanes:
		var lane := RoadLane.new()
		lane.name = "Lane_%d" % data.id
		lane.curve = data.curve
		lane.draw_in_editor = false
		lane.draw_in_game = false
		lane.auto_free_vehicles = false
		manager.add_child(lane)
		road_lanes.append(lane)
	for data in network.lanes:
		if not data.next.is_empty():
			road_lanes[data.id].lane_next = road_lanes[data.id].get_path_to(road_lanes[data.next[0]])

func sync(vehicles: Array):
	for vehicle in vehicles:
		if not actors.has(vehicle.id):
			var actor := Node3D.new()
			actor.name = "TrafficActor_%d" % vehicle.id
			manager.add_child(actor)
			var agent := RoadLaneAgent.new()
			agent.name = "RoadLaneAgent"
			agent.road_manager_path = manager.get_path()
			actor.add_child(agent)
			actors[vehicle.id] = actor
			agents[vehicle.id] = agent
			last_lane[vehicle.id] = -1
			last_progress[vehicle.id] = 0.0
		var actor: Node3D = actors[vehicle.id]
		var agent: RoadLaneAgent = agents[vehicle.id]
		var delta_distance: float = vehicle.progress-float(last_progress[vehicle.id])
		if last_lane[vehicle.id] != vehicle.lane or delta_distance < 0:
			agent.assign_lane(road_lanes[vehicle.lane])
			actor.position = road_lanes[vehicle.lane].curve.get_point_position(0)
			delta_distance = vehicle.progress
		# Upstream helper computes the real position along Curve3D in metres.
		actor.global_position = agent.move_along_lane(delta_distance)
		agent_moves += 1
		var forward: Vector2 = network.tangent(vehicle.lane, vehicle.progress)
		actor.rotation.y = atan2(forward.x, forward.y)
		last_lane[vehicle.id] = vehicle.lane
		last_progress[vehicle.id] = vehicle.progress

func _exit_tree():
	# RoadLaneAgent registration must not outlive the bridge.
	for agent in agents.values():
		if is_instance_valid(agent): agent.unassign_lane()
