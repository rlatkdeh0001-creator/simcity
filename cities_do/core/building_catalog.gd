extends RefCounted
## Data-only definitions; no textures, scene objects or gameplay RNG here.
const DATA_PATH := "res://assets/buildings/catalog.json"
var entries: Array = []

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data is Dictionary and data.has("buildings"), "Invalid building catalog")
	entries = data.buildings
	# Godot JSON numbers are floats; normalize discrete catalog fields before matching.
	for entry in entries:
		entry.footprint = [int(entry.footprint[0]), int(entry.footprint[1])]
		entry.storeys = int(entry.storeys)
		entry.min_level = int(entry.min_level)

func get_asset(id: String) -> Dictionary:
	for entry in entries:
		if entry.id == id:
			return entry
	return {}

func eligible(building: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if entry.zone == building.zone and entry.footprint == [building.size, building.size] and building.level >= entry.min_level:
			ids.append(entry.id)
	return ids

func assign(building: Dictionary, appearance_rng: RandomNumberGenerator):
	var ids := eligible(building)
	if building.get("asset_id", "") in ids:
		return # Keep an eligible facade on same-size growth.
	building.asset_id = "" if ids.is_empty() else ids[appearance_rng.randi_range(0, ids.size() - 1)]

func sprite_rect(asset: Dictionary, front_corner: Vector2, tile_width: float) -> Rect2:
	var scale_factor: float = float(asset.footprint[0]) * tile_width / float(asset.lot_width_px)
	return Rect2(front_corner - Vector2(asset.anchor_px[0], asset.anchor_px[1]) * scale_factor, Vector2(asset.image_size[0], asset.image_size[1]) * scale_factor)
