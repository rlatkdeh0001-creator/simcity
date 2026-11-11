extends RefCounted
## Separate public inventory: private population and growth never consume these records.
const Balance=preload("res://core/public_balance.gd")
var balance=Balance.new()
var entries: Dictionary={}
var lots: Array[Dictionary]=[]
var owner_reference: WeakRef
var city:
 get:return owner_reference.get_ref()
func _init(owner_city):
 owner_reference=weakref(owner_city)
 var definitions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/economy/public_facilities.json")).facilities
 var catalogs: Dictionary={}
 for definition: Dictionary in definitions:
  if not catalogs.has(definition.catalog):catalogs[definition.catalog]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/%s/catalog.json" % definition.catalog)).facilities
  var catalog: Array=catalogs[definition.catalog]
  for source: Dictionary in catalog:
   if source.id==definition.id:
    var entry: Dictionary=source.duplicate(true);entry.merge(definition,true);entries[entry.id]=entry
func price(id: String) -> float:return balance.number(entries[id].price_key) if entries.has(id) else NAN
func upkeep(id: String) -> float:return balance.number(entries[id].upkeep_key) if entries.has(id) else NAN
func polygon(center: Vector2,width: int,depth: int,turns: int,base_front: Vector2=Vector2.DOWN) -> PackedVector2Array:
 var front:=base_front.rotated(posmod(turns,4)*PI/2)
 var side:=Vector2(front.y,-front.x)
 var a:=center-side*width/2.0-front*depth/2.0
 return PackedVector2Array([a,a+side*width,a+side*width+front*depth,a+front*depth])
func road_anchor(id: String,point: Vector2) -> Dictionary:
 # Temporary two-cell cursor-front acquisition band; actual frontage stays 0.375 cells.
 var best: Dictionary={};var distance_squared:=4.000001
 for road: Dictionary in city.roads:
  if road.kind!="local":continue
  for frame: Dictionary in city.Parcels.blocks(road.points,float(road.width)/2,int(road.get("parcel_id",-1))):
   var offset: Vector2=point-frame.origin
   var along: float=clampf(roundf(offset.dot(frame.along)),0,float(frame.columns))
   var center: Vector2=frame.origin+frame.along*along+frame.outward*float(entries[id].depth)/2
   var candidate_distance: float=point.distance_squared_to(center)
   if candidate_distance<distance_squared:
    distance_squared=candidate_distance;best={"center":center,"front":-Vector2(frame.outward)}
 return best
func preview(id: String,point: Vector2,turns: int=0,snap_to_road: bool=false) -> Dictionary:
 if not entries.has(id) or not point.is_finite():return {"ok":false,"code":"invalid_asset","reason":"invalid_asset"}
 var entry: Dictionary=entries[id];var cost:=price(id);var maintenance:=upkeep(id)
 var center:=point.round();var base_front:=Vector2.DOWN
 var parcel: Dictionary=city.zoning_grid.parcel_at(point)
 if not parcel.is_empty():
  var frame: Dictionary=parcel.frame;var offset: Vector2=point-frame.origin
  center=frame.origin+frame.along*roundf(offset.dot(frame.along))+frame.outward*roundf(offset.dot(frame.outward))
  base_front=-Vector2(frame.outward)
 if snap_to_road:
  var anchor:=road_anchor(id,point)
  if not anchor.is_empty():center=anchor.center;base_front=anchor.front
 var shape:=polygon(center,int(entry.width),int(entry.depth),turns,base_front)
 var record: Dictionary={"id":-1,"public_asset_id":id,"position":center,"polygon":shape,"turns":posmod(turns,4),"front_direction":base_front.rotated(posmod(turns,4)*PI/2),"front_road_id":-1,"utility_id":-1,"engine":entry.engine,"capacity":balance.capacities(id)}
 var response: Dictionary={"ok":false,"code":"","reason":"","record":record,"cost":cost}
 if not is_finite(cost) or cost<0 or floorf(cost)!=cost or not is_finite(maintenance) or maintenance<0:
  response.code="invalid_balance";response.reason=response.code;return response
 for value in record.capacity.values():
  if not is_finite(float(value)) or float(value)<0:response.code="invalid_capacity";response.reason=response.code;return response
 var error: String=city._polygon_error(shape)
 if not error.is_empty():response.code="geometry";response.reason=error;return response
 for candidate: Dictionary in city.Frontage.candidates(shape,city.roads,city.config.road_access_distance):
  if Vector2(candidate.front).dot(record.front_direction)>.999:record.front_road_id=candidate.road;break
 if record.front_road_id<0:response.code="frontage_direction";response.reason=response.code;return response
 if city.utility_balance()<cost:response.code="insufficient_funds";response.reason=response.code;return response
 response.ok=true
 return response
func place(id: String,point: Vector2,turns: int=0,snap_to_road: bool=false) -> Dictionary:
 var result:=preview(id,point,turns,snap_to_road)
 if not result.ok:return result
 var record: Dictionary=result.record
 record.id=city.next_id
 if record.engine=="power":
  record.utility_id=city.power.add_plant(record.position*4,float(record.capacity.get("average_output_kw",NAN)))
  if record.utility_id<0:result.ok=false;result.code="utility_rejected";return result
  for plant: Dictionary in city.power.plants:
   if plant.id==record.utility_id:plant.public_lot_id=record.id;plant.public_polygon=record.polygon
 elif record.engine in ["water","sewage"]:
  var key: String="supply_m3_day" if record.engine=="water" else "sewage_m3_day"
  record.utility_id=city.water.add_facility(record.position*4,record.engine,float(record.capacity.get(key,NAN)))
  if record.utility_id<0:result.ok=false;result.code="utility_rejected";return result
  for facility: Dictionary in city.water.facilities:
   if facility.id==record.utility_id:facility.public_lot_id=record.id;facility.public_polygon=record.polygon
 city.next_id+=1
 lots.append(record)
 city.funds-=int(result.cost)
 city.society_changed.emit()
 return result
func monthly_upkeep() -> int:
 var result:=0
 for record: Dictionary in lots:result+=int(upkeep(record.public_asset_id))
 return result
func bill_months(previous: int,current: int):
 var crossed:=maxi(0,current-previous)
 if crossed>0:city.funds-=crossed*monthly_upkeep()
func remove(id: int) -> bool:
 for index in range(lots.size()):
  if lots[index].id!=id:continue
  var record: Dictionary=lots[index]
  if record.engine=="power" and record.utility_id>=0:city.power.remove_plant(record.utility_id)
  elif record.engine in ["water","sewage"] and record.utility_id>=0:city.water.remove_facility(record.utility_id)
  lots.remove_at(index)
  city.society_changed.emit()
  return true
 return false
