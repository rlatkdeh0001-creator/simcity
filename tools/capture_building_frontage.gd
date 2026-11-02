extends SceneTree
func _initialize():run.call_deferred()
func run():
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for child in scene.get_children():
		if child is CanvasLayer:child.hide()
	scene.set_process(false)
	scene.city=scene.Model.new(70,70)
	for points in [PackedVector2Array([Vector2(7,16),Vector2(18,16)]),PackedVector2Array([Vector2(21,8),Vector2(32,8)]),PackedVector2Array([Vector2(8,21),Vector2(8,32)]),PackedVector2Array([Vector2(30,21),Vector2(30,32)]),PackedVector2Array([Vector2(38,12),Vector2(54,22)])]:
		assert(scene.city.add_road(points).ok)
	for p in [Vector2i(10,10),Vector2i(24,10),Vector2i(10,24),Vector2i(24,24)]:
		assert(scene.city.place_catalog_building("mansion-a-4x4-4f",p.x,p.y).ok)
	var sides:={}
	for frame in scene.city.zoning_grid.frames.values():
		if frame.road_index!=4 or sides.has(frame.side):continue
		var result: Dictionary=scene.city.add_building_at(frame.origin+frame.along*2.5+frame.outward*.5,"residential",100)
		if not result.ok:continue
		scene.city.config.size_weights={8:0.0,4:1.0,2:0.0}
		assert(scene.city.upgrade_chain(result.building.id).ok)
		result.building.asset_id="mansion-a-4x4-4f"
		sides[frame.side]=true
	assert(scene.city.buildings.size()==6)
	scene.map_zoom=1.8
	scene.origin=Vector2(560,130)
	for b in scene.city.buildings:scene.building_visual(b)
	for frame in range(300):
		await process_frame
		if not scene.building_views.busy and scene.building_views.queue.is_empty():break
	assert(not scene.building_views.busy and scene.building_views.queue.is_empty())
	for b in scene.city.buildings:
		var visual: Dictionary=scene.building_visual(b)
		assert(not visual.is_empty())
		assert(not visual.image.get_used_rect().size==Vector2i.ZERO)
		var picked:=false
		for y in range(10,visual.image.get_height()-10,20):
			for x in range(10,visual.image.get_width()-10,20):
				if visual.image.get_pixel(x,y).a<.9:continue
				var point: Vector2=visual.rect.position+Vector2(x,y)/Vector2(visual.image.get_size())*visual.rect.size
				if scene.pick_rendered_building(point).get("id",-1)==b.id:picked=true;break
			if picked:break
		assert(picked,"Directional visible facade must accept selection")
		print("FRONTAGE_CAPTURE ",b.id," facing=",scene.city.front_direction(b)," road=",b.front_road_id)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])==OK)
	quit()
