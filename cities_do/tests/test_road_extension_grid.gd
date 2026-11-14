extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
static func point(x:float,y:float,axis:int)->Vector2:return Vector2(x,y) if axis==0 else Vector2(y,x)
static func fixture(finish:float,axis:int=0):
 var city=City.new(100,100)
 city.add_road(PackedVector2Array([point(10,30,axis),point(90,30,axis)]),"local",true,4)
 city.add_road(PackedVector2Array([point(50.5,10,axis),point(50.5,finish,axis)]),"local",true,4,false,false,1,city.zoning_lattices[0])
 return city
static func shape_key(polygon:PackedVector2Array)->String:
 var parts:Array[String]=[]
 for p in polygon:parts.append(str(Vector2i((p*10000).round())))
 parts.sort();return "|".join(parts)
static func shapes(city)->Dictionary:
 var result:Dictionary={}
 for parcel in city.zoning_grid.parcels.values():result[shape_key(parcel.polygon)]=true
 return result
func run():
 for axis in [0,1]:
  var wanted:Dictionary=shapes(fixture(75,axis))
  for seam in [46.0,46.5,50.0,50.5]:
   for overlay in [false,true]:
    var city=fixture(seam,axis);var old_roads:=var_to_bytes(city.roads);var old_cells:Dictionary={}
    for parcel in city.zoning_grid.parcels.values():old_cells[parcel.id]=shape_key(parcel.polygon);city.zone_designations[parcel.id]="residential"
    var start:float=seam-4 if overlay else seam
    var result:Dictionary=city.add_road(PackedVector2Array([point(50.5,start,axis),point(50.5,75,axis)]),"local",true,4,false,true,1,city.zoning_lattices[1])
    verify(result.ok and var_to_bytes(city.roads.slice(0,2))==old_roads,"straight continuation/overlay retains authored road records %s/%s/%s"%[axis,seam,overlay])
    verify(shapes(city)==wanted,"one-shot and split road have identical full polygon sets %s/%s/%s"%[axis,seam,overlay])
    var preserved:=true
    for id in old_cells:preserved=preserved and city.zone_designations.get(id)=="residential" and city.zoning_grid.parcels.has(id) and shape_key(city.zoning_grid.parcels[id].polygon)==old_cells[id]
    verify(preserved,"extension preserves every old parcel ID, polygon and designation")
 var city=fixture(50);var built:Dictionary={}
 for parcel in city.zoning_grid.parcels.values():
  if parcel.frame.road_index!=1 or parcel.v!=0 or parcel.u>parcel.frame.columns-2 or parcel.center.y<37 or parcel.center.y>45:continue
  var result:Dictionary=city.add_building_at(parcel.center)
  if result.ok:built=result.building;break
 verify(not built.is_empty(),"preservation fixture uses a legally constructed existing building")
 var before:=var_to_bytes(city.buildings)
 city.add_road(PackedVector2Array([Vector2(50.5,50),Vector2(50.5,75)]),"local",true,4,false,true,1,city.zoning_lattices[1])
 verify(var_to_bytes(city.buildings)==before,"extending a road keeps the full existing building record and footprint unchanged")
 print("RESULT %d/%d road extension grid checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
