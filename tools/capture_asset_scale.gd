extends SceneTree
## Review-only staging: real main scene, actual asset scales, fixed zoom in every image.
const Showcase = preload("res://core/residential_showcase.gd")
func _initialize(): run.call_deferred()
func run():
	var output: String = OS.get_cmdline_user_args()[0]
	var scene = load("res://main.tscn").instantiate()
	scene.showcase_view = true
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	for child in scene.get_children():
		if child is CanvasLayer: child.hide()
	var groups = [["small-2x2-a", "small-2x2-b", "small-4x4-a", "small-4x4-b"],
		["mansion-a-4x4-4f", "mansion-b-4x4-4f", "large-4x4-a", "large-4x4-b"],
		["large-8x8-a", "large-8x8-b"]]
	var names = ["small", "medium", "large"]
	for index in range(groups.size()):
		scene.city = Showcase.create_city()
		scene.city.buildings = scene.city.buildings.filter(func(b): return b.asset_id in groups[index])
		scene.map_zoom = 2.2
		scene.origin = Vector2.ZERO
		var extent := Rect2()
		var first := true
		for b in scene.city.buildings:
			var asset: Dictionary = scene.city.catalog.get_asset(b.asset_id)
			var rect: Rect2 = scene.city.catalog.sprite_rect(asset, scene.screen(Vector2(b.x+b.size,b.y+b.size)), scene.tile.x*2*scene.map_zoom)
			var used: Rect2 = Rect2(scene.building_images[asset.id].get_used_rect())
			var size: Vector2 = scene.building_images[asset.id].get_size()
			var visible_rect := Rect2(rect.position+used.position/size*rect.size, used.size/size*rect.size)
			extent = visible_rect if first else extent.merge(visible_rect)
			first = false
		# Include the full road width below the front corners; never change relative asset scale.
		extent.size.y += 140
		scene.origin = root.size/2.0 - extent.get_center()
		assert(scene.traffic.rebuild(scene.city.roads))
		var lane: Dictionary = scene.traffic.network.lanes[0]
		for b in scene.city.buildings:
			var front := Vector2(b.x+b.size/2.0,b.y+b.size+2)*4.0
			var direction: Vector2 = scene.traffic.network.tangent(lane.id,0.0)
			var lane_start_3d: Vector3 = lane.curve.get_point_position(0)
			var lane_start := Vector2(lane_start_3d.x,lane_start_3d.z)
			var progress: float = (front-lane_start).dot(direction)
			var asset: Dictionary = scene.traffic.catalog.filter(func(a): return a.id=="car-sedan-03")[0].duplicate()
			asset.max_speed = 0.0
			assert(not scene.traffic.simulation.spawn(asset,[lane.id],progress).is_empty())
		# Same bus reference in each capture, on the opposite lane near the group's centre.
		var bus_lane: Dictionary = scene.traffic.network.lanes[2]
		var bus: Dictionary = scene.traffic.catalog.filter(func(a): return a.id=="bus-city-01")[0].duplicate()
		var centre_front := Vector2.ZERO
		for b in scene.city.buildings: centre_front += Vector2(b.x+b.size/2.0,b.y+b.size+2)*4.0
		centre_front /= scene.city.buildings.size()
		var bus_direction: Vector2 = scene.traffic.network.tangent(bus_lane.id,0.0)
		var bus_start_3d: Vector3 = bus_lane.curve.get_point_position(0)
		var bus_start := Vector2(bus_start_3d.x,bus_start_3d.z)
		var bus_progress: float = (centre_front-bus_start).dot(bus_direction)
		assert(not scene.traffic.simulation.spawn(bus,[bus_lane.id],bus_progress).is_empty())
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"/"+names[index]+".png")==OK)
		print("SCALE_CAPTURE ", names[index], " buildings=",scene.city.buildings.size()," zoom=",scene.map_zoom)
	quit()
