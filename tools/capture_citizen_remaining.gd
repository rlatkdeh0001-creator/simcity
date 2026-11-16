extends SceneTree
## Read-only asset fixture. The demo adapter/shader are copied byte-for-byte from
## demo/citizens-100 into an agent-scratch project; live game code is not edited.
var _args: Dictionary = {}
var _script
var _adapters: Dictionary = {}
const PARTS := ["body", "hair", "top", "bottom"]
const DIRECTIONS := ["S", "SE", "E", "NE", "N"]
const POSES := ["idle", "1", "2", "3", "4"]

func _initialize() -> void:
	var words := OS.get_cmdline_user_args()
	for i in range(0, words.size(), 2):
		_args[words[i]] = words[i + 1]
	call_deferred("_run")

func _adapter_for(path: String):
	if _adapters.has(path):
		return _adapters[path]
	var a = _script.new()
	a.spec = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("spec.json")))
	var zip := ZIPReader.new()
	assert(zip.open(path.path_join("layer-depths.npz")) == OK)
	var depths: Dictionary = a._read_npy(zip.read_file("depth_mm.npy"))
	var names: Dictionary = a._read_npy(zip.read_file("names.npy"))
	zip.close()
	assert(depths.dtype == "<u2" and depths.shape == [100, 96, 64])
	var width := String(names.dtype).substr(2).to_int()
	var indices: Dictionary = {}
	for i in range(100):
		var stem := ""
		for j in range(width):
			var point: int = names.data.decode_u32((i * width + j) * 4)
			if point == 0:
				break
			stem += String.chr(point)
		indices[stem] = i
	assert(indices.size() == 100)
	for part in PARTS:
		var colors := Image.create(320, 480, false, Image.FORMAT_RGBA8)
		var zs := Image.create(320, 480, false, Image.FORMAT_RG8)
		zs.fill(Color(1, 1, 0, 1))
		for col in range(5):
			for row in range(5):
				var stem := "%s_%s_%s" % [part, DIRECTIONS[col], POSES[row]]
				var image := Image.load_from_file(path.path_join("sprites/" + stem + ".png"))
				assert(image != null and image.get_size() == Vector2i(64, 96))
				image.convert(Image.FORMAT_RGBA8)
				var offset: int = indices[stem] * 64 * 96 * 2
				var depth_image := Image.create_from_data(64, 96, false, Image.FORMAT_RG8, depths.data.slice(offset, offset + 64 * 96 * 2))
				colors.blit_rect(image, Rect2i(0, 0, 64, 96), Vector2i(col * 64, row * 96))
				zs.blit_rect(depth_image, Rect2i(0, 0, 64, 96), Vector2i(col * 64, row * 96))
		a.color_atlases[part] = ImageTexture.create_from_image(colors)
		a.depth_atlases[part] = ImageTexture.create_from_image(zs)
	_adapters[path] = a
	return a

func _text(parent: Node, text: String, pos: Vector2, size: int = 12) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("34413e"))
	parent.add_child(label)

func _run() -> void:
	root.size = Vector2i(1100, 610)
	root.position = Vector2i(40, 40)
	root.title = "Citizen modular wardrobe / read-only asset fixture"
	_script = load("res://core/citizen_demo_sprites.gd")
	assert(_script != null)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_args["--run"]))
	var samples: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_args["--samples"]))
	var paths: Dictionary = {}
	for row in manifest.parts:
		paths[row.id] = String(row.stage)
	var scene := Node2D.new()
	root.add_child(scene)
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1100, 0), Vector2(1100, 610), Vector2(0, 610)])
	bg.color = Color("eceee5")
	scene.add_child(bg)
	_text(scene, "GODOT / "+String(samples.batch)+" / 12 random modular combinations / height "+str(samples.height_m)+"m", Vector2(16, 10), 16)
	_text(scene, "Game scale @ map_zoom1 above; native40px/m + full detail2x below. Original depth shader; no live game changes.", Vector2(16, 39))
	var eight := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
	for i in range(samples.samples.size()):
		var sample: Dictionary = samples.samples[i]
		var a = _adapter_for(paths[sample.hair])
		var colors: Dictionary = {}
		for p in range(4):
			var rgb: Array = sample.tints_rgb[p]
			colors[PARTS[p]] = Color(float(rgb[0])/255, float(rgb[1])/255, float(rgb[2])/255, 1)
		var sprite: Sprite2D = a.create_sprite(colors)
		assert(sprite != null)
		var octant: int = eight.find(sample.direction)
		var heading := Vector2.RIGHT.rotated(PI/4 + octant*PI/4)
		assert(a.direction(heading).name == sample.direction)
		var walking: bool = sample.frame != "idle"
		var seconds: float = (int(sample.frame)-1)*0.2+0.001 if walking else 0.0
		a.set_pose(sprite, heading, walking, seconds)
		assert(sprite.frame_coords.y == (int(sample.frame) if walking else 0))
		var x := 16+(i%6)*180
		var y := 155+floori(float(i)/6.0)*205
		var panel := Polygon2D.new()
		panel.polygon = PackedVector2Array([Vector2(x,y), Vector2(x+170,y), Vector2(x+170,y+190), Vector2(x,y+190)])
		panel.color = Color("fafaf4")
		scene.add_child(panel)
		_text(scene, String(sample.label), Vector2(x+7,y+6))
		sprite.position = Vector2(x+39,y+113)
		scene.add_child(sprite)
		var game: Sprite2D = sprite.duplicate()
		game.scale = Vector2.ONE*float(samples.game_scale)
		game.position = Vector2(26+i*88+32*float(samples.game_scale),105)
		scene.add_child(game)
		_text(scene, str(i+1), Vector2(19+i*88,113), 11)
		var clip := Control.new()
		clip.position = Vector2(x+86,y+30)
		clip.size = Vector2(80,144)
		clip.clip_contents = true
		scene.add_child(clip)
		var zoom: Sprite2D = sprite.duplicate()
		zoom.scale = Vector2.ONE*2
		zoom.position = Vector2(40,128)
		clip.add_child(zoom)
		_text(scene, String(sample.direction)+" / "+String(sample.frame),Vector2(x+7,y+134))
		_text(scene,"native1x",Vector2(x+7,y+153),11)
		_text(scene,"detail2x",Vector2(x+90,y+176),11)
	_text(scene,"64x96 / foot(32,84) / 8 logical directions / four per-pixel depth-sorted layers / original parts remain read-only",Vector2(16,577),12)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and image.get_size() == Vector2i(1100,610))
	assert(image.save_png(_args["--capture"]) == OK)
	print("CITIZEN_PARTS_GODOT_OK batch=",samples.batch," combinations=",samples.samples.size()," capture=",_args["--capture"])
	quit(0)
