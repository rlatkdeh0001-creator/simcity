extends SceneTree
var Routes=load("res://core/transit_routes.gd")
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func arc(radius_m:float)->PackedVector2Array:
 var points:=PackedVector2Array()
 for i in range(33):points.append(Vector2(40,40)+Vector2.from_angle(float(i)*PI/64)*radius_m/4)
 return points
func contact_order_parity():
 var View=load("res://core/transit_view.gd")
 var branch:=PackedVector2Array([Vector2(40,10),Vector2(40,30)])
 var hosts:Array[PackedVector2Array]=[
  PackedVector2Array([Vector2(10,30),Vector2(70,30)]),
  PackedVector2Array([Vector2(10,30),Vector2(40,30),Vector2(70,30)]),
  PackedVector2Array([Vector2(40,30),Vector2(70,30)])]
 for kind in ["rail","metro"]:
  for host in hosts:
   for order in range(2):
    var city=load("res://core/city_model.gd").new(100,100,42)
    var first:PackedVector2Array=branch if order==0 else host
    var second:PackedVector2Array=host if order==0 else branch
    var label:="%s host_samples=%d order=%d"%[kind,host.size(),order]
    var added:Dictionary=city.add_transit_route(first,kind)
    check(added.ok,"contact fixture "+label)
    var before:=var_to_bytes([city.transit_routes,city.next_transit_route_id])
    var preview:Dictionary=city.add_transit_route(second,kind,false)
    check(not preview.ok and preview.get("code")=="curve","sharp contact preview rejects "+label)
    var result:Dictionary=city.add_transit_route(second,kind)
    check(not result.ok and result.get("code")=="curve","sharp contact commit rejects "+label)
    check(before==var_to_bytes([city.transit_routes,city.next_transit_route_id]),"rejected contact atomic "+label)
    if order==0:
     check(View.terminal(city,city.get_transit_route(added.route.id),1),"rejected host preserves branch end buffer "+label)
    # Updating either participant must obey the same rule, excluding only itself.
    city=load("res://core/city_model.gd").new(100,100,42)
    city.add_transit_route(first,kind)
    var detached:=PackedVector2Array([Vector2(10,80),Vector2(70,80)])
    var moving:Dictionary=city.add_transit_route(detached,kind)
    check(moving.ok,"update fixture "+label)
    before=var_to_bytes([city.transit_routes,city.next_transit_route_id])
    for commit in [false,true]:
     var updated:Dictionary=city.update_transit_route(moving.route.id,second,commit)
     check(not updated.ok and updated.get("code")=="curve","sharp contact update rejects %s commit=%s"%[label,commit])
     check(before==var_to_bytes([city.transit_routes,city.next_transit_route_id]),"rejected update atomic "+label)
func valid_contact_parity():
 var View=load("res://core/transit_view.gd")
 var host:=PackedVector2Array([Vector2(10,30),Vector2(70,30)])
 var sampled:=PackedVector2Array([Vector2(10,30),Vector2(40,30),Vector2(70,30)])
 var branch:=PackedVector2Array([Vector2(20,28),Vector2(40,30)])
 var cases:Array=[
  [host,PackedVector2Array([Vector2(70,30),Vector2(90,30)]),"straight extension"],
  [host,PackedVector2Array([Vector2(70,30),Vector2(90,32)]),"smooth endpoint join"],
  [host,branch,"smooth interior join"],
  [sampled,branch,"smooth sampled vertex join"],
  [host,PackedVector2Array([Vector2(40,10),Vector2(40,50)]),"interior crossing"]]
 for kind in ["rail","metro"]:
  for pair in cases:
   for order in range(2):
    var first:PackedVector2Array=pair[order]
    var second:PackedVector2Array=pair[1-order]
    var label:="%s %s order=%d"%[kind,pair[2],order]
    var city=load("res://core/city_model.gd").new(100,100,42)
    check(city.add_transit_route(first,kind).ok,"valid fixture "+label)
    var preview:Dictionary=city.add_transit_route(second,kind,false)
    var added:Dictionary=city.add_transit_route(second,kind)
    check(preview.ok and added.ok and city.transit_routes.size()==2,"valid contact both admission paths "+label)
    if added.ok and pair[2]=="straight extension":
     var route:Dictionary=city.get_transit_route(added.route.id)
     check(not View.terminal(city,route,0 if order==0 else 1),"joined endpoint has no buffer "+label)
    city=load("res://core/city_model.gd").new(100,100,42)
    city.add_transit_route(first,kind)
    var moving:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(10,80),Vector2(70,80)]),kind)
    var before:=var_to_bytes(city.transit_routes)
    var update_preview:Dictionary=city.update_transit_route(moving.route.id,second,false)
    check(update_preview.ok and before==var_to_bytes(city.transit_routes),"valid update preview detached "+label)
    var updated:Dictionary=city.update_transit_route(moving.route.id,second)
    check(updated.ok and updated.route.id==moving.route.id and city.get_transit_route(moving.route.id).points==second,"valid update keeps identity "+label)
 # Different modes may touch without creating a same-mode joint.
 for order in range(2):
  var city=load("res://core/city_model.gd").new(100,100,42)
  var kinds:=["rail","metro"]
  city.add_transit_route(host,kinds[order])
  check(city.add_transit_route(PackedVector2Array([Vector2(40,10),Vector2(40,30)]),kinds[1-order]).ok,"different modes keep independent contact policy")
func run():
 contact_order_parity()
 valid_contact_parity()
 var city=load("res://core/city_model.gd").new(100,100,42)
 check(not city.add_transit_route(arc(33.5),"rail",false).ok,"inner radius below 32m rejected")
 check(city.add_transit_route(arc(34.0),"rail",false).ok,"centre radius 34m accepted")
 check(not city.add_transit_route(PackedVector2Array([Vector2(10,10),Vector2(40,10),Vector2(40,40)]),"rail",false).ok,"sharp corner not a smooth curve")
 check(not city.add_transit_route(PackedVector2Array([Vector2(10,10),Vector2(10,10),Vector2(20,10)]),"rail",false).ok,"duplicate samples rejected")
 var building:Dictionary={"id":40,"x":20,"y":20,"size":2,"zone":"residential","level":1}
 city.buildings.append(building)
 for kind in ["rail","metro"]:
  check(not city.add_transit_route(PackedVector2Array([Vector2(10,21),Vector2(30,21)]),kind,false).ok,"building collision "+kind)
 city.buildings.clear()
 city.public_facilities.lots.append({"id":41,"polygon":PackedVector2Array([Vector2(20,20),Vector2(22,20),Vector2(22,22),Vector2(20,22)])})
 check(not city.add_transit_route(PackedVector2Array([Vector2(10,21),Vector2(30,21)]),"rail",false).ok,"public footprint collision")
 city.public_facilities.lots.clear()
 city.add_road(PackedVector2Array([Vector2(10,30),Vector2(70,30)]))
 var road_snapshot:=var_to_bytes([city.roads,city.next_road_id,city.zoning_grid.parcels,city.zone_designations])
 var cross:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(40,10),Vector2(40,50)]),"rail")
 check(cross.ok,"transverse road crossing allowed")
 check(not city.add_transit_route(PackedVector2Array([Vector2(20,30),Vector2(60,30)]),"rail",false).ok,"rail cannot run along road centre")
 check(not city.add_transit_route(PackedVector2Array([Vector2(20,31),Vector2(60,31)]),"rail",false).ok,"parallel road overlap rejected")
 check(city.add_transit_route(PackedVector2Array([Vector2(20,30),Vector2(60,30)]),"metro",false).ok,"underground road overlap allowed")
 check(road_snapshot==var_to_bytes([city.roads,city.next_road_id,city.zoning_grid.parcels,city.zone_designations]),"transit never regenerates road parcels")
 check(city._polygon_error(PackedVector2Array([Vector2(39,32),Vector2(41,32),Vector2(41,34),Vector2(39,34)]))!="","future building cannot occupy rail")
 var update:Dictionary=city.update_transit_route(cross.route.id,PackedVector2Array([Vector2(-1,0),Vector2(10,0)]))
 check(not update.ok and city.get_transit_route(cross.route.id)==cross.route,"failed update atomic")
 check(Routes.has_method("resolve"),"three-mode geometry resolver exists")
 if Routes.has_method("resolve"):
  var straight:Dictionary=Routes.call("resolve",city,"rail","straight",PackedVector2Array([Vector2(10,60)]),Vector2(15.3,60))
  check(straight.ok and is_equal_approx(Routes.Paths.length_of(straight.points),6),"8m independent length units")
  var connection:Dictionary=Routes.call("resolve",city,"rail","straight",PackedVector2Array([Vector2(40.2,50.2)]),Vector2(40,60.1))
  check(connection.ok and connection.points[0]==Vector2(40,50),"same mode endpoint snap and continuation")
  var incompatible:Dictionary=Routes.call("snap",city,Vector2(40.2,50.2),"metro")
  check(not incompatible.get("snapped",false),"metro never snaps to rail or roads")
  var curve:Dictionary=Routes.call("resolve",city,"rail","curve",PackedVector2Array([Vector2(10,60),Vector2(30,60)]),Vector2(30,80))
  check(curve.ok and curve.points.size()>2,"quadratic mode generates constrained smooth path")
  var free:Dictionary=Routes.call("resolve",city,"rail","free",PackedVector2Array([Vector2(10,60)]),Vector2(30,80),Vector2.RIGHT)
  check(free.ok and free.points.size()>2,"free mode inherits start tangent")
 # Reciprocal admission: road built after rail must obey the same crossing rule.
 var reverse=load("res://core/city_model.gd").new(100,100,42)
 reverse.add_transit_route(PackedVector2Array([Vector2(10,30),Vector2(70,30)]),"rail")
 check(not reverse.add_road(PackedVector2Array([Vector2(20,30),Vector2(60,30)]),"local",false).ok,"road cannot cover an existing rail")
 check(reverse.add_road(PackedVector2Array([Vector2(40,10),Vector2(40,50)]),"local",false).ok,"road crosses existing rail without altering it")
 check(not reverse.add_transit_route(PackedVector2Array([Vector2(70,30),Vector2(70,50)]),"rail",false).ok,"endpoint joint cannot bypass curve radius with a corner")
 check(not reverse.add_transit_route(PackedVector2Array([Vector2(30,30),Vector2(50,30)]),"rail",false).ok,"duplicate collinear coverage rejected")
 check(not reverse.add_transit_route(PackedVector2Array([Vector2(40,30),Vector2(40,50)]),"rail",false).ok,"mid-route branch cannot bypass radius with a corner")
 check(reverse.add_transit_route(PackedVector2Array([Vector2(70,30),Vector2(90,30)]),"rail",false).ok,"tangent extension accepted")
 reverse.update_transit_route(1,PackedVector2Array([Vector2(10,30),Vector2(40,30),Vector2(70,30)]))
 check(not reverse.add_transit_route(PackedVector2Array([Vector2(40,30),Vector2(40,50)]),"rail",false).ok,"sample vertex branch cannot bypass radius")
 for failure in failures:printerr("FAIL "+failure)
 print("TRANSIT_GEOMETRY checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
