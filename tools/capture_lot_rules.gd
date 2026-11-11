extends SceneTree
## Real production zoning and existing HUD growth input; no authored lot injection.
func _initialize():run.call_deferred()
func click(button: Button):
 var point:=button.get_global_rect().get_center()
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  root.push_input(event,true)
 await process_frame
func run():
 var scenario:="wide"
 var path:=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 if scenario not in ["wide","narrow","stage5"] or path.is_empty():push_error("Invalid evidence case");quit(1);return
 var paint_size: int=8 if scenario=="stage5" else (2 if scenario=="narrow" else 4)
 var target_size: int=paint_size
 var target_stage: int=5 if scenario=="stage5" else 1
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false # visual fixture permits all three zones; production demand is unchanged
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(44,40)]),"local",true,4)
 var setup: Array=[]
 var initial_paint: int=2 if scenario=="narrow" else 4
 for index in range(3):
  var zone: String=["residential","commercial","industrial"][index]
  var x: int=(2 if paint_size==8 else 4)+16*index
  var painted: Dictionary=city.paint_zones(PackedVector2Array([Vector2(x,38-initial_paint),Vector2(x+initial_paint,38-initial_paint),Vector2(x+initial_paint,38),Vector2(x,38)]),zone)
  var spawned: Array=city.advance_development(2)
  if painted.changed!=initial_paint*initial_paint or spawned.size()!=1 or spawned[0].zone!=zone or spawned[0].size!=(2 if scenario=="narrow" else 4):push_error("Actual zoning/development failed expected lot policy");quit(1);return
  var b: Dictionary=spawned[0]
  setup.append({"id":b.id,"zone":zone,"painted_cells":painted.changed,"size":b.size,"stage":b.level,"asset_id":b.asset_id})
 # Reserve expansion space after initial births, then remain paused while using manual growth.
 # Letting development fill all 8x8 paint first would correctly create competing 4x4 buildings.
 var expansion_paint: Array=[]
 if scenario=="stage5":
  for index in range(3):
   var x: int=2+16*index
   var zone: String=["residential","commercial","industrial"][index]
   expansion_paint.append(city.paint_zones(PackedVector2Array([Vector2(x,30),Vector2(x+8,30),Vector2(x+8,38),Vector2(x,38)]),zone))
 var game=load("res://main.tscn").instantiate();game.city=city;game.paused=true
 root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 game.select_category("build");await process_frame
 var score: Button=game.drawer_box.get_node("Tool_score")
 var upgrade: Button=game.drawer_box.get_node("Tool_upgrade")
 var actions: Array=[]
 for item: Dictionary in setup:
  var b: Dictionary=city.find_building(item.id);game.selected=b.id
  while b.level<target_stage:
   var old_stage: int=b.level
   await click(score);await click(upgrade)
   if b.level!=old_stage+1 or (b.level<5 and b.size>4):push_error("Existing manual button violated stage/lot policy");quit(1);return
   actions.append({"id":b.id,"stage":b.level,"size":b.size,"input":"existing HUD score and upgrade viewport mouse press/release"})
 var buildings: Array=[]
 for b: Dictionary in city.buildings:
  if b.size!=target_size or b.level!=target_stage or city.parcel_placement_error(b.frame,b.u,b.v,b.size,b.id)!="":push_error("Wrong captured actual lot/stage/frontage");quit(1);return
  buildings.append({"id":b.id,"zone":b.zone,"size":b.size,"stage":b.level,"asset_id":b.asset_id,"density":city.catalog.get_asset(b.asset_id).density})
 if city.funds!=50000:push_error("Private construction charged funds");quit(1);return
 game.message="";game.drawer.hide();game.fit_preview();game.refresh()
 for frame in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var state:={"scenario":scenario,"viewport":str(root.get_visible_rect()),"funds":city.funds,"population_gating_disabled_in_fixture_only":true,"authored_lot_injection":false,"initial_development":setup,"expansion_paint_after_birth":expansion_paint,"growth_button_actions":actions,"buildings":buildings}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
