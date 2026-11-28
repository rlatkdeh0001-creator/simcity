extends VBoxContainer
## Approved C: three mode buttons, then - / height / +.
const Height=preload("res://core/road_height.gd")
var owner_view
var value_label:Label
var minus:Button
var plus:Button
var mode_buttons:Dictionary={}
## E3a/E3b: the same control drives the rail tool (transit_view), including the -10m underground button.
var rail:=false
func target():return owner_view.transit_view if rail else owner_view.road_drawer
func setup(view):
 owner_view=view;name="RailHeightControls" if rail else "RoadHeightControls";custom_minimum_size=Vector2(276,84)
 add_theme_constant_override("separation",4)
 var row:=HBoxContainer.new();add_child(row)
 for spec in [["Underground","지하",-10],["Ground","지상",0],["Elevated","고가",10]]:
  var button:=Button.new();button.name=spec[0];button.text=spec[1];button.custom_minimum_size=Vector2(88,38)
  button.toggle_mode=true;button.add_theme_font_size_override("font_size",20)
  button.pressed.connect(select.bind(spec[2]));row.add_child(button);mode_buttons[spec[2]]=button
 var adjust:=HBoxContainer.new();add_child(adjust)
 minus=Button.new();minus.name="HeightMinus";minus.text="−";minus.custom_minimum_size=Vector2(52,36);adjust.add_child(minus)
 value_label=Label.new();value_label.name="HeightValue";value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;value_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;value_label.add_theme_font_size_override("font_size",22);adjust.add_child(value_label)
 plus=Button.new();plus.name="HeightPlus";plus.text="+";plus.custom_minimum_size=Vector2(52,36);adjust.add_child(plus)
 minus.pressed.connect(change.bind(-5));plus.pressed.connect(change.bind(5));synchronize()
func select(value:int):
 if mode_buttons[value].disabled:return
 target().set_height(value);synchronize()
func shallowest_underground_height()->float:
 return -5.0 if rail else Height.SHALLOWEST_ROAD_TUNNEL_M
func change(delta:int):
 if not rail and target().center_tool:return
 var height:float=target().target_height_m+delta
 # -/+ stay inside the selected layer, unlike Page Up/Down.
 target().set_height(minf(shallowest_underground_height(),height) if target().target_height_m<0 else maxf(5,height));synchronize()
func synchronize():
 var height:float=target().target_height_m
 var ground_only:bool=not rail and target().travel_dir!=0
 var center:bool=not rail and target().center_tool
 value_label.text="0 m" if height==0 else ("+%d m"%height if height>0 else "−%d m"%absf(height))
 minus.disabled=center or height==0;plus.disabled=center or height==0 or (not rail and height==Height.SHALLOWEST_ROAD_TUNNEL_M)
 var dim:=Color(1,1,1,.55)
 minus.self_modulate=dim if center else Color.WHITE;plus.self_modulate=minus.self_modulate
 for key in mode_buttons:
  var active:bool=(key==0 and height==0) or (key==10 and height>0) or (key<0 and height<0)
  var button:Button=mode_buttons[key];button.disabled=ground_only and key!=0;button.set_pressed_no_signal(active)
  var box:=StyleBoxFlat.new();box.bg_color=Color("36b7ff") if active else Color("142b37");box.set_corner_radius_all(4)
  box.border_width_bottom=3 if active else 0;box.border_color=Color("edf4f5")
  button.add_theme_stylebox_override("normal",box);button.add_theme_stylebox_override("pressed",box)
  button.add_theme_color_override("font_color",Color("142b37") if active else Color("edf4f5"))
