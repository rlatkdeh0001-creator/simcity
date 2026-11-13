extends SceneTree
var game
func _initialize():run.call_deferred()
func settle():
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
func button(point:Vector2,down:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;e.global_position=point;root.push_input(e,true);await process_frame
func click(point:Vector2):
 await button(point,true);await button(point,false);await settle()
func run():
 var output:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):output=arg.trim_prefix("--evidence=")
 assert(not output.is_empty());root.size=Vector2i(960,640)
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 await click(game.categories[1].get_global_rect().get_center());assert(game.road_lane_cards.size()==7)
 for card in game.road_lane_cards:
  if int(card.get_meta("lanes"))==6:await click(card.get_global_rect().get_center())
 assert(game.road_lanes==6 and game.city.roads.is_empty())
 var strip=game.find_child("RoadCardStrip",true,false);var bar:HScrollBar=strip.get_h_scroll_bar();assert(bar.visible and bar.max_value>bar.page);strip.scroll_horizontal=0;await settle()
 var rect:=bar.get_global_rect();var dec:float=bar.get_theme_icon("decrement").get_width();var inc:float=bar.get_theme_icon("increment").get_width();var track:float=rect.size.x-dec-inc;var thumb:float=track*bar.page/bar.max_value;var start:=Vector2(rect.position.x+dec+thumb/2,rect.get_center().y);var finish:=start+Vector2((track-thumb)/2,0)
 await button(start,true);var e:=InputEventMouseMotion.new();e.position=finish;e.global_position=finish;e.relative=finish-start;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await settle();await button(finish,false);await settle()
 var fraction:float=strip.scroll_horizontal/(bar.max_value-bar.page);assert(fraction>.3 and fraction<.7);game.queue_redraw();await settle()
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(960,640) and image.save_png(output)==OK)
 var state:={"viewport":str(image.get_size()),"cards":7,"selected_lanes":6,"scroll_fraction":fraction,"scroll":strip.scroll_horizontal,"maximum_scroll":bar.max_value-bar.page,"input":"actual road category + six-lane card press/release + native scrollbar handle drag","track":"#38515e","handle":"#36b7ff","world_roads":game.city.roads.size()}
 var file:=FileAccess.open(output.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close();print("NATIVE_GRADE_CARD_CAPTURE_PASS ",state);quit()
