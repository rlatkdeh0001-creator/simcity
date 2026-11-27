extends SceneTree
## Second review: physical placement transactions and retained rail elevation.
const City = preload("res://core/city_model.gd")
const Routes = preload("res://core/transit_routes.gd")
const Height = preload("res://core/road_height.gd")
var passed := 0
var failed := 0

func _initialize():
 run.call_deferred()

func check(ok: bool, label: String):
 if ok:
  passed += 1
  print("PASS ", label)
 else:
  failed += 1
  printerr("FAIL ", label)

func new_city():
 var city = City.new(180, 150, 20261126)
 city.population_enabled = false
 city.happiness_enabled = false
 city.funds = 100000000
 return city

func rail_reedit():
 var city = new_city()
 var original := PackedVector2Array([Vector2(10,40), Vector2(82,40), Vector2(154,40)])
 var made: Dictionary = city.add_transit_route(original, "rail", true, PackedFloat64Array([0,10,10]))
 check(made.ok, "build the ramp and 10m deck before editing")
 if not made.ok:return
 var id: int = made.route.id
 var edited := PackedVector2Array([Vector2(10,42), Vector2(46,42), Vector2(100,42), Vector2(154,42)])
 var before := var_to_bytes(city.transit_routes)
 var preview: Dictionary = city.update_transit_route(id, edited, false)
 check(var_to_bytes(city.transit_routes)==before, "rail preview does not mutate the original route")
 check(preview.ok and Routes.raised(preview.route) and not preview.route.get("piers",[]).is_empty(), "adding samples keeps the route on piers")
 if preview.ok:
  check(is_equal_approx(Height.height_at(preview.route,Vector2(46,42)),5) and is_equal_approx(Height.height_at(preview.route,Vector2(82,42)),10) and is_equal_approx(Height.height_at(preview.route,Vector2(154,42)),10), "resampling keeps the ramp and its transition to flat +10m")
 var placed: Dictionary = city.update_transit_route(id, edited)
 check(placed.ok and placed.route==preview.get("route",{}) and city.get_transit_route(id)==placed.route, "commit matches preview, including heights, support plan and route ID")
 var reduced := PackedVector2Array([Vector2(10,44),Vector2(154,44)])
 var changed: Dictionary = city.update_transit_route(id,reduced)
 check(changed.ok and changed.route.get("heights_m",PackedFloat64Array())==PackedFloat64Array([0,10,10]), "removing author samples keeps the grade break as a vertex")
 var compressed := PackedVector2Array([Vector2(10,42),Vector2(11,42),Vector2(54,42),Vector2(70,42)])
 before = var_to_bytes(city.transit_routes)
 var rejected: Dictionary = city.update_transit_route(id, compressed)
 check(not rejected.ok and rejected.get("code")=="grade" and var_to_bytes(city.transit_routes)==before, "too-short reedit rejects invalid grade without flattening or mutating")
 var flat := PackedVector2Array([Vector2(10,84),Vector2(90,84)])
 var flat_route: Dictionary = city.add_transit_route(flat,"rail",true,PackedFloat64Array([15,15]))
 var moved: Dictionary = city.update_transit_route(flat_route.route.id,PackedVector2Array([Vector2(12,86),Vector2(22,86),Vector2(100,86)])) if flat_route.ok else {}
 check(moved.get("ok",false) and moved.route.get("heights_m",PackedFloat64Array())==PackedFloat64Array([15,15,15]), "a flat elevated track keeps its authored +15m at every new sample")
 check(Routes.snapshot_error(city.transit_routes,180,150).is_empty(), "all edited records remain valid for worker snapshot transport")

func piers():
 var deck := PackedVector2Array([Vector2(20,60),Vector2(108,60)])
 for rail_deck: bool in [false,true]:
  var city = new_city()
  var made: Dictionary = city.add_transit_route(deck,"rail",true,PackedFloat64Array([20,20])) if rail_deck else city.add_elevated_road(deck,PackedFloat64Array([20,20]))
  var label := "rail viaduct" if rail_deck else "road viaduct"
  check(made.ok and made.get("piers",[]).size()>=3, label+": real supports were placed")
  if not made.ok or made.get("piers",[]).size()<3:continue
  var x: float = made.piers[1].positions[0].x
  var clear_x: float = (x+made.piers[2].positions[0].x)*.5
  var conflict := PackedVector2Array([Vector2(x,30),Vector2(x,90)])
  var clear_path := PackedVector2Array([Vector2(clear_x,30),Vector2(clear_x,90)])
  var before := var_to_bytes([city.roads,city.transit_routes,city.next_road_id,city.next_transit_route_id])
  for commit: bool in [false,true]:
   var road: Dictionary = city.add_road(conflict,"local",commit)
   var rail: Dictionary = city.add_transit_route(conflict,"rail",commit)
   check(not road.ok and road.reason=="교각과 겹침", "%s: road rejects piercing the shaft (commit=%s)"%[label,commit])
   check(not rail.ok and rail.reason=="교각과 겹침", "%s: rail rejects piercing the shaft (commit=%s)"%[label,commit])
  check(var_to_bytes([city.roads,city.transit_routes,city.next_road_id,city.next_transit_route_id])==before, label+": refused construction is atomic")
  check(city.add_road(clear_path,"local",false).ok and city.add_transit_route(clear_path,"rail",false).ok,label+": true clear span permits a perpendicular road and rail")
  var lower_road: Dictionary = city.add_elevated_road(conflict,PackedFloat64Array([10,10]),"local",false)
  var lower_rail: Dictionary = city.add_transit_route(conflict,"rail",false,PackedFloat64Array([10,10]))
  check(not lower_road.ok and not lower_rail.ok and lower_road.reason=="교각과 겹침" and lower_rail.reason=="교각과 겹침",label+": ten metres of deck clearance does not bypass a shaft")
  check(city.add_elevated_road(conflict,PackedFloat64Array([-10,-10]),"local",false).ok and city.add_transit_route(conflict,"rail",false,PackedFloat64Array([-10,-10])).ok,label+": covered tunnels may pass below the shaft")
  var lower_first = new_city()
  var lower: Dictionary = lower_first.add_road(conflict)
  var supported: Dictionary = lower_first.add_transit_route(deck,"rail",true,PackedFloat64Array([20,20])) if rail_deck else lower_first.add_elevated_road(deck,PackedFloat64Array([20,20]))
  var half_width: float = lower_first.roads[0].width/2+.5 if lower.ok else INF
  check(lower.ok and supported.ok and supported.piers.all(func(p):return p.positions.all(func(pos):return absf(pos.x-x)>=half_width)),label+": a later deck places its supports around the pre-existing road")

func crossing_order():
 var road := PackedVector2Array([Vector2(8,40),Vector2(50,40),Vector2(82,40),Vector2(160,40)])
 var levels := PackedFloat64Array([0,0,10,10])
 for is_crossing: bool in [false,true]:
  var rail := PackedVector2Array([Vector2(22,12),Vector2(22,60)]) if is_crossing else PackedVector2Array([Vector2(14,41.5),Vector2(44,41.5)])
  for rail_first: bool in [false,true]:
   var city = new_city()
   var first: Dictionary = city.add_transit_route(rail) if rail_first else city.add_elevated_road(road,levels)
   check(first.ok,"crossing fixture first construction (rail_first=%s): %s"%[rail_first,first.get("reason","")])
   if not first.ok:continue
   var before := var_to_bytes([city.roads,city.transit_routes])
   var preview: Dictionary = city.add_elevated_road(road,levels,"local",false) if rail_first else city.add_transit_route(rail,"rail",false)
   check(var_to_bytes([city.roads,city.transit_routes])==before,"crossing preview is non-mutating")
   var result: Dictionary = city.add_elevated_road(road,levels) if rail_first else city.add_transit_route(rail)
   check(preview.ok==is_crossing and result.ok==is_crossing,"at-grade part obeys the same crossing rule (cross=%s, rail_first=%s)"%[is_crossing,rail_first])
   if not is_crossing:
    check(var_to_bytes([city.roads,city.transit_routes])==before,"non-crossing overlap leaves both networks unchanged")

func run():
 rail_reedit()
 piers()
 crossing_order()
 print("SECOND_FIX_STRUCTURES passed=%d failed=%d"%[passed,failed])
 quit(1 if failed else 0)
