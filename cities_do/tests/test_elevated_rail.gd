extends SceneTree
## E3a elevated rail: correctness only. No benchmark, wall-clock sampling or capture.
const City=preload("res://core/city_model.gd")
const Routes=preload("res://core/transit_routes.gd")
const Height=preload("res://core/road_height.gd")
const View=preload("res://core/transit_view.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
const Planner=preload("res://core/transit_line_planner.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
 if value:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func path(values:Array)->PackedVector2Array:
 var result:=PackedVector2Array()
 for value in values:result.append(value)
 return result
func heights(values:Array)->PackedFloat64Array:
 var result:=PackedFloat64Array()
 for value in values:result.append(float(value))
 return result
func ramp_city(size:Vector2i=Vector2i(200,80)):
 var city=City.new(size.x,size.y);city.funds=1000000
 return city
## 0 -> +10m over exactly 72 cells (288m), then a +10m deck.
func viaduct_points(y:float=40,end_x:float=150)->PackedVector2Array:return path([Vector2(10,y),Vector2(82,y),Vector2(end_x,y)])
func run()->void:
 test_ground_compat()
 test_grade_boundaries()
 test_two_piece_grade()
 test_supports()
 test_vertical_clearance()
 test_rail_over_rail()
 test_under_rules()
 test_demolition_b()
 test_station_and_crossover()
 test_geometry_and_catenary()
 test_line_levels()
 test_cost_and_grid_off()
 print("E3a elevated rail: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
func test_ground_compat():
 var city=ramp_city()
 var ground:Dictionary=city.add_transit_route(path([Vector2(10,20),Vector2(60,20)]))
 check(ground.ok and not city.transit_routes[0].has("heights_m"),"a ground rail keeps the previous record shape (no heights_m)")
 check(Height.height_at(city.transit_routes[0],Vector2(30,20))==0.0,"a rail without heights is read as ground (0m)")
 var saved:Array=[city.transit_routes[0].duplicate(true)]
 check(Routes.snapshot_error(saved,200,80)=="","an old saved rail record without heights still loads")
 var raised:Array=saved.duplicate(true);raised[0].heights_m=heights([0,5])
 check(Routes.snapshot_error(raised,200,80)=="","a saved rail with per-point heights loads")
 var wrong:Array=saved.duplicate(true);wrong[0].heights_m=heights([0])
 check(Routes.snapshot_error(wrong,200,80)!="","a height list of the wrong length is refused on load")
 var negative:Array=saved.duplicate(true);negative[0].heights_m=heights([0,-10])
 check(Routes.snapshot_error(negative,200,80)!="","a too-short (200m) descent to -10m is refused on load")
 var metro:Dictionary=city.add_transit_route(path([Vector2(10,60),Vector2(60,60)]),"metro",false,heights([10,10]))
 check(not metro.ok,"metro heights cannot be changed: "+str(metro.get("reason","")))
 var plain_metro:Dictionary=city.add_transit_route(path([Vector2(10,60),Vector2(60,60)]),"metro",false)
 check(plain_metro.ok and is_equal_approx(plain_metro.route.rail_top_z_m,-12.7) and not plain_metro.route.has("heights_m"),"metro keeps its single -12.7m level")
 var below:Dictionary=city.add_transit_route(path([Vector2(10,70),Vector2(82,70)]),"rail",false,heights([0,-10]))
 check(below.ok,"E3b: a 288m descent to -10m is buildable: "+str(below.get("reason","")))
func test_grade_boundaries():
 var city=ramp_city()
 check(is_equal_approx(Routes.minimum_ramp_m(10),288.0) and is_equal_approx(Routes.minimum_ramp_m(5),144.0),"rail ramp minimum: 10m -> 288m, 5m -> 144m (3.5%, 8m units)")
 var exact:Dictionary=city.add_transit_route(viaduct_points(),"rail",false,heights([0,10,10]))
 check(exact.ok,"0 -> +10m over exactly 288m passes: "+str(exact.get("reason","")))
 var short:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(81.9,40),Vector2(150,40)]),"rail",false,heights([0,10,10]))
 check(not short.ok and short.reason=="경사로 길이가 부족합니다","287.6m ramp is refused: "+short.reason)
 var steep:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(80,40),Vector2(150,40)]),"rail",false,heights([0,10,10]))
 check(not steep.ok and steep.reason=="경사가 너무 급합니다","280m (3.57%) is too steep: "+steep.reason)
 var half:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(46,40),Vector2(150,40)]),"rail",false,heights([0,5,5]))
 check(half.ok,"0 -> +5m over 144m passes: "+str(half.get("reason","")))
 var down:Dictionary=city.add_transit_route(path([Vector2(150,40),Vector2(82,40),Vector2(10,40)]),"rail",false,heights([10,10,0]))
 check(down.ok,"the same ramp descending passes")
 var layer:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(82,40),Vector2(150,40)]),"rail",false,heights([0,7,7]))
 check(not layer.ok and layer.reason=="높이는 5m 단위입니다","flat rail stays on 5m layers: "+layer.reason)
func test_two_piece_grade():
 var city=ramp_city()
 # 0->3m over 86m and 3->10m over 201m: each piece alone is under 3.5%, the run is 287m < 288m.
 var bad:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(31.5,40),Vector2(81.75,40),Vector2(150,40)]),"rail",false,heights([0,3,10,10]))
 check(not bad.ok and bad.reason=="경사로 길이가 부족합니다","a two-piece ramp is measured as one run, not by its last piece: "+bad.reason)
 var good:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(31.75,40),Vector2(82,40),Vector2(150,40)]),"rail",false,heights([0,3,10,10]))
 check(good.ok,"the same two pieces over 288m pass: "+str(good.get("reason","")))
func gaps(piers:Array)->Array:
 var result:=[]
 for i in range(1,piers.size()):result.append((float(piers[i].distance)-float(piers[i-1].distance))*4)
 return result
func test_supports():
 var city=ramp_city()
 var plan:Dictionary=city.add_transit_route(viaduct_points(),"rail",false,heights([0,10,10]))
 var piers:Array=plan.get("piers",[])
 var spans:=gaps(piers)
 check(not piers.is_empty() and piers.all(func(p):return p.positions.size()==1 and absf(p.positions[0].y-40)<.001),"10m rail structure: one centreline pier per station (W <= 12m)")
 check(spans.all(func(g):return g>=16-.001 and g<=48+.001) and spans.count(32.0)>=spans.size()-1,"unobstructed pier spacing is 32m: "+str(spans))
 check(float(piers[0].distance)*4-144<=48.001 and float(piers[0].height_m)>=5-.001,"first pier stands at the +5m end of the earth-filled ramp")
 check(plan.ok and Height.height_at(plan.route,Vector2(100,40))==10.0 and plan.route.piers==piers,"plan stores heights and piers on the route record")
 for lanes in [2,8]:
  var crossed=ramp_city()
  check(crossed.add_road(path([Vector2(120,5),Vector2(120,75)]),"local",true,lanes).ok,"road under the deck fixture %d lanes"%lanes)
  var result:Dictionary=crossed.add_transit_route(viaduct_points(),"rail",false,heights([0,10,10]))
  var half:float=float(crossed.roads[0].width)/2+.5
  var moved:=gaps(result.get("piers",[]))
  check(result.ok and result.piers.all(func(p):return absf(p.positions[0].x-120)>=half-.001) and moved.all(func(g):return g>=16-.001 and g<=48+.001),"piers step around a %d-lane road within 16..48m: %s"%[lanes,str(moved)])
func test_vertical_clearance():
 for order in ["road_first","rail_first"]:
  for offset in [1.5,1.4]:
   var city=ramp_city()
   var road:=path([Vector2(82+offset,5),Vector2(82+offset,75)])
   var result:Dictionary
   if order=="road_first":
    check(city.add_road(road).ok,"clearance road fixture")
    result=city.add_transit_route(viaduct_points(),"rail",true,heights([0,10,10]))
   else:
    check(city.add_transit_route(viaduct_points(),"rail",true,heights([0,10,10])).ok,"clearance rail fixture")
    result=city.add_elevated_road(road,heights([0,0]))
   var expected:bool=offset>=1.5
   check(result.ok==expected and (expected or result.reason=="수직 간격 부족"),"%s: road edge %.1f cell from the ramp top -> %s (%s)"%[order,offset-1.5,"pass" if expected else "수직 간격 부족",result.get("reason","")])
 var city=ramp_city()
 check(city.add_transit_route(viaduct_points(),"rail",true,heights([0,10,10])).ok,"deck for stacked roads")
 for level in [20,15,10]:
  var stacked:Dictionary=city.add_elevated_road(path([Vector2(120,5),Vector2(120,75)]),heights([level,level]),"local",false)
  check(stacked.ok==(level==20) and (level==20 or stacked.reason=="수직 간격 부족"),"elevated road at +%dm across the +10m deck: %s"%[level,stacked.get("reason","ok")])
 var under:Dictionary=city.add_elevated_road(path([Vector2(120.5,40),Vector2(123.5,40)]),heights([0,0]),"local",false)
 check(under.ok,"a ground road may lie along under the +10m deck between piers (no level-crossing rule): "+str(under.get("reason","")))
 var on_pier:Dictionary=city.add_elevated_road(path([Vector2(115,40),Vector2(121,40)]),heights([0,0]),"local",false)
 check(not on_pier.ok and on_pier.reason=="교각과 겹침","a ground road through a rail pier is red: "+str(on_pier.get("reason","")))
 var ground_city=ramp_city()
 check(ground_city.add_transit_route(path([Vector2(10,40),Vector2(150,40)])).ok,"ground rail comparison fixture")
 check(not ground_city.add_elevated_road(path([Vector2(115,40),Vector2(121,40)]),heights([0,0]),"local",false).ok,"the same road along a ground rail is still refused (level crossings only)")
func test_rail_over_rail():
 for y_cross in [100.0,60.0]:
  var city=ramp_city()
  check(city.add_transit_route(path([Vector2(y_cross,5),Vector2(y_cross,75)])).ok,"ground rail under fixture")
  var result:Dictionary=city.add_transit_route(viaduct_points(),"rail",false,heights([0,10,10]))
  var expected:bool=y_cross>=100
  check(result.ok==expected and (expected or result.reason=="수직 간격 부족"),"rail over ground rail at x=%d: %s"%[y_cross,result.get("reason","ok")])
 var city=ramp_city()
 check(city.add_transit_route(path([Vector2(4,40),Vector2(10,40)])).ok,"ground approach")
 var joined:Dictionary=city.add_transit_route(viaduct_points(),"rail",false,heights([0,10,10]))
 check(joined.ok,"a ramp continues from the end of a ground track: "+str(joined.get("reason","")))
 var jump:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(10,10)]),"rail",false,heights([10,10]))
 check(not jump.ok,"a track cannot join another track at a different height: "+str(jump.get("reason","")))
func test_under_rules():
 var city=ramp_city(Vector2i(200,80))
 check(city.add_road(path([Vector2(5,40),Vector2(195,40)])).ok,"zoning road fixture")
 var probe:=Vector2(120.3,44.2);var outside:=Vector2(120.3,41.8)
 check(not city.zoning_grid.parcel_at(probe).is_empty() and not city.zoning_grid.parcel_at(outside).is_empty(),"zoning cells exist beside the road before the viaduct")
 var result:Dictionary=city.add_transit_route(viaduct_points(44,190),"rail",true,heights([0,10,10]))
 check(result.ok,"viaduct beside the road: "+str(result.get("reason","")))
 check(city.zoning_grid.parcel_at(probe).is_empty(),"zoning cells under the viaduct are deleted")
 check(not city.zoning_grid.parcel_at(outside).is_empty(),"cells outside the 10m structure stay")
 var lot:=city.footprint({"x":120,"y":43,"size":2})
 check(city._polygon_error(lot)!="","no building can be placed under the viaduct")
 var deck_park:=city.footprint({"x":118,"y":42,"size":4});var ramp_park:=city.footprint({"x":30,"y":42,"size":4})
 check(city._polygon_error(deck_park,-1,true,-1,PackedVector2Array(),true).find("철도")<0,"a park may use the open space under the +10m deck")
 check(city._polygon_error(ramp_park,-1,true,-1,PackedVector2Array(),true)!="","a park cannot sit on the earth-filled ramp below +5m")
func test_demolition_b():
 var city=ramp_city()
 city.buildings.append({"id":91,"x":119,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 city.buildings.append({"id":92,"x":119,"y":42,"size":2,"level":1,"zone":"residential","asset_id":""})
 var points:=viaduct_points();var levels:=heights([0,10,10])
 var plan:Dictionary=city.add_transit_route(points,"rail",false,levels)
 check(plan.ok and plan.get("warning",false) and plan.get("demolish_ids",[])==[91],"only the overlapped zoned building needs confirmation (yellow B): "+str(plan.get("demolish_ids",[])))
 var unconfirmed:Dictionary=city.add_transit_route(points,"rail",true,levels)
 check(not unconfirmed.ok and unconfirmed.reason=="이미 지어진 건물이 파괴됩니다" and city.transit_routes.is_empty() and not city.find_building(91).is_empty(),"commit without confirmation changes nothing")
 var wrong:Dictionary=city.add_transit_route(points,"rail",true,levels,true,[92])
 check(not wrong.ok and city.transit_routes.is_empty(),"a different confirmed list is refused: "+wrong.reason)
 var done:Dictionary=city.add_transit_route(points,"rail",true,levels,true,[91])
 check(done.ok and city.find_building(91).is_empty() and not city.find_building(92).is_empty() and city.transit_routes.size()==1,"confirmed commit demolishes exactly the overlapped building")
 var public_city=ramp_city()
 public_city.public_facilities.lots.append({"id":93,"public_asset_id":"medical-clinic","polygon":public_city.footprint({"x":119,"y":39,"size":2})})
 var blocked:Dictionary=public_city.add_transit_route(points,"rail",false,levels)
 check(not blocked.ok and blocked.reason=="공공시설과 겹침","a public facility under the viaduct is red: "+blocked.reason)
 var park_city=ramp_city()
 park_city.public_facilities.lots.append({"id":94,"public_asset_id":"park-plaza-4x4","polygon":park_city.footprint({"x":118,"y":38,"size":4})})
 check(park_city.add_transit_route(points,"rail",false,levels).ok,"a park under the +10m deck passes")
 park_city.public_facilities.lots[0].polygon=park_city.footprint({"x":30,"y":38,"size":4})
 check(not park_city.add_transit_route(points,"rail",false,levels).ok,"a park on the earth-filled ramp is red")
 var ground_city=ramp_city()
 ground_city.buildings.append({"id":95,"x":119,"y":39,"size":2,"level":1,"zone":"residential","asset_id":""})
 var ground:Dictionary=ground_city.add_transit_route(path([Vector2(10,40),Vector2(150,40)]),"rail",false)
 check(not ground.ok and ground.reason=="건물 또는 시설과 충돌합니다","ground-only rail keeps the existing red building rule")
func station_city():
 var city=City.new(260,80,42);city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 city.add_road(path([Vector2(2,40),Vector2(250,40)]),"local",true,4)
 var placed:Dictionary=city.public_facilities.place("train-station-01",Vector2(70,33),0,true)
 return [city,placed]
func test_station_and_crossover():
 var pair:Array=station_city();var city=pair[0];var placed:Dictionary=pair[1]
 check(placed.ok,"station fixture")
 var lot:Dictionary=city.public_facilities.lots[0]
 var port:Dictionary=lot.station_ports[0] if lot.station_ports[0].outward.x>0 else lot.station_ports[1]
 var p:Vector2=port.point;var out:Vector2=Vector2(port.outward).normalized()
 var raised:Dictionary=city.add_transit_route(path([p,p+out*20]),"rail",false,heights([10,10]))
 check(not raised.ok and raised.reason=="고가 구간에는 역을 둘 수 없습니다","a station port on an elevated track is red: "+str(raised.get("reason","")))
 var ramp:Dictionary=city.add_transit_route(path([p,p+out*72,p+out*80]),"rail",false,heights([0,10,10]))
 check(ramp.ok,"a ramp may start at ground level from the station port: "+str(ramp.get("reason","")))
 var lot_id:int=lot.id
 check(city.public_facilities.remove(lot_id),"station removal fixture")
 check(city.add_transit_route(path([p,p+out*20]),"rail",true,heights([10,10])).ok,"a +10m deck ending where the port was")
 var again:Dictionary=city.public_facilities.place("train-station-01",Vector2(70,33),0,true)
 check(not again.ok and again.reason=="고가 구간에는 역을 둘 수 없습니다","placing a station onto an elevated track end is red: "+str(again.get("reason","")))
 var x:={"kind":"rail","start":Vector2(20,20)*4,"end":Vector2(28,20)*4,"axis":Vector2(1,0),"station_id":-99}
 var flat=ramp_city()
 check(flat.add_transit_route(path([Vector2(20,20),Vector2(60,20)])).ok and Crossover.available(flat,x),"a straight ground double track still allows the X crossover")
 var deck=ramp_city()
 check(deck.add_transit_route(path([Vector2(20,20),Vector2(60,20)]),"rail",true,heights([10,10])).ok and not Crossover.available(deck,x),"no X crossover on an elevated deck")
 var sloped=ramp_city()
 check(sloped.add_transit_route(path([Vector2(20,20),Vector2(92,20)]),"rail",true,heights([0,10])).ok and not Crossover.available(sloped,x),"no X crossover on a ramp")
func test_geometry_and_catenary():
 var city=ramp_city()
 check(city.add_road(path([Vector2(120,5),Vector2(120,75)])).ok,"road under deck for geometry")
 var result:Dictionary=city.add_transit_route(viaduct_points(),"rail",true,heights([0,10,10]))
 check(result.ok,"geometry viaduct fixture")
 var route:Dictionary=city.transit_routes[0]
 var geometry:Dictionary=View.build_geometry(city)
 var deck:Array=geometry.get("deck",[])
 check(not deck.is_empty() and deck.all(func(s):return s.route_id==route.id and s.depths.size()==s.points.size() and Array(s.depths).all(func(h):return h>=0) and Array(s.depths).max()>0),"track strips above ground are emitted as deck shapes carrying their heights")
 check(deck.any(func(s):return s.texture=="strip") and deck.any(func(s):return s.texture.is_empty()),"deck carries ballast and textured running strips")
 var leaked:=false
 for shape:Dictionary in geometry.rail:
  for point:Vector2 in shape.points:
   if point.x>10.6 and absf(point.y-40)<1.5:leaked=true
 check(not leaked,"the ground rail layer stops where the ramp leaves the ground")
 var own:Array=geometry.catenary.filter(func(c):return c.get("route_id",-1)==route.id)
 var contacts:Array=own.filter(func(c):return c.kind=="contact")
 check(not contacts.is_empty() and contacts.all(func(c):return absf(c.a_height-3.8-Height.height_at(route,c.a))<.02 and absf(c.b_height-3.8-Height.height_at(route,c.b))<.02),"contact wire stays 3.8m above the rail top on ramp and deck")
 var poles:Array=own.filter(func(c):return c.kind=="pole")
 check(poles.any(func(c):return absf(c.a_height-10)<.001 and absf(c.b_height-15.3)<.001) and poles.all(func(c):return absf(c.a_height-Height.height_at(route,c.a))<.02),"poles stand on the deck (base at deck level, top +5.3m)")
 check(contacts.any(func(c):return minf(c.a.x,c.b.x)<=120 and maxf(c.a.x,c.b.x)>=120 and c.a_height>13),"wire continues over the road under the deck")
 check(poles.all(func(c):return absf(c.a.x-120)>1.5 or c.a_height>=10),"no ground pole stands on the road; deck poles above it are allowed")
func test_line_levels():
 var city=ramp_city()
 check(city.add_transit_route(path([Vector2(120,5),Vector2(120,75)])).ok,"ground rail crossing below")
 check(city.add_transit_route(viaduct_points(),"rail",true,heights([0,10,10])).ok,"viaduct over it")
 var planner=Planner.new();planner.build_graph(city,"rail")
 check(not planner.nodes.any(func(n):return n.distance_to(Vector2(120,40)*4)<.01),"the line graph has no switch where the viaduct passes over the ground track")
 var level=ramp_city()
 check(level.add_transit_route(path([Vector2(120,5),Vector2(120,75)])).ok and level.add_transit_route(path([Vector2(10,40),Vector2(150,40)])).ok,"ground diamond fixture")
 var flat=Planner.new();flat.build_graph(level,"rail")
 check(flat.nodes.any(func(n):return n.distance_to(Vector2(120,40)*4)<.01),"a same-level ground crossing keeps its graph node")
func test_cost_and_grid_off():
 var city=ramp_city()
 var config:Dictionary=Height.config.get("rail_height_cost",{})
 check(not config.is_empty() and config.get("enabled",true)==false and str(config.get("approval_status","")).contains("pending"),"rail height cost is a disabled, pending reversible placeholder")
 var factors:Array=[]
 for level in [0,10,20]:
  var plan:Dictionary=city.add_transit_route(path([Vector2(20,50),Vector2(80,50)]),"rail",false,heights([level,level]))
  factors.append(float(plan.get("height_cost_factor",-1)))
 check(is_equal_approx(factors[0],1.0) and factors[1]>factors[0] and factors[2]-factors[1]>factors[1]-factors[0],"placeholder factor grows non-linearly with height: "+str(factors))
 var points:=path([Vector2(20.37,30.11),Vector2(92.37,30.11),Vector2(110.91,30.73)])
 var levels:=heights([0,10,10])
 check(city.add_transit_route(points,"rail",true,levels).ok,"off-grid elevated rail commit")
 check(city.transit_routes[-1].points==points and city.transit_routes[-1].heights_m==levels,"grid OFF keeps every confirmed point and height exactly")
