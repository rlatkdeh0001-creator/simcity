extends RefCounted
## Separate public inventory: private population and growth never consume these records.
const Balance=preload("res://core/public_balance.gd")
var balance=Balance.new()
var entries: Dictionary={}
var lots: Array[Dictionary]=[]
var subway_platform:Dictionary={}
var owner_reference: WeakRef
var city:
 get:return owner_reference.get_ref()
func _init(owner_city):
 owner_reference=weakref(owner_city)
 var definitions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/economy/public_facilities.json")).facilities
 definitions.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/economy/transit_facilities.json")).facilities)
 var catalogs: Dictionary={}
 for definition: Dictionary in definitions:
  if not catalogs.has(definition.catalog):catalogs[definition.catalog]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/%s/catalog.json" % definition.catalog)).facilities
  var catalog: Array=catalogs[definition.catalog]
  for source: Dictionary in catalog:
   if source.id==definition.id:
    var entry: Dictionary=source.duplicate(true);entry.merge(definition,true);entries[entry.id]=entry
 for source:Dictionary in catalogs.get("facilities",[]):
  if source.id=="subway-platform-silhouette-01":subway_platform=source.duplicate(true)
func price(id: String) -> float:
 if not entries.has(id):return NAN
 return float(entries[id].construction_default) if entries[id].has("construction_default") else balance.number(entries[id].price_key)
func upkeep(id: String) -> float:
 if not entries.has(id):return NAN
 return float(entries[id].upkeep_default) if entries[id].has("upkeep_default") else balance.number(entries[id].upkeep_key)
func polygon(center: Vector2,width: float,depth: float,turns: int,base_front: Vector2=Vector2.DOWN) -> PackedVector2Array:
 var front:=base_front.rotated(posmod(turns,4)*PI/2)
 var side:=Vector2(front.y,-front.x)
 var a:=center-side*width/2.0-front*depth/2.0
 return PackedVector2Array([a,a+side*width,a+side*width+front*depth,a+front*depth])
func sidewalk_anchor(entry:Dictionary,point:Vector2,fixed_front:Vector2=Vector2.ZERO)->Dictionary:
 var retained:=fixed_front!=Vector2.ZERO
 var best:Dictionary={};var distance:=0.0001 if retained else 2.0
 for road:Dictionary in city.roads:
  if road.kind!="local":continue
  var asphalt:float=city.RoadProfile.asphalt_width(road)
  if (float(road.width)-asphalt)*2+0.0001<float(entry.required_sidewalk_width_m):continue
  for i in range(1,road.points.size()):
   var a:Vector2=road.points[i-1];var b:Vector2=road.points[i]
   var axis:Vector2=(b-a).normalized();var length:float=a.distance_to(b)
   var half:float=float(entry.width)/2
   if length<float(entry.width):continue
   var projected:float=(point-a).dot(axis)
   var along:float=clampf(projected if retained else roundf(projected),half,length-half)
   for sign_value:int in [-1,1]:
    var outward:=Vector2(-axis.y,axis.x)*sign_value
    if retained and (-outward).dot(fixed_front)<.999:continue
    var curb:Vector2=a+axis*along+outward*asphalt/2
    var gap:=point.distance_to(curb)
    if gap<distance:
     distance=gap;best={"position":curb,"front":-outward,"road_id":road.parcel_id,"direction":sign_value}
 return best
func refresh_road_bindings() -> void:
 # A retained curb is not a new placement: never snap it to a nearby road/end.
 for record:Dictionary in lots:
  var entry:Dictionary=entries.get(record.public_asset_id,{})
  if entry.get("placement_surface","")!="sidewalk_only":continue
  var anchor:=sidewalk_anchor(entry,record.position,record.front_direction)
  record.front_road_id=anchor.get("road_id",-1)
  record.road_direction=anchor.get("direction",0)
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
 if not entry.get("unlock_default",true):return {"ok":false,"code":"locked","reason":"아직 사용할 수 없습니다"}
 var center:=point.round();var base_front:=Vector2.DOWN
 var sidewalk:bool=entry.get("placement_surface","")=="sidewalk_only"
 var stop_anchor:Dictionary={}
 var parcel: Dictionary=city.zoning_grid.parcel_at(point)
 if not parcel.is_empty():
  var frame: Dictionary=parcel.frame;var offset: Vector2=point-frame.origin
  center=frame.origin+frame.along*roundf(offset.dot(frame.along))+frame.outward*roundf(offset.dot(frame.outward))
  base_front=-Vector2(frame.outward)
 if snap_to_road:
  var anchor:=road_anchor(id,point)
  if not anchor.is_empty():center=anchor.center;base_front=anchor.front
 if sidewalk:
  stop_anchor=sidewalk_anchor(entry,point)
  if stop_anchor.is_empty():return {"ok":false,"code":"sidewalk","reason":"보도 위에 배치하세요"}
  center=stop_anchor.position;base_front=stop_anchor.front
 var shape:=polygon(center-base_front*float(entry.depth)/2 if sidewalk else center,float(entry.width),float(entry.depth),turns,base_front)
 var record: Dictionary={"id":-1,"public_asset_id":id,"position":center,"polygon":shape,"turns":posmod(turns,4),"front_direction":base_front.rotated(posmod(turns,4)*PI/2),"front_road_id":-1,"utility_id":-1,"engine":entry.engine,"capacity":balance.capacities(id)}
 record.effect_enabled=entry.get("effect_enabled",true)
 var response: Dictionary={"ok":false,"code":"","reason":"","record":record,"cost":cost}
 if city.loans.bankrupt:response.code="bankrupt";response.reason="파산 · 게임 오버";return response
 if cost>0 and city.treasury_balance()<0:response.code="insufficient_funds";response.reason="자금 부족";return response
 if not is_finite(cost) or cost<0 or floorf(cost)!=cost or not is_finite(maintenance) or maintenance<0:
  response.code="invalid_balance";response.reason=response.code;return response
 for value in record.capacity.values():
  if not is_finite(float(value)) or float(value)<0:response.code="invalid_capacity";response.reason=response.code;return response
 if sidewalk:
  record.front_road_id=stop_anchor.road_id;record.road_direction=stop_anchor.direction
  record.curb_point=center
  if posmod(turns,4)!=0:response.code="frontage_direction";response.reason="도로를 향해 배치하세요";return response
 if id=="train-station-01":
  var connection:Dictionary=city.TransitRoutes.station_ports(entry,record.position,record.front_direction)
  if not connection.ok:return connection
  record.station_ports=connection.ports;record.internal_points=connection.points;record.internal_kind="rail"
 elif id=="subway-entrance-01":
  var front:Vector2=record.front_direction;var side:=Vector2(front.y,-front.x)
  var half:float=float(subway_platform.width_m)/8
  record.internal_points=PackedVector2Array([record.position-side*half,record.position+side*half]);record.internal_kind="metro"
  record.station_ports=[{"kind":"metro","point":record.internal_points[0],"outward":-side,"rail_top_z_m":-12.7},{"kind":"metro","point":record.internal_points[1],"outward":side,"rail_top_z_m":-12.7}]
  var tunnel:Dictionary=city.TransitRoutes.plan(city,record.internal_points,"metro")
  if not tunnel.ok:return tunnel
 var error: String=city._polygon_error(shape,-1,true,int(record.front_road_id) if sidewalk else -1,record.get("internal_points",PackedVector2Array()),id.begins_with("park-"))
 if not error.is_empty():response.code="geometry";response.reason=error;return response
 for candidate: Dictionary in ([] if sidewalk else city.Frontage.candidates(shape,city.roads,city.config.road_access_distance)):
  if Vector2(candidate.front).dot(record.front_direction)>.999:record.front_road_id=candidate.road;break
 if record.front_road_id<0:response.code="frontage_direction";response.reason=response.code;return response
 if city.utility_balance()<cost:response.code="insufficient_funds";response.reason=response.code;return response
 response.ok=true
 return response
func place(id: String,point: Vector2,turns: int=0,snap_to_road: bool=false) -> Dictionary:
 if city._defer_simulation_edit(place.bind(id,point,turns,snap_to_road)):return city._queued_simulation_edit()
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
 if record.has("internal_points"):
  var route:Dictionary=city.TransitRoutes.profile(record.get("internal_kind","rail"))
  route.points=record.internal_points.duplicate();route.id=city.next_transit_route_id;route.station_id=record.id
  record.internal_route_id=route.id
  city.next_transit_route_id+=1;city.transit_routes.append(route)
  city._transit_routes_changed()
 city.funds-=int(result.cost)
 city._simulation_world_changed()
 city.society_changed.emit()
 return result
func monthly_upkeep() -> int:
 var result:=0
 for record: Dictionary in lots:result+=int(upkeep(record.public_asset_id))
 return result
func bill_months(previous: int,current: int):
 if city.simulation!=null:return # Worker clock already bills; public clock is display only.
 var crossed:=maxi(0,current-previous)
 if crossed>0:
  var charge:=monthly_upkeep()
  city._upkeep_day=current;city._upkeep_per_day=float(charge)
  city.funds-=crossed*charge
func remove(id: int) -> bool:
 if city._defer_simulation_edit(remove.bind(id)):return true
 for index in range(lots.size()):
  if lots[index].id!=id:continue
  var record: Dictionary=lots[index]
  if record.engine=="power" and record.utility_id>=0:city.power.remove_plant(record.utility_id)
  elif record.engine in ["water","sewage"] and record.utility_id>=0:city.water.remove_facility(record.utility_id)
  lots.remove_at(index)
  if record.has("internal_route_id"):
   for i in range(city.transit_routes.size()-1,-1,-1):
    if city.transit_routes[i].get("station_id",-1)==id:city.transit_routes.remove_at(i)
   city._transit_routes_changed()
  city._simulation_world_changed()
  city.society_changed.emit()
  return true
 return false
