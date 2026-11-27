extends PanelContainer
## Approved B only: cursor-side bubble, yellow tint, corner count and two actions.
func setup(drawer,endpoint:Vector2,count:int):
 name="RoadDemolitionWarning";z_index=100
 var box:=StyleBoxFlat.new();box.bg_color=Color("142b37");box.border_color=Color("e6c442");box.set_border_width_all(2);box.set_corner_radius_all(8)
 box.content_margin_left=18;box.content_margin_right=18;box.content_margin_top=18;box.content_margin_bottom=14
 add_theme_stylebox_override("panel",box)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
 var title:=Label.new();title.text="⚠ 이미 지어진 건물이 파괴됩니다";title.add_theme_font_size_override("font_size",20);column.add_child(title)
 var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_END;row.add_theme_constant_override("separation",10);column.add_child(row)
 for spec in [["Confirm","짓기"],["Cancel","취소"]]:
  var button:=Button.new();button.name=spec[0];button.text=spec[1];button.custom_minimum_size=Vector2(104,42);button.add_theme_font_size_override("font_size",20)
  var style:=StyleBoxFlat.new();style.bg_color=Color("36b7ff") if spec[0]=="Confirm" else Color("38515e");style.set_corner_radius_all(4);button.add_theme_stylebox_override("normal",style)
  row.add_child(button)
  if spec[0]=="Confirm":button.pressed.connect(drawer.confirm_pending)
  else:button.pressed.connect(drawer.cancel)
 var badge:=Label.new();badge.name="DemolitionCount";badge.text=str(count);badge.add_theme_font_size_override("font_size",20);badge.add_theme_color_override("font_color",Color("142b37"))
 var badge_style:=StyleBoxFlat.new();badge_style.bg_color=Color("e6c442");badge_style.set_corner_radius_all(14);badge_style.content_margin_left=12;badge_style.content_margin_right=12
 badge.add_theme_stylebox_override("normal",badge_style);add_child(badge)
 # A top-level badge remains outside container layout, at the bubble's upper-right corner.
 badge.set_as_top_level(true)
 position=endpoint+Vector2(28,-32)
 fit.call_deferred(endpoint,badge)
func fit(endpoint:Vector2,badge:Label):
 size=get_combined_minimum_size()
 var viewport:=get_viewport_rect().size
 position.x=endpoint.x+28 if endpoint.x+28+size.x<viewport.x-12 else endpoint.x-size.x-28
 position.x=clampf(position.x,12,maxf(12,viewport.x-size.x-12));position.y=clampf(endpoint.y-32,24,maxf(24,viewport.y-size.y-220))
 badge.position=position+Vector2(size.x-44,-22)
