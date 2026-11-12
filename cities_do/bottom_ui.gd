extends "res://main.gd"
## Shared main/preview bottom HUD. No city fixture or service placement logic.
var dock: PanelContainer
var drawer: PanelContainer
var drawer_scroll: ScrollContainer
var drawer_box: HBoxContainer
var categories: Array[Button] = []
var bulldozer: Button
var money: Label
var chosen := ""
var paused := false
var simulation_speed := 1.0
var capture_path := ""
var elapsed := 0.0
var capture_pending := false
signal game_month_closed(day_index: int)
var date_label: Label
var playback_controls: HBoxContainer
var pause_button: Button
var speed_button: Button
var status_left: HBoxContainer
var happiness_label: Label
var population_label: Label
var balance_label: Label
var city_name_button: Button
var city_name_edit: LineEdit
var demand_bars: Array[ProgressBar]=[]
var editing_city_name:=false
var monthly_balance: Variant=null
var status_cache: Dictionary={}
var observed_city
var hud_refresh_count:=0
var utility_popup: PopupPanel
var utility_content: Control
var utility_owner: PanelContainer
var road_modes: PanelContainer
var road_mode_buttons: Array[Button]=[]
const CurrencyLabel=preload("res://core/currency_label.gd")
var money_toast: PanelContainer
var money_toast_timer: Timer
var rejected_card: WeakRef
var asset_info: PanelContainer
var hovered_card: WeakRef
const NAMES := {"build":"구획","road":"도로","power":"전력","water":"수도","environment":"환경","park":"공원","transport":"교통","health":"보건","education":"교육","fire":"소방","police":"경찰"}
const INK := Color("e4eef1")
const BLUE := Color("39b7ff")
const ThumbnailButton=preload("res://core/asset_thumbnail_button.gd")
var thumbnail_manifest: Dictionary={}
const SERVICE_TOOLS := {"clinic":"medical-clinic","hospital":"medical-hospital","large_hospital":"medical-large-hospital","elementary":"elementary-school","high_school":"high-school","college":"technical-college","university":"university","crematorium":"crematorium-4x4"}

# Main uses the model already created/restored by the base view; only the preview adds a town.
func _build_controls(layer: CanvasLayer):
 controls_panel=PanelContainer.new()
 controls_panel.name="LegacyControlsPlaceholder"
 controls_panel.hide()
 layer.add_child(controls_panel)
 info=Label.new()
 controls_panel.add_child(info)
 hud=Label.new()
 hud.hide()
 layer.add_child(hud)
 treasury_label=Label.new()
 controls_panel.add_child(treasury_label)

func _ready():
 var restoring := not showcase_view and get_tree().has_meta("construction_session")
 super._ready()
 mode="select"
 build_bottom_hud()
 get_viewport().size_changed.connect(layout_bottom_hud)
 layout_bottom_hud()
 if not restoring: fit_preview()
 drawer.hide()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--capture-bottom-ui="): capture_path=argument.trim_prefix("--capture-bottom-ui=")
  if argument.begins_with("--bottom-tab="): select_category(argument.trim_prefix("--bottom-tab="))
 focus_initial_category.call_deferred()
 refresh()

func focus_initial_category():
 if is_inside_tree(): categories[maxi(0,NAMES.keys().find(chosen))].grab_focus()

func keyboard_focus_style() -> StyleBoxTexture:
 var image:=Image.create(128,96,false,Image.FORMAT_RGBA8)
 image.fill(Color.TRANSPARENT)
 for x in range(4,124):
  if x%8<4:
   for y in [3,4,91,92]:image.set_pixel(x,y,Color("edf4f5"))
 for y in range(4,92):
  if y%8<4:
   for x in [3,4,123,124]:image.set_pixel(x,y,Color("edf4f5"))
 var outline:=StyleBoxTexture.new()
 outline.resource_name="KeyboardFocusDashed"
 outline.texture=ImageTexture.create_from_image(image)
 return outline

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
  "health": body='<path d="M8 2h8v6h6v8h-6v6H8v-6H2V8h6z"/>'
  "education": body='<path d="m1 7 11-5 11 5-11 5zM5 11v7q7 7 14 0v-7l-7 4z"/>'
  "fire": body='<path d="M13 1q3 7-2 10 1-5-3-7 1 5-3 9-5 11 7 11 12-1 7-12-1 5-4 5 3-7-2-16z"/>'
  "police": body='<path d="m12 1 9 4v8q-1 7-9 10-8-3-9-10V5zm0 5-2 4-4 1 3 3-1 4 4-2 4 2-1-4 3-3-4-1z" fill-rule="evenodd"/>'
  "corrections": body='<path d="M3 2h18v21H3zm3 3v13h2V5zm5 0v13h2V5zm5 0v13h2V5z" fill-rule="evenodd"/>'
  "settings":
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
 theme_value.set_stylebox("focus","Button",keyboard_focus_style())
 theme_value.set_color("font_color","Button",INK)
 root.theme=theme_value
 layer.add_child(root)
 utility_popup=PopupPanel.new()
 utility_popup.name="UtilitySettings"
 utility_popup.theme=theme_value
 utility_popup.popup_hide.connect(restore_utility_controls)
 root.add_child(utility_popup)
 hud.reparent(root)
 hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hud.offset_left=16
 hud.offset_right=-16
 hud.offset_top=-350
 hud.offset_bottom=-320
 hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 info.reparent(root)
 info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 info.offset_left=-450
 info.offset_right=-16
 info.offset_top=-310
 info.offset_bottom=-195
 info.mouse_filter=Control.MOUSE_FILTER_IGNORE
 info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 info.hide()
 dock=PanelContainer.new()
 dock.name="BottomDock"
 root.add_child(dock)
 dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 dock.offset_top=-196
 var dock_style:=style(Color("102633"),Color("38515e"))
 dock_style.content_margin_top=0
 dock_style.content_margin_bottom=0
 dock.add_theme_stylebox_override("panel",dock_style)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",0)
 dock.add_child(box)
 var status_line:=build_status_row(box)
 var divider:=HSeparator.new()
 divider.add_theme_constant_override("separation",1)
 var line:=StyleBoxLine.new()
 line.color=Color("38515e")
 line.thickness=1
 divider.add_theme_stylebox_override("separator",line)
 box.add_child(divider)
 var scroll := ScrollContainer.new()
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus=true
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var navigation := HBoxContainer.new()
 navigation.custom_minimum_size.y=96
 scroll.custom_minimum_size.y=72
 scroll.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 box.add_child(navigation)
 scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 navigation.add_child(scroll)
 bulldozer=small_button("bulldozer","철거",toggle_demolition)
 bulldozer.name="BulldozerButton"
 bulldozer.custom_minimum_size=Vector2(72,72)
 bulldozer.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 bulldozer.add_theme_constant_override("icon_max_width",42)
 bulldozer.toggle_mode=true
 bulldozer.add_theme_stylebox_override("pressed",style(Color("614328"),Color("f3b34f")))
 navigation.add_child(bulldozer)
 var row := HBoxContainer.new()
 row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",4)
 row.alignment=BoxContainer.ALIGNMENT_CENTER
 scroll.add_child(row)
 for key in NAMES:
  var button := Button.new()
  button.name="Bottom_"+key
  button.custom_minimum_size=Vector2(64,72)
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
  var caption := label(NAMES[key],18)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(caption)
  categories.append(button)
 box.move_child(navigation,0)
 box.move_child(status_line,2)
 for i in range(categories.size()):
  categories[i].focus_neighbor_left=categories[(i+categories.size()-1)%categories.size()].get_path()
  categories[i].focus_neighbor_right=categories[(i+1)%categories.size()].get_path()
 drawer=PanelContainer.new()
 drawer.name="BottomDrawer"
 root.add_child(drawer)
 drawer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 drawer.offset_bottom=-210
 drawer.offset_top=-330
 drawer.add_theme_stylebox_override("panel",style(Color("142e3c"),Color("38515e")))
 drawer_scroll=ScrollContainer.new()
 drawer_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 drawer_scroll.follow_focus=true
 drawer.add_child(drawer_scroll)
 drawer_box=HBoxContainer.new()
 drawer_box.add_theme_constant_override("separation",16)
 drawer_scroll.add_child(drawer_box)
 build_road_modes(root)
 drawer.visibility_changed.connect(sync_utility_visibility)

func sync_utility_visibility():
 # Keep above-ground facility models; only their tab-gated network drawing changes.
 var tray_open:=drawer.is_visible_in_tree()
 for pair in [["power",power_overlay],["water",water_overlay]]:
  var overlay=pair[1]
  var active: bool=tray_open and chosen==pair[0]
  overlay.tab_open=active
  overlay.show_ranges=active
  if not active:
   overlay.drawing=false
   overlay.stroke.clear()
  overlay.queue_redraw()
 if not tray_open and mode in ["power_wire","power_select","water_pipe","water_select"]:mode="select"

func road_mode_icon(key: String,selected: bool) -> Texture2D:
 var paths:={"straight":'<path d="M5 27 L27 5"/>',"curve":'<path d="M5 27 Q5 5 27 5"/>',"free":'<path d="M4 24 C10 4 16 30 28 8"/>'}
 var color:="#142b37" if selected else "#edf4f5"
 var image:=Image.new()
 image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g stroke="'+color+'" stroke-width="3" stroke-linecap="round" fill="none">'+paths[key]+'</g></svg>')
 return ImageTexture.create_from_image(image)
func build_road_modes(root: Control):
 # Approved mockups.html 1-B; only these three controls are new.
 road_modes=PanelContainer.new();road_modes.name="RoadModePalette"
 root.add_child(road_modes);road_modes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 var background:=style(Color("142b37"))
 background.content_margin_left=6;background.content_margin_right=6;background.content_margin_top=6;background.content_margin_bottom=6
 road_modes.add_theme_stylebox_override("panel",background)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);road_modes.add_child(row)
 var group:=ButtonGroup.new()
 for key: String in ["straight","curve","free"]:
  var button:=Button.new();button.name="RoadMode_"+key;button.set_meta("road_kind",key)
  button.custom_minimum_size=Vector2(44,44);button.toggle_mode=true;button.button_group=group
  button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.expand_icon=true
  button.add_theme_constant_override("icon_max_width",28);button.add_theme_font_size_override("font_size",18)
  button.tooltip_text={"straight":"직선","curve":"곡선","free":"자유 곡선"}[key]
  for state in ["normal","hover","pressed"]:
   var skin:=style(Color("36b7ff") if state=="pressed" else Color("38515e"))
   skin.content_margin_left=6;skin.content_margin_right=6;skin.content_margin_top=6;skin.content_margin_bottom=6
   button.add_theme_stylebox_override(state,skin)
  button.pressed.connect(road_drawer.set_kind.bind(key));row.add_child(button);road_mode_buttons.append(button)
 for i in range(road_mode_buttons.size()):
  road_mode_buttons[i].focus_neighbor_left=road_mode_buttons[posmod(i-1,3)].get_path()
  road_mode_buttons[i].focus_neighbor_right=road_mode_buttons[(i+1)%3].get_path()
 update_road_modes()
func update_road_modes():
 if road_modes==null:return
 road_modes.visible=chosen=="road"
 for button in road_mode_buttons:
  var active: bool=button.get_meta("road_kind")==road_drawer.kind
  button.set_pressed_no_signal(active);button.icon=road_mode_icon(button.get_meta("road_kind"),active)

func build_status_row(box: VBoxContainer) -> Control:
 var status_line:=Control.new()
 status_line.name="CityStatusRow"
 status_line.custom_minimum_size.y=99
 box.add_child(status_line)
 var left_margin:=MarginContainer.new()
 left_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 left_margin.add_theme_constant_override("margin_left",4)
 left_margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 status_line.add_child(left_margin)
 status_left=HBoxContainer.new()
 status_left.name="LeftInstruments"
 status_left.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
 status_left.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 status_left.add_theme_constant_override("separation",12)
 left_margin.add_child(status_left)
 var date_box:=VBoxContainer.new()
 date_box.add_theme_constant_override("separation",6)
 status_left.add_child(date_box)
 date_label=label(city.clock.caption(),24)
 date_label.name="GameDate"
 date_box.add_child(date_label)
 playback_controls=HBoxContainer.new()
 playback_controls.add_theme_constant_override("separation",6)
 date_box.add_child(playback_controls)
 pause_button=small_button("pause","일시정지 / 재개",toggle_pause)
 pause_button.name="PauseButton"
 pause_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
 pause_button.toggle_mode=true
 speed_button=Button.new()
 speed_button.name="SpeedButton"
 speed_button.text="1×"
 speed_button.tooltip_text="시간 배속"
 speed_button.pressed.connect(toggle_speed)
 for button in [pause_button,speed_button]:
  button.custom_minimum_size=Vector2(0,32)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.add_theme_constant_override("icon_max_width",18)
  for state in ["normal","hover","pressed"]:
   var background:=style(Color("152d3b") if state=="normal" else Color("244958"),Color("38515e"))
   background.content_margin_left=4;background.content_margin_right=4
   background.content_margin_top=3;background.content_margin_bottom=3
   button.add_theme_stylebox_override(state,background)
  playback_controls.add_child(button)
 status_left.add_child(VSeparator.new())
 var happy:=HBoxContainer.new()
 happy.add_theme_constant_override("separation",10)
 happy.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 status_left.add_child(happy)
 var face:=TextureRect.new()
 face.texture=icon("smile")
 face.modulate=Color("5fd38a")
 face.custom_minimum_size=Vector2(36,36)
 face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 happy.add_child(face)
 happiness_label=label("—",28)
 happiness_label.name="HappinessValue"
 happy.add_child(happiness_label)
 status_left.add_child(VSeparator.new())
 var demands:=HBoxContainer.new()
 demands.name="RCIDemand"
 demands.add_theme_constant_override("separation",10)
 demands.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 status_left.add_child(demands)
 for key in ["residential","commercial","industrial"]:
  var bar:=ProgressBar.new()
  bar.name="Demand_"+key
  bar.set_meta("demand_key",key)
  bar.custom_minimum_size=Vector2(22,64)
  bar.fill_mode=ProgressBar.FILL_BOTTOM_TO_TOP
  bar.show_percentage=false
  bar.add_theme_stylebox_override("background",style(Color("0b1c26"),Color("38515e")))
  var fill:=StyleBoxFlat.new()
  fill.bg_color={"residential":Color("5fd38a"),"commercial":Color("4aa8ff"),"industrial":Color("f2c14e")}[key]
  bar.add_theme_stylebox_override("fill",fill)
  demand_bars.append(bar)
  demands.add_child(bar)
 var center:=CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 center.mouse_filter=Control.MOUSE_FILTER_IGNORE
 status_line.add_child(center)
 var city_box:=VBoxContainer.new()
 city_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
 city_box.add_theme_constant_override("separation",2)
 center.add_child(city_box)
 city_name_button=Button.new()
 city_name_button.name="CityNameButton"
 city_name_button.text=city.city_name
 city_name_button.clip_text=true
 city_name_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 city_name_button.tooltip_text="도시 이름 변경"
 var transparent:=StyleBoxEmpty.new()
 city_name_button.add_theme_stylebox_override("normal",transparent)
 city_name_button.add_theme_stylebox_override("hover",transparent)
 city_name_button.add_theme_stylebox_override("pressed",transparent)
 city_name_button.add_theme_color_override("font_color",Color("9fb3bb"))
 city_name_button.pressed.connect(begin_city_name_edit)
 city_box.add_child(city_name_button)
 city_name_edit=LineEdit.new()
 city_name_edit.name="CityNameEdit"
 city_name_edit.alignment=HORIZONTAL_ALIGNMENT_CENTER
 city_name_edit.custom_minimum_size.x=180
 city_name_edit.expand_to_text_length=false
 city_name_edit.text_submitted.connect(func(_text):finish_city_name_edit(true))
 city_name_edit.gui_input.connect(on_city_name_input)
 city_name_edit.focus_exited.connect(func():finish_city_name_edit(false))
 city_box.add_child(city_name_edit)
 city_name_edit.hide()
 var finance:=HBoxContainer.new()
 finance.mouse_filter=Control.MOUSE_FILTER_IGNORE
 finance.alignment=BoxContainer.ALIGNMENT_CENTER
 finance.add_theme_constant_override("separation",18)
 city_box.add_child(finance)
 var population_box:=HBoxContainer.new()
 population_box.add_theme_constant_override("separation",8)
 population_box.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 finance.add_child(population_box)
 var person:=TextureRect.new()
 person.texture=icon("people")
 person.custom_minimum_size=Vector2(26,26)
 person.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 person.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 population_box.add_child(person)
 population_label=label("0",22)
 population_label.name="PopulationValue"
 population_box.add_child(population_label)
 money=CurrencyLabel.new();money.text=city.Economy.format_amount(city.funds);money.add_theme_font_size_override("font_size",34)
 money.name="MoneyValue"
 money.add_theme_color_override("font_color",Color("edf4f5"))
 finance.add_child(money)
 balance_label=CurrencyLabel.new();balance_label.text="—";balance_label.add_theme_font_size_override("font_size",24)
 balance_label.name="MonthlyBalanceValue"
 finance.add_child(balance_label)
 var right_margin:=MarginContainer.new()
 right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 right_margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 right_margin.add_theme_constant_override("margin_right",0)
 status_line.add_child(right_margin)
 var actions:=HBoxContainer.new()
 actions.size_flags_horizontal=Control.SIZE_SHRINK_END
 actions.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 actions.add_theme_constant_override("separation",6)
 right_margin.add_child(actions)
 actions.add_child(small_button("map","도시 전체 보기",fit_preview))
 actions.add_child(small_button("menu","도구 모음 접기 / 펼치기",func():drawer.visible=not drawer.visible))
 return status_line

func toggle_pause():
 paused=not paused
 pause_button.set_pressed_no_signal(paused)

func toggle_speed():
 simulation_speed=3.0 if simulation_speed==1 else 1.0
 speed_button.text="%d×" % int(simulation_speed)

func bind_status_events():
 if observed_city==city:return
 if observed_city!=null:
  for event in ["funds_changed","society_changed","city_name_changed"]:
   if observed_city.is_connected(event,refresh_status):observed_city.disconnect(event,refresh_status)
  if observed_city.clock.minute_changed.is_connected(refresh_status):observed_city.clock.minute_changed.disconnect(refresh_status)
  if observed_city.clock.day_changed.is_connected(on_game_day_changed):observed_city.clock.day_changed.disconnect(on_game_day_changed)
 observed_city=city
 for event in ["funds_changed","society_changed","city_name_changed"]:city.connect(event,refresh_status)
 city.clock.minute_changed.connect(refresh_status)
 city.clock.day_changed.connect(on_game_day_changed)
 status_cache.clear()
 monthly_balance=null

func refresh_status():
 if money==null:return
 var stats: Dictionary=city.population.stats()
 var demand: Dictionary=city.population.demand(city.buildings)
 var snapshot: Dictionary={"name":city.city_name,"funds":city.funds,"available":city.utility_balance(),"date":city.clock.caption(),"stats":stats,"demand":demand,"balance":monthly_balance}
 if snapshot==status_cache:return
 hud_refresh_count+=1
 if snapshot.name!=status_cache.get("name"):city_name_button.text=snapshot.name
 if snapshot.funds!=status_cache.get("funds"):money.text=city.Economy.format_amount(city.funds)
 if snapshot.date!=status_cache.get("date"):date_label.text=snapshot.date
 if snapshot.stats!=status_cache.get("stats") or snapshot.demand!=status_cache.get("demand"):
  population_label.text=city.Economy.format_number(stats.population)
  population_label.tooltip_text="취업 %d · 미취업 %d · 주 %d 상 %d 공 %d" % [stats.employed,stats.unemployed,demand.residential,demand.commercial,demand.industrial]
  for bar in demand_bars:
   var key: String=bar.get_meta("demand_key")
   bar.max_value=maxf(8,float(demand[key]))
   bar.value=maxf(0,float(demand[key]))
   bar.tooltip_text={"residential":"주거","commercial":"상업","industrial":"공업"}[key]+" "+str(demand[key])
 if snapshot.balance!=status_cache.get("balance") or status_cache.is_empty():
  balance_label.text="—" if monthly_balance==null else ("−" if monthly_balance<0 else "+")+city.Economy.format_amount(absi(monthly_balance))+"/월"
  balance_label.add_theme_color_override("font_color",INK if monthly_balance==null else (Color("ff6b6b") if monthly_balance<0 else Color("5fd38a")))
 status_cache=snapshot.duplicate(true)
 update_asset_affordability()

func set_monthly_balance(value: Variant):
 # Future economic producer publishes the closed game day's (= game month's) total.
 if value!=null and not value is int:return
 monthly_balance=value
 refresh_status()

func on_game_day_changed(previous: int,current: int):
 for index in range(previous,current):game_month_closed.emit(index)

func begin_city_name_edit():
 editing_city_name=true
 city_name_edit.text=city.city_name
 city_name_button.hide()
 city_name_edit.show()
 city_name_edit.grab_focus()
 city_name_edit.select_all()

func finish_city_name_edit(commit: bool):
 if not editing_city_name:return
 editing_city_name=false
 var candidate:=city_name_edit.text.strip_edges()
 if commit and not candidate.is_empty():city.city_name=candidate
 city_name_edit.hide()
 city_name_button.show()
 city_name_button.grab_focus()

func on_city_name_input(event: InputEvent):
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  city_name_edit.accept_event()
  finish_city_name_edit(false)

static func developer_tools_allowed(debug_build: bool,arguments: PackedStringArray) -> bool:
 return debug_build and arguments.has("--developer-tools")

func developer_tools_enabled() -> bool:
 return developer_tools_allowed(OS.is_debug_build(),OS.get_cmdline_user_args())

func select_category(key: String):
 if not NAMES.has(key): return
 hide_asset_info()
 clear_money_toast()
 if road_drawer!=null:road_drawer.cancel()
 if public_controller!=null:public_controller.cancel()
 if utility_popup.visible: utility_popup.hide()
 cancel_zoning_drag()
 drawing=false
 stroke.clear()
 chosen=key
 for button in categories:
  button.add_theme_stylebox_override("normal",style(Color("163f58") if button.name=="Bottom_"+key else Color("152d3b"),BLUE if button.name=="Bottom_"+key else Color.TRANSPARENT))
  if button.name=="Bottom_"+key:button.grab_focus()
 for child in drawer_box.get_children():
  drawer_box.remove_child(child)
  child.queue_free()
 power_overlay.panel.hide()
 water_overlay.panel.hide()
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
  "power": choices=[["지중 전력선","power_wire"]]
  "water": choices=[["상하수관 함께","water_pipe"],["시설 선택","water_select"]]
  "build": choices=[["주거","build"],["상업","build_commercial"],["공업","build_industrial"],["구획 해제","build_erase"],["건물 선택","select"]]
  "health": choices=[["병원","hospital"],["진료소","clinic"],["대형병원","large_hospital"],["화장터","crematorium"]]
  "education": choices=[["초등학교","elementary"],["고등학교","high_school"],["전문대학","college"],["대학교","university"]]
  "road": choices=[["도로 그리기","road"],["건물 선택","select"]]

  _:
   pass
 if key=="build" and developer_tools_enabled():choices.append(["건물 성장","upgrade"])
 for choice in choices:
  if SERVICE_TOOLS.has(choice[1]):
   var service_entries: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/catalog.json")).facilities
   var matches: Array=service_entries.filter(func(entry):return entry.id==SERVICE_TOOLS[choice[1]])
   if not matches.is_empty():
    var service_button:=make_asset_button(matches[0],activate_tool.bind(str(choice[1])))
    service_button.name="Tool_"+str(choice[1])
    drawer_box.add_child(service_button)
    continue
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
  image.texture=icon(tool_icons.get(choice[1],key))
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.custom_minimum_size=Vector2(38,38)
  image.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(image)
  var caption := label(choice[0],18)
  button.custom_minimum_size.x=maxf(112,caption.get_minimum_size().x+16)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
  content.add_child(caption)
  var tool: String=choice[1]
  if key in ["health","education"]:
   button.tooltip_text=choice[0]+" · 애셋 보기"
  button.pressed.connect(activate_tool.bind(tool))
  drawer_box.add_child(button)
 if key=="road":
  var lanes := OptionButton.new()
  lanes.name="RoadLanes"
  lanes.add_item("왕복 2차로")
  lanes.add_item("왕복 4차로")
  lanes.select(0 if road_lanes==2 else 1)
  lanes.item_selected.connect(func(index):road_lanes=2 if index==0 else 4;queue_redraw())
  drawer_box.add_child(lanes)
 for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/registered_30.json")).assets:
  if entry.ui_category!=key:continue
  var registered_button:=make_asset_button(entry,select_public_asset.bind(str(entry.id)))
  registered_button.name="Registered_"+str(entry.id)
  registered_button.set_meta("registered_asset_id",str(entry.id))
  drawer_box.add_child(registered_button)
 if key=="park":
  for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities:
   var facility_button:=make_asset_button(entry,select_public_asset.bind(str(entry.id)))
   facility_button.name="Facility_"+str(entry.id)
   drawer_box.add_child(facility_button)
 for slot in service_slots():
  if slot.category!=key:continue
  var entry:=slot_asset(slot)
  var slot_button: Button
  if not entry.is_empty():slot_button=make_asset_button(entry,select_public_asset.bind(str(entry.id)))
  else:
   slot_button=Button.new()
   slot_button.text=slot.name
   slot_button.disabled=true
   slot_button.custom_minimum_size=Vector2(128,96)
  slot_button.name="Slot_"+slot.id.replace(".","_")
  slot_button.set_meta("slot_id",slot.id)
  drawer_box.add_child(slot_button)
 mode="road" if key=="road" else ("power_wire" if key=="power" else ("water_pipe" if key=="water" else "select"))
 update_road_modes()
 bulldozer.set_pressed_no_signal(false)
 demolition_hover.clear()
 var close := Button.new()
 close.text="⌄"
 close.custom_minimum_size.x=42
 close.pressed.connect(func():drawer.hide();layout_bottom_hud())
 drawer_box.add_child(close)
 drawer.show()
 sync_utility_visibility()
 layout_bottom_hud()
 queue_redraw()

func show_zoning_tiles() -> bool:
 return chosen in ["build","road"] and mode!="demolish"

func toggle_demolition():
 hide_asset_info();clear_money_toast()
 if public_controller!=null:public_controller.cancel()
 cancel_zoning_drag()
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
 var available := Rect2(60,40,maxf(280,viewport_size.x-120),maxf(200,viewport_size.y-384))
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
 for record: Dictionary in city.public_facilities.lots:
  var rect:=Rect2()
  var first_point:=true
  for point in record.polygon:
   var projected:=Vector2((point.x-point.y)*tile.x,(point.x+point.y)*tile.y)
   rect=Rect2(projected,Vector2.ZERO) if first_point else rect.expand(projected)
   first_point=false
  var height: float=public_controller.asset(record.public_asset_id).height_m*tile.x/4*sqrt(1.5)
  rect.position.y-=height;rect.size.y+=height
  bounds=rect if first else bounds.merge(rect);first=false
 if first:
  bounds=Rect2(Vector2(-city.height*tile.x,0),Vector2((city.width+city.height)*tile.x,(city.width+city.height)*tile.y))
 map_zoom=minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y)
 origin=available.position+(available.size-bounds.size*map_zoom)/2-bounds.position*map_zoom
 layout_bottom_hud()
 queue_redraw()

func _process(delta: float):
 if dock==null: return
 bulldozer.set_pressed_no_signal(mode=="demolish")
 var simulated_delta := 0.0 if paused else delta*simulation_speed
 super._process(simulated_delta)
 hud.visible=not message.is_empty()
 info.visible=selected>=0 and not drawer.visible
 elapsed+=delta
 if capture_path!="" and elapsed>3 and not capture_pending:
  capture_pending=true
  capture.call_deferred()

func capture():
 await RenderingServer.frame_post_draw
 var state_file:=FileAccess.open(capture_path.trim_suffix(".png")+".state.json",FileAccess.WRITE)
 state_file.store_string(JSON.stringify({"tab":chosen,"drawer_visible":drawer.visible,"viewport":str(get_viewport_rect()),"dock":str(dock.get_global_rect()),"city_name":city.city_name,"funds":city.funds,"population":city.population.stats().population,"args":OS.get_cmdline_user_args()},"  ")+"\n")
 state_file.close()
 var error := get_viewport().get_texture().get_image().save_png(capture_path)
 get_tree().quit(0 if error==OK else 1)

func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  hide_asset_info();clear_money_toast()
  if public_controller!=null:public_controller.cancel()
  cancel_zoning_drag()
  if mode=="demolish": toggle_demolition()
  drawer.hide()

func asset_info_rows(id: String) -> Array[Dictionary]:return preload("res://core/asset_money_info.gd").rows(city,id)
func hide_asset_info():
 if asset_info!=null:asset_info.hide()
 hovered_card=null
func position_asset_info():
 if asset_info==null or hovered_card==null:return
 var card=hovered_card.get_ref()
 if not is_instance_valid(card) or not card.is_inside_tree():hide_asset_info();return
 var rect: Rect2=card.get_global_rect();var viewport_size:=get_viewport_rect().size
 asset_info.global_position=Vector2(clampf(rect.get_center().x-asset_info.size.x/2,8,viewport_size.x-asset_info.size.x-8),clampf(rect.position.y-asset_info.size.y-12,8,maxf(8,viewport_size.y-asset_info.size.y-8)))
func fit_asset_info():
 if asset_info==null or not asset_info.visible:return
 var minimum:=asset_info.get_combined_minimum_size()
 if asset_info.size!=minimum:asset_info.size=minimum
 position_asset_info()
func show_asset_info(card):
 if not is_instance_valid(card) or not card.is_inside_tree() or card.disabled:return
 if money_toast!=null and money_toast.visible:return
 hovered_card=weakref(card)
 if asset_info==null:
  asset_info=PanelContainer.new();asset_info.name="AssetMoneyInfo";asset_info.mouse_filter=Control.MOUSE_FILTER_IGNORE
  asset_info.custom_minimum_size.x=290;drawer.get_parent().add_child(asset_info)
  var skin:=style(Color("142b37"),Color("38515e"))
  skin.content_margin_left=10;skin.content_margin_right=10;skin.content_margin_top=10;skin.content_margin_bottom=10
  asset_info.add_theme_stylebox_override("panel",skin);asset_info.resized.connect(position_asset_info)
  asset_info.minimum_size_changed.connect(func():fit_asset_info.call_deferred())
 for child in asset_info.get_children():asset_info.remove_child(child);child.queue_free()
 var body:=VBoxContainer.new();body.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_theme_constant_override("separation",6);asset_info.add_child(body)
 var title:=label(card.get_meta("asset_name",""),20);title.add_theme_color_override("font_color",Color("edf4f5"));title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(title)
 var picture:=TextureRect.new();picture.texture=load(card.get_meta("source_preview",""));picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.custom_minimum_size=Vector2(270,90 if get_viewport_rect().size.y<760 else 150);body.add_child(picture)
 var rows:=asset_info_rows(card.get_meta("thumbnail_asset_id",""));asset_info.set_meta("rows",rows)
 var table:=GridContainer.new();table.name="AssetInfoTable";table.columns=3;table.mouse_filter=Control.MOUSE_FILTER_IGNORE
 table.add_theme_constant_override("h_separation",8);table.add_theme_constant_override("v_separation",6);body.add_child(table)

 for data in rows:
  var key:=label(data.label,18);key.add_theme_color_override("font_color",Color("edf4f5"));key.size_flags_horizontal=Control.SIZE_EXPAND_FILL;key.mouse_filter=Control.MOUSE_FILTER_IGNORE;table.add_child(key)
  var value:=label(data.number,18);value.name="InfoNumber_"+data.id;value.add_theme_color_override("font_color",Color("edf4f5"))
  value.custom_minimum_size.x=100;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.size_flags_horizontal=Control.SIZE_EXPAND_FILL;value.mouse_filter=Control.MOUSE_FILTER_IGNORE;table.add_child(value)
  var unit:=CurrencyLabel.new();unit.name="InfoUnit_"+data.id;unit.text=data.unit;unit.add_theme_font_size_override("font_size",18);unit.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;table.add_child(unit)
  key.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;unit.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 asset_info.size=asset_info.get_combined_minimum_size();position_asset_info();asset_info.show();fit_asset_info.call_deferred()

func update_asset_affordability():
 if drawer_box==null:return
 for card in drawer_box.get_children():
  var id: String=str(card.get_meta("thumbnail_asset_id",""))
  if card is ThumbnailButton and city.public_facilities.entries.has(id):card.set_unaffordable(city.public_facilities.price(id)>city.utility_balance())
func clear_money_toast():
 if money_toast!=null:money_toast.hide()
 if money_toast_timer!=null:money_toast_timer.stop()
 if rejected_card!=null:
  var previous=rejected_card.get_ref()
  if is_instance_valid(previous):previous.set_rejected(false)
 rejected_card=null
func show_money_toast(card):
 hide_asset_info()
 clear_money_toast()
 if money_toast==null:
  money_toast=PanelContainer.new();money_toast.name="InsufficientFundsBubble";money_toast.mouse_filter=Control.MOUSE_FILTER_IGNORE
  drawer.get_parent().add_child(money_toast)
  money_toast.add_theme_stylebox_override("panel",style(Color("142b37"),Color("ff5a5a")))
  var text_value:=label("잔고가 부족합니다.",18);text_value.add_theme_color_override("font_color",Color("edf4f5"));text_value.mouse_filter=Control.MOUSE_FILTER_IGNORE;money_toast.add_child(text_value)
  money_toast.set_meta("message",text_value.text)
  money_toast.draw.connect(func():
   var x: float=money_toast.get_meta("tail_x",money_toast.size.x/2);var y: float=money_toast.size.y
   money_toast.draw_colored_polygon(PackedVector2Array([Vector2(x-7,y-1),Vector2(x+7,y-1),Vector2(x,y+8)]),Color("ff5a5a")))
  money_toast_timer=Timer.new();money_toast_timer.one_shot=true;money_toast_timer.wait_time=2;money_toast_timer.ignore_time_scale=true
  money_toast_timer.process_mode=Node.PROCESS_MODE_ALWAYS
  add_child(money_toast_timer);money_toast_timer.timeout.connect(clear_money_toast)
 rejected_card=weakref(card);card.set_rejected(true)
 money_toast.size=money_toast.get_combined_minimum_size()
 position_money_toast()
 money_toast.show();money_toast_timer.start()

func position_money_toast():
 if money_toast==null or rejected_card==null:return
 var card=rejected_card.get_ref()
 if not is_instance_valid(card) or not card.is_inside_tree():clear_money_toast();return
 var rect: Rect2=card.get_global_rect();var viewport_size:=get_viewport_rect().size
 money_toast.global_position=Vector2(clampf(rect.get_center().x-money_toast.size.x/2,8,viewport_size.x-money_toast.size.x-8),maxf(8,rect.position.y-money_toast.size.y-10))
 money_toast.set_meta("tail_x",clampf(rect.get_center().x-money_toast.global_position.x,10,money_toast.size.x-10));money_toast.queue_redraw()

func make_asset_button(entry: Dictionary,action: Callable) -> Button:
 if thumbnail_manifest.is_empty():thumbnail_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/thumbnails/manifest.json"))
 var item=ThumbnailButton.new()
 var preview_path: String=thumbnail_manifest.get(str(entry.id),{}).get("thumbnail",str(entry.preview))
 item.set_asset(entry,preview_path)
 item.tooltip_text="" # Approved image/CSV bubble below replaces the old native text tooltip.
 item.mouse_entered.connect(show_asset_info.bind(item))
 item.mouse_exited.connect(hide_asset_info)
 if city.public_facilities.entries.has(str(entry.id)):
  item.set_unaffordable(city.public_facilities.price(str(entry.id))>city.utility_balance())
 item.pressed.connect(func():
  if not item.disabled:action.call())
 return item

func select_public_asset(id: String) -> bool:
 if city.public_facilities.entries.has(id):
  if city.public_facilities.price(id)>city.utility_balance():
   public_controller.cancel();road_drawer.cancel();mode="select"
   for card in drawer_box.get_children():
    if card is Button and card.get_meta("thumbnail_asset_id","")==id:show_money_toast(card);break
   return false
  clear_money_toast()
  return public_controller.begin(id)
 return open_registered_asset(id) # Hydro stays inspection-only.

func open_registered_asset(id: String) -> bool:
 # Inspection only: never dispatch a placement tool or touch the simulation.
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/registered_30.json"))
 if not data is Dictionary:return false
 for registered: Dictionary in data.get("assets",[]):
  if registered.id!=id:continue
  if not FileAccess.file_exists(str(registered.spec)):return false
  var entry=JSON.parse_string(FileAccess.get_file_as_string(str(registered.spec)))
  if not entry is Dictionary or entry.get("status","")!="asset_preview_only" or entry.get("simulation_enabled",true):return false
  if not ResourceLoader.exists(str(entry.get("model",""))):return false
  var preview=preload("res://service_asset_preview.gd").new()
  preview.name="ServiceAssetPreview"
  preview.set_meta("asset_id",id)
  add_child(preview)
  preview.show_asset(entry)
  return true
 return false

func open_facility_asset(id: String):
 for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json")).facilities:
  if entry.id==id:
   var preview=preload("res://service_asset_preview.gd").new()
   preview.name="ServiceAssetPreview"
   add_child(preview)
   preview.show_asset(entry)
   return

func service_slots() -> Array:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/pending_slots.json"))
 return data.get("slots",[]) if data is Dictionary else []

func slot_asset(slot: Dictionary) -> Dictionary:
 # A ready slot points at a real, compatible service spec. Never invent geometry or size.
 if slot.get("status","")!="ready": return {}
 var path: String=slot.get("asset","")
 if path.is_empty() or not FileAccess.file_exists(path): return {}
 var entry=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not entry is Dictionary: return {}
 for field in ["name","model","width","depth","height_m"]:
  if not entry.has(field): return {}
 if not ResourceLoader.exists(str(entry.model)): return {}
 return entry

func open_service_slot(id: String) -> bool:
 for slot in service_slots():
  if slot.id!=id: continue
  var entry := slot_asset(slot)
  if entry.is_empty(): return false
  var preview=preload("res://service_asset_preview.gd").new()
  preview.name="ServiceAssetPreview"
  add_child(preview)
  preview.show_asset(entry)
  return true
 return false

func layout_bottom_hud():
 if dock==null: return
 var narrow:=get_viewport_rect().size.x<1280
 money.add_theme_font_size_override("font_size",26 if narrow else 34)
 date_label.add_theme_font_size_override("font_size",18 if narrow else 24)
 happiness_label.add_theme_font_size_override("font_size",22 if narrow else 28)
 balance_label.add_theme_font_size_override("font_size",18 if narrow else 24)
 status_left.add_theme_constant_override("separation",2 if narrow else 12)
 money.get_parent().add_theme_constant_override("separation",12 if narrow else 18)
 for bar in demand_bars:bar.custom_minimum_size=Vector2(16 if narrow else 22,48 if narrow else 64)
 var width_value := minf(maxf(410,240+145*(drawer_box.get_child_count()-2)),get_viewport_rect().size.x-32)
 drawer.offset_left=-width_value/2
 drawer.offset_right=width_value/2
 if road_modes!=null:
  var margin:=344 if drawer.visible and (get_viewport_rect().size.x-width_value)/2<188 else 206
  road_modes.offset_left=16;road_modes.offset_right=172
  road_modes.offset_top=-margin-56;road_modes.offset_bottom=-margin
 if asset_info!=null and asset_info.visible and hovered_card!=null:
  var card=hovered_card.get_ref()
  if is_instance_valid(card):show_asset_info.call_deferred(card)
 position_money_toast.call_deferred()
 queue_redraw()

func activate_tool(tool: String):
 hide_asset_info();clear_money_toast()
 if road_drawer!=null:road_drawer.cancel()
 if public_controller!=null:public_controller.cancel()
 cancel_zoning_drag()
 if SERVICE_TOOLS.has(tool):
  select_public_asset(SERVICE_TOOLS[tool])
  return
 if tool=="water_settings":
  open_utility_settings("water")
  return
 match tool:
  "reset":
   stop_traffic()
   city=Model.new(int(map_settings.width_cells),int(map_settings.height_cells),int(map_settings.seed))
   selected=-1
   message=""
  "upgrade":
   var result: Dictionary=city.upgrade_chain(selected)
   message="성장 %d개" % result.events.size() if result.ok else result.reason

  "traffic": toggle_traffic()
  _:
   zone="" if tool=="build_erase" else ("commercial" if tool=="build_commercial" else ("industrial" if tool=="build_industrial" else "residential"))
   mode="build" if tool.begins_with("build") else tool
 refresh()

func refresh():
 super.refresh()
 if money==null: return
 bind_status_events()
 refresh_status()
 money.tooltip_text=message

func open_utility_settings(kind: String):
 if utility_popup.visible: utility_popup.hide()
 var overlay=power_overlay if kind=="power" else water_overlay
 utility_owner=overlay.panel
 utility_content=utility_owner.get_child(0)
 var close: Button=utility_content.get_child(0).get_child(utility_content.get_child(0).get_child_count()-1)
 if close.pressed.is_connected(overlay.toggle): close.pressed.disconnect(overlay.toggle)
 if not close.pressed.is_connected(utility_popup.hide): close.pressed.connect(utility_popup.hide)
 utility_content.reparent(utility_popup)
 utility_popup.popup_centered(Vector2i(mini(560,int(get_viewport_rect().size.x)-32),mini(540,int(get_viewport_rect().size.y)-64)))

func restore_utility_controls():
 if is_instance_valid(utility_content) and is_instance_valid(utility_owner):
  utility_content.reparent(utility_owner)
  utility_owner.hide()
 utility_content=null
 utility_owner=null
