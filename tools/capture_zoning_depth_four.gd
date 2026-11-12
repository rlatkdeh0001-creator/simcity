extends SceneTree
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false;root.add_child(game);current_scene=game
 for y in [40,50,65]:assert(game.city.add_road(PackedVector2Array([Vector2(25,y),Vector2(65,y)])).ok)
 assert(game.city.zoning_grid.parcels.values().all(func(p):return p.v>=0 and p.v<4))
 game.map_zoom=1.2;game.origin=Vector2.ZERO;game.origin=Vector2(960,410)-game.screen(Vector2(45,51));game.queue_redraw()
 for i in range(5):await process_frame
 await click(game.categories[game.NAMES.keys().find("build")].get_global_rect().get_center())
 for i in range(5):await process_frame
 await click(game.drawer_box.get_node("Tool_build").get_global_rect().get_center())
 var frame: Dictionary=game.city.zoning_grid.frames.values().filter(func(f):return f.road_index==0 and f.side==1)[0]
 var a: Vector2=frame.origin+(frame.along+frame.outward)*.5
 var b: Vector2=frame.origin+(frame.along+frame.outward)*7.5
 var press:=InputEventMouseButton.new();press.position=game.screen(a);press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true);await process_frame
 var motion:=InputEventMouseMotion.new();motion.position=game.screen(b);root.push_input(motion,true)
 for i in range(5):await process_frame
 assert(game.zoning_drag and game.zoning_selection()==game.city.Parcels.polygon(frame,0,0,8))
 var cells: Array=game.city.zoning_grid.opposing_lot_cells(frame,0,0)
 assert(cells.size()==64 and cells.filter(func(p):return p.frame.road_index==0).size()==32 and cells.filter(func(p):return p.frame.road_index==1).size()==32)
 assert(game.city.parcel_placement_error(frame,0,0,8).is_empty())
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var release:=InputEventMouseButton.new();release.position=game.screen(b);release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release,true);await process_frame
 assert(game.city.zone_designations.size()==64 and game.message.is_empty())
 var created: Array=game.city.advance_development(2);assert(created.size()==1 and created[0].size==4)
 var lot: Dictionary=created[0]
 for stage in range(2,6):
  lot.score=100;assert(game.city.upgrade_chain(lot.id).ok and lot.level==stage and lot.size==(8 if stage==5 else 4))
 var state:={"capture_phase":"actual 8x8 drag preview spanning two opposing roads; third isolated road shows four-deep strips","viewport":str(image.get_size()),"max_depth_rows":4,"front_cells":32,"rear_cells":32,"interior_gap_cells":8,"actual_release_painted_cells":game.city.zone_designations.size(),"growth_after_capture":{"id":lot.id,"size":lot.size,"level":lot.level,"asset_id":lot.asset_id},"input":"actual category click and mouse press/motion/release; then deterministic existing development/growth APIs"}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_FOUR_DEPTH_PASS all sides four rows; opposed 32+32 shared lot; actual release64; growth 4x4 to stage5 8x8");quit()
