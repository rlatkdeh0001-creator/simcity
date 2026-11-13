extends Node2D
const Flow = preload("res://core/water_flow.gd")
var view
var tab_open := false
var show_flow := true
var show_ranges := true
var visual_paused := false
var visual_time := 0.0
var drawing := false
var stroke := PackedVector2Array()
var panel: PanelContainer
var summary: Label
var instruction: Label
var output: SpinBox
var selected_facility := -1

func setup(owner_view, layer: CanvasLayer):
 view=owner_view
 panel=PanelContainer.new()
 panel.name="WaterPanel"
 panel.custom_minimum_size.x=320
 layer.add_child(panel)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 var box := VBoxContainer.new()
 box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation",8)
 scroll.add_child(box)
 var title := Label.new()
 title.text="상하수도 · 함께 설치"
 title.add_theme_font_size_override("font_size",20)
 box.add_child(title)
 for pair in [["취수장 배치","supply"],["하수처리장 배치","treatment"],["상하수관 함께 · 드래그","pipe"]]:
  var button := Button.new()
  button.name="Water_"+pair[1]
  button.text=pair[0]
  var action: String=pair[1]
  button.pressed.connect(func():
   drawing=false
   stroke.clear()
   view.mode="water_"+action
   instruction.text=button.text
   queue_redraw())
  box.add_child(button)
 var capacity_label := Label.new()
 capacity_label.text="시설 용량 (m³/일)"
 box.add_child(capacity_label)
 output=SpinBox.new()
 output.name="WaterFacilityCapacity"
 output.min_value=0
 output.max_value=1000000
 output.step=10
 output.value=1000
 box.add_child(output)
 var apply := Button.new()
 apply.text="선택 시설 용량 적용"
 apply.pressed.connect(func():
  view.city.water.set_capacity(selected_facility,output.value)
  refresh())
 box.add_child(apply)
 for item in [["공급 범위 표시","ranges"],["푸른·갈색 흐름 원 표시","flow"],["흐름 표시만 일시정지","pause"]]:
  var check := CheckButton.new()
  check.text=item[0]
  var action: String=item[1]
  check.button_pressed=action!="pause"
  check.toggled.connect(func(value):
   if action=="ranges": show_ranges=value
   elif action=="flow": show_flow=value
   else: visual_paused=value
   queue_redraw())
  box.add_child(check)
 instruction=Label.new()
 instruction.text=""
 box.add_child(instruction)
 summary=preload("res://core/currency_label.gd").new()
 summary.name="WaterSummary"
 box.add_child(summary)
 var close := Button.new()
 close.text="상하수도 닫기"
 close.pressed.connect(toggle)
 box.add_child(close)
 panel.hide()
 view.get_viewport().size_changed.connect(position_panel)
 position_panel()

func position_panel():
 panel.position=Vector2(maxf(350,view.get_viewport_rect().size.x-340),18)
 panel.size=Vector2(320,maxf(160,view.get_viewport_rect().size.y-36))

func toggle():
 tab_open=not tab_open
 if tab_open and view.power_overlay.tab_open: view.power_overlay.toggle()
 panel.visible=tab_open
 drawing=false
 stroke.clear()
 view.mode="water_pipe" if tab_open else "select"
 refresh()

func refresh():
 view.water_snapshot=view.city.water_state()
 view.refresh()
 update_state(0)
 queue_redraw()

func update_state(delta: float):
 if not visual_paused: visual_time+=delta
 if tab_open:
  var state: Dictionary=view.water_snapshot
  summary.text="상수 수요 %.1f / 공급 %.1f m³/일\n상수 수입 %.1f / 잉여 수출 %.1f\n하수 발생 %.1f / 내부 처리 %.1f\n하수 외부 위탁 %.1f / 미처리 %.1f\n누적 급수 %.4f / 내부 처리 %.4f m³" % [state.get("demand_m3_day",0),state.get("water_supplied_m3_day",0),state.get("water_import_m3_day",0),state.get("water_export_m3_day",0),state.get("sewage_generated_m3_day",0),state.get("sewage_treated_m3_day",0),state.get("sewage_export_m3_day",0),state.get("unhandled_sewage_m3_day",0),view.city.water.supplied_m3,view.city.water.treated_m3]
  summary.text+="\n외부 요금 %s/일\n수출 수익 %s/일\n수도 미정산 잔액 %s" % [view.city.Economy.format_fraction(state.get("expense_doth_day",0),4),view.city.Economy.format_fraction(state.get("revenue_doth_day",0),4),view.city.Economy.format_fraction(view.city.water.pending_doth,6,true)]
 if tab_open or not view.city.water.facilities.is_empty(): queue_redraw()

func finish_capture(event):
 if drawing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  finish_pipe.call_deferred()

func handle_input(event) -> bool:
 if not tab_open: return false
 if event is InputEventMouseMotion and drawing:
  var p: Vector2=view.world(event.position)*4.0
  if view.city.water.geometry.valid(p) and (stroke.is_empty() or stroke[-1].distance_to(p)>.8): stroke.append(p)
  queue_redraw()
  return true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if not event.pressed:
   if drawing: finish_pipe()
   return false
  var p: Vector2=view.world(event.position)
  match view.mode:
   "water_pipe":
    var anchor: Dictionary=view.city.water.geometry.snap(p*4)
    if anchor.is_empty(): instruction.text="시설·이웃·기존 접속점에서 시작하세요"
    else:
     drawing=true
     stroke=PackedVector2Array([anchor.position])
     instruction.text=""
   "water_supply","water_treatment":
    var kind := "water" if view.mode=="water_supply" else "sewage"
    var result: Dictionary=view.city.add_water_facility(p,kind,output.value)
    instruction.text=result.reason
    if result.ok: selected_facility=result.id
    refresh()
   "water_erase_pipe":
    var nearest := 6.0
    var selected := -1
    for wire in view.city.water.geometry.wires:
     for i in range(wire.points.size()-1):
      var d: float=(p*4).distance_to(Geometry2D.get_closest_point_to_segment(p*4,wire.points[i],wire.points[i+1]))
      if d<nearest:
       nearest=d
       selected=wire.id
    if selected!=-1: view.city.water.remove_pipe(selected)
    refresh()
   "water_erase_facility","water_select":
    var found := -1
    for plant in view.city.water.facilities:
     if plant.position.distance_to(p*4)<10:
      found=plant.id
      output.value=plant.capacity_m3_day
    if view.mode=="water_erase_facility" and found!=-1: view.city.water.remove_facility(found)
    else: selected_facility=found
    refresh()
   _:
    return false
  return true
 return false

func finish_pipe():
 if not drawing: return
 drawing=false
 var result: Dictionary=view.city.water.add_pipe(stroke)
 instruction.text="상수관·하수관 함께 건설 완료" if result.ok else result.reason
 stroke.clear()
 refresh()

func projected(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
 var path := PackedVector2Array()
 for point in points: path.append(view.screen(point/4.0)+offset)
 return path

func _draw():
 if view==null: return
 var water_color := Color("35b8ff")
 var sewage_color := Color("aa6737")
 var grid=view.city.water.geometry
 for facility in view.city.water.facilities:
  if facility.has("public_lot_id"):continue
  var p: Vector2=facility.position/4-Vector2.ONE
  var base: PackedVector2Array=view.polygon(p.x,p.y,2)
  var top: PackedVector2Array=view.polygon(p.x,p.y,2,20)
  var color: Color=water_color if facility.kind=="water" else sewage_color
  draw_colored_polygon(PackedVector2Array([base[1],base[2],top[2],top[1]]),color.darkened(.4))
  draw_colored_polygon(PackedVector2Array([base[2],base[3],top[3],top[2]]),color.darkened(.55))
  draw_colored_polygon(top,color.lightened(.2))
  var label := "취수장" if facility.kind=="water" else "하수처리장"
  draw_string(ThemeDB.fallback_font,view.screen(facility.position/4)-Vector2(20,30)*view.map_zoom,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
 if not tab_open: return
 grid.rebuild()
 if show_ranges:
  for node in grid.nodes:
   if not node.service or grid.adjacency[node.id].is_empty(): continue
   var ring := PackedVector2Array()
   for i in range(65):
    var a := float(i)/64*TAU
    ring.append(view.screen((node.position+Vector2(cos(a),sin(a))*64)/4.0))
   draw_polyline(ring,Color(.18,.65,.9,.16),1,true)
 for pipe in grid.wires:
  for pair in [[water_color,Vector2(0,-4)],[sewage_color,Vector2(0,4)]]:
   var path := projected(pipe.points,pair[1])
   draw_polyline(path,Color("19323b"),7,true)
   draw_polyline(path,pair[0].darkened(.3),5,true)
   draw_polyline(path,pair[0],2,true)
 preload("res://core/boundary_links.gd").draw_links(self,view,preload("res://core/boundary_links.gd").utility_links(grid,tab_open))
 for node in grid.nodes:
  if node.service and not grid.adjacency[node.id].is_empty():
   for pair in [[water_color,Vector2(0,-4)],[sewage_color,Vector2(0,4)]]:
    var p: Vector2=view.screen(node.position/4)+pair[1]
    draw_circle(p,2.8,pair[0])
    draw_arc(p,2.8,0,TAU,16,Color(1,1,1,.7),1,true)
 for anchor in view.city.water.facilities+grid.ports:
  var p: Vector2=view.screen(anchor.position/4)
  draw_circle(p+Vector2(0,-4),5,water_color)
  draw_circle(p+Vector2(0,4),5,sewage_color)

 for building in view.city.buildings:
  var service: Dictionary=view.water_snapshot.get("consumers",{}).get(building.id,{})
  var p: Vector2=view.screen(Vector2(building.x+building.size/2.0,building.y+building.size/2.0))-Vector2(0,15)*view.map_zoom
  draw_circle(p+Vector2(-4,0),3,water_color if service.get("has_water",false) else Color("d75454"))
  draw_circle(p+Vector2(4,0),3,sewage_color if service.get("has_sewage",false) else Color("d75454"))
 if show_flow:
  for marker in Flow.markers(view.water_snapshot,visual_time):
   var color: Color=water_color if marker.kind=="water" else sewage_color
   var offset := Vector2(0,-4) if marker.kind=="water" else Vector2(0,4)
   var center: Vector2=view.screen(marker.position/4)+offset
   color.a=marker.alpha
   draw_colored_polygon(Flow.contour(center,5,marker.pulse),color)
   draw_circle(center+Vector2(-1,-1),1.2,Color(1,1,1,.65*marker.alpha))
 if stroke.size()>1:
  draw_polyline(projected(stroke,Vector2(0,-4)),water_color,3,true)
  draw_polyline(projected(stroke,Vector2(0,4)),sewage_color,3,true)
