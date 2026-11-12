extends SceneTree
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 game.city.add_road(PackedVector2Array([Vector2(10,40),Vector2(60,40)]),"local",true,4)
 root.add_child(game);current_scene=game
 var frame: Dictionary=game.city.zoning_grid.frames.values().filter(func(f):return f.outward.y<-.5)[0]
 var old_patch: PackedVector2Array=game.city.Parcels.polygon(frame,16,0,4)
 assert(game.city.paint_zones(old_patch,"residential").changed==16)
 var before: Dictionary=game.city.zone_designations.duplicate()
 var range_polygon: PackedVector2Array=game.city.Parcels.polygon(frame,12,0,12)
 game.map_zoom=2.5;game.origin=Vector2.ZERO
 var bounds:=Rect2(game.screen(range_polygon[0]),Vector2.ZERO)
 for p in range_polygon:bounds=bounds.expand(game.screen(p))
 game.origin=Vector2(960,330)-bounds.get_center();game.queue_redraw()
 for i in range(5):await process_frame
 await mouse(game.categories[0].get_global_rect().get_center(),true);await mouse(game.categories[0].get_global_rect().get_center(),false)
 for i in range(5):await process_frame
 var tool: Button=game.drawer_box.get_node("Tool_build_commercial")
 await mouse(tool.get_global_rect().get_center(),true);await mouse(tool.get_global_rect().get_center(),false)
 bounds=Rect2(game.screen(range_polygon[0]),Vector2.ZERO)
 for p in range_polygon:bounds=bounds.expand(game.screen(p))
 await mouse(bounds.position-Vector2.ONE,true)
 var motion:=InputEventMouseMotion.new();motion.position=bounds.end+Vector2.ONE;root.push_input(motion,true);await process_frame
 await mouse(motion.position,false)
 for i in range(5):game.queue_redraw();await process_frame
 assert(before.keys().all(func(id):return game.city.zone_designations.get(id)=="residential"))
 var commercial: int=game.city.zone_designations.values().filter(func(v):return v=="commercial").size()
 assert(commercial>0 and not game.zoning_drag and game.city.buildings.is_empty() and game.city.funds==50000)
 await RenderingServer.frame_post_draw
 var state:={"input":"actual category/tool clicks and commercial drag over existing residential cells plus empty cells","existing_residential_retained":before.size(),"new_commercial":commercial,"funds":game.city.funds,"buildings":game.city.buildings.size(),"viewport":str(root.get_visible_rect()),"zones":game.city.zone_designations}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_NON_OVERPAINT_PASS ",before.size()," residential retained; ",commercial," new commercial")
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
