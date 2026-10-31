extends RefCounted
## Sparse 32x32 chunks; empty terrain never allocates a million cells.
const CHUNK_SIZE := 32
var chunks := {}
func _chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK_SIZE)), floori(cell.y / float(CHUNK_SIZE)))
func set_cell(cell: Vector2i, enabled: bool):
	var key := _chunk(cell)
	if enabled:
		if not chunks.has(key): chunks[key] = {}
		chunks[key][cell] = true
	elif chunks.has(key):
		chunks[key].erase(cell)
		if chunks[key].is_empty(): chunks.erase(key)
func has_cell(cell: Vector2i) -> bool:
	var key := _chunk(cell)
	return chunks.has(key) and chunks[key].has(cell)
func count() -> int:
	var result := 0
	for cells in chunks.values(): result += cells.size()
	return result
func cells_in(bounds: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if bounds.size.x <= 0 or bounds.size.y <= 0: return cells
	var first := _chunk(bounds.position)
	var last := _chunk(bounds.end - Vector2i.ONE)
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1):
			var key := Vector2i(x,y)
			if not chunks.has(key): continue
			for cell in chunks[key]:
				if bounds.has_point(cell): cells.append(cell)
	return cells
