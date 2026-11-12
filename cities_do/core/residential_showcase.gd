extends RefCounted
const Model = preload("res://core/city_model.gd")
const ORDER := ["small-2x2-a","small-2x2-b","small-4x4-a","small-4x4-b","mansion-a-4x4-4f","mansion-b-4x4-4f","large-4x4-a","large-4x4-b","large-8x8-a","large-8x8-b"]
static func create_city():
	var city = Model.new(100,100,42)
	var cursor:=4
	var placements: Array[Dictionary]=[]
	# World-axis lots share a real front edge with a straight, sidewalk-inclusive road.
	for id in ORDER:
		var size: int=city.catalog.get_asset(id).footprint[0]
		placements.append({"id":id,"x":cursor,"y":58-size})
		cursor+=size+1
	var road_result: Dictionary=city.add_road(PackedVector2Array([Vector2(2,60),Vector2(cursor+2,60)]),"local",true,4)
	assert(road_result.ok)
	# Authored review lots follow the production 4+4 frontage rule without moving originals.
	for placement in placements:
		if city.catalog.get_asset(placement.id).footprint[0]!=8:continue
		var rear: Dictionary=city.add_road(PackedVector2Array([Vector2(placement.x,placement.y-1),Vector2(placement.x+8,placement.y-1)]))
		assert(rear.ok)
	for placement in placements:
		var result: Dictionary=city.place_catalog_building(placement.id,placement.x,placement.y)
		assert(result.ok,"Invalid showcase placement: "+placement.id)
	return city
