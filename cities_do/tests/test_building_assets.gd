extends SceneTree
const Model = preload("res://core/city_model.gd")
var failures := 0
var checks := 0
func verify(value: bool, label: String):
	checks += 1
	if value: print("PASS ", label)
	else:
		failures += 1
		push_error(label)
func _initialize():
	call_deferred("run")
func make_city(seed_value: int = 42):
	var city = Model.new(40, 40, seed_value)
	city.add_road(PackedVector2Array([Vector2(1,20),Vector2(39,20)]))
	city.add_building(8,17,"residential",100)
	city.config.size_weights = {8:0.0,4:1.0,2:0.0}
	return city
func run():
	var city = make_city()
	verify(not city.catalog.get_asset("mansion-a-4x4-4f").is_empty() and not city.catalog.get_asset("mansion-b-4x4-4f").is_empty(), "both mansion designs registered")
	verify(city.catalog.get_asset(city.buildings[0].asset_id).density == "small", "2x2 new construction uses small, never medium asset")
	city.upgrade_chain(1)
	var b: Dictionary = city.buildings[0]
	verify(b.size == 4 and city.catalog.get_asset(b.asset_id).density=="small", "4x4 stage2 uses approved small facade; stage3 selects mansions")
	var original_id: String = b.asset_id
	city.upgrade_chain(1)
	verify(b.asset_id != original_id and city.catalog.get_asset(b.asset_id).density=="medium", "stage2 to3 rematches density on the same lot")
	original_id=b.asset_id
	city.upgrade_chain(1)
	verify(b.asset_id == original_id, "same-density same-size growth preserves facade")
	city.config.size_weights = {8:0.0,4:0.0,2:1.0}
	city.upgrade_chain(1)
	verify(b.size == 8 and b.level==5 and city.catalog.get_asset(b.asset_id).footprint==[8,8], "stage5 expands to the largest legal lot without shrinking")
	city.config.size_weights = {8:1.0,4:0.0,2:0.0}
	verify(not city.upgrade_chain(1).ok and b.level==5,"final stage cannot grow into stage6")
	verify(b.size == 8 and city.catalog.get_asset(b.asset_id).density=="large" and city.catalog.get_asset(b.asset_id).footprint==[8,8], "8x8 uses its original large model, not a stretched mansion")
	for zone in ["commercial", "industrial"]:
		verify(city.catalog.eligible({"zone":zone,"size":4,"level":3}).all(func(id):return city.catalog.get_asset(id).zone==zone), "mansion excluded from " + zone)
	var variants := {}
	var replay_equal := true
	for seed_value in range(100):
		var a = make_city(seed_value)
		var replay = make_city(seed_value)
		a.upgrade_chain(1)
		replay.upgrade_chain(1)
		variants[a.buildings[0].asset_id] = true
		if a.buildings[0].asset_id != replay.buildings[0].asset_id: replay_equal = false
	verify(variants.size() == 2, "seeded growth can select either facade")
	verify(replay_equal, "facade assignment reproducible for same seed")
	var baseline = make_city()
	var with_assets = make_city()
	baseline.catalog.entries = []
	baseline.upgrade_chain(1)
	with_assets.upgrade_chain(1)
	verify(baseline.rng.state == with_assets.rng.state, "appearance choice does not consume growth RNG")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.map_zoom = 1.0
	await process_frame
	for asset in city.catalog.entries.filter(func(entry): return entry.id.begins_with("mansion-")):
		verify(asset.category == "medium_residential" and asset.storeys == 4 and asset.footprint == [4,4], asset.id + " classified as 4-floor medium residential")
		verify(scene.building_textures.has(asset.id), asset.id + " Godot texture imported")
		scene.city = make_city()
		scene.city.upgrade_chain(1)
		var building: Dictionary = scene.city.buildings[0]
		building.asset_id = asset.id
		var front_corner: Vector2 = scene.screen(Vector2(building.x+4,building.y+4))
		var rect: Rect2 = scene.city.catalog.sprite_rect(asset,front_corner,28.0)
		var scale_factor: float = 112.0 / asset.lot_width_px
		verify((rect.position+Vector2(asset.anchor_px[0],asset.anchor_px[1])*scale_factor).distance_to(front_corner) < 0.001, asset.id + " ground pivot aligns to lot corner")
		verify(abs(asset.lot_width_px*scale_factor - 112.0) < 0.001, asset.id + " projected footprint matches 4x4 grid")
		verify(scene.pick_rendered_building(rect.position + Vector2(450,450)*scale_factor).get("id",-1) == building.id, asset.id + " visible facade can be selected")
		verify(scene.pick_rendered_building(rect.position + Vector2(1,1)*scale_factor).is_empty(), asset.id + " transparent sprite margin does not capture clicks")
		scene.selected = building.id
		scene.refresh()
		verify("중형 주거" in scene.info.text and "4층" in scene.info.text and asset.name in scene.info.text, asset.id + " selection info shows category, variant, floors")
		await process_frame
	scene.queue_free()
	await process_frame
	print("RESULT ", checks-failures, "/", checks, " asset checks passed")
	quit(1 if failures else 0)
