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
var _read_view # Immutable full-city publication, never a mutable worker-core alias.
func attach_read_view(view):
 assert(view!=null)
 _read_view=view
func detach_read_view():_read_view=null
func has_read_view()->bool:return _read_view!=null
func published_read_view():return _read_view
func inspect(id:int)->Dictionary:return _read_view.Inspect(id) if _read_view!=null else core.Inspect(id)
func preview(id:int)->Dictionary:return _read_view.Preview(id) if _read_view!=null else core.Preview(id)
var background_enabled:=false
var supply_changes:Dictionary={}
func note_supply(building:Dictionary):
 if _read_view!=null:return
 supply_changes[building.id]=PackedInt64Array([building.id,int(building.get("has_power",false)),int(building.get("has_water",false))])
func average_value()->Variant:
 if _read_view!=null:
  var published:Variant=_read_view.CityHappiness()
  return null if published==null else roundi(float(published))
 if not background_enabled:return city_average
 var value:Variant=core.CityHappiness()
 return null if value==null else roundi(float(value))
func enable_background():
 assert(_read_view==null,"Full-city worker cannot nest a main happiness worker")
 if background_enabled:return
 var city=owner.get_ref()
 if city!=null:city.population.enable_geometry_transport(city.buildings)
 core.EnableBackground();background_enabled=true;dirty=true;supply_changes.clear()
func background_busy()->bool:
 return background_enabled and core.IsBackgroundBusy()
func skip_background_cycle():
 if background_enabled:core.RecordSkippedBackgroundCycle()
func suspend_background():
 if background_enabled:core.SuspendBackground()
func materialize_values(building_values:Array):
 # Explicit compatibility/readout only; normal background publication swaps one buffer.
 for b:Dictionary in building_values:
  var values:Dictionary=inspect(b.id)
  if values.is_empty() or not values.get("initialized",false):continue
  b.happiness=values.actual;b.happiness_target=values.target;b.happiness_factors=values.factors
func publish_boundary()->bool:
 if not background_enabled:return false
 var result:Dictionary=core.PublishBackgroundTick()
 if result.is_empty():return false
 _apply_result(result,false)
 return true
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
 core.SetWorld(buildings,facilities,edges);last_count=city.buildings.size();dirty=false;supply_changes.clear()
func advance(game_seconds:float)->void:
 assert(_read_view==null,"Main happiness simulation must not run while full-city worker owns it")
 if not is_finite(game_seconds) or game_seconds<=0:return
 if background_enabled:
  if background_busy():skip_background_cycle();return
  publish_boundary()
 var city=owner.get_ref()
 if city==null or not city.population.has_method("backend_name"):return
 if bound!=city.population.core:core.BindPopulation(city.population.core);bound=city.population.core;dirty=true
 var current:int=hash([city.roads,city.public_facilities.lots])
 if dirty or last_count!=city.buildings.size() or current!=signature:_rebuild(city);signature=current
 var supplies:=PackedInt64Array()
 if background_enabled:
  for change:PackedInt64Array in supply_changes.values():supplies.append_array(change)
  supply_changes.clear()
 else:
  # Synchronous compatibility fixtures may directly mutate building dictionaries.
  supplies.resize(city.buildings.size()*3);var offset:=0
  for b:Dictionary in city.buildings:
   supplies[offset]=b.id;supplies[offset+1]=int(b.get("has_power",false));supplies[offset+2]=int(b.get("has_water",false));offset+=3
 supply_changes.clear()
 if background_enabled:
  assert(core.SubmitBackgroundTick(game_seconds,supplies),"one logical happiness job per accepted boundary")
 else:_apply_result(core.Tick(game_seconds,supplies),true)
func _apply_result(result:Dictionary,materialize:bool):
 var city=owner.get_ref()
 if city==null:return
 city_average=null if result.city_happiness==null else roundi(float(result.city_happiness))
 if materialize:
  for id in result.updates:
   if not records.has(id):continue
   var b:Dictionary=records[id];var values:Dictionary=result.updates[id]
   b.happiness=values.actual;b.happiness_target=values.target;b.happiness_factors=values.factors
 for id in result.upgrades:
  if not records.has(id):continue
  var b:Dictionary=records[id]
  if not city.buildings.has(b):core.Acknowledge(id,false,b.level);continue
  var changed:bool=city._upgrade(b)
  core.Acknowledge(id,changed,b.level)
  if changed:city.population.sync(city.buildings);dirty=true
