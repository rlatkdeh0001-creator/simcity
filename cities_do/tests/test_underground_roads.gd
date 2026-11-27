extends SceneTree
## E2 underground roads: correctness only. No benchmark, wall-clock sampling or capture.
const City = preload("res://core/city_model.gd")
const Height = preload("res://core/road_height.gd")
const Network = preload("res://core/traffic_network.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 call_deferred("run")
func check(value: bool, label: String) -> void:
 if value:
  passed += 1
  print("PASS ", label)
 else:
  failed += 1
  print("FAIL ", label)
func path(values:Array)->PackedVector2Array:
 var result:=PackedVector2Array()
 for value in values:result.append(value)
 return result
func heights(values:Array)->PackedFloat64Array:
 var result:=PackedFloat64Array()
 for value in values:result.append(float(value))
 return result
func run() -> void:
 check(is_equal_approx(Height.PORTAL_M,-6.0) and is_equal_approx(4.5+1.0+0.5,-Height.PORTAL_M),"portal road surface is -6.0m = 4.5m clearance + 1.0m slab + 0.5m beam")
 test_grade_boundaries()
 test_flat_trench_construction()
 test_portal_split()
 test_vertical_clearance()
 test_metro_exception()
 test_rail_order()
 test_covered_keeps_surface()
 test_trench_demolition_rules()
 test_demolish_and_modify()
 test_trench_junction_and_mixed()
 test_zoning_and_frontage()
 test_traffic_levels()
 test_cost_placeholder()
 test_grid_off_points()
 print("E2 underground roads: %d passed, %d failed" % [passed,failed])
 quit(1 if failed else 0)
func test_grade_boundaries():
 var city=City.new(120,100)
 # 0 -> -10m local: 10m / 8% = 125m -> rounded up to 8m units = 128m (32 cells).
 check(is_equal_approx(Height.minimum_ramp_m(-10,"local"),128.0) and is_equal_approx(Height.minimum_ramp_m(-10,"highway"),200.0),"descending ramp minimum is 128m local / 200m highway")
 var exact:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(52,40)]),heights([0,-10]),"local",false)
 check(exact.ok,"128m local descent to -10m accepted: "+exact.reason)
 var short:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(51.9975,40)]),heights([0,-10]),"local",false)
 check(not short.ok and short.reason=="경사로 길이가 부족합니다","127.99m local descent rejected by the 8m rounded length: "+short.reason)
 var steep:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(51,40)]),heights([0,-10]),"local",false)
 check(not steep.ok and steep.reason=="경사가 너무 급합니다","124m local descent exceeds 8%: "+steep.reason)
 var highway:Dictionary=city.add_elevated_road(path([Vector2(10,60),Vector2(60,60)]),heights([0,-10]),"highway",false)
 check(highway.ok,"200m highway descent accepted: "+highway.reason)
 var highway_short:Dictionary=city.add_elevated_road(path([Vector2(10,60),Vector2(59.9975,60)]),heights([0,-10]),"highway",false)
 check(not highway_short.ok,"199.99m highway descent rejected")
 # The whole run counts, not only the last placed segment.
 var split:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(36,40),Vector2(52,40)]),heights([0,-5,-10]),"local",false)
 check(split.ok,"two 64m pieces of one 128m descent accepted: "+split.reason)
 var split_short:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(36,40),Vector2(51.9975,40)]),heights([0,-5,-10]),"local",false)
 check(not split_short.ok and split_short.reason=="경사로 길이가 부족합니다","last-piece-only ramp measurement cannot pass a 127.99m total descent: "+split_short.reason)
 var layer:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(60,40)]),heights([-7,-7]),"local",false)
 check(not layer.ok and layer.reason=="높이는 5m 단위입니다","flat underground layers remain 5m multiples")
 check(city.roads.is_empty(),"previews never commit underground records")
func test_flat_trench_construction():
 for kind in ["local","highway"]:
  var city=City.new(120,100)
  for commit in [false,true]:
   var id:int=city.next_road_id
   var flat:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(50,40)]),heights([-5,-5]),kind,commit)
   check(not flat.ok and flat.reason=="열린 트렌치에는 평탄한 도로를 만들 수 없습니다","flat -5m %s rejected (commit=%s): %s"%[kind,commit,flat.reason])
   check(city.roads.is_empty() and city.next_road_id==id,"rejected flat -5m request does not add a road or allocate an ID")
 var city=City.new(120,100)
 var p:=path([Vector2(20,40),Vector2(36,40),Vector2(44,40),Vector2(60,40)])
 var levels:=heights([0,-5,-5,-10])
 for commit in [false,true]:
  var plateau:Dictionary=city.add_elevated_road(p,levels,"local",commit)
  check(not plateau.ok and plateau.reason=="열린 트렌치에는 평탄한 도로를 만들 수 없습니다" and city.roads.is_empty(),"a -5m plateau embedded in a ramp is rejected (commit=%s): %s"%[commit,plateau.reason])
 var restored=City.new(120,100)
 var legacy:={"parcel_id":0,"points":path([Vector2(20,40),Vector2(50,40)]),"heights_m":heights([-5,-5]),"kind":"local","lanes":2,"width":3.0,"major_side":1}
 restored.roads.append(legacy.duplicate(true));restored.next_road_id=1
 var tunnel:Dictionary=restored.add_elevated_road(path([Vector2(20,60),Vector2(50,60)]),heights([-10,-10]))
 check(tunnel.ok and restored.roads.size()==2 and restored.roads[0]==legacy,"new construction preserves a retained legacy flat trench")
 check(Height.open_pieces(restored.roads[0]).size()==1,"retained flat trench still has open geometry")
func test_portal_split():
 var road:={"points":path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),"heights_m":heights([0,-10,-10]),"width":3.0}
 var covered:Array=Height.covered_pieces(road)
 var open:Array=Height.open_pieces(road)
 check(covered.size()==1 and open.size()==1,"one trench piece and one covered piece")
 if covered.size()!=1 or open.size()!=1:return
 var portal:Vector2=covered[0].points[0]
 check(portal.distance_to(Vector2(39.2,40))<.0001 and open[0].points[-1].distance_to(portal)<.0001,"portal lies where the 128m ramp reaches -6.0m: "+str(portal))
 check(is_equal_approx(Height.height_at(road,portal),-6.0) and covered[0].points[-1]==Vector2(80,40),"covered piece runs from the portal to the end")
 check(not Height.covered_at(-5.99) and Height.covered_at(-6.0) and Height.covered_at(-10),"portal boundary: -5.99m open, -6.0m and deeper covered")
 check(Height.sunken(road) and not Height.raised(road) and Height.off_ground(road) and Height.level(road)==-1,"underground level helpers")
func test_vertical_clearance():
 var ground=City.new(100,100)
 check(ground.add_road(path([Vector2(50,10),Vector2(50,90)])).ok,"ground crossing fixture")
 var tunnel:Dictionary=ground.add_elevated_road(path([Vector2(20,50),Vector2(80,50)]),heights([-10,-10]),"local",false)
 check(tunnel.ok,"ground x -10m tunnel: exactly 10m clearance accepted: "+tunnel.reason)
 var ramp:Dictionary=ground.add_elevated_road(path([Vector2(34,50),Vector2(66,50)]),heights([0,-10]),"local",false)
 check(not ramp.ok and ramp.reason=="수직 간격 부족","ground x through-ramp at -5m: 5m clearance rejected: "+ramp.reason)
 for order in [0,1]:
  for pair in [[-10,-20,true],[-10,-15,false]]:
   var city=City.new(100,100)
   var first:Array=[path([Vector2(20,50),Vector2(80,50)]),heights([pair[0],pair[0]])]
   var second:Array=[path([Vector2(50,10),Vector2(50,90)]),heights([pair[1],pair[1]])]
   if order==1:var swap:=first;first=second;second=swap
   check(city.add_elevated_road(first[0],first[1]).ok,"underground clearance fixture")
   var result:Dictionary=city.add_elevated_road(second[0],second[1],"local",false)
   check(result.ok==pair[2] and (pair[2] or result.reason=="수직 간격 부족"),"underground x underground %s/%s order %d: %s"%[pair[0],pair[1],order,result.reason])
 # Ramp interior: the full crossing width is checked against the interpolated depth.
 var base=City.new(100,100)
 check(base.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10])).ok,"ramp clearance fixture")
 var half:float=float(base.roads[0].width)/2
 var crossing_width:float=float(preload("res://core/road_profile.gd").width_for("local",2,base.config.road_width))/2
 var at_ten:Dictionary=base.add_elevated_road(path([Vector2(52+crossing_width,10),Vector2(52+crossing_width,90)]),heights([0,0]),"local",false)
 check(at_ten.ok,"ground road whose full width starts where the ramp reaches -10m is accepted: "+str(at_ten.get("reason","")))
 var inside:Dictionary=base.add_elevated_road(path([Vector2(51.9+crossing_width,10),Vector2(51.9+crossing_width,90)]),heights([0,0]),"local",false)
 check(not inside.ok and inside.reason=="수직 간격 부족","0.1 cell into the ramp is below 10m clearance: "+str(inside.get("reason","")))
 var mid:Dictionary=base.add_elevated_road(path([Vector2(45,10),Vector2(45,90)]),heights([0,0]),"local",false)
 check(not mid.ok and mid.reason=="수직 간격 부족","ground road over the covered ramp at -7.8m rejected")
 check(half>0,"fixture width")
func test_metro_exception():
 var states:Array=[]
 for order in [0,1]:
  var city=City.new(100,100)
  var metro:=path([Vector2(10,50),Vector2(90,50)])
  var roads:=[[path([Vector2(20,50),Vector2(52,50),Vector2(80,50)]),heights([0,-10,-10])],[path([Vector2(60,20),Vector2(60,80)]),heights([-20,-20])]]
  if order==0:check(city.add_transit_route(metro,"metro").ok,"metro first")
  for entry in roads:
   var result:Dictionary=city.add_elevated_road(entry[0],entry[1])
   check(result.ok,"road over/under metro accepted, order %d: %s"%[order,result.reason])
  var ground:Dictionary=city.add_elevated_road(path([Vector2(15,20),Vector2(15,80)]),heights([0,0]))
  check(ground.ok,"ground road across metro accepted, order %d: %s"%[order,ground.reason])
  if order==1:
   var metro_result:Dictionary=city.add_transit_route(metro,"metro")
   check(metro_result.ok,"metro after trench, tunnel and ground roads accepted: "+str(metro_result.get("reason","")))
  var road_points:=[]
  for road in city.roads:road_points.append([road.points,road.get("heights_m",PackedFloat64Array())])
  road_points.sort_custom(func(a,b):return str(a)<str(b))
  states.append(var_to_bytes([road_points,city.transit_routes.map(func(r):return r.points)]))
 check(states.size()==2 and states[0]==states[1],"metro exception gives the same records in either build order")
func test_rail_order():
 for order in [0,1]:
  for spec in [[50.0,false],[70.0,true]]:
   var city=City.new(100,100)
   var rail:=path([Vector2(spec[0],10),Vector2(spec[0],90)])
   var road:=path([Vector2(20,40),Vector2(52,40),Vector2(80,40)])
   var ok:bool
   var reason:String
   if order==0:
    check(city.add_transit_route(rail,"rail").ok,"rail first fixture")
    var result:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]))
    ok=result.ok;reason=result.reason
   else:
    check(city.add_elevated_road(road,heights([0,-10,-10])).ok,"road first fixture")
    var result:Dictionary=city.add_transit_route(rail,"rail")
    ok=result.ok;reason=str(result.get("reason",""))
   check(ok==spec[1] and (ok or reason=="수직 간격 부족"),"rail over %s, order %d: %s"%["covered -10m" if spec[1] else "ramp at -9.4m",order,reason])
func fixture_buildings(city):
 city.buildings.append({"id":71,"x":30,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":72,"x":60,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":73,"x":30,"y":44,"size":2,"level":1,"zone":"residential","asset_id":""})
func test_covered_keeps_surface():
 var city=City.new(100,100)
 fixture_buildings(city)
 city.buildings.remove_at(0)
 city.public_facilities.lots.append({"id":81,"public_asset_id":"medical-clinic","polygon":path([Vector2(64,38),Vector2(68,38),Vector2(68,42),Vector2(64,42)])})
 city.public_facilities.lots.append({"id":82,"public_asset_id":"park-plaza-4x4","polygon":path([Vector2(70,38),Vector2(74,38),Vector2(74,42),Vector2(70,42)])})
 var road:=path([Vector2(20,40),Vector2(52,40),Vector2(80,40)])
 var plan:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]),"local",false)
 check(plan.ok and plan.demolish_ids.is_empty() and not plan.warning,"covered section passes under building, clinic and park without demolition: "+plan.reason)
 var result:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]))
 check(result.ok and not city.find_building(72).is_empty() and not city.find_building(73).is_empty() and city.public_facilities.lots.size()==2,"commit keeps every surface record above the tunnel")
 var over_tunnel:=city.footprint({"x":56,"y":39,"size":2})
 var over_trench:=city.footprint({"x":26,"y":39,"size":2})
 check(city._polygon_error(over_tunnel,-1,false)=="","new lots may be placed above the covered section")
 check(city._polygon_error(over_trench,-1,false)=="도로와 충돌합니다","the open trench blocks lots like a ground road")
func test_trench_demolition_rules():
 var city=City.new(100,100)
 fixture_buildings(city)
 var road:=path([Vector2(20,40),Vector2(52,40),Vector2(80,40)])
 var plan:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]),"local",false)
 check(plan.ok and plan.demolish_ids==[71] and plan.warning,"only the zoned building over the trench needs B confirmation: "+str(plan.get("demolish_ids",[])))
 var refused:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]))
 check(not refused.ok and refused.reason=="이미 지어진 건물이 파괴됩니다" and city.roads.is_empty(),"unconfirmed trench commit is refused")
 var confirmed:Dictionary=city.add_elevated_road(road,heights([0,-10,-10]),"local",true,2,true,1,{},[71])
 check(confirmed.ok and city.find_building(71).is_empty() and not city.find_building(72).is_empty() and not city.find_building(73).is_empty(),"confirmed trench demolishes exactly the overlapped building")
 for spec in [["medical-clinic",Vector2(28,38)],["park-plaza-4x4",Vector2(28,38)]]:
  var public=City.new(100,100)
  var corner:Vector2=spec[1]
  public.public_facilities.lots.append({"id":91,"public_asset_id":spec[0],"polygon":path([corner,corner+Vector2(4,0),corner+Vector2(4,4),corner+Vector2(0,4)])})
  var blocked:Dictionary=public.add_elevated_road(road,heights([0,-10,-10]),"local",false)
  check(not blocked.ok and blocked.reason=="공공시설과 겹침","%s over the trench is red: %s"%[spec[0],blocked.reason])
func test_demolish_and_modify():
 var city=City.new(100,100)
 check(city.add_road(path([Vector2(10,40),Vector2(20,40)])).ok,"ground approach")
 check(city.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10])).ok,"underground road")
 city.buildings.append({"id":72,"x":60,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 var tunnel_index:=-1
 for i in range(city.roads.size()):
  if Height.sunken(city.roads[i]):tunnel_index=i
 check(tunnel_index>=0,"tunnel record found")
 if tunnel_index<0:return
 var id:int=city.roads[tunnel_index].parcel_id
 var selection:Dictionary=city.road_demolition_selection(id,Vector2(66,40),Vector2(74,40))
 var result:Dictionary=city.demolish_road_selection(selection)
 check(result.ok,"partial tunnel demolition succeeds: "+str(result.get("reason","")))
 var remaining:Array=city.roads.filter(func(r):return Height.sunken(r))
 var keeps:=remaining.size()==2
 for road in remaining:
  for point in road.points:keeps=keeps and absf(Height.height_at(road,point)-Height.height_at({"points":path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),"heights_m":heights([0,-10,-10])},point))<.0001
 check(keeps,"remaining tunnel pieces keep their interpolated heights")
 check(not city.find_building(72).is_empty(),"demolishing the tunnel leaves the building above it")
 for road in city.roads.duplicate():
  if Height.sunken(road):
   var all:Dictionary=city.road_demolition_selection(road.parcel_id,road.points[0],road.points[-1])
   check(city.demolish_road_selection(all).ok,"whole tunnel piece demolition")
 check(city.roads.size()==1 and not Height.off_ground(city.roads[0]),"only the ground approach remains")
 var rebuilt:Dictionary=city.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10]),"local",false)
 check(rebuilt.ok and rebuilt.demolish_ids.is_empty(),"the same tunnel can be planned again under the surviving building")
func test_trench_junction_and_mixed():
 var city=City.new(100,100)
 var cross:Dictionary=city.add_elevated_road(path([Vector2(10,50),Vector2(90,50),Vector2(90,10),Vector2(50,10),Vector2(50,90)]),heights([0,-10,-10,0,-10]),"local",false)
 check(not cross.ok and cross.reason=="트렌치 안에는 교차로를 만들 수 없습니다","same-level junction inside an open trench is red: "+cross.reason)
 check(city.add_elevated_road(path([Vector2(20,40),Vector2(36,40)]),heights([0,-5])).ok,"first half of a ramp reaches -5m without a flat section")
 var continuation:=path([Vector2(36,40),Vector2(52,40)])
 var width_change:Dictionary=city.add_elevated_road(continuation,heights([-5,-10]),"local",true,4)
 check(not width_change.ok and width_change.reason=="트렌치 안에는 교차로를 만들 수 없습니다" and city.roads.size()==1,"width change at a -5m ramp join is refused without adding a road: "+width_change.reason)
 var through:Dictionary=city.add_elevated_road(continuation,heights([-5,-10]))
 check(through.ok and city.roads.size()==2,"same-width through-ramp can continue at -5m: "+through.reason)
 var deep=City.new(100,100)
 check(deep.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10])).ok,"covered road")
 var covered_cross:Dictionary=deep.add_elevated_road(path([Vector2(70,20),Vector2(70,60)]),heights([-10,-10]))
 check(covered_cross.ok,"covered same-level junction is allowed: "+covered_cross.reason)
 var mixed:Dictionary=City.new(120,100).add_elevated_road(path([Vector2(10,40),Vector2(42,40),Vector2(74,40)]),heights([10,0,-10]),"local",false)
 check(not mixed.ok and mixed.reason=="고가와 지하는 지상에서 나눠 그립니다","one record cannot span elevated and underground: "+mixed.reason)
func test_zoning_and_frontage():
 var city=City.new(100,100)
 check(city.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10])).ok,"zoning fixture tunnel")
 check(city.zoning_grid.count()==0,"no roadside cells beside the trench or tunnel")
 check(city.add_road(path([Vector2(10,44),Vector2(90,44)])).ok,"parallel ground road")
 var road:Dictionary=city.roads.filter(func(r):return Height.sunken(r))[0]
 var trench:Array=[];var covered:Array=[]
 for piece in Height.open_pieces(road):trench.append_array(preload("res://core/road_geometry.gd").ribbons(piece.points,road.width,true,true))
 for piece in Height.covered_pieces(road):covered.append_array(preload("res://core/road_geometry.gd").ribbons(piece.points,road.width,true,true))
 var over_trench:=false;var over_cover:=false
 for parcel in city.zoning_grid.parcels.values():
  for ribbon in trench:over_trench=over_trench or preload("res://core/road_parcels.gd").overlap(parcel.polygon,ribbon)
  for ribbon in covered:over_cover=over_cover or preload("res://core/road_parcels.gd").overlap(parcel.polygon,ribbon)
 check(not over_trench and over_cover,"neighbour cells stop at the trench but survive above the covered section")
 var frontage:=preload("res://core/building_frontage.gd").candidates(city.footprint({"x":60,"y":41.5,"size":2}),[road],city.config.road_access_distance)
 check(frontage.is_empty(),"an underground road never provides building frontage")
func lanes_of(network,road_index:int)->Array:
 return network.lanes.filter(func(l):return int(l.get("road",-1))==road_index).map(func(l):return int(l.id))
func test_traffic_levels():
 var city=City.new(100,100)
 check(city.add_road(path([Vector2(10,40),Vector2(20,40)])).ok,"traffic ground approach")
 check(city.add_elevated_road(path([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),heights([0,-10,-10])).ok,"traffic tunnel")
 check(city.add_road(path([Vector2(70,20),Vector2(70,60)])).ok,"ground road above the tunnel")
 var network=Network.new()
 check(network.build(city.roads),"traffic network builds across levels")
 var ground:=-1;var tunnel:=-1;var above:=-1
 for i in range(city.roads.size()):
  if Height.sunken(city.roads[i]):tunnel=i
  elif city.roads[i].points[0].y==20:above=i
  else:ground=i
 var reach:=false;var leak:=false
 for a in lanes_of(network,ground):
  for b in lanes_of(network,tunnel):reach=reach or not network.route(a,b).is_empty()
 for a in lanes_of(network,above):
  for b in lanes_of(network,tunnel):leak=leak or not network.route(a,b).is_empty() or not network.route(b,a).is_empty()
 check(reach,"cars route from the ground road through the trench into the tunnel")
 check(not leak,"the crossing ground road has no lane connection to the tunnel 10m below")
func test_cost_placeholder():
 var city=City.new(100,100)
 var config:Dictionary=Height.config.get("depth_cost",{})
 check(not config.is_empty() and config.get("enabled",true)==false and str(config.get("approval_status","")).contains("pending"),"depth cost is a disabled, pending reversible placeholder")
 var factors:Array=[]
 for depth in [0,-10,-20]:
  var result:Dictionary=city.add_elevated_road(path([Vector2(20,50),Vector2(80,50)]),heights([depth,depth]),"local",false)
  factors.append(float(result.get("depth_cost_factor",-1)))
 check(is_equal_approx(factors[0],1.0) and factors[1]>factors[0] and factors[2]>factors[1],"placeholder factor grows non-linearly with depth: "+str(factors))
 check(factors[2]-factors[1]>factors[1]-factors[0],"deeper steps cost more than shallower steps")
func test_grid_off_points():
 var city=City.new(100,100)
 var points:=path([Vector2(20.37,40.11),Vector2(52.37,40.11),Vector2(80.91,40.73)])
 check(city.add_elevated_road(points,heights([0,-10,-10])).ok,"off-grid underground commit")
 var road:Dictionary=city.roads.filter(func(r):return Height.sunken(r))[0]
 check(road.points==points and not road.has("grid_frame"),"grid OFF keeps every confirmed underground point exactly")
