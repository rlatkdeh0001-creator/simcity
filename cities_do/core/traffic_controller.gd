extends Node
## Scene-facing facade. One simulation state serves 2D sprites and GLB views.
const Network = preload("res://core/traffic_network.gd")
const Simulation = preload("res://core/traffic_simulation.gd")
const Bridge = preload("res://core/road_generator_traffic.gd")
var network = Network.new()
var simulation
var bridge
var catalog: Array = []
var status := ""
var running := false
var textures := {}
var render_entries := {}

func _ready():
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json")).vehicles
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/render_manifest.json"))
	for entry in manifest.vehicles: render_entries[entry.id] = entry

func rebuild(roads: Array) -> bool:
	stop()
	network = Network.new()
	if not network.build(roads) or not network.errors.is_empty():
		status = network.errors[0] if not network.errors.is_empty() else "도로 경로를 확인해 주세요"
		return false
	if network.lanes.is_empty():
		status = "도로를 먼저 그려 주세요"
		return false
	simulation = Simulation.new(network)
	bridge = Bridge.new()
	add_child(bridge)
	bridge.setup(network)
	running = true
	status = "우측통행 · 앞차 간격 유지"
	return true

func seed_traffic():
	for lane in network.lanes:
		if lane.length < 24: continue
		var route := [lane.id]
		var cursor: int = lane.id
		while not network.lanes[cursor].next.is_empty():
			var next: int = network.lanes[cursor].next[0]
			if next in route: break
			route.append(next)
			cursor = next
		var loop: bool = route[0] in network.lanes[route[-1]].next
		var count := mini(4, int(lane.length/35.0))
		for i in range(count):
			var asset: Dictionary = catalog[2+(i+lane.id)%10].duplicate()
			asset.max_speed = 7.0 if i == count-1 else 14.0
			simulation.spawn(asset, route, 8.0+i*25.0, loop)
	bridge.sync(simulation.vehicles)

func update(delta: float):
	if not running or simulation == null: return
	simulation.update(delta)
	bridge.sync(simulation.vehicles)

func stop():
	running = false
	if is_instance_valid(bridge):
		remove_child(bridge)
		bridge.free()
	bridge = null
	simulation = null

func texture_for(asset_id: String, heading: Vector2) -> Texture2D:
	# The 2D isometric projection has screen-right = world X - world Y.
	# Hence world +Y maps to Blender -Y for the sprite camera at azimuth 45°.
	var azimuth := wrapf(heading.angle()-deg_to_rad(45.0), 0, TAU)
	var angle := (int(round(rad_to_deg(azimuth)/45.0))*45)%360
	var key := "%s/%03d" % [asset_id, angle]
	if not textures.has(key):
		textures[key] = load("res://assets/vehicles/sprites/%s/%03d.png" % [asset_id, angle])
	return textures[key]

func sprite_rect(asset_id: String, position: Vector2, pixels_per_metre: float) -> Rect2:
	var ppm: float = render_entries[asset_id].pixels_per_metre
	var scale := pixels_per_metre/ppm
	var asset: Dictionary = catalog.filter(func(item): return item.id == asset_id)[0]
	# Blender capture points at body mid-height, not the ground origin.
	var anchor := Vector2(215, 122.5+float(asset.height_m)*0.48*ppm*cos(deg_to_rad(30)))
	return Rect2(position-anchor*scale, Vector2(430,245)*scale)
