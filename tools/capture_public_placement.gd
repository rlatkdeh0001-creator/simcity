extends SceneTree
var game
var actions: Array=[]
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
func move(point: Vector2):
 var event:=InputEventMouseMotion.new();event.position=point;root.push_input(event,true)
 await process_frame
func card(category: String,id: String) -> bool:
 game.select_category(category)
 for frame in range(5):await process_frame
 var buttons: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.get_meta("thumbnail_asset_id","")==id)
 if buttons.size()!=1:push_error("Missing unique C-card "+id);quit(1);return false
 var button: Button=buttons[0];game.drawer_scroll.ensure_control_visible(button)
 for frame in range(5):await process_frame
 var point:=button.get_global_rect().get_center();await mouse(point,true);await mouse(point,false)
 if game.public_controller.asset_id!=id:push_error("Actual card did not begin placement: expected="+id+" actual="+game.public_controller.asset_id+" mode="+game.mode+" rect="+str(button.get_global_rect()));quit(1);return false
 return true
func place(category: String,id: String,center: Vector2) -> bool:
 if not await card(category,id):return false
 var funds: int=game.city.funds;var count: int=game.city.public_facilities.lots.size()
 var point: Vector2=game.screen(center);await move(point);await mouse(point,true);await mouse(point,false)
 var result: Dictionary=game.public_controller.last_result
 if not result.get("ok",false) or game.city.public_facilities.lots.size()!=count+1 or game.city.funds!=funds-int(game.city.public_facilities.price(id)):
  push_error("Actual world placement failed: "+id+" "+str(result));quit(1);return false
 actions.append({"asset":id,"input":"real C-card and world mouse press/release","funds_before":funds,"funds_after":game.city.funds})
 game.public_controller.cancel()
 return true
func run():
 var scenario:="services";var path:=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 if path.is_empty() or scenario not in ["services","power","insufficient"]:push_error("Invalid capture request");quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 game.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 var initial_budget: int=100000 if scenario=="services" else 50000
 game.city.funds=initial_budget
 root.add_child(game);current_scene=game
 for frame in range(4):await process_frame
 var network: Dictionary={}
 if scenario in ["services","insufficient"]:
  if not await place("fire","fire-station",Vector2(10,35)):return
  if not await place("police","police-station",Vector2(26,35)):return
  if scenario=="services":
   if not await place("health","medical-hospital",Vector2(42,35)):return
   if not await place("education","elementary-school",Vector2(58,36)):return
  else:
   if not await card("health","medical-hospital"):return
   await move(game.screen(Vector2(42,35)));await mouse(game.screen(Vector2(42,35)),true);await mouse(game.screen(Vector2(42,35)),false)
   if game.public_controller.last_result.get("code","")!="insufficient_funds" or game.city.public_facilities.lots.size()!=2:push_error("Expected actual insufficient-cash rejection");quit(1);return
   actions.append({"asset":"medical-hospital","rejection":game.public_controller.last_result.code,"funds":game.city.funds,"cost":game.city.public_facilities.price("medical-hospital")})
 else:
  if not await place("power","power-wind",Vector2(10,36)):return
  game.city.paint_zones(PackedVector2Array([Vector2(38,36),Vector2(40,36),Vector2(40,38),Vector2(38,38)]),"residential")
  if game.city.advance_development(2).size()!=1:push_error("Actual zoned consumer did not develop");quit(1);return
  game.activate_tool("power_wire")
  await mouse(game.screen(Vector2(10,36)),true)
  await move(game.screen(Vector2(39,37)))
  await mouse(game.screen(Vector2(39,37)),false)
  game.power_snapshot=game.city.power_state()
  var supply: Dictionary=game.power_snapshot.consumers[game.city.buildings[0].id]
  if not supply.powered or game.city.power.wires.is_empty():push_error("Actual wire did not supply consumer");quit(1);return
  network={"plants":game.city.power.plants,"wire_count":game.city.power.wires.size(),"consumer":supply}
  actions.append({"input":"real world wire drag","powered":supply.powered})
 game.drawer.hide()
 if scenario=="insufficient":
  game.map_zoom=1.1;game.origin=Vector2(1000,100);await move(game.screen(Vector2(42,35)))
 else:game.fit_preview()
 for frame in range(120):
  await process_frame
  if frame>20 and not game.building_views.busy and game.building_views.queue.is_empty():break
 await RenderingServer.frame_post_draw
 var state:={"scenario":scenario,"viewport":str(root.get_visible_rect()),"initial_fixture_budget":initial_budget,"normal_starting_funds_unchanged":50000,"population_gate_disabled_in_fixture_only":true,"funds":game.city.funds,"monthly_upkeep":game.city.public_facilities.monthly_upkeep(),"public_lots":game.city.public_facilities.lots,"actions":actions,"network":network,"ghost":game.public_controller.preview() if scenario=="insufficient" else {},"ghost_color":str(game.public_controller.ghost_color()) if scenario=="insufficient" else ""}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
