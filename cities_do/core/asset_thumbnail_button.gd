extends Button
## One physical PNG-based C-card, inspection-only; original art stays untouched.
var picture: TextureRect
var caption: Label
var unaffordable:=false
var normal_borders: Dictionary={}
func set_asset(entry: Dictionary,thumbnail_path: String):
 custom_minimum_size=Vector2(128,96)
 set_meta("thumbnail_asset_id",str(entry.id))
 set_meta("asset_name",str(entry.name))
 set_meta("source_preview",str(entry.preview))
 tooltip_text=str(entry.name)+" · 애셋 보기"
 picture=TextureRect.new()
 picture.name="AssetThumbnail"
 picture.texture=load(thumbnail_path)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(picture)
 picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 picture.offset_left=2;picture.offset_right=-2
 picture.offset_top=2;picture.offset_bottom=-2
 var band:=Panel.new()
 band.name="NameBand"
 band.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(band)
 band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 band.offset_top=-30;band.offset_bottom=-2
 band.offset_left=2;band.offset_right=-2
 var shade:=StyleBoxFlat.new()
 shade.bg_color=Color(.025,.065,.09,.85)
 shade.corner_radius_bottom_left=6;shade.corner_radius_bottom_right=6
 band.add_theme_stylebox_override("panel",shade)
 caption=Label.new()
 caption.name="AssetName"
 caption.text=entry.name
 caption.add_theme_font_size_override("font_size",18)
 caption.add_theme_color_override("font_color",Color.WHITE)
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 caption.clip_text=true
 caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 band.add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 caption.offset_left=5;caption.offset_right=-5
 for state in ["normal","hover","pressed","disabled"]:
  var outline:=StyleBoxFlat.new()
  outline.bg_color=Color("152d3b")
  outline.border_color=Color("39b7ff") if state in ["hover","pressed"] else Color("38515e")
  outline.set_border_width_all(2)
  outline.set_corner_radius_all(8)
  normal_borders[state]=outline.border_color
  add_theme_stylebox_override(state,outline)
 var focus_overlay:=Control.new()
 focus_overlay.name="FocusOverlay"
 focus_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(focus_overlay)
 focus_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 focus_overlay.draw.connect(func():
  if has_focus():focus_overlay.draw_style_box(get_theme_stylebox("focus"),Rect2(Vector2.ZERO,size)))
 focus_entered.connect(focus_overlay.queue_redraw)
 focus_exited.connect(focus_overlay.queue_redraw)
func set_unaffordable(value: bool):
 if value==unaffordable and has_meta("unaffordable"):return
 unaffordable=value;set_meta("unaffordable",value);queue_redraw()
func set_rejected(active: bool):
 for state in normal_borders:
  var outline: StyleBoxFlat=get_theme_stylebox(state).duplicate()
  outline.border_color=Color("ff5a5a") if active else normal_borders[state]
  add_theme_stylebox_override(state,outline)
 queue_redraw()
func _notification(what: int):
 if what==NOTIFICATION_DRAW and is_instance_valid(picture):
  picture.modulate=Color(.45,.45,.45,.7) if disabled or unaffordable else Color.WHITE
  caption.modulate=Color(.65,.65,.65,1) if disabled or unaffordable else Color.WHITE
