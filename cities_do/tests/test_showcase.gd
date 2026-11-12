extends SceneTree
const Showcase = preload("res://core/residential_showcase.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String):
	checks += 1
	if value: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize():
	# Headless SceneTree defaults to 64x64; test the intended logical game viewport.
	root.content_scale_size = Vector2i(1920,1100)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1920,1100)
	call_deferred("run")
func run():
	var city = Showcase.create_city()
	check(city.buildings.size() == 10,"showcase has ten residential buildings")
	check(city.roads.size() == 3 and city.roads[0].lanes == 4,"shared four-lane road plus two genuine opposite-frontage roads")
	check(city.buildings.filter(func(b):return b.size==8).all(func(b):return city.zoning_grid.has_opposing_lot(city.footprint(b))),"both original 8x8 lots satisfy the production two-road 4+4 rule")
	var groups := {}
	var ids := {}
	var baseline_sum := -1
	for building in city.buildings:
		var asset: Dictionary = city.catalog.get_asset(building.asset_id)
		groups[asset.category] = groups.get(asset.category,0)+1
		ids[asset.id] = true
		var front_sum: int = building.y+building.size
		if baseline_sum == -1: baseline_sum = front_sum
		check(front_sum == baseline_sum and city.placement_error(building.x,building.y,building.size,building.id) == "",asset.id+" on shared baseline, valid lot and road access")
	check(ids.size()==10 and groups=={"small_residential":4,"medium_residential":2,"large_residential":4},"all ten unique assets and exact categories")
	var previous_count: int = city.buildings.size()
	var previous_id: int = city.next_id
	check(not city.place_catalog_building("unknown",10,10).ok,"unknown scenario asset rejected")
	check(not city.place_catalog_building("small-2x2-a",city.buildings[0].x,city.buildings[0].y).ok,"scenario asset overlap rejected")
	check(city.buildings.size()==previous_count and city.next_id==previous_id,"failed placement is atomic")
	check(city.catalog.eligible({"zone":"residential","size":2,"level":1}).all(func(id):return city.catalog.get_asset(id).density=="small") and city.catalog.eligible({"zone":"residential","size":8,"level":5}).all(func(id):return city.catalog.get_asset(id).density=="large"),"approved appearance activation respects small new lots and large 8x8 originals")
	var saved_city = city
	set_meta("construction_session",{"city":saved_city,"map_zoom":1.2,"origin":Vector2(700,150)})
	var scene = load("res://residential_showcase.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.city.buildings.size()==10 and scene.city.buildings.all(func(b):return ids.has(b.asset_id)) and ids.keys().all(func(id):return scene.building_textures.has(id)),"actual showcase retains all ten original residential textures and buildings")
	check(scene.building_textures.size()==scene.city.catalog.entries.size(),"texture cache includes the complete expanded catalogue without placing the new inspection assets")
	check(has_meta("construction_session") and get_meta("construction_session").city==saved_city and scene.city!=saved_city,"opening showcase preserves the original construction session")
	var reference_scale := -1.0
	var all_clicks := true
	var all_info := true
	var all_fit := true
	for building in scene.city.buildings:
		var asset: Dictionary = scene.city.catalog.get_asset(building.asset_id)
		var rect: Rect2 = scene.city.catalog.sprite_rect(asset,scene.screen(Vector2(building.x+building.size,building.y+building.size)),scene.tile.x*2*scene.map_zoom)
		var scale_per_cell: float = asset.lot_width_px * rect.size.x / asset.image_size[0] / building.size
		if reference_scale < 0: reference_scale = scale_per_cell
		if abs(scale_per_cell-reference_scale)>.001:
			print("SCALE MISMATCH ",asset.id," ",scale_per_cell," ",reference_scale)
			all_fit = false
		if not Rect2(Vector2.ZERO,scene.get_viewport_rect().size).encloses(rect):
			print("OUT OF VIEW ",asset.id," rect ",rect," viewport ",scene.get_viewport_rect())
			all_fit = false
		var image: Image = scene.building_images[asset.id]
		var clicked := false
		for y in range(40,image.get_height()-40,40):
			for x in range(40,image.get_width()-40,40):
				if image.get_pixel(x,y).a < .9:continue
				var position: Vector2 = rect.position+Vector2(float(x)/image.get_width(),float(y)/image.get_height())*rect.size
				if scene.pick_rendered_building(position).get("id",-1) != building.id:continue
				var click := InputEventMouseButton.new();click.position=position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
				scene._unhandled_input(click)
				clicked = scene.selected == building.id
				break
			if clicked:break
		if not clicked:all_clicks = false
		if not (asset.name in scene.details.text and ("%d층" % asset.storeys) in scene.details.text):all_info = false
	check(all_fit,"all buildings fit viewport at one uniform scale")
	check(all_clicks,"each of ten visible buildings accepts actual input events")
	check(all_info,"each selection displays the matching name and storeys")
	var full_zoom: float = scene.map_zoom
	scene.show_group("small")
	check(scene.map_zoom > full_zoom and "소형 주거" in scene.details.text,"small/medium close-up increases zoom and selects matching building")
	scene.show_group("large")
	check(scene.map_zoom > full_zoom and "대형 주거" in scene.details.text,"large close-up increases zoom and selects matching building")
	scene.show_group("")
	check(abs(scene.map_zoom-full_zoom)<0.001,"overview button restores full-row framing")
	scene.queue_free();await process_frame
	# Scene return restores the actual saved construction model and camera.
	var normal = load("res://main.tscn").instantiate();root.add_child(normal);await process_frame
	check(normal.city==saved_city and normal.map_zoom==1.2 and normal.origin==Vector2(700,150) and not has_meta("construction_session"),"return restores previous city and camera, consumes saved session")
	normal.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," showcase checks passed")
	quit(1 if failures else 0)
