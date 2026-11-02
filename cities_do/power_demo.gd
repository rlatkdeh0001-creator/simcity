extends "res://main.gd"
var plant_id := -1
var external_wire := -1
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
  if result.ok: result.building.power_demand_kw=40.0
 for y in [60,72]:
  var result: Dictionary=city.add_building(34,y,"residential")
  if result.ok: result.building.power_demand_kw=40.0
 var plant: Dictionary=city.add_power_plant(Vector2(20,40),240)
 plant_id=plant.id
 city.power.add_wire(PackedVector2Array([Vector2(84,164),Vector2(340,164)]))
 city.power.add_wire(PackedVector2Array([Vector2(148,164),Vector2(148,280)]))
 power_overlay.selected_plant=plant_id
 power_overlay.toggle()
 power_overlay.output.value=240
 power_snapshot=city.power_state()
 mode="power_wire"
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
 title.text="CITIES_DO\n실제 전력 공급·교역"
 title.add_theme_font_size_override("font_size",22)
 box.add_child(title)
 for pair in [["내부 공급 240kW","domestic"],["수출: 발전 300kW","export"],["수입: 발전 100kW","import"],["발전 정지·단선","off"]]:
  var button := Button.new()
  button.name="Scenario_"+pair[1]
  button.text=pair[0]
  var action: String=pair[1]
  button.pressed.connect(func():set_scenario(action))
  box.add_child(button)
 var back := Button.new()
 back.name="PowerDemoReturn"
 back.text="내 도시로 돌아가기"
 back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"))
 box.add_child(back)
 get_viewport().size_changed.connect(fit_power)
 fit_power()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--power-scenario="): selected_scenario=arg.trim_prefix("--power-scenario=")
  if arg.begins_with("--capture-power="): capture_path=arg.trim_prefix("--capture-power=")
  if arg.begins_with("--record-power="):
   record_dir=arg.trim_prefix("--record-power=")
   DirAccess.make_dir_recursive_absolute(record_dir)
 if selected_scenario!="": set_scenario(selected_scenario)

func fit_power():
 var size := get_viewport_rect().size
 var area := Rect2(300,60,maxf(400,size.x-660),maxf(300,size.y-150))
 map_zoom=minf(area.size.x/1700.0,area.size.y/900.0)
 origin=area.get_center()-Vector2(0,700)*map_zoom

func set_scenario(which: String):
 scenario=which
 if external_wire!=-1:
  city.power.remove_wire(external_wire)
  external_wire=-1
 var output_kw: float={"domestic":240.0,"export":300.0,"import":100.0,"off":0.0}[which]
 city.power.set_output(plant_id,output_kw)
 power_overlay.output.value=output_kw
 if which in ["export","import"]:
  var added: Dictionary=city.power.add_wire(PackedVector2Array([Vector2(340,164),Vector2(400,164),Vector2(400,200)]))
  if added.ok:external_wire=added.wire.id
 power_overlay.visual_time=0
 power_overlay.refresh()

func _process(delta: float):
 super._process(delta)
 elapsed_demo+=delta
 if capture_path!="" and elapsed_demo>5 and not capture_pending:
  capture_pending=true
  capture.call_deferred(capture_path)
 if record_dir!="" and not capture_pending:
  var target_mode := "domestic" if elapsed_demo<8 else ("export" if elapsed_demo<16 else "import")
  if scenario!=target_mode: set_scenario(target_mode)
  if int(elapsed_demo*2)>record_index:
   record_index=int(elapsed_demo*2)
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
 if error!=OK or elapsed_demo>=24:get_tree().quit(0 if error==OK else 1)
