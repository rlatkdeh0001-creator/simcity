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

func target_density(level: int) -> String:
	return "small" if level<=2 else ("medium" if level<=4 else "large")

func appearance_density(entry: Dictionary) -> String:
	if int(entry.footprint[0])==8:return "large"
	var value: String=entry.get("density",str(entry.category).get_slice("_",0))
	return value if value in ["small","medium","large"] else str(entry.category).get_slice("_",0)

func matching(building: Dictionary) -> Dictionary:
	var target:=target_density(int(building.level))
	var ranks: Array[String]=["small","medium","large"]
	var desired:=ranks.find(target)
	var best_distance:=99
	var best_rank:=99
	var ids: Array[String]=[]
	for entry: Dictionary in entries:
		if not entry.get("growth_enabled",true) or entry.zone!=building.zone or entry.footprint!=[int(building.size),int(building.size)] or int(building.level)<int(entry.min_level):continue
		var rank:=ranks.find(appearance_density(entry))
		if rank<0:continue
		var distance:=absi(rank-desired)
		# A missing density never changes the lot or simulation level. Lower wins a tie.
		if distance<best_distance or (distance==best_distance and rank<best_rank):
			best_distance=distance;best_rank=rank;ids.clear()
		if distance==best_distance and rank==best_rank:ids.append(str(entry.id))
	return {"target_density":target,"resolved_density":"" if ids.is_empty() else ranks[best_rank],"candidates":ids,"fallback":not ids.is_empty() and best_rank!=desired}

func eligible(building: Dictionary) -> Array[String]:
	return matching(building).candidates

func assign(building: Dictionary, appearance_rng: RandomNumberGenerator):
	var ids := eligible(building)
	if building.get("asset_id", "") in ids:
		return # Keep an eligible facade on same-size growth.
	building.asset_id = "" if ids.is_empty() else ids[appearance_rng.randi_range(0, ids.size() - 1)]

func sprite_rect(asset: Dictionary, front_corner: Vector2, tile_width: float) -> Rect2:
	var scale_factor: float = float(asset.footprint[0]) * tile_width / float(asset.lot_width_px)
	return Rect2(front_corner - Vector2(asset.anchor_px[0], asset.anchor_px[1]) * scale_factor, Vector2(asset.image_size[0], asset.image_size[1]) * scale_factor)
