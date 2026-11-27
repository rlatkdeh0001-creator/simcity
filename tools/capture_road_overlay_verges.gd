extends "res://tests/test_road_grade_flow.gd"
const Verges=preload("res://core/roadside_verges.gd")
var output:="D:/project/simcity/docs/road-overlay-verge-validation"
func move(point:Vector2):
 var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;root.push_input(event,true);await settle()
func save(name:String,state:Dictionary):
 game.queue_redraw();await settle();await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(output.path_join(name+"-1920.png"))==OK)
 state.viewport=str(image.get_size());state.input="real category/lane card and viewport mouse press/release"
 var file:=FileAccess.open(output.path_join(name+".state.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 return image
func run():
 DirAccess.make_dir_recursive_absolute(output);root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 game.city=City.new(100,100)
 game.city.add_road(PackedVector2Array([Vector2(10,50),Vector2(52,50)]),"local",true,4)
 game.city.add_road(PackedVector2Array([Vector2(50,10),Vector2(50,90)]),"local",true,4)
 game.road_grid_enabled=true;game.map_zoom=1.25;game.origin=Vector2.ZERO;game.origin=Vector2(960,450)-game.screen(Vector2(61,50));await select_lanes(4)
 var original:=var_to_bytes(game.city.roads)
 await click(game.screen(Vector2(50.25,50)));await move(game.screen(Vector2(74.5,50)))
 var preview:Dictionary=game.road_drawer.preview();var length:float=game.city.RoadJunctions.length_of(preview.points)*4
 verify(preview.ok,"native short-arm junction overlay is green")
 verify(is_equal_approx(length,96),"native overlay has the reported 96m total length")
 verify(game.road_drawer.preview_colors(preview.ok).outline==Color("3ddc84"),"production preview really selects green")
 await click(game.screen(Vector2(74.5,50)));await settle()
 verify(game.city.roads.size()==3 and var_to_bytes(game.city.roads.slice(0,2))==original,"native mouse commit preserves both originals and adds only one uncovered tail")
 verify(game.city.junctions.size()==1,"native overlay leaves the existing four-arm junction unchanged")
 var state:={"fixture":"four-lane existing four-arm junction with a two-cell east stub","preview_ok":preview.ok,"preview_points":preview.points,"total_length_m":length,"new_length_m":preview.get("new_length_m",-1),"retained_length_m":preview.get("retained_length_m",-1),"originals_preserved":var_to_bytes(game.city.roads.slice(0,2))==original,"roads_after":game.city.roads,"junctions_after":game.city.junctions.size(),"image_phase":"after successful real mouse commit"}
 game.road_drawer.cancel();await save("overlay-success",state)
 game.city=City.new(100,100)
 var grid:={"origin":Vector2.ZERO,"along":Vector2.RIGHT,"outward":Vector2.DOWN}
 game.city.add_road(PackedVector2Array([Vector2(30,40),Vector2(60,40),Vector2(60,75)]),"local",true,4,false,false,1,grid)
 game.city.add_road(PackedVector2Array([Vector2(45,60),Vector2(80,60)]),"local",true,4,false,false,1,grid)
 game.map_zoom=1.4;game.origin=Vector2.ZERO;game.origin=Vector2(960,435)-game.screen(Vector2(55,50));await click(game.categories[0].get_global_rect().get_center());await settle()
 verify(game.chosen=="build" and game.world_renderer.zones.visible,"real zoning category reveals the unchanged grid")
 verify(not game.world_renderer.verges.is_empty(),"four-lane L and crossing have retained verge patches")
 var model_before:=var_to_bytes([game.city.roads,game.city.zoning_grid.parcels]);var generation:int=game.world_renderer.road_generation
 await move(Vector2(15,15));var image:Image=await save("roadside-verges",{"fixture":"four-lane L and four-arm crossing on one unchanged shared board","verge_color":Verges.COLOR.to_html(),"verge_patches":game.world_renderer.verges.size(),"roads":game.city.roads,"parcel_count":game.city.zoning_grid.count(),"display_only":true})
 var correct:=true
 for p in [Vector2(40.25,37.25),Vector2(40.25,42.75),Vector2(57.25,50.25),Vector2(62.75,50.25)]:
  var pixel:Color=image.get_pixelv(Vector2i(game.screen(p).round()));correct=correct and absf(pixel.r-Verges.COLOR.r)<.035 and absf(pixel.g-Verges.COLOR.g)<.035 and absf(pixel.b-Verges.COLOR.b)<.035
 verify(correct,"actual framebuffer has grass color on both sides of both L arms")
 verify(var_to_bytes([game.city.roads,game.city.zoning_grid.parcels])==model_before and game.world_renderer.road_generation==generation,"stationary native frames preserve grid and retained geometry generation")
 game.queue_free();await process_frame
 print("RESULT %d/%d native overlay and verge checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
