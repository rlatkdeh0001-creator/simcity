extends SceneTree
## Real HUD controls and renderer; authored 4x4 setup is not a new spawning rule.
func _initialize():run.call_deferred()
func click(button: Button):
 var point:=button.get_global_rect().get_center()
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  root.push_input(event,true)
 await process_frame
func run():
 var lot:=2
 var stage:=1
 var path:=""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--lot="):lot=int(argument.trim_prefix("--lot="))
  if argument.begins_with("--stage="):stage=int(argument.trim_prefix("--stage="))
  if argument.begins_with("--evidence="):path=argument.trim_prefix("--evidence=")
 if path.is_empty() or lot not in [2,4] or stage not in [1,3,5]:push_error("Invalid capture request");quit(1);return
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false # deterministic visual fixture only; runtime demand remains unchanged
 city.config.size_weights={2:1.0 if lot==2 else 0.0,4:1.0 if lot==4 else 0.0,8:0.0}
 var road: Dictionary=city.add_road(PackedVector2Array([Vector2(2,40),Vector2(44,40)]),"local",true,4)
 if not road.ok:push_error("Fixture road failed");quit(1);return
 var setup: Array=[]
 for index in range(3):
  var zone: String=["residential","commercial","industrial"][index]
  var x: int=4+16*index
  var y: int=38-lot
  var painted: Dictionary=city.paint_zones(PackedVector2Array([Vector2(x,y),Vector2(x+lot,y),Vector2(x+lot,38),Vector2(x,38)]),zone)
  if painted.changed!=lot*lot:push_error("Expected actual painted parcel cells");quit(1);return
  var building: Dictionary
  if lot==2:
   var spawned: Array=city.advance_development(city.config.development_interval_seconds)
   if spawned.size()!=1 or spawned[0].zone!=zone:push_error("Actual painted-zone development failed");quit(1);return
   building=spawned[0]
  else:
   # Existing scenario API supplies an already-4x4 stage1 lot. No new 4x4 spawning implementation.
   var candidates: Array=city.catalog.eligible({"zone":zone,"size":4,"level":1})
   var placed: Dictionary=city.place_catalog_building(candidates[0],x,y)
   if not placed.ok:push_error("Existing authored 4x4 placement failed");quit(1);return
   building=placed.building
  setup.append({"id":building.id,"zone":zone,"painted_cells":painted.changed,"initial_stage":building.level,"initial_asset":building.asset_id})
 var game=load("res://main.tscn").instantiate()
 game.city=city;game.paused=true
 root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 game.select_category("build")
 await process_frame
 var score: Button=game.drawer_box.get_node("Tool_score")
 var upgrade: Button=game.drawer_box.get_node("Tool_upgrade")
 var actions: Array=[]
 var funds: int=city.funds
 for item: Dictionary in setup:
  var building: Dictionary=city.find_building(item.id)
  game.selected=building.id
  while building.level<stage:
   var previous: int=building.level
   await click(score)
   await click(upgrade)
   if building.level!=previous+1 or building.size!=lot:push_error("Real growth button did not produce expected stage/fixture lot");quit(1);return
   actions.append({"building":building.id,"from_stage":previous,"to_stage":building.level,"asset_id":building.asset_id,"input":"actual viewport mouse press/release on existing score and upgrade buttons"})
 if city.funds!=funds:push_error("Private growth charged funds");quit(1);return
 game.message="";game.drawer.hide();game.fit_preview();game.refresh()
 for frame in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var buildings: Array=[]
 for building: Dictionary in city.buildings:
  var asset: Dictionary=city.catalog.get_asset(building.asset_id)
  if asset.is_empty() or building.level!=stage or building.size!=lot:push_error("Wrong actual capture state");quit(1);return
  buildings.append({"id":building.id,"zone":building.zone,"lot":building.size,"stage":building.level,"asset_id":building.asset_id,"density":asset.density,"model":asset.model,"frontage":str(city.front_direction(building))})
 var state:={"viewport":str(root.get_visible_rect()),"lot":lot,"stage":stage,"funds":city.funds,"painted_setup":setup,"buildings":buildings,"growth_button_actions":actions,"authored_4x4_setup":lot==4,"production_growth_rules_changed":false,"population_gating_disabled_in_fixture_only":true}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
 var error:=root.get_texture().get_image().save_png(path)
 quit(0 if error==OK else 1)
