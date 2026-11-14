extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func settle():
 for i in range(5):await process_frame
func run():
 root.size=Vector2i(1280,820)
 verify(FileAccess.file_exists("res://core/cached_world_renderer.gd"),"fixed world renderer exists")
 if failures:quit(1);return
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true
 game.city.add_road(PackedVector2Array([Vector2(20,40),Vector2(80,40)]))
 game.city.add_building_at(Vector2(30.5,42));root.add_child(game);current_scene=game;await settle()
 var render=game.world_renderer
 verify(render!=null and render.actors.y_sort_enabled,"buildings and vehicles share engine y-sort")
 verify(render.buildings.size()==game.city.buildings.size() and render.buildings.values()[0] is Sprite2D,"each building is a retained Sprite2D")
 var road_generation:int=render.road_generation;var grid_generation:int=render.grid_generation;var sorts:int=render.building_sorts
 game.origin+=Vector2(80,40);game.map_zoom*=.7;game.queue_redraw();await settle()
 verify(render.road_generation==road_generation and render.grid_generation==grid_generation and render.building_sorts==sorts,"camera movement/zoom does not rebuild geometry or sort buildings")
 verify(render.position==game.origin and render.scale==Vector2.ONE*game.map_zoom,"camera applies only the world-layer transform")
 game.select_category("build");game.map_zoom=.8;game.refresh();await settle()
 verify(render.zones.visible and render.grid.visible,"zoning mode reveals existing cached fill and line groups")
 game.map_zoom=.2;await settle()
 verify(render.zones.visible and not render.grid.visible and render.grid_generation==grid_generation,"far zoom hides grid outlines without rebuilding cached fills")
 var parcel:Dictionary=game.city.zoning_grid.parcels.values()[0];game.city.zone_designations[parcel.id]="commercial";game.refresh();await settle()
 verify(render.grid_generation==grid_generation+1 and render.road_generation==road_generation,"zone paint invalidates only the zoning layer")
 game.city.add_road(PackedVector2Array([Vector2(20,70),Vector2(80,70)]));game.refresh();await settle()
 verify(render.road_generation==road_generation+1,"road edits rebuild fixed road geometry once")
 game.activate_tool("road");game.road_grid_enabled=false;game.road_drawer.click(Vector2(20,40));game.pointer=Vector2(20,20)
 var first:Dictionary=game.road_drawer.preview();var computations:int=game.road_drawer.preview_computations
 for i in range(10):game.road_drawer.preview()
 verify(game.road_drawer.preview_computations==computations,"stationary cursor does not repeat add_road validation")
 game.origin+=Vector2.ONE;game.map_zoom=.8;game.road_drawer.preview()
 verify(game.road_drawer.preview_computations==computations,"camera transform does not invalidate world-space preview")
 game.city.buildings[0].has_power=not game.city.buildings[0].get("has_power",false);game.road_drawer.preview()
 verify(game.road_drawer.preview_computations==computations,"non-geometric service flags do not repeat road admission")
 game.pointer=Vector2(20,18);game.road_drawer.preview()
 verify(game.road_drawer.preview_computations==computations+1,"cursor movement recomputes validation once")
 verify(game.road_drawer.has_method("legacy_preview"),"retained internal drag mode also has a preview cache")
 if game.road_drawer.has_method("legacy_preview"):
  var legacy:=PackedVector2Array([Vector2(5,5),Vector2(15,5)])
  game.road_drawer.legacy_preview(legacy);var legacy_count:int=game.road_drawer.preview_computations
  game.road_drawer.legacy_preview(legacy);verify(game.road_drawer.preview_computations==legacy_count,"legacy stationary stroke skips repeated admission")
 var old_sorts:int=render.building_sorts;game.city.buildings[0].level+=1;game.city.society_changed.emit();await settle()
 verify(render.building_sorts==old_sorts+1,"same-count building changes update sprites through the existing society event")
 verify(render.display_eligible({"trip_ordinal":0}) and not render.display_eligible({"trip_ordinal":1}) and render.display_eligible({"trip_ordinal":100}),"demand display sampling stays one per hundred trips")
 verify(render.display_eligible({"id":7}),"already sampled authored fleets are not thinned a second time")
 game.city.water.add_facility(Vector2(100,100),"water",1000);game.water_overlay.refresh();await settle()
 var redraws:=[0];game.water_overlay.draw.connect(func():redraws[0]+=1)
 for i in range(10):game.water_overlay.update_state(.016);await process_frame
 verify(redraws[0]==0,"closed water tab does not redraw even with an above-ground facility")
 var old_origin:Vector2=game.water_overlay.paint_origin;var old_zoom:float=game.water_overlay.paint_zoom
 game.origin+=Vector2(20,30);game.map_zoom*=.7;await settle()
 verify(game.water_overlay.position.is_equal_approx(game.origin-old_origin*(game.map_zoom/old_zoom)) and redraws[0]==0,"closed water facilities follow the camera by transform without redraw")
 game.select_category("water");await settle()
 verify(redraws[0]>0,"opening the water tab resumes its network drawing")
 game.origin=Vector2(100000,100000)
 verify(game.traffic.rebuild(game.city.roads),"traffic fixture has real routes")
 game.traffic.seed_traffic();var vehicle_count:int=game.traffic.simulation.vehicles.size()
 var texture_count:int=game.traffic.textures.size();render._process(0)
 game.paused=false;game._process(1.0);game.paused=true;render._process(0)
 verify(vehicle_count>0 and game.traffic.simulation.vehicles[0].distance>0,"offscreen vehicles retain real fixed-step movement and congestion simulation")
 verify(game.traffic.textures.size()==texture_count and render.cars.values().all(func(node):return not node.visible),"offscreen vehicles skip sprite direction/texture display work")
 game.origin=Vector2(300,80);render._process(0)
 verify(render.cars.values().any(func(node):return node.visible and node is Sprite2D),"returning to the viewport restores full car sprites")
 game.map_zoom=.2;render._process(0)
 verify(render.cars.values().any(func(node):return node.visible and node.texture!=null) and game.traffic.simulation.vehicles.size()==vehicle_count,"zoom-out retains cars and never changes simulation population")
 game.queue_free();await process_frame
 print("RESULT %d/%d cached world render checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
