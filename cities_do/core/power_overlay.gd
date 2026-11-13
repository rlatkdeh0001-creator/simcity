extends Node2D
const Flow = preload("res://core/power_flow.gd")
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
var load_input: SpinBox
var selected_plant := -1

func setup(owner_view, layer: CanvasLayer):
 view=owner_view
 panel=PanelContainer.new()
 panel.name="PowerPanel"
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
 title.text="전력"
 title.add_theme_font_size_override("font_size",20)
 box.add_child(title)
 for pair in [["발전소 배치","plant"],["지중 전력선 · 드래그","wire"],["발전소 선택","select"]]:
  var button := Button.new()
  button.name="Power_"+pair[1]
  button.text=pair[0]
  var action: String=pair[1]
  button.pressed.connect(func():
   drawing=false
   stroke.clear()
   view.mode="power_"+action
   instruction.text=button.text
   queue_redraw())
  box.add_child(button)
 var power_label := Label.new()
 power_label.text="발전 출력 (kW)"
 box.add_child(power_label)
 output=SpinBox.new()
 output.name="GeneratorOutput"
 output.min_value=0
 output.max_value=1000000
 output.step=10
 output.value=300
 box.add_child(output)
 var apply := Button.new()
 apply.text="선택 발전소 출력 적용"
 apply.pressed.connect(func():
  view.city.power.set_output(selected_plant,output.value)
  refresh())
 box.add_child(apply)
 var load_label := Label.new()
 load_label.text="건물 전력 수요 (kW)"
 box.add_child(load_label)
 load_input=SpinBox.new()
 load_input.min_value=0
 load_input.max_value=1000000
 load_input.value=50
 load_input.step=1
 box.add_child(load_input)
 var apply_load := Button.new()
 apply_load.text="선택 건물 부하 적용"
 apply_load.pressed.connect(func():
  var b: Dictionary=view.city.find_building(view.selected)
  if not b.is_empty(): b.power_demand_kw=load_input.value
  refresh())
 box.add_child(apply_load)
 for item in [["공급 범위 표시","ranges"],["하얀 흐름 원 표시","flow"],["흐름 표시만 일시정지","pause"]]:
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
 summary.name="PowerSummary"
 box.add_child(summary)
 var close := Button.new()
 close.text="전력 탭 닫기"
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
 panel.visible=tab_open
 drawing=false
 stroke.clear()
 view.mode="power_wire" if tab_open else "select"
 refresh()

func refresh():
 view.power_snapshot=view.city.power_state()
 view.refresh()
 update_state(0)
 queue_redraw()

func update_state(delta: float):
 if not visual_paused: visual_time+=delta
 if tab_open:
  var state: Dictionary=view.power_snapshot
  var generation := 0.0
  var demand := 0.0
  var supplied := 0.0
  for group in state.get("groups",[]):
   generation+=float(group.generation_kw)
   demand+=float(group.demand_kw)
   supplied+=float(group.supplied_kw)
  summary.text="연결망 발전 %.1f kW / 부하 %.1f kW\n공급 %.1f kW\n수입 %.1f kW / 수출 %.1f kW\n누적 수입 %.3f / 수출 %.3f kWh\n미정산 잔액 %s" % [generation,demand,supplied,state.get("import_kw",0),state.get("export_kw",0),view.city.power.imported_kwh,view.city.power.exported_kwh,view.city.Economy.format_fraction(view.city.power.pending_doth,6,true)]
 if tab_open or not view.city.power.plants.is_empty(): queue_redraw()

func finish_capture(event):
 if drawing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  finish_wire.call_deferred()

func handle_input(event) -> bool:
 if not tab_open: return false
 if event is InputEventMouseMotion and drawing:
  var p: Vector2=view.world(event.position)*4.0
  if view.city.power.valid(p) and (stroke.is_empty() or stroke[-1].distance_to(p)>.8): stroke.append(p)
  queue_redraw()
  return true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if not event.pressed:
   if drawing: finish_wire()
   return false
  var p: Vector2=view.world(event.position)
  match view.mode:
   "power_wire":
    var anchor: Dictionary=view.city.power.snap(p*4)
    if anchor.is_empty(): instruction.text="파란 점에서 시작하세요"
    else:
     drawing=true
     stroke=PackedVector2Array([anchor.position])
     instruction.text=""
   "power_plant":
    var result: Dictionary=view.city.add_power_plant(p,output.value)
    instruction.text="" if result.ok else result.reason
    if result.ok: selected_plant=result.id
    refresh()
   "power_erase_wire":
    var nearest := 6.0
    var selected := -1
    for wire in view.city.power.wires:
     for i in range(wire.points.size()-1):
      var d: float=(p*4).distance_to(Geometry2D.get_closest_point_to_segment(p*4,wire.points[i],wire.points[i+1]))
      if d<nearest:
       nearest=d
       selected=wire.id
    if selected!=-1: view.city.power.remove_wire(selected)
    refresh()
   "power_erase_plant","power_select":
    var found := -1
    for plant in view.city.power.plants:
     if plant.position.distance_to(p*4)<10:
      found=plant.id
      output.value=plant.output_kw
    if view.mode=="power_erase_plant" and found!=-1: view.city.power.remove_plant(found)
    else: selected_plant=found
    refresh()
   _:
    return false
  return true
 return false

func finish_wire():
 if not drawing: return
 drawing=false
 var result: Dictionary=view.city.power.add_wire(stroke)
 instruction.text="" if result.ok else result.reason
 stroke.clear()
 refresh()

func _draw():
 if view==null: return
 for plant in view.city.power.plants:
  if plant.has("public_lot_id"):continue
  var p: Vector2=plant.position/4-Vector2.ONE
  var base: PackedVector2Array=view.polygon(p.x,p.y,2)
  var top: PackedVector2Array=view.polygon(p.x,p.y,2,22)
  draw_colored_polygon(PackedVector2Array([base[1],base[2],top[2],top[1]]),Color("69838a"))
  draw_colored_polygon(PackedVector2Array([base[2],base[3],top[3],top[2]]),Color("526970"))
  draw_colored_polygon(top,Color("b4c6c4"))
  draw_string(ThemeDB.fallback_font,view.screen(plant.position/4)-Vector2(20,30)*view.map_zoom,"발전소",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
 if not tab_open: return
 var grid=view.city.power
 grid.rebuild()
 if show_ranges:
  for node in grid.nodes:
   if not node.service or grid.adjacency[node.id].is_empty(): continue
   var ring := PackedVector2Array()
   for i in range(65):
    var a := float(i)/64*TAU
    ring.append(view.screen((node.position+Vector2(cos(a),sin(a))*64)/4.0))
   draw_colored_polygon(ring,Color(.12,.65,1,.025))
   draw_polyline(ring,Color(.12,.65,1,.20),1,true)
 for wire in grid.wires:
  var path := PackedVector2Array()
  for p in wire.points: path.append(view.screen(p/4.0))
  draw_polyline(path,Color("12659a"),maxf(2,5*view.map_zoom),true)
  draw_polyline(path,Color("38b7ff"),maxf(1,2*view.map_zoom),true)
 preload("res://core/boundary_links.gd").draw_links(self,view,preload("res://core/boundary_links.gd").utility_links(grid,tab_open))
 for node in grid.nodes:
  if node.service and not grid.adjacency[node.id].is_empty():
   var p: Vector2=view.screen(node.position/4)
   draw_circle(p,maxf(2.5,4*view.map_zoom),Color("239ff0"))
   draw_arc(p,maxf(2.5,4*view.map_zoom),0,TAU,20,Color("c8f1ff"),1,true)
 for plant in grid.plants:
  var p: Vector2=view.screen(plant.position/4)
  draw_circle(p,7,Color("219df0"))
  draw_arc(p,7,0,TAU,24,Color.WHITE,1.5,true)
 for port in grid.ports:
  var p: Vector2=view.screen(port.position/4)
  draw_circle(p,8,Color("219df0"))
  draw_arc(p,8,0,TAU,24,Color.WHITE,1.5,true)

 for building in view.city.buildings:
  var supply: Dictionary=view.power_snapshot.get("consumers",{}).get(building.id,{})
  var color := Color("6bdfbc") if supply.get("powered",false) else Color("ebaa69")
  draw_circle(view.screen(Vector2(building.x+building.size/2.0,building.y+building.size/2.0))-Vector2(0,15)*view.map_zoom,3,color)
 if show_flow:
  for marker in Flow.markers(view.power_snapshot,visual_time):
   draw_circle(view.screen(marker.position/4),3.5,Color(1,1,1,marker.alpha))
 if stroke.size()>1:
  var path := PackedVector2Array()
  for p in stroke:path.append(view.screen(p/4.0))
  draw_polyline(path,Color(.3,.8,1,.8),2,true)
