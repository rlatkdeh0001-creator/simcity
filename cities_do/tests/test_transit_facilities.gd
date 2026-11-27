extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 for id in ["bus-stop-01","bus-station-01","train-station-01","subway-entrance-01","park-large-8x8"]:
  check(city.public_facilities.entries.has(id),"placement registered "+id)
 if city.public_facilities.entries.has("train-station-01"):
  city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  var placed:Dictionary=city.public_facilities.place("train-station-01",Vector2(30,33),0,true)
  check(placed.ok,"station places on road")
  check(city.transit_routes.size()==1,"station atomically installs internal rail")
  if placed.ok and not city.transit_routes.is_empty():
   var route:Dictionary=city.transit_routes[0]
   check(route.points[0].distance_to(route.points[-1])==8,"internal track length 32m")
   check(route.get("station_id",-1)==placed.record.id,"track owner is station")
   check(city.TransitRoutes.snap(city,route.points[0]+Vector2(.1,0),"rail").snapped,"station port participates in snap")
   var extension:Dictionary=city.add_transit_route(PackedVector2Array([route.points[0]-Vector2(8,0),route.points[0]]),"rail")
   check(extension.ok,"rail joins station corridor only")
   check(not city.update_transit_route(route.id,route.points+PackedVector2Array()).ok,"internal track cannot detach")
   check(not city.remove_transit_route(route.id).ok,"internal track cannot be separately bulldozed")
   check(city.public_facilities.remove(placed.record.id),"remove station")
   check(city.transit_routes.size()==1 and city.transit_routes[0].id==extension.get("route",{}).get("id",-2),"remove only owned rail preserve extension")
   check(city.public_facilities.place("train-station-01",Vector2(30,33),0,true).ok,"station can reconnect to surviving port extension")
 for lanes in [2,3,4,5,6,7,8]:
  var stop_city=load("res://core/city_model.gd").new(100,100,42)
  stop_city.population_enabled=false;stop_city.happiness_enabled=false
  stop_city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,lanes)
  var road:Dictionary=stop_city.roads[0]
  var curb:=Vector2(30,40-stop_city.RoadProfile.asphalt_width(road)/2)
  var stop:Dictionary=stop_city.public_facilities.place("bus-stop-01",curb,0,true)
  check(stop.ok,"bus stop on sidewalk lanes %d"%lanes)
  if stop.ok:
   check(stop.record.position.distance_to(curb)<.001,"curb origin preserved")
   check(absf(stop_city.Parcels.area(stop.record.polygon)-.36)<.001,"fractional sidewalk footprint")
   check(stop.record.front_road_id==road.parcel_id,"stable host road")
   check(stop_city.roads[0].lanes==lanes,"stop never changes road lanes")
   check(not stop_city.public_facilities.place("bus-stop-01",curb,0,true).ok,"duplicate stop rejected")
   check(not stop_city.public_facilities.preview("bus-stop-01",curb,1,true).ok,"sideways stop rejected")
 for id in ["bus-station-01","subway-entrance-01","park-large-8x8"]:
  var other=load("res://core/city_model.gd").new(100,100,42)
  other.population_enabled=false;other.happiness_enabled=false
  other.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  var depth:float=other.public_facilities.entries[id].depth
  var placed:Dictionary=other.public_facilities.place(id,Vector2(30,37.5-depth/2),0,true)
  check(placed.ok,"facility placement "+id)
  if id=="subway-entrance-01":
   check(other.transit_routes.size()==1,"subway entrance installs platform track")
   if not other.transit_routes.is_empty():check(other.transit_routes[0].kind=="metro" and other.transit_routes[0].points[0].distance_to(other.transit_routes[0].points[-1])==16,"subway platform 64m original length")
  check(other.public_facilities.price(id)==0 and other.public_facilities.upkeep(id)==0,"unapproved fees not charged "+id)
  if placed.ok:
   check(not placed.record.get("effect_enabled",true),"unapproved service effect disabled "+id)
   check(other.public_facilities.remove(placed.record.id),"facility removal "+id)
  other.public_facilities.entries[id].unlock_default=false
  check(not other.public_facilities.preview(id,Vector2(30,37.5-depth/2),0,true).ok,"reversible unlock gate "+id)
 for turn in range(4):
  var rotated=load("res://core/city_model.gd").new(100,100,42)
  rotated.population_enabled=false;rotated.happiness_enabled=false
  var axis:=Vector2.RIGHT.rotated(turn*PI/2);var front:=Vector2.DOWN.rotated(turn*PI/2)
  rotated.add_road(PackedVector2Array([Vector2(50,50)-axis*35,Vector2(50,50)+axis*35]),"local",true,4)
  var placed:Dictionary=rotated.public_facilities.place("train-station-01",Vector2(50,50)-front*7,0,true)
  check(placed.ok,"rotated station %d"%turn)
  if placed.ok:
   check(placed.record.front_direction.distance_to(front)<.001,"road-facing rotated station")
   check(Vector2(placed.record.internal_points[0]).distance_to(placed.record.position-axis*4-front*2.5)<.001,"spec ports rotated with station")
   check(not rotated.add_transit_route(PackedVector2Array([placed.record.position-axis*10,placed.record.position+axis*10]),"rail").ok,"station building not exempt from rail collision")
 print("TRANSIT_FACILITIES checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
