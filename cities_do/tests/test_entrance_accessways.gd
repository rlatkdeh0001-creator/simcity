extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func rotated(point:Vector2,turn:int)->Vector2:return (point-Vector2(50,50)).rotated(turn*PI/2)+Vector2(50,50)
func town(turn:int):
 var city=City.new(100,100);city.population_enabled=false
 assert(city.add_road(PackedVector2Array([rotated(Vector2(20.5,20),turn),rotated(Vector2(20.5,80),turn)])).ok)
 assert(city.add_road(PackedVector2Array([rotated(Vector2(20.5,60.75),turn),rotated(Vector2(90,60.75),turn)]),"local",true,4).ok)
 return city
func run():
 verify(FileAccess.file_exists("res://core/entrance_accessways.gd"),"entrance paving is a separate display-only cached geometry helper")
 if failures:quit(1);return
 var helper=load("res://core/entrance_accessways.gd");var last
 for asset in ["parking-small-2x4","parking-medium-4x4","parking-large-4x8","parking-tower-4x4-4f"]:
  for turn in range(4):
   var city=town(turn);var depth:float=city.public_facilities.entries[asset].depth
   city.funds=maxi(city.funds,int(city.public_facilities.price(asset))+1000)
   var placed:Dictionary=city.public_facilities.place(asset,rotated(Vector2(60,58-depth/2),turn),0,false)
   assert(placed.ok,"valid shared-grid fixture "+asset+" "+str(placed))
   var snapshot:=var_to_bytes([city.roads,city.buildings,city.public_facilities.lots,city.zone_designations,city.zoning_grid.parcels,city.funds])
   var polygons:Array=helper.build(city);var area:=0.0
   for p in polygons:area+=city.Parcels.area(p)
   var count:int=2 if asset in ["parking-medium-4x4","parking-large-4x8"] else 1
   var width:float=(3.65-.35) if asset=="parking-tower-4x4-4f" else ((3.81-1.0) if asset=="parking-small-2x4" else (3.0+7.81-5.0))
   verify(polygons.size()==count,"only measured front openings are connected "+asset+" turn="+str(turn))
   verify(absf(area-width/4*.25)<.001,"paving covers only the one-metre curb gap and entrance span "+asset+" turn="+str(turn))
   verify(snapshot==var_to_bytes([city.roads,city.buildings,city.public_facilities.lots,city.zone_designations,city.zoning_grid.parcels,city.funds]),"paving never moves lots or changes parcel ownership, prices or funds")
   last=city
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.city=last;game.paused=true;root.add_child(game)
 for i in range(5):await process_frame
 var generation:int=game.world_renderer.access_generation
 game.origin+=Vector2(70,40);game.map_zoom=.5
 for i in range(4):await process_frame
 verify(generation==game.world_renderer.access_generation and not game.world_renderer.accessways.is_empty(),"camera changes transform cached accessways without rebuilding them")
 game.city.public_facilities.lots.clear();game.refresh();await process_frame
 verify(game.world_renderer.accessways.is_empty() and game.world_renderer.access_generation==generation+1,"demolishing a lot invalidates only its retained connector geometry")
 game.queue_free();await process_frame
 print("RESULT %d/%d entrance accessway checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
