extends "res://tests/test_road_grade_flow.gd"
const Cases=preload("res://tests/test_road_extension_grid.gd")
func run():
 var output:="D:/project/simcity/docs/road-overlay-verge-validation"
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game;await settle()
 game.city=Cases.fixture(50)
 var built:Dictionary={}
 for parcel in game.city.zoning_grid.parcels.values():
  if parcel.frame.road_index!=1 or parcel.v!=0 or parcel.u>parcel.frame.columns-2 or parcel.center.y<37 or parcel.center.y>45:continue
  var placed:Dictionary=game.city.add_building_at(parcel.center)
  if placed.ok:built=placed.building;break
 verify(not built.is_empty(),"native fixture contains an existing legally placed building")
 game.city.paint_zones(PackedVector2Array([Vector2(43,36),Vector2(48,36),Vector2(48,46),Vector2(43,46)]),"residential")
 game.road_grid_enabled=true;game.map_zoom=1.3;game.origin=Vector2.ZERO;game.origin=Vector2(960,420)-game.screen(Vector2(50.5,50))
 await select_lanes(4)
 var buildings_before:=var_to_bytes(game.city.buildings);var zones_before:Dictionary=game.city.zone_designations.duplicate();var roads_before:=var_to_bytes(game.city.roads)
 await click(game.screen(Vector2(50.5,50)))
 var motion:=InputEventMouseMotion.new();motion.position=game.screen(Vector2(50.5,75));motion.global_position=motion.position;root.push_input(motion,true);await settle()
 verify(game.road_drawer.preview().ok,"real endpoint extension has a green preview")
 await click(game.screen(Vector2(50.5,75)));await settle()
 verify(game.city.roads.size()==3 and var_to_bytes(game.city.roads.slice(0,2))==roads_before,"real endpoint mouse construction retains old roads and adds the tail")
 var wanted:Dictionary=Cases.shapes(Cases.fixture(75));var actual:Dictionary=Cases.shapes(game.city)
 verify(actual==wanted,"native split extension has the complete one-shot cell polygon set")
 verify(var_to_bytes(game.city.buildings)==buildings_before,"native extension preserves the full existing building record")
 var zones_preserved:=not zones_before.is_empty()
 for id in zones_before:zones_preserved=zones_preserved and game.city.zone_designations.get(id)==zones_before[id]
 verify(zones_preserved,"native extension preserves all prepainted zone IDs and types")
 game.road_drawer.cancel();await click(game.categories[0].get_global_rect().get_center());await settle();game.queue_redraw();await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(output.path_join("extended-grid-1920.png"))==OK)
 var state:={"input":"real four-lane card and endpoint viewport mouse press/release","fixture":"four-arm junction, vertical four-lane road ending at y50 then continued to y75","whole_cell_count":wanted.size(),"split_cell_count":actual.size(),"polygon_sets_equal":actual==wanted,"building_preserved":var_to_bytes(game.city.buildings)==buildings_before,"designations_preserved":zones_preserved,"old_designated_cells":zones_before.size(),"roads":game.city.roads,"viewport":str(image.get_size())}
 var file:=FileAccess.open(output.path_join("extended-grid.state.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 game.queue_free();await process_frame
 print("RESULT %d/%d native extension grid checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
