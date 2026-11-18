extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func finish():
 for failure in failures:printerr("FAIL "+failure)
 print("TRANSIT_ROUTES checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 check(city.has_method("add_transit_route"),"independent transit construction API exists")
 if not city.has_method("add_transit_route"):finish();return
 var points:=PackedVector2Array([Vector2(10,20),Vector2(30,20)])
 var before:=var_to_bytes([city.roads,city.next_road_id,city.zone_designations,city.funds])
 var preview:Dictionary=city.add_transit_route(points,"rail",false)
 check(preview.ok and city.transit_routes.is_empty(),"preview does not allocate routes")
 var added:Dictionary=city.add_transit_route(points,"rail")
 check(added.ok and city.transit_routes.size()==1,"commit independent rail")
 check(is_equal_approx(added.route.width*4,7.6),"rail bed 7.6 metres")
 check(added.route.track_offsets_m==PackedFloat64Array([-2.0,2.0]),"rail tracks plus/minus two metres")
 check(before==var_to_bytes([city.roads,city.next_road_id,city.zone_designations,city.funds]),"no road IDs zoning or money writes")
 check(city.get_transit_route(added.route.id)==added.route,"read by stable transit ID")
 var copy:Dictionary=city.get_transit_route(added.route.id)
 copy.points[0]=Vector2.ZERO
 check(city.get_transit_route(added.route.id).points==points,"read is detached")
 var updated:Dictionary=city.update_transit_route(added.route.id,PackedVector2Array([Vector2(10,22),Vector2(30,22)]))
 check(updated.ok and updated.route.id==added.route.id,"update preserves identity")
 check(city.remove_transit_route(added.route.id).ok and city.transit_routes.is_empty(),"delete route")
 var metro:Dictionary=city.add_transit_route(points,"metro")
 check(metro.ok and metro.route.id>added.route.id,"IDs never reused")
 check(is_equal_approx(metro.route.width*4,12.0) and is_equal_approx(metro.route.rail_top_z_m,-12.7),"metro width and depth")
 check(metro.route.track_offsets_m==PackedFloat64Array([-4.15,4.15]),"metro track spacing")
 var invalids:Array=[PackedVector2Array(),PackedVector2Array([Vector2(2,2)]),PackedVector2Array([Vector2(NAN,2),Vector2(4,2)]),PackedVector2Array([Vector2(-1,2),Vector2(4,2)])]
 for invalid:PackedVector2Array in invalids:
  check(not city.add_transit_route(invalid,"rail").ok,"malformed path rejects without mutation")
 check(not city.add_transit_route(points,"bus").ok,"road vehicle mode is not a physical transit route")
 check(not city.update_transit_route(999,points).ok and not city.remove_transit_route(999).ok,"missing IDs reject")
 var edge_city=load("res://core/city_model.gd").new(100,100,42)
 edge_city.add_transit_route(PackedVector2Array([Vector2(0,0),Vector2(10,10)]),"rail")
 edge_city.add_transit_route(PackedVector2Array([Vector2(10,0),Vector2(30,0)]),"rail")
 check(edge_city.external_infrastructure.is_empty(),"corner and boundary-parallel routes do not open neighbor channels")
 var boundary:Dictionary=edge_city.add_transit_route(PackedVector2Array([Vector2(0,40),Vector2(100,40)]),"metro")
 check(boundary.ok and edge_city.external_infrastructure.size()==1,"opposite terminals share one route-owned link")
 var active:=0
 for town:Dictionary in edge_city.regional_exchange().neighbors:
  if town.channels.metro.connected:active+=1
 check(active==2,"opposite route connects exactly two neighbors")
 var link_id:int=edge_city.external_infrastructure[0].id
 edge_city.update_transit_route(boundary.route.id,PackedVector2Array([Vector2(0,42),Vector2(100,42)]))
 check(edge_city.external_infrastructure[0].id==link_id,"boundary update preserves external link identity")
 finish()
