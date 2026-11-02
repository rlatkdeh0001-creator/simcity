extends "res://main.gd"
var supply_id := -1
var treatment_id := -1
var external_pipe := -1
var capture_path := ""
var record_dir := ""
var record_index := -1
var capture_pending := false
var elapsed_demo := 0.0
var button_layer: CanvasLayer
var controls: PanelContainer
var scenario := "domestic"
var selected_scenario := ""

func _ready():
 showcase_view=true
 super._ready()
 controls_panel.hide()
 hud.hide()
 city=Model.new(100,100,42)
 city.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)]))
 city.add_road(PackedVector2Array([Vector2(38,50),Vector2(38,80)]))
 for x in [32,42,62,76]:
  var result: Dictionary=city.add_building(x,40,"residential")
  if result.ok: result.building.water_demand_m3_day=40.0
 for y in [60,72]:
  var result: Dictionary=city.add_building(34,y,"residential")
  if result.ok: result.building.water_demand_m3_day=40.0
 var plant: Dictionary=city.add_water_facility(Vector2(20,40),"water",240)
 var treatment: Dictionary=city.add_water_facility(Vector2(34,76),"sewage",192)
 treatment_id=treatment.id
 supply_id=plant.id
 city.water.add_pipe(PackedVector2Array([Vector2(84,164),Vector2(340,164)]))
 city.water.add_pipe(PackedVector2Array([Vector2(148,164),Vector2(148,280),Vector2(140,308)]))
 water_overlay.selected_facility=supply_id
 water_overlay.toggle()
 water_overlay.output.value=240
 water_snapshot=city.water_state()
 mode="water_pipe"
 button_layer=CanvasLayer.new()
 add_child(button_layer)
 controls=PanelContainer.new()
 controls.position=Vector2(16,18)
 controls.custom_minimum_size.x=270
 button_layer.add_child(controls)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",10)
 controls.add_child(box)
 var title := Label.new()
 title.text="CITIES_DO\n함께 설치하는 상하수도"
 title.add_theme_font_size_override("font_size",22)
 box.add_child(title)
 for pair in [["내부 급수·하수 처리","domestic"],["잉여 상수 수출","export"],["상수 수입·하수 외부 위탁","import"],["관로 단선","off"]]:
  var button := Button.new()
  button.name="Scenario_"+pair[1]
  button.text=pair[0]
  var action: String=pair[1]
  button.pressed.connect(func():set_scenario(action))
  box.add_child(button)
 var back := Button.new()
 back.name="WaterDemoReturn"
 back.text="내 도시로 돌아가기"
 back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"))
 box.add_child(back)
 get_viewport().size_changed.connect(fit_water)
 fit_water()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--water-scenario="): selected_scenario=arg.trim_prefix("--water-scenario=")
  if arg.begins_with("--capture-water="): capture_path=arg.trim_prefix("--capture-water=")
  if arg.begins_with("--record-water="):
   record_dir=arg.trim_prefix("--record-water=")
   DirAccess.make_dir_recursive_absolute(record_dir)
 if selected_scenario!="": set_scenario(selected_scenario)

func fit_water():
 var size := get_viewport_rect().size
 var area := Rect2(300,60,maxf(400,size.x-660),maxf(300,size.y-150))
 map_zoom=minf(area.size.x/1700.0,area.size.y/900.0)
 origin=area.get_center()-Vector2(0,700)*map_zoom

func set_scenario(which: String):
 scenario=which
 if external_pipe!=-1:
  city.water.remove_pipe(external_pipe)
  external_pipe=-1
 if which=="off":
  for pipe in city.water.geometry.wires.duplicate(): city.water.remove_pipe(pipe.id)
 elif city.water.geometry.wires.is_empty():
  city.water.add_pipe(PackedVector2Array([Vector2(84,164),Vector2(340,164)]))
  city.water.add_pipe(PackedVector2Array([Vector2(148,164),Vector2(148,280),Vector2(140,308)]))
 var capacity: float={"domestic":240.0,"export":300.0,"import":100.0,"off":0.0}[which]
 city.water.set_capacity(supply_id,capacity)
 city.water.set_capacity(treatment_id,64 if which=="import" else (0 if which=="off" else 192))
 water_overlay.output.value=capacity
 if which in ["export","import"]:
  var added: Dictionary=city.water.add_pipe(PackedVector2Array([Vector2(340,164),Vector2(400,164),Vector2(400,200)]))
  if added.ok:external_pipe=added.wire.id
 water_overlay.visual_time=0
 water_overlay.refresh()

func _process(delta: float):
 super._process(delta)
 elapsed_demo+=delta
 if capture_path!="" and elapsed_demo>5 and not capture_pending:
  capture_pending=true
  capture.call_deferred(capture_path)
 if record_dir!="" and not capture_pending:
  var target_mode := "domestic" if elapsed_demo<4 else ("export" if elapsed_demo<8 else "import")
  if scenario!=target_mode: set_scenario(target_mode)
  if int(elapsed_demo*8)>record_index:
   record_index=int(elapsed_demo*8)
   capture_pending=true
   record_frame.call_deferred()

func capture(path: String):
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(path)
 get_tree().quit(0 if error==OK else 1)

func record_frame():
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(record_dir.path_join("%03d.png"%record_index))
 capture_pending=false
 if error!=OK or elapsed_demo>=12:get_tree().quit(0 if error==OK else 1)
