extends ScrollContainer
## Reusable card palette: native draggable AUTO bar; wheel belongs only to hovered palette.
var content:=HBoxContainer.new()
static func flat(color:String,radius:int=6) -> StyleBoxFlat:
 var result:=StyleBoxFlat.new();result.bg_color=Color(color)
 result.corner_radius_top_left=radius;result.corner_radius_top_right=radius;result.corner_radius_bottom_left=radius;result.corner_radius_bottom_right=radius
 return result
func _init():
 horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 size_flags_horizontal=Control.SIZE_EXPAND_FILL;custom_minimum_size=Vector2(0,102);follow_focus=true;mouse_force_pass_scroll_events=false
 content.name="Cards";content.add_theme_constant_override("separation",8);content.size_flags_vertical=Control.SIZE_SHRINK_CENTER;content.mouse_filter=Control.MOUSE_FILTER_PASS;add_child(content)
 var bar:=get_h_scroll_bar();bar.custom_minimum_size.y=14;bar.focus_mode=Control.FOCUS_ALL
 bar.add_theme_stylebox_override("scroll",flat("38515e"))
 for state in ["grabber","grabber_highlight","grabber_pressed"]:bar.add_theme_stylebox_override(state,flat("36b7ff"))
func _input(event:InputEvent):
 if not is_visible_in_tree() or not event is InputEventMouseButton or not event.pressed:return
 if event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] or not get_global_rect().has_point(event.position):return
 var bar:=get_h_scroll_bar();var direction:=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
 scroll_horizontal=clampi(scroll_horizontal+direction*104,0,maxi(0,ceili(bar.max_value-bar.page)))
 get_viewport().set_input_as_handled()
