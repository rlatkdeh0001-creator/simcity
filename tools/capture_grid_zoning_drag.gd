extends SceneTree
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 game.city.add_road(PackedVector2Array([Vector2(20,35),Vector2(65,50)]));root.add_child(game);current_scene=game
 var f: Dictionary=game.city.zoning_grid.frames.values().filter(func(frame):return game.city.zoning_grid.has_parcel(frame.id,1,0) and game.city.zoning_grid.has_parcel(frame.id,6,3))[0]
 var first: Vector2=f.origin+f.along*1.5+f.outward*.5;var last: Vector2=f.origin+f.along*6.5+f.outward*3.5
 assert(game.city.paint_zones(game.city.Parcels.polygon(f,1,0,2),"residential").changed==4)
 game.map_zoom=3;game.origin=Vector2.ZERO;game.origin=Vector2(960,330)-game.screen((first+last)/2);game.queue_redraw()
 for i in range(5):await process_frame
 await mouse(game.categories[0].get_global_rect().get_center(),true);await mouse(game.categories[0].get_global_rect().get_center(),false)
 for i in range(5):await process_frame
 var tool: Button=game.drawer_box.get_node("Tool_build_commercial")
 await mouse(tool.get_global_rect().get_center(),true);await mouse(tool.get_global_rect().get_center(),false)
 await mouse(game.screen(first),true)
 var motion:=InputEventMouseMotion.new();motion.position=game.screen(last);root.push_input(motion,true)
 for i in range(5):await process_frame
 assert(game.zoning_drag and game.city.zone_designations.size()==4)
 var selection: PackedVector2Array=game.zoning_selection();await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(path)==OK)
 await mouse(game.screen(last),false)
 assert(game.city.zone_designations.size()==24 and game.city.zone_designations.values().count("residential")==4 and game.city.zone_designations.values().count("commercial")==20)
 var state:={"input":"actual category/tool clicks and held diagonal-local-grid drag","capture_phase":"uncommitted translucent 6x4 grid preview","frame":f,"preview_polygon":selection,"after_release_residential":4,"after_release_commercial":20,"viewport":str(root.get_visible_rect())}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_GRID_DRAG_PASS 6x4; prior4 preserved; new20 committed");quit()
