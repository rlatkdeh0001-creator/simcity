extends RefCounted
## Geometry remains GDScript; managed state evaluates happiness and the ID%75 growth schedule.
var owner:WeakRef
var core=preload("res://simulation/HappinessCore.cs").new()
var dirty:=true
var last_count:=-1
var signature:=-1
var records:Dictionary={}
var bound
var city_average:Variant=null
func _init(city):
 owner=weakref(city)
 core.Configure(JSON.parse_string(FileAccess.get_file_as_string("res://core/happiness_config.json")))
 core.BindPopulation(city.population.core);bound=city.population.core
func mark_dirty():dirty=true
func _shape(shape:PackedVector2Array)->PackedVector2Array:
 var result:=PackedVector2Array()
 for point in shape:result.append(point*4)
 return result
func _center(shape:PackedVector2Array)->Vector2:
 var result:=Vector2.ZERO
 for point in shape:result+=point
 return result/maxi(1,shape.size())
func _rebuild(city):
 var buildings:Array=[];var facilities:Array=[];records.clear()
 for b:Dictionary in city.buildings:
  records[b.id]=b
  var polygon:PackedVector2Array=city.footprint(b);var noise:=false
  for road:Dictionary in city.roads:
   if int(road.get("lanes",2))>=4 and city._polygon_road_distance(polygon,road)<=city.config.road_access_distance+.00001:noise=true;break
  buildings.append({"id":b.id,"road":b.get("front_road_id",-1),"level":b.level,"zone":b.zone,"position":_center(polygon)*4,"polygon":_shape(polygon),"power":b.get("has_power",false),"water":b.get("has_water",false),"noise":noise})
 for f:Dictionary in city.public_facilities.lots:
  var asset:String=f.public_asset_id;var kind:="";var capacity:=0.0;var school:=0
  if asset.begins_with("medical-"):kind="health";capacity=float(f.capacity.get("outpatient_day",0))
  elif asset.contains("police-station"):kind="police";capacity=float(f.capacity.get("population_capacity",0))
  elif asset.contains("fire-station"):kind="fire";capacity=float(f.capacity.get("simultaneous_incidents",0))
  elif asset in ["elementary-school","high-school","technical-college","university"]:
   kind="education";school=["elementary-school","high-school","technical-college","university"].find(asset);capacity=float(f.capacity.get("students",0))
  elif asset.begins_with("park-"):kind="park"
  elif asset in ["power-coal","power-oil","waste-incinerator"]:kind="pollution"
  if not kind.is_empty():facilities.append({"id":f.id,"road":f.get("front_road_id",-1),"position":f.position*4,"polygon":_shape(f.polygon),"kind":kind,"capacity":capacity,"school_stage":school})
 var edges:=PackedFloat64Array()
 var topology:Dictionary=city.RoadJunctions.analyze(city.roads)
 for section:Dictionary in topology.sections:
  var points:PackedVector2Array=section.points.duplicate()
  points[0]=topology.nodes[section.start_node].position;points[-1]=topology.nodes[section.end_node].position
  var road_id:int=city.roads[section.road].get("parcel_id",section.road)
  for i in range(1,points.size()):edges.append_array(PackedFloat64Array([road_id,points[i-1].x*4,points[i-1].y*4,points[i].x*4,points[i].y*4]))
 core.SetWorld(buildings,facilities,edges);last_count=city.buildings.size();dirty=false
func advance(game_seconds:float)->void:
 if not is_finite(game_seconds) or game_seconds<=0:return
 var city=owner.get_ref()
 if city==null or not city.population.has_method("backend_name"):return
 if bound!=city.population.core:core.BindPopulation(city.population.core);bound=city.population.core;dirty=true
 var current:int=hash([city.roads,city.public_facilities.lots])
 if dirty or last_count!=city.buildings.size() or current!=signature:_rebuild(city);signature=current
 var supplies:=PackedInt64Array();supplies.resize(city.buildings.size()*3);var offset:=0
 for b:Dictionary in city.buildings:
  supplies[offset]=b.id;supplies[offset+1]=int(b.get("has_power",false));supplies[offset+2]=int(b.get("has_water",false));offset+=3
 var result:Dictionary=core.Tick(game_seconds,supplies)
 city_average=null if result.city_happiness==null else roundi(float(result.city_happiness))
 for id in result.updates:
  if not records.has(id):continue
  var b:Dictionary=records[id];var values:Dictionary=result.updates[id]
  b.happiness=values.actual;b.happiness_target=values.target;b.happiness_factors=values.factors
 for id in result.upgrades:
  if not records.has(id):continue
  var b:Dictionary=records[id];var changed:bool=city._upgrade(b)
  core.Acknowledge(id,changed,b.level)
  if changed:city.population.sync(city.buildings);dirty=true
