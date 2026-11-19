extends Control
## Edit warning (user rule 2026-11-19, ASSET_REQUEST_RAIL_PARK_KO.md 5절 12번): a centred modal with one
## line and two buttons, styled like the economy window. 확인 (accent) applies the pending edit, 취소
## drops it. Enter confirms, Esc cancels; every other key is swallowed and the full-screen shade
## takes all clicks while it is open.
const TEXT:="수정사항이 있는 모든 열차가 초기화됩니다!"
const BACKGROUND:=Color("142b37")
const BORDER:=Color("38515e")
const FOREGROUND:=Color("edf4f5")
const ACCENT:=Color("36b7ff")
var on_confirm:Callable
var on_cancel:Callable
var panel:PanelContainer
var message:Label
var confirm_button:Button
var cancel_button:Button
func _init():
	name="RouteResetWarning";mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.name="Shade";shade.color=Color(0,0,0,.45);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new();center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel=PanelContainer.new();panel.name="Panel";center.add_child(panel)
	var box:=StyleBoxFlat.new();box.bg_color=BACKGROUND;box.border_color=BORDER;box.set_border_width_all(1);box.set_corner_radius_all(10)
	box.content_margin_left=32;box.content_margin_right=32;box.content_margin_top=26;box.content_margin_bottom=22
	panel.add_theme_stylebox_override("panel",box)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",22);panel.add_child(column)
	message=Label.new();message.name="Message";message.text=TEXT;message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size",22);message.add_theme_color_override("font_color",FOREGROUND)
	column.add_child(message)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",14)
	column.add_child(row)
	confirm_button=button(row,"Confirm","확인",ACCENT,BACKGROUND)
	cancel_button=button(row,"Cancel","취소",BORDER,FOREGROUND)
	confirm_button.pressed.connect(confirm)
	cancel_button.pressed.connect(cancel)
	hide()
func button(row:HBoxContainer,id:String,caption:String,fill:Color,ink:Color)->Button:
	var b:=Button.new();b.name=id;b.text=caption;b.custom_minimum_size=Vector2(128,46);b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",20)
	for state:String in ["normal","hover","pressed","focus","disabled"]:
		var s:=StyleBoxFlat.new();s.bg_color=fill.lightened(.12) if state=="hover" else fill;s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state,s)
	for state:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,ink)
	row.add_child(b)
	return b
func open(apply:Callable,cancelled:Callable=Callable()):
	on_confirm=apply;on_cancel=cancelled
	show()
func confirm():
	if not visible:return
	var action:=on_confirm
	hide();on_confirm=Callable();on_cancel=Callable()
	if action.is_valid():action.call()
func cancel():
	if not visible:return
	var action:=on_cancel
	hide();on_confirm=Callable();on_cancel=Callable()
	if action.is_valid():action.call()
func _input(event:InputEvent):
	if not visible or not event is InputEventKey:return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:return
	if event.keycode in [KEY_ENTER,KEY_KP_ENTER]:confirm()
	elif event.keycode==KEY_ESCAPE:cancel()
