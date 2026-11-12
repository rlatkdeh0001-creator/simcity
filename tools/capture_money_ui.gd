extends SceneTree
var game
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func click(point: Vector2):await mouse(point,true);await mouse(point,false)
func run():
 var path:="";var scenario:="hover"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
 if path.is_empty() or scenario not in ["poor","hover"]:quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 if scenario=="poor":game.city.funds=3200
 root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 await click(game.categories[2].get_global_rect().get_center())
 for frame in range(5):await process_frame
 var cards: Array=game.drawer_box.get_children().filter(func(b):return b is Button and b.get_meta("thumbnail_asset_id","")=="power-wind")
 if cards.size()!=1:quit(1);return
 var card=cards[0];game.drawer_scroll.ensure_control_visible(card)
 for frame in range(5):await process_frame
 var event:=InputEventMouseMotion.new();event.position=card.get_global_rect().get_center();root.push_input(event,true);await process_frame
 if scenario=="poor":
  await click(card.get_global_rect().get_center())
  if game.mode=="public_placement" or not game.public_controller.asset_id.is_empty() or game.money_toast==null or not game.money_toast.visible:quit(1);return
 else:
  if game.asset_info==null or not game.asset_info.visible:quit(1);return
 for frame in range(10):await process_frame
 await RenderingServer.frame_post_draw
 var state:={"scenario":scenario,"input":"actual power-category and C-card mouse input","viewport":str(root.get_visible_rect()),"funds":game.city.funds,"money_text":game.money.text,"currency_glyph_supported":game.money.glyph_supported(),"font":game.money.get_theme_font("font").get_font_name(),"currency_color":str(game.money.ICON_COLOR),"mode":game.mode,"ghost_asset":game.public_controller.asset_id,"card_dimmed":card.unaffordable,"card_border":str(card.get_theme_stylebox("normal").border_color),"toast":str(game.money_toast.get_global_rect()) if game.money_toast!=null and game.money_toast.visible else "","hover_rows":game.asset_info.get_meta("rows",[]) if game.asset_info!=null and game.asset_info.visible else []}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
