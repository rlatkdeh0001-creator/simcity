extends "res://main.gd"
## Review-only HUD scene, rendered by the actual city model and main.gd renderer.
var dock: PanelContainer
var drawer: PanelContainer
var drawer_box: HBoxContainer
var categories: Array[Button] = []
var bulldozer: Button
var money: Label
var counts: Label
var chosen := "power"
var paused := false
var simulation_speed := 1.0
var capture_path := ""
var elapsed := 0.0
var capture_pending := false
var last_funds := -1
var last_count := -1
const NAMES := {"build":"구획","road":"도로","power":"전력","water":"상하수도","environment":"환경","park":"공원","transport":"교통","other":"기타"}
const INK := Color("e4eef1")
const BLUE := Color("39b7ff")

func _ready():
 showcase_view=true
 super._ready()
 controls_panel.hide()
 hud.hide()
 city=Model.new(100,100,42)
 make_town()
 mode="select"
 build_bottom_hud()
 get_viewport().size_changed.connect(fit_preview)
 fit_preview()
 select_category("power")
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--capture-bottom-ui="): capture_path=argument.trim_prefix("--capture-bottom-ui=")
  if argument.begins_with("--bottom-tab="): select_category(argument.trim_prefix("--bottom-tab="))
 categories[NAMES.keys().find(chosen)].grab_focus.call_deferred()
 refresh()

func make_town():
 for y in [30,50,70]:
  city.add_road(PackedVector2Array([Vector2(15,y),Vector2(85,y)]),"local",true,4 if y==50 else 2)
 for x in [20,50,80]: city.add_road(PackedVector2Array([Vector2(x,20),Vector2(x,80)]))
 var examples := [
  ["small-4x4-a",24,25],["small-4x4-b",32,25],["mansion-a-4x4-4f",40,25],
  ["small-2x2-a",55,27],["small-2x2-b",60,27],["small-4x4-a",66,25],["mansion-b-4x4-4f",72,25],
  ["large-8x8-a",24,31],["mansion-b-4x4-4f",38,31],["small-4x4-a",43,31],
  ["small-2x2-b",24,46],["small-2x2-a",29,46],["small-4x4-b",35,44],["mansion-a-4x4-4f",42,44],
  ["large-8x8-b",55,31],["small-4x4-b",66,31],["small-4x4-a",73,31],
  ["mansion-b-4x4-4f",55,44],["small-2x2-b",64,46],["small-2x2-a",69,46],["small-2x2-b",74,46],
  ["small-4x4-b",24,52],["mansion-a-4x4-4f",32,52],["small-4x4-a",40,52],
  ["small-2x2-a",25,67],["small-4x4-b",32,65],["mansion-b-4x4-4f",40,65],
  ["large-4x4-a",55,52],["small-4x4-a",63,52],["mansion-a-4x4-4f",72,52],
  ["small-4x4-b",55,65],["small-2x2-a",63,67],["small-2x2-b",68,67],["small-4x4-a",73,65]]
 for entry in examples:
  var result: Dictionary=city.place_catalog_building(entry[0],entry[1],entry[2])
  if not result.ok: push_error("Invalid UI preview lot: %s %s" % [entry[0],result.reason])
 city.add_power_plant(Vector2(17,44),1500)
 city.power.add_wire(PackedVector2Array([Vector2(72,180),Vector2(320,180)]))
 city.power.add_wire(PackedVector2Array([Vector2(128,180),Vector2(128,116)]))
 city.add_water_facility(Vector2(17,60),"water",1000)
 city.add_water_facility(Vector2(81,60),"sewage",2400)
 city.water.add_pipe(PackedVector2Array([Vector2(72,244),Vector2(328,244)]))
 city.water.add_pipe(PackedVector2Array([Vector2(128,244),Vector2(128,116)]))

func style(background: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color=background
 result.border_color=border
 result.set_border_width_all(1)
 result.set_corner_radius_all(7)
 result.content_margin_left=16
 result.content_margin_right=16
 result.content_margin_top=10
 result.content_margin_bottom=10
 return result

func label(text: String, size_value: int = 18) -> Label:
 var item := Label.new()
 item.text=text
 item.add_theme_font_size_override("font_size",size_value)
 item.add_theme_color_override("font_color",INK)
 return item

func icon(kind: String) -> Texture2D:
 var body := ""
 match kind:
  "build": body='<path d="M2 11 12 2 22 11h-3v11h-5v-7h-4v7H5V11z"/>'
  "road": body='<path d="m7 2-5 20h8v-4h4v4h8L17 2h-4v4h-2V2zm4 7h2v5h-2z" fill-rule="evenodd"/>'
  "power": body='<path d="M14 1 3 14h8l-2 9L22 9h-9z"/>'
  "water": body='<path d="M12 1C10 6 4 11 4 16a8 8 0 0 0 16 0c0-5-6-10-8-15z"/>'
  "environment": body='<path d="m8 3 4-2 5 7-4 2-2-4-2 4-5-2zm13 9 2 5-8 5-2-4 5-2-4-1 1-5zM9 22H3L1 13l5-1 1 5 2-4 4 3z"/>'
  "park": body='<path d="M10 23v-5H5a4 4 0 0 1-2-7 5 5 0 0 1 3-7 6 6 0 0 1 12 0 5 5 0 0 1 3 7 4 4 0 0 1-2 7h-5v5z"/>'
  "transport": body='<rect x="4" y="1" width="16" height="20" rx="4"/><path d="M7 20v3m10-3v3" stroke="white" stroke-width="2"/><path d="M7 5h10v8H7z" fill="#152d3b"/><circle cx="8" cy="17" r="1.3" fill="#152d3b"/><circle cx="16" cy="17" r="1.3" fill="#152d3b"/>'
  "other":
   var path := ""
   for i in range(32):
    var a := TAU*i/32.0
    var radius := 11.0 if i%4 in [0,1] else 8.0
    var p := Vector2(12,12)+Vector2(cos(a),sin(a))*radius
    path+=("M" if i==0 else "L")+str(p.x)+" "+str(p.y)+" "
   body='<path d="'+path+'z M16 12a4 4 0 1 0-8 0a4 4 0 1 0 8 0z" fill-rule="evenodd"/>'
  "bulldozer": body='<path d="M5 4h8l3 10H4zm3 3v5h5l-2-5z" fill-rule="evenodd"/><rect x="1" y="15" width="16" height="7" rx="3"/><path d="m18 10 5-3v16l-5-2zm-4 5 5-2 1 3-6 2z"/><circle cx="5" cy="18.5" r="1.5" fill="#152d3b"/><circle cx="12" cy="18.5" r="1.5" fill="#152d3b"/>'
  "wire": body='<path d="m5 17 14-10" fill="none" stroke="#e4eef1" stroke-width="2"/><circle cx="5" cy="17" r="4"/><circle cx="19" cy="7" r="4"/>'
  "pipes": body='<path d="M2 6h20v4H2zm0 9h20v4H2z"/><path d="M6 4h3v8H6zm9 9h3v8h-3z"/>'
  "factory": body='<path d="M2 22V11l6-4v5l6-4v5h3V2h4v20z"/><path d="M5 17h3v3H5zm6 0h3v3h-3z" fill="#152d3b"/>'
  "erase": body='<path d="m4 10 9-8 9 9-8 10H8l-6-6zm5 9h5l-5-5-3 3zM2 22h20v2H2z"/>'
  "select": body='<path d="M5 1v20l5-5 4 7 4-2-4-7h8z"/>'
  "map": body='<path d="m2 4 6-3 8 3 6-3v19l-6 3-8-3-6 3zm6 0v13l8 3V7z" fill-rule="evenodd"/>'
  "menu": body='<path d="M2 4h20v3H2zm0 7h20v3H2zm0 7h20v3H2z"/>'
  "pause": body='<path d="M5 3h5v18H5zm9 0h5v18h-5z"/>'
  "people": body='<circle cx="9" cy="6" r="4"/><circle cx="18" cy="8" r="3"/><path d="M1 22v-7a8 8 0 0 1 16 0v7zm17 0v-7a9 9 0 0 0-1-3 6 6 0 0 1 6 6v4z"/>'
  "smile": body='<circle cx="12" cy="12" r="11"/><path d="M7 15q5 7 10 0M8 8h1m6 0h1" fill="none" stroke="#152d3b" stroke-width="2"/>'
 var image := Image.new()
 image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24"><g fill="#e4eef1">'+body+'</g></svg>')
 return ImageTexture.create_from_image(image)

func small_button(kind: String, tooltip: String, action: Callable) -> Button:
 var button := Button.new()
 button.icon=icon(kind)
 button.expand_icon=true
 button.custom_minimum_size=Vector2(42,38)
 button.add_theme_constant_override("icon_max_width",24)
 for state in ["normal","hover","pressed"]:
  var compact := style(Color("152d3b") if state=="normal" else Color("244958"))
  compact.content_margin_left=6
  compact.content_margin_right=6
  compact.content_margin_top=6
  compact.content_margin_bottom=6
  button.add_theme_stylebox_override(state,compact)
 button.tooltip_text=tooltip
 button.pressed.connect(action)
 return button

func build_bottom_hud():
 var layer := CanvasLayer.new()
 add_child(layer)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var theme_value := Theme.new()
 theme_value.default_font_size=18
 theme_value.set_stylebox("normal","Button",style(Color("152d3b")))
 theme_value.set_stylebox("hover","Button",style(Color("244958")))
 theme_value.set_stylebox("pressed","Button",style(Color("163f58"),BLUE))
 theme_value.set_stylebox("focus","Button",style(Color(0,0,0,0),BLUE))
 theme_value.set_color("font_color","Button",INK)
 root.theme=theme_value
 layer.add_child(root)
 dock=PanelContainer.new()
 dock.name="BottomDock"
 root.add_child(dock)
 dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 dock.offset_top=-156
 dock.add_theme_stylebox_override("panel",style(Color("102633"),Color("38515e")))
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",6)
 dock.add_child(box)
 var status_scroll := ScrollContainer.new()
 status_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 box.add_child(status_scroll)
 var status := HBoxContainer.new()
 status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 status.add_theme_constant_override("separation",22)
 status_scroll.add_child(status)
 status.add_child(label("CITIES_DO",23))
 money=label(city.Economy.format_amount(city.funds),20)
 money.add_theme_color_override("font_color",Color("efcd7c"))
 status.add_child(money)
 counts=label("건물 %d개" % city.buildings.size())
 status.add_child(counts)
 status.add_child(label("인구 —   만족도 —"))
 var spacer := Control.new()
 spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 status.add_child(spacer)
 status.add_child(small_button("pause","일시정지 / 재개",func():paused=not paused))
 var speed := Button.new()
 speed.text="1×"
 speed.custom_minimum_size=Vector2(50,38)
 speed.pressed.connect(func():
  simulation_speed=3.0 if simulation_speed==1 else 1.0
  speed.text="%d×" % int(simulation_speed))
 status.add_child(speed)
 status.add_child(small_button("map","도시 전체 보기",fit_preview))
 status.add_child(small_button("other","설정",func():select_category("other")))
 status.add_child(small_button("menu","도구 모음 접기 / 펼치기",func():drawer.visible=not drawer.visible))
 box.add_child(HSeparator.new())
 var scroll := ScrollContainer.new()
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var navigation := HBoxContainer.new()
 box.add_child(navigation)
 scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 navigation.add_child(scroll)
 bulldozer=small_button("bulldozer","철거",toggle_demolition)
 bulldozer.name="BulldozerButton"
 bulldozer.custom_minimum_size=Vector2(72,72)
 bulldozer.add_theme_constant_override("icon_max_width",42)
 bulldozer.toggle_mode=true
 bulldozer.add_theme_stylebox_override("pressed",style(Color("614328"),Color("f3b34f")))
 navigation.add_child(bulldozer)
 var row := HBoxContainer.new()
 row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",8)
 row.alignment=BoxContainer.ALIGNMENT_CENTER
 scroll.add_child(row)
 for key in NAMES:
  var button := Button.new()
  button.name="Bottom_"+key
  button.custom_minimum_size=Vector2(92,72)
  button.pressed.connect(select_category.bind(key))
  row.add_child(button)
  var content := VBoxContainer.new()
  content.mouse_filter=Control.MOUSE_FILTER_IGNORE
  button.add_child(content)
  content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  content.offset_top=6
  content.add_theme_constant_override("separation",5)
  var picture := TextureRect.new()
  picture.texture=icon(key)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.custom_minimum_size=Vector2(32,32)
  picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(picture)
  var caption := label(NAMES[key],16)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(caption)
  categories.append(button)
 box.move_child(navigation,0)
 box.move_child(status_scroll,2)
 for i in range(categories.size()):
  categories[i].focus_neighbor_left=categories[(i+7)%8].get_path()
  categories[i].focus_neighbor_right=categories[(i+1)%8].get_path()
 drawer=PanelContainer.new()
 drawer.name="BottomDrawer"
 root.add_child(drawer)
 drawer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 drawer.offset_bottom=-170
 drawer.offset_top=-290
 drawer.add_theme_stylebox_override("panel",style(Color("142e3c"),Color("38515e")))
 drawer_box=HBoxContainer.new()
 drawer_box.add_theme_constant_override("separation",16)
 drawer.add_child(drawer_box)

func select_category(key: String):
 if not NAMES.has(key): return
 chosen=key
 for button in categories:
  button.add_theme_stylebox_override("normal",style(Color("163f58") if button.name=="Bottom_"+key else Color("152d3b"),BLUE if button.name=="Bottom_"+key else Color.TRANSPARENT))
 for child in drawer_box.get_children():
  drawer_box.remove_child(child)
  child.queue_free()
 power_overlay.tab_open=key=="power"
 water_overlay.tab_open=key=="water"
 power_overlay.panel.hide()
 water_overlay.panel.hide()
 power_overlay.show_ranges=false
 water_overlay.show_ranges=false
 power_overlay.drawing=false
 water_overlay.drawing=false
 power_overlay.stroke.clear()
 water_overlay.stroke.clear()
 var heading := VBoxContainer.new()
 heading.custom_minimum_size.x=140
 heading.add_child(label(NAMES[key],22))
 drawer_box.add_child(heading)
 var choices := []
 match key:
  "power": choices=[["지중 전력선","power_wire"],["발전시설","power_plant"]]
  "water": choices=[["상하수관 함께","water_pipe"],["취수장","water_supply"],["하수처리장","water_treatment"]]
  "build": choices=[["주거","build"],["상업","build_commercial"],["공업","build_industrial"]]
  "road": choices=[["도로 그리기","road"],["건물 선택","select"]]
  _:
   pass
 for choice in choices:
  var button := Button.new()
  button.name="Tool_"+choice[1]
  button.tooltip_text=choice[0]
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.custom_minimum_size=Vector2(112,84)
  var content := VBoxContainer.new()
  button.add_child(content)
  content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  content.offset_top=8
  content.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var image := TextureRect.new()
  var tool_icons := {"power_wire":"wire","power_plant":"factory","power_erase_wire":"erase","water_pipe":"pipes","water_supply":"water","water_treatment":"factory","water_erase_pipe":"erase","build":"build","build_commercial":"build","build_industrial":"factory","road":"road","select":"select"}
  image.texture=icon(tool_icons.get(choice[1],"other"))
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.custom_minimum_size=Vector2(38,38)
  image.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(image)
  var caption := label(choice[0],16)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(caption)
  var tool: String=choice[1]
  button.pressed.connect(func():
   zone="commercial" if tool=="build_commercial" else ("industrial" if tool=="build_industrial" else "residential")
   mode="build" if tool.begins_with("build") else tool)
  drawer_box.add_child(button)
 mode="power_wire" if key=="power" else ("water_pipe" if key=="water" else "select")
 bulldozer.set_pressed_no_signal(false)
 demolition_hover.clear()
 var close := Button.new()
 close.text="⌄"
 close.custom_minimum_size.x=42
 close.pressed.connect(func():drawer.hide())
 drawer_box.add_child(close)
 drawer.show()
 fit_preview()
 queue_redraw()

func show_zoning_tiles() -> bool:
 return chosen in ["build","road"] and mode!="demolish"

func toggle_demolition():
 mode="select" if mode=="demolish" else "demolish"
 drawing=false
 stroke.clear()
 power_overlay.drawing=false
 power_overlay.stroke.clear()
 water_overlay.drawing=false
 water_overlay.stroke.clear()
 demolition_hover.clear()
 drawer.hide()
 bulldozer.set_pressed_no_signal(mode=="demolish")
 queue_redraw()

func fit_preview():
 if dock==null: return
 var viewport_size := get_viewport_rect().size
 var available := Rect2(60,40,maxf(280,viewport_size.x-120),maxf(200,viewport_size.y-360))
 var bounds := Rect2()
 var first := true
 for building in city.buildings:
  var asset: Dictionary=city.catalog.get_asset(building.asset_id)
  var point := Vector2(building.x+building.size,building.y+building.size)
  var anchor := Vector2((point.x-point.y)*tile.x,(point.x+point.y)*tile.y)
  var rect := Rect2()
  if asset.is_empty():
   var corners: PackedVector2Array=city.footprint(building)
   var first_corner: Vector2=corners[0]
   rect=Rect2(Vector2((first_corner.x-first_corner.y)*tile.x,(first_corner.x+first_corner.y)*tile.y),Vector2.ZERO)
   for corner in corners: rect=rect.expand(Vector2((corner.x-corner.y)*tile.x,(corner.x+corner.y)*tile.y))
   rect.position.y-=visual_lift(building)
   rect.size.y+=visual_lift(building)
  else:
   rect=city.catalog.sprite_rect(asset,anchor,tile.x*2)
  bounds=rect if first else bounds.merge(rect)
  first=false
 if first:
  bounds=Rect2(Vector2(-city.height*tile.x,0),Vector2((city.width+city.height)*tile.x,(city.width+city.height)*tile.y))
 map_zoom=minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y)
 origin=available.position+(available.size-bounds.size*map_zoom)/2-bounds.position*map_zoom
 var width_value := minf(maxf(410,240+145*(drawer_box.get_child_count()-2)),viewport_size.x-32)
 drawer.offset_left=-width_value/2
 drawer.offset_right=width_value/2
 queue_redraw()

func _process(delta: float):
 if dock==null: return
 bulldozer.set_pressed_no_signal(mode=="demolish")
 var simulated_delta := 0.0 if paused else delta*simulation_speed
 super._process(simulated_delta)
 if city.funds!=last_funds:
  money.text=city.Economy.format_amount(city.funds)
  last_funds=city.funds
 if city.buildings.size()!=last_count:
  counts.text="건물 %d개" % city.buildings.size()
  last_count=city.buildings.size()
 elapsed+=delta
 if capture_path!="" and elapsed>3 and not capture_pending:
  capture_pending=true
  capture.call_deferred()

func capture():
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(capture_path)
 get_tree().quit(0 if error==OK else 1)

func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  if mode=="demolish": toggle_demolition()
  drawer.hide()
