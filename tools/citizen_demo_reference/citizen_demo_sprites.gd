extends RefCounted
## Read-only adapter for the original 40 px/m citizen pilot.
## Atlases are generated in memory: no editor import or Python dependency.

const PARTS := ["body", "hair", "top", "bottom"]
const DIRECTIONS := ["S", "SE", "E", "NE", "N"]
const POSES := ["idle", "1", "2", "3", "4"]
const CELL := Vector2i(64, 96)
const ATLAS_SIZE := Vector2i(320, 480)

var spec: Dictionary = {}
var color_atlases: Dictionary = {}
var depth_atlases: Dictionary = {}
var depth_names: PackedStringArray = []
var _shader: Shader
var _depth_bytes := PackedByteArray()
var _depth_indices: Dictionary = {}

func setup() -> bool:
	if color_atlases.size() == 4 and depth_atlases.size() == 4:
		return true
	var root := ProjectSettings.globalize_path("res://").path_join("../assets/citizens/adult-pilot-01").simplify_path()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("spec.json")))
	if not parsed is Dictionary:
		return false
	spec = parsed
	var zip := ZIPReader.new()
	if zip.open(root.path_join(spec.get("depth_sidecar", "layer-depths.npz"))) != OK:
		return false
	var depths := _read_npy(zip.read_file("depth_mm.npy"))
	var names := _read_npy(zip.read_file("names.npy"))
	zip.close()
	if depths.is_empty() or names.is_empty():
		return false
	if depths.dtype != "<u2" or depths.shape != [100, 96, 64]:
		return false
	if not String(names.dtype).begins_with("<U") or names.shape != [100]:
		return false
	var width := String(names.dtype).substr(2).to_int()
	var name_data: PackedByteArray = names.data
	if width <= 0 or name_data.size() != 100 * width * 4:
		return false
	depth_names.clear()
	_depth_indices.clear()
	for i in range(100):
		var stem := ""
		for j in range(width):
			var codepoint := name_data.decode_u32((i * width + j) * 4)
			if codepoint == 0:
				break
			if codepoint > 0x10ffff:
				return false
			stem += String.chr(codepoint)
		if _depth_indices.has(stem):
			return false
		depth_names.append(stem)
		_depth_indices[stem] = i
	_depth_bytes = depths.data
	if _depth_bytes.size() != 100 * 96 * 64 * 2:
		return false
	var colors: Dictionary = {}
	var depth_textures: Dictionary = {}
	for part in PARTS:
		var color_image := Image.create(320, 480, false, Image.FORMAT_RGBA8)
		var depth_image := Image.create(320, 480, false, Image.FORMAT_RG8)
		depth_image.fill(Color(1, 1, 0, 1))
		for column in range(5):
			for row in range(5):
				var stem := "%s_%s_%s" % [part, DIRECTIONS[column], POSES[row]]
				if not _depth_indices.has(stem):
					return false
				var image := Image.load_from_file(root.path_join("sprites/" + stem + ".png"))
				if image == null or image.get_size() != CELL:
					return false
				image.convert(Image.FORMAT_RGBA8)
				var offset: int = _depth_indices[stem] * 64 * 96 * 2
				# Little-endian uint16 bytes map exactly to R=low, G=high.
				var depth_cell := Image.create_from_data(64, 96, false, Image.FORMAT_RG8, _depth_bytes.slice(offset, offset + 64 * 96 * 2))
				var target := Vector2i(column * 64, row * 96)
				color_image.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), target)
				depth_image.blit_rect(depth_cell, Rect2i(Vector2i.ZERO, CELL), target)
		colors[part] = ImageTexture.create_from_image(color_image)
		depth_textures[part] = ImageTexture.create_from_image(depth_image)
	color_atlases = colors
	depth_atlases = depth_textures
	return true

## S=(+X,+Y); labels are camera azimuths, matching the live vehicle renderer.
static func direction(heading_world: Vector2) -> Dictionary:
	var octant := 0
	if not heading_world.is_zero_approx():
		octant = posmod(roundi((heading_world.angle() - PI / 4.0) / (PI / 4.0)), 8)
	var names := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
	return {"index": octant if octant <= 4 else 8 - octant, "mirror": octant > 4, "name": names[octant]}

func create_sprite(colors: Dictionary) -> Sprite2D:
	if not setup():
		return null
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FileAccess.get_file_as_string("res://core/citizen_demo.gdshader")
	var material := ShaderMaterial.new()
	material.shader = _shader
	for part in PARTS:
		material.set_shader_parameter(part + "_color", color_atlases[part])
		material.set_shader_parameter(part + "_depth", depth_atlases[part])
		material.set_shader_parameter(part + "_tint", colors.get(part, Color.WHITE))
	var sprite := Sprite2D.new()
	sprite.texture = color_atlases.body
	sprite.hframes = 5
	sprite.vframes = 5
	sprite.offset = Vector2(0, -36)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = material
	return sprite

func set_pose(sprite: Sprite2D, heading: Vector2, walking: bool, seconds: float) -> void:
	var facing := direction(heading)
	var row := 0
	if walking:
		var cycle: float = spec.get("cycle_seconds", 0.8)
		# A small boundary tolerance prevents 0.6/0.2 rounding to frame 3.
		row = 1 + posmod(floori(fposmod(seconds, cycle) / (cycle / 4.0) + 0.0000001), 4)
	sprite.frame_coords = Vector2i(facing.index, row)
	sprite.flip_h = facing.mirror

## Each ID uses a private RNG; spawning order cannot change citizen colors.
static func palette(id: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = id ^ 0x434954495a454e
	var skins := [Color("e1b691"), Color("c28d66"), Color("a46d49"), Color("784b35"), Color("f0cbaa")]
	var hairs := [Color("4d3628"), Color("292523"), Color("875a35"), Color("b58b50"), Color("b3aaa0")]
	return {
		"body": skins[random.randi_range(0, skins.size() - 1)],
		"hair": hairs[random.randi_range(0, hairs.size() - 1)],
		"top": Color.from_hsv(random.randf(), random.randf_range(0.25, 0.75), random.randf_range(0.45, 0.95)),
		"bottom": Color.from_hsv(random.randf(), random.randf_range(0.15, 0.55), random.randf_range(0.22, 0.55)),
	}

## Parse the NPY framing/header, not assumed fixed offsets or ZIP order.
## Supported payloads are C-contiguous little-endian uint16 and UTF-32.
static func _read_npy(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 10 or bytes[0] != 0x93 or bytes.slice(1, 6).get_string_from_ascii() != "NUMPY":
		return {}
	var major := bytes[6]
	var start := 10 if major == 1 else 12
	if major < 1 or major > 3 or bytes.size() < start:
		return {}
	var header_size := bytes.decode_u16(8) if major == 1 else bytes.decode_u32(8)
	if start + header_size > bytes.size():
		return {}
	var header := bytes.slice(start, start + header_size).get_string_from_utf8()
	var expression := RegEx.new()
	expression.compile("['\"]descr['\"]\\s*:\\s*['\"]([^'\"]+)['\"]")
	var dtype_match := expression.search(header)
	if dtype_match == null:
		return {}
	expression.compile("['\"]fortran_order['\"]\\s*:\\s*False")
	if expression.search(header) == null:
		return {}
	expression.compile("['\"]shape['\"]\\s*:\\s*\\(([^)]*)\\)")
	var shape_match := expression.search(header)
	if shape_match == null:
		return {}
	var shape: Array = []
	for dimension in shape_match.get_string(1).split(",", false):
		var value := dimension.strip_edges()
		if not value.is_valid_int() or value.to_int() < 0:
			return {}
		shape.append(value.to_int())
	return {"dtype": dtype_match.get_string(1), "shape": shape, "data": bytes.slice(start + header_size)}
