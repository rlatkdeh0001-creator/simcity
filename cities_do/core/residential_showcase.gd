extends RefCounted
const Model = preload("res://core/city_model.gd")
const ORDER := ["small-2x2-a","small-2x2-b","small-4x4-a","small-4x4-b","mansion-a-4x4-4f","mansion-b-4x4-4f","large-4x4-a","large-4x4-b","large-8x8-a","large-8x8-b"]
static func create_city():
	var city = Model.new(100,100,42)
	var front_x := 10
	var previous_size := 2
	var placements: Array[Dictionary] = []
	for id in ORDER:
		var asset: Dictionary = city.catalog.get_asset(id)
		var size: int = asset.footprint[0]
		if not placements.is_empty(): front_x += (previous_size+size)/2+1
		placements.append({"id":id,"x":front_x-size,"y":90-front_x-size})
		previous_size = size
	var road_result: Dictionary = city.add_road(PackedVector2Array([Vector2(4,90),Vector2(front_x+4,94-front_x-4)]),"local",true,4)
	assert(road_result.ok)
	for placement in placements:
		var result: Dictionary = city.place_catalog_building(placement.id,placement.x,placement.y)
		assert(result.ok,"Invalid showcase placement: "+placement.id)
	return city
