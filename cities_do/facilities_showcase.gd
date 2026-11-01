extends Control
const Parking = preload("res://core/modular_parking.gd")
var parking = Parking.new()
var entries: Array = []
var gallery: GridContainer
var merge_view: SubViewportContainer
var merged_root: Node3D
var status: Label
var camera: Camera3D
var bridge_id := -1
var merged_mode := false

func _ready():
 entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities
 var bg := ColorRect.new()
 bg.color = Color("142830")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
 add_child(margin)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation",12)
 margin.add_child(column)
 var title := Label.new()
 title.text = "CITIES_DO   /   공원과 주차 시설"
 title.add_theme_font_size_override("font_size",30)
 column.add_child(title)
 var bar := HBoxContainer.new()
 column.add_child(bar)
 for pair in [["8종 함께 보기","gallery"],["주차장 합치기","merge"],["연결부 철거 / 복원","bridge"],["소형 추가","small"],["중형 추가","medium"],["대형 추가","large"],["건설 화면으로","back"]]:
  var button := Button.new()
  button.name = "Facility_"+pair[1]
  button.text = pair[0]
  var action: String = pair[1]
  button.pressed.connect(func(): act(action))
  bar.add_child(button)
 status = Label.new()
 status.add_theme_font_size_override("font_size",18)
 column.add_child(status)
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(scroll)
 gallery = GridContainer.new()
 gallery.columns = 4
 gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 gallery.add_theme_constant_override("h_separation",12)
 gallery.add_theme_constant_override("v_separation",12)
 scroll.add_child(gallery)
 for entry in entries: add_card(entry)
 merge_view = SubViewportContainer.new()
 merge_view.stretch = true
 merge_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
 merge_view.custom_minimum_size.y = 550
 column.add_child(merge_view)
 var viewport := SubViewport.new()
 viewport.size = Vector2i(1600,850)
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_2X
 merge_view.add_child(viewport)
 setup_light(viewport)
 merged_root = Node3D.new()
 viewport.add_child(merged_root)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 62
 viewport.add_child(camera)
 camera.position = Vector3(60,55,75)
 camera.look_at(Vector3(16,0,23))
 camera.current = true
 seed_example()
 merge_view.hide()
 status.text = "공원 4종 · 평면 주차장 3종 · 4층 주차타워 1종    |    1칸 = 4m"
 for arg in OS.get_cmdline_user_args():
  if arg == "--facilities-merged": act("merge")
  if arg.begins_with("--capture-facilities="): capture.call_deferred(arg.trim_prefix("--capture-facilities="))

func setup_light(viewport: SubViewport):
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("b8c9b2")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("edf0df")
 environment.environment.ambient_light_energy = .65
 viewport.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-35,0)
 light.light_energy = 1.15
 viewport.add_child(light)

func add_card(entry: Dictionary):
 var panel := PanelContainer.new()
 panel.custom_minimum_size = Vector2(350,360)
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 gallery.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 var name_label := Label.new()
 name_label.text = "%s   %d×%d" % [entry.name,entry.width,entry.depth]
 name_label.add_theme_font_size_override("font_size",20)
 column.add_child(name_label)
 var container := SubViewportContainer.new()
 container.stretch = true
 container.custom_minimum_size = Vector2(320,300)
 column.add_child(container)
 var viewport := SubViewport.new()
 viewport.size = Vector2i(430,300)
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_2X
 container.add_child(viewport)
 setup_light(viewport)
 viewport.add_child(load(entry.model).instantiate())
 var cam := Camera3D.new()
 cam.projection = Camera3D.PROJECTION_ORTHOGONAL
 viewport.add_child(cam)
 var height := 13.0 if entry.kind == "parking_tower" else 3.5
 var target := Vector3(0,height*(.5 if entry.kind=="parking_tower" else .32),0)
 cam.position = target+Vector3(30,24.5,30)
 cam.look_at(target)
 cam.size = (float(entry.width+entry.depth)*4*.354+height*.866)*1.16
 cam.current = true
 var details := Label.new()
 details.text = "%d × %d m%s" % [entry.width*4,entry.depth*4," · 4층" if entry.kind=="parking_tower" else (" · %d면"%entry.capacity if entry.kind=="surface_parking" else "")]
 column.add_child(details)

func seed_example():
 parking = Parking.new()
 parking.add("surface_parking",Vector2i(0,0),Vector2i(2,4))
 bridge_id = parking.add("surface_parking",Vector2i(2,0),Vector2i(4,4))
 parking.add("surface_parking",Vector2i(2,4),Vector2i(4,8))
 parking.add("parking_tower",Vector2i(8,0),Vector2i(4,4))
 rebuild_meshes()

func rebuild_meshes():
 for child in merged_root.get_children():
  merged_root.remove_child(child)
  child.queue_free()
 var groups: Array = parking.groups()
 var capacity := 0
 for group in groups:
  var instance := MeshInstance3D.new()
  instance.name = "CombinedParking_%d" % group.lot_ids[0]
  instance.mesh = Parking.combined_mesh(group)
  merged_root.add_child(instance)
  capacity += group.capacity
 for lot in parking.lots:
  if lot.kind != "parking_tower": continue
  var tower = load("res://assets/facilities/parking-tower-4x4-4f.glb").instantiate()
  tower.position = Vector3((lot.origin.x+2)*4,0,(lot.origin.y+2)*4)
  merged_root.add_child(tower)
 status.text = "평면 주차장 %d개 단지 · 총 %d면    |    내부 경계석 제거 · 통로 공유 · 타워는 별도" % [groups.size(),capacity]

func act(action: String):
 if action == "back":
  get_tree().change_scene_to_file("res://main.tscn")
  return
 if action in ["gallery","merge"]:
  merged_mode = action == "merge"
  gallery.get_parent().visible = not merged_mode
  merge_view.visible = merged_mode
  if merged_mode: rebuild_meshes()
  else: status.text = "공원 4종 · 평면 주차장 3종 · 4층 주차타워 1종"
 elif action == "bridge":
  if parking.remove(bridge_id): bridge_id = -1
  else: bridge_id = parking.add("surface_parking",Vector2i(2,0),Vector2i(4,4))
  act("merge")
 else:
  var footprint: Vector2i = {"small":Vector2i(2,4),"medium":Vector2i(4,4),"large":Vector2i(4,8)}[action]
  var end := 6
  for lot in parking.lots:
   if lot.kind == "surface_parking": end = maxi(end,lot.origin.x+lot.size.x)
  # Extend the bottom band to avoid the independently placed tower.
  var id: int = parking.add("surface_parking",Vector2i(end,4),footprint)
  act("merge")
  if id == -1: status.text += " · 전시 경계에 도달했습니다"

func capture(path: String):
 for i in range(15): await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(path)
 get_tree().quit(0 if error == OK else 1)
