extends SceneTree
const City=preload("res://core/city_model.gd")
const Parcels=preload("res://core/road_parcels.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func fixture():
 var city=City.new(100,100)
 var grid={"origin":Vector2.ZERO,"along":Vector2.RIGHT,"outward":Vector2.DOWN}
 city.add_road(PackedVector2Array([Vector2(20,40),Vector2(60,40),Vector2(60,75)]),"local",true,4,false,false,1,grid)
 city.add_road(PackedVector2Array([Vector2(40,60),Vector2(85,60)]),"local",true,4,false,false,1,grid)
 return city
func run():
 verify(FileAccess.file_exists("res://core/roadside_verges.gd"),"display-only roadside verge geometry exists")
 if failures:quit(1);return
 var city=fixture();var before:=var_to_bytes([city.roads,city.zone_designations,city.zoning_grid.parcels])
 var polygons:Array=load("res://core/roadside_verges.gd").build(city)
 verify(not polygons.is_empty(),"shared-board four-lane L and junction have retained grass strips")
 verify(var_to_bytes([city.roads,city.zone_designations,city.zoning_grid.parcels])==before,"verge builder never mutates roads, grid coordinates or zoning")
 for point in [Vector2(30,37.25),Vector2(30,42.75),Vector2(57.25,50),Vector2(62.75,50)]:
  verify(polygons.any(func(p):return Geometry2D.is_point_in_polygon(point,p)),"both curb sides fill their sub-cell phase gap: "+str(point))
  verify(city.zoning_grid.parcel_at(point).is_empty() and not city.add_building_at(point).ok,"grass strip remains outside all buildable parcels")
 var clean:=true
 for polygon in polygons:
  for p in polygon:clean=clean and p.x>=0 and p.y>=0 and p.x<=city.width and p.y<=city.height
  for road in city.road_pavement+city.junction_pavement:
   for overlap in Geometry2D.intersect_polygons(polygon,road):clean=clean and absf(Parcels.area(overlap))<.0001
  for parcel in city.zoning_grid.parcels_in(Rect2i(Parcels.bounds(polygon).grow(2))):
   for overlap in Geometry2D.intersect_polygons(polygon,parcel.polygon):clean=clean and absf(Parcels.area(overlap))<.0001
 verify(clean,"verges are map-clipped and never paint over roads or actual grid cells")
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game)
 for i in range(5):await process_frame
 verify(game.world_renderer.verges.size()==polygons.size(),"grass belongs to the retained fixed world layer")
 var generation:int=game.world_renderer.road_generation
 game.origin+=Vector2(20,20);game.map_zoom*=.7
 for i in range(5):await process_frame
 verify(game.world_renderer.road_generation==generation,"camera changes do not regenerate grass geometry")
 game.queue_free();await process_frame
 print("RESULT %d/%d roadside verge checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
