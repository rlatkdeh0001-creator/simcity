extends RefCounted
## Sparse world buckets containing road-local square cells, not axis-aligned world cells.
const Parcels = preload("res://core/road_parcels.gd")
const CHUNK_SIZE := 32
var chunks := {}
var frames := {}
var parcels := {}
func _chunk(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/CHUNK_SIZE),floori(point.y/CHUNK_SIZE))
func clear():
	chunks.clear();frames.clear();parcels.clear()
func key(frame_id: String,u: int,v: int) -> String:return "%s:%d:%d" % [frame_id,u,v]
func add_parcel(frame: Dictionary,u: int,v: int) -> bool:
	var polygon: PackedVector2Array = Parcels.polygon(frame,u,v)
	var bounds: Rect2 = Parcels.bounds(polygon)
	for other in parcels_in(Rect2i(Vector2i(bounds.position.floor())-Vector2i.ONE,Vector2i(bounds.size.ceil())+Vector2i(3,3))):
		if Parcels.overlap(polygon,other.polygon):return false
	var id := key(frame.id,u,v)
	var center: Vector2 = (polygon[0]+polygon[2])/2
	var bucket := _chunk(center)
	if not chunks.has(bucket):chunks[bucket]={}
	var parcel := {"id":id,"frame":frame,"u":u,"v":v,"polygon":polygon,"center":center}
	chunks[bucket][id]=parcel;parcels[id]=parcel;frames[frame.id]=frame
	return true
func count() -> int:return parcels.size()
func has_parcel(frame_id: String,u: int,v: int) -> bool:return parcels.has(key(frame_id,u,v))
func parcels_in(bounds: Rect2i) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if bounds.size.x<=0 or bounds.size.y<=0:return result
	var first := _chunk(Vector2(bounds.position)-Vector2.ONE)
	var last := _chunk(Vector2(bounds.end)+Vector2.ONE)
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1):
			var bucket:=Vector2i(x,y)
			if not chunks.has(bucket):continue
			for parcel in chunks[bucket].values():
				if Rect2(bounds).intersects(Parcels.bounds(parcel.polygon)):result.append(parcel)
	return result
func parcel_at(point: Vector2) -> Dictionary:
	for parcel in parcels_in(Rect2i(Vector2i(point.floor())-Vector2i.ONE,Vector2i(3,3))):
		if Geometry2D.is_point_in_polygon(point,parcel.polygon):return parcel
	return {}
func has_cell(cell: Vector2i) -> bool:return not parcel_at(Vector2(cell)+Vector2(0.5,0.5)).is_empty()
func cells_in(bounds: Rect2i) -> Array[Vector2i]:
	# Compatibility query for world-coordinate diagnostics; rendering uses full polygons.
	var unique := {}
	for parcel in parcels_in(bounds):
		var cell:=Vector2i(Vector2(parcel.center).floor())
		if bounds.has_point(cell):unique[cell]=true
	var result: Array[Vector2i]=[]
	for cell in unique:result.append(cell)
	return result
