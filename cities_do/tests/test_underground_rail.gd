extends SceneTree
## E3b underground rail (trenches, portals, covered tunnels): correctness only. No benchmark, wall-clock sampling or capture.
const City=preload("res://core/city_model.gd")
const Routes=preload("res://core/transit_routes.gd")
const Height=preload("res://core/road_height.gd")
const View=preload("res://core/transit_view.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
const Planner=preload("res://core/transit_line_planner.gd")
const DOWN:=[0,-10,-10]
## Ramp start x=10, portal (-7.0m) at 201.6m = 50.4 cells, -10m from x=82 (288m).
const PORTAL_X:=10.0+201.6/4.0
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
## 0 -> -10m over exactly 72 cells (288m), then a -10m covered tunnel.
func tunnel_points(y:float=40,end_x:float=150)->PackedVector2Array:return path([Vector2(10,y),Vector2(82,y),Vector2(end_x,y)])
func building(id:int,x:int,y:int)->Dictionary:return {"id":id,"x":x,"y":y,"size":2,"level":1,"zone":"residential","asset_id":""}
func run()->void:
 test_heights_and_compat()
 test_grade_and_portal()
 test_vertical_clearance()
 test_metro_exception()
 test_trench_and_covered_rules()
 test_zoning()
 test_station_and_crossover()
 test_geometry_and_catenary()
 test_line_and_joints()
 test_cost_and_grid_off()
 print("E3b underground rail: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
func test_heights_and_compat():
 var city=ramp_city()
 var ground:Dictionary=city.add_transit_route(path([Vector2(10,20),Vector2(60,20)]))
 check(ground.ok and not city.transit_routes[0].has("heights_m"),"a ground rail keeps the previous record shape (no heights_m)")
 var saved:Array=[city.transit_routes[0].duplicate(true)]
 check(Routes.snapshot_error(saved,200,80)=="","an old saved rail record without heights still loads")
 var below:Array=saved.duplicate(true);below[0].points=path([Vector2(10,20),Vector2(82,20)]);below[0].heights_m=heights([0,-10])
 check(Routes.snapshot_error(below,200,80)=="","a saved rail descending to -10m over 288m loads")
 var mixed:Array=saved.duplicate(true);mixed[0].points=path([Vector2(10,20),Vector2(82,20),Vector2(154,20),Vector2(190,20)]);mixed[0].heights_m=heights([10,0,-10,-10])
 check(Routes.snapshot_error(mixed,200,80)!="","a saved rail mixing viaduct and tunnel is refused on load")
 var plan:Dictionary=city.add_transit_route(tunnel_points(),"rail",false,heights(DOWN))
 check(plan.ok and plan.route.heights_m==heights(DOWN),"a ground-to--10m rail plan keeps per-point heights: "+str(plan.get("reason","")))
 check(plan.ok and Routes.sunken(plan.route) and not Routes.raised(plan.route) and Routes.off_ground(plan.route),"the descending rail is sunken, not raised")
 var mix:Dictionary=city.add_transit_route(path([Vector2(10,60),Vector2(82,60),Vector2(154,60),Vector2(190,60)]),"rail",false,heights([10,0,-10,-10]))
 check(not mix.ok and mix.reason=="고가와 지하는 지상에서 나눠 그립니다","one track never mixes viaduct and tunnel (E2 road rule): "+str(mix.get("reason","")))
 var metro:Dictionary=city.add_transit_route(path([Vector2(10,70),Vector2(60,70)]),"metro",false,heights([-10,-10]))
 check(not metro.ok,"metro data stays unchanged (no rail heights): "+str(metro.get("reason","")))
func test_grade_and_portal():
 var city=ramp_city()
 check(is_equal_approx(Routes.minimum_ramp_m(-10),288.0) and is_equal_approx(Routes.minimum_ramp_m(-5),144.0),"rail descent minimum: -10m -> 288m, -5m -> 144m (3.5%, 8m units)")
 var exact:Dictionary=city.add_transit_route(tunnel_points(),"rail",false,heights(DOWN))
 check(exact.ok,"0 -> -10m over exactly 288m passes: "+str(exact.get("reason","")))
 var short:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(81.9,40),Vector2(150,40)]),"rail",false,heights(DOWN))
 check(not short.ok and short.reason=="경사로 길이가 부족합니다","287.6m descent is refused: "+str(short.get("reason","")))
 var steep:Dictionary=city.add_transit_route(path([Vector2(10,40),Vector2(80,40),Vector2(150,40)]),"rail",false,heights(DOWN))
 check(not steep.ok and steep.reason=="경사가 너무 급합니다","280m (3.57%) descent is too steep: "+str(steep.get("reason","")))
 var up:Dictionary=city.add_transit_route(path([Vector2(150,40),Vector2(82,40),Vector2(10,40)]),"rail",false,heights([-10,-10,0]))
 check(up.ok,"the same ramp climbing out of the tunnel passes")
 var layer:Dictionary=city.add_transit_route(tunnel_points(),"rail",false,heights([0,-7,-7]))
 check(not layer.ok and layer.reason=="높이는 5m 단위입니다","flat tunnel stays on 5m layers: "+str(layer.get("reason","")))
 check(is_equal_approx(Height.RAIL_PORTAL_M,-7.0),"rail portal rail top = -(5.5m clearance + 1.0m cover + 0.5m beam) = -7.0m")
 check(not Height.covered_at(-6.99,Height.RAIL_PORTAL_M) and Height.covered_at(-7.0,Height.RAIL_PORTAL_M),"rail: -6.99m is open trench, -7.0m is covered")
 check(Height.covered_at(-6.0) and not Height.covered_at(-5.99),"road portal stays at -6.0m")
 if not exact.ok:return
 var covered:Array=Height.covered_pieces(exact.route,Height.RAIL_PORTAL_M)
 check(covered.size()==1 and covered[0].points[0].distance_to(Vector2(PORTAL_X,40))<.001,"the rail portal sits 201.6m from the ramp start: "+str(covered[0].points[0] if not covered.is_empty() else null))
 var trench:Array=Routes.trench_pieces(exact.route)
 check(trench.size()==1 and trench[0].points[-1].distance_to(Vector2(PORTAL_X,40))<.001 and absf(trench[0].heights_m[-1]+7.0)<.0001,"the open trench runs from ground level to the -7.0m portal")
 check(Routes.trench_ribbons(exact.route).size()==1 and is_equal_approx(Routes.structure(exact.route).width*4,10.0),"trench and tunnel use the 10.0m rail structure body")
func test_vertical_clearance():
 for order in ["road_first","rail_first"]:
  for offset in [1.5,1.4]:
   var city=ramp_city()
   var road:=path([Vector2(82+offset,5),Vector2(82+offset,75)])
   var result:Dictionary
   if order=="road_first":
    check(city.add_road(road).ok,"clearance road fixture")
    result=city.add_transit_route(tunnel_points(),"rail",true,heights(DOWN))
   else:
    check(city.add_transit_route(tunnel_points(),"rail",true,heights(DOWN)).ok,"clearance tunnel fixture")
    result=city.add_road(road)
   var expected:bool=offset>=1.5
   check(result.ok==expected and (expected or result.reason=="수직 간격 부족"),"%s: ground road edge %.1f cell before the -10m point -> %s (%s)"%[order,1.5-offset,"pass" if expected else "수직 간격 부족",result.get("reason","")])
 var city=ramp_city()
 check(city.add_transit_route(path([Vector2(2,40),Vector2(10,40),Vector2(82,40),Vector2(150,40)]),"rail",true,heights([0,0,-10,-10])).ok,"tunnel with a ground approach")
 var level:Dictionary=city.add_road(path([Vector2(5,30),Vector2(5,50)]))
 check(level.ok,"a ground road may cross the 0m part at grade: "+str(level.get("reason","")))
 var over_trench:Dictionary=city.add_road(path([Vector2(40,30),Vector2(40,50)]))
 check(not over_trench.ok and over_trench.reason=="수직 간격 부족","a ground road cannot cross the open trench (no level crossing): "+str(over_trench.get("reason","")))
 var over_tunnel:Dictionary=city.add_road(path([Vector2(120,30),Vector2(120,50)]))
 check(over_tunnel.ok,"a ground road crosses over the -10m tunnel (10m clearance): "+str(over_tunnel.get("reason","")))
 for level_m in [-20,-15,-10]:
  var deep:Dictionary=city.add_elevated_road(path([Vector2(135,5),Vector2(135,75)]),heights([level_m,level_m]),"local",false)
  check(deep.ok==(level_m==-20) and (level_m==-20 or deep.reason=="수직 간격 부족"),"underground road at %dm across the -10m rail tunnel: %s"%[level_m,deep.get("reason","ok")])
 var road_first=ramp_city()
 check(road_first.add_elevated_road(path([Vector2(135,5),Vector2(135,75)]),heights([-10,-10])).ok,"same-depth road tunnel first")
 var after:Dictionary=road_first.add_transit_route(tunnel_points(),"rail",false,heights(DOWN))
 check(not after.ok and after.reason=="수직 간격 부족","the rail tunnel after a same-depth road tunnel is red in the other order too: "+str(after.get("reason","")))
 for spec in [[120.0,true],[40.0,false]]:
  var rails=ramp_city()
  check(rails.add_transit_route(path([Vector2(spec[0],5),Vector2(spec[0],75)])).ok,"ground rail fixture at x=%d"%spec[0])
  var tunnel:Dictionary=rails.add_transit_route(tunnel_points(),"rail",false,heights(DOWN))
  check(tunnel.ok==spec[1] and (spec[1] or tunnel.reason=="수직 간격 부족"),"ground rail over the %s: %s"%["covered tunnel" if spec[1] else "open trench",tunnel.get("reason","ok")])
func test_metro_exception():
 var states:Array=[]
 var metros:=[path([Vector2(60,5),Vector2(60,75)]),path([Vector2(120,5),Vector2(120,75)]),path([Vector2(100,40),Vector2(140,40)])]
 for order in [0,1]:
  var city=ramp_city()
  if order==0:
   for metro in metros:check(city.add_transit_route(metro,"metro").ok,"metro first, order 0")
  var tunnel:Dictionary=city.add_transit_route(tunnel_points(),"rail",true,heights(DOWN))
  check(tunnel.ok,"rail trench/tunnel over, under and along metro tunnels is buildable, order %d: %s"%[order,tunnel.get("reason","ok")])
  if order==1:
   for metro in metros:
    var result:Dictionary=city.add_transit_route(metro,"metro")
    check(result.ok,"metro after the rail tunnel is buildable: "+str(result.get("reason","ok")))
  var rows:Array=city.transit_routes.map(func(r):return [r.kind,r.points,r.get("heights_m",PackedFloat64Array())])
  rows.sort_custom(func(a,b):return str(a)<str(b))
  states.append(var_to_bytes(rows))
 check(states.size()==2 and states[0]==states[1],"rail tunnel x metro gives the same records in either build order (no clearance check)")
func test_trench_and_covered_rules():
 var city=ramp_city()
 city.buildings.append(building(91,39,39)) # over the open trench (x=40: -4.2m)
 city.buildings.append(building(92,119,39)) # above the covered -10m tunnel
 city.buildings.append(building(93,39,42)) # beside the trench, outside the 10m body
 var points:=tunnel_points();var levels:=heights(DOWN)
 var plan:Dictionary=city.add_transit_route(points,"rail",false,levels)
 check(plan.ok and plan.get("warning",false) and plan.get("demolish_ids",[])==[91],"only the zoned building over the open trench needs warning B: "+str(plan.get("demolish_ids",[])))
 var unconfirmed:Dictionary=city.add_transit_route(points,"rail",true,levels)
 check(not unconfirmed.ok and unconfirmed.reason=="이미 지어진 건물이 파괴됩니다" and city.transit_routes.is_empty() and not city.find_building(91).is_empty(),"commit without confirmation changes nothing")
 var done:Dictionary=city.add_transit_route(points,"rail",true,levels,true,[91])
 check(done.ok and city.find_building(91).is_empty() and city.transit_routes.size()==1,"confirmed commit demolishes the trench building")
 check(not city.find_building(92).is_empty(),"the building above the covered tunnel stays (passes under, no demolition)")
 check(not city.find_building(93).is_empty(),"an unrelated building beside the trench is excluded")
 check(city._polygon_error(city.footprint({"x":125,"y":39,"size":2})).find("철도")<0,"a new building may stand above the covered tunnel")
 check(city._polygon_error(city.footprint({"x":30,"y":39,"size":2})).find("철도")>=0,"no new building on the open trench")
 for spec in [["medical-clinic",30,false],["medical-clinic",120,true],["park-plaza-4x4",30,false],["park-plaza-4x4",120,true]]:
  var other=ramp_city()
  other.public_facilities.lots.append({"id":95,"public_asset_id":spec[0],"polygon":other.footprint({"x":spec[1],"y":38,"size":4})})
  var result:Dictionary=other.add_transit_route(points,"rail",false,levels)
  check(result.ok==spec[2] and (spec[2] or result.reason=="공공시설과 겹침"),"%s %s -> %s"%[spec[0],"above the covered tunnel" if spec[2] else "on the open trench",result.get("reason","ok")])
 var ground_city=ramp_city()
 ground_city.buildings.append(building(96,5,39))
 var approach:Dictionary=ground_city.add_transit_route(path([Vector2(2,40),Vector2(10,40),Vector2(82,40),Vector2(150,40)]),"rail",false,heights([0,0,-10,-10]))
 check(not approach.ok and approach.reason=="건물 또는 시설과 충돌합니다","the ground part keeps the existing red building rule: "+str(approach.get("reason","")))
func test_zoning():
 var city=ramp_city()
 check(city.add_road(path([Vector2(5,40),Vector2(195,40)])).ok,"zoning road fixture")
 var trench_probe:=Vector2(40.3,44.2);var covered_probe:=Vector2(120.3,44.2)
 check(not city.zoning_grid.parcel_at(trench_probe).is_empty() and not city.zoning_grid.parcel_at(covered_probe).is_empty(),"zoning cells exist beside the road before the rail")
 var result:Dictionary=city.add_transit_route(tunnel_points(44,190),"rail",true,heights(DOWN))
 check(result.ok,"trench and tunnel beside the road: "+str(result.get("reason","")))
 check(city.zoning_grid.parcel_at(trench_probe).is_empty(),"zoning cells on the open trench are deleted")
 check(not city.zoning_grid.parcel_at(covered_probe).is_empty(),"zoning cells above the covered tunnel stay")
 check(city.remove_transit_route(int(city.transit_routes[0].id)).ok and not city.zoning_grid.parcel_at(trench_probe).is_empty(),"removing the trench restores the roadside cells")
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
 var sunk:Dictionary=city.add_transit_route(path([p,p+out*20]),"rail",false,heights([-10,-10]))
 check(not sunk.ok and sunk.reason=="지하 구간에는 역을 둘 수 없습니다","a station port on a tunnel is red: "+str(sunk.get("reason","")))
 var trench_port:Dictionary=city.add_transit_route(path([p,p+out*20]),"rail",false,heights([-5,-5]))
 check(not trench_port.ok and trench_port.reason=="지하 구간에는 역을 둘 수 없습니다","a station port in an open trench is red: "+str(trench_port.get("reason","")))
 var ramp:Dictionary=city.add_transit_route(path([p,p+out*72,p+out*80]),"rail",false,heights([0,-10,-10]))
 check(ramp.ok,"a trench may start at ground level from the station port: "+str(ramp.get("reason","")))
 check(city.public_facilities.remove(int(lot.id)),"station removal fixture")
 check(city.add_transit_route(path([p,p+out*20]),"rail",true,heights([-10,-10])).ok,"a -10m tunnel ending where the port was")
 var again:Dictionary=city.public_facilities.place("train-station-01",Vector2(70,33),0,true)
 check(not again.ok and again.reason=="지하 구간에는 역을 둘 수 없습니다","placing a station onto a tunnel end is red: "+str(again.get("reason","")))
 var x:={"kind":"rail","start":Vector2(20,20)*4,"end":Vector2(28,20)*4,"axis":Vector2(1,0),"station_id":-99}
 var flat=ramp_city()
 check(flat.add_transit_route(path([Vector2(20,20),Vector2(60,20)])).ok and Crossover.available(flat,x),"a straight ground double track still allows the X crossover")
 var tunnel=ramp_city()
 check(tunnel.add_transit_route(path([Vector2(20,20),Vector2(60,20)]),"rail",true,heights([-10,-10])).ok and not Crossover.available(tunnel,x),"no X crossover in a covered tunnel")
 var trench=ramp_city()
 check(trench.add_transit_route(path([Vector2(20,20),Vector2(92,20)]),"rail",true,heights([0,-10])).ok and not Crossover.available(trench,x),"no X crossover in an open trench")
func test_geometry_and_catenary():
 var city=ramp_city()
 check(city.add_road(path([Vector2(120,5),Vector2(120,75)])).ok,"road over the tunnel for geometry")
 check(city.add_transit_route(tunnel_points(),"rail",true,heights(DOWN)).ok,"geometry tunnel fixture")
 var route:Dictionary=city.transit_routes[0]
 var geometry:Dictionary=View.build_geometry(city)
 var trench:Array=geometry.get("trench",[])
 check(not trench.is_empty() and trench.all(func(s):return s.route_id==route.id and s.depths.size()==s.points.size() and Array(s.depths).all(func(h):return h<=.001 and h>=Height.RAIL_PORTAL_M-.001)),"open-trench track shapes carry depths between ground and the -7.0m portal")
 check(trench.any(func(s):return s.texture=="strip") and trench.any(func(s):return s.texture.is_empty()),"the trench carries ballast and textured running strips")
 var leaked:=false
 for shape:Dictionary in geometry.rail:
  for point:Vector2 in shape.points:
   if point.x>10.6 and absf(point.y-40)<1.5:leaked=true
 check(not leaked,"the ground rail layer stops where the trench leaves the ground")
 var bands:Array=geometry.metro.filter(func(s):return s.get("rail_tunnel",false))
 check(not bands.is_empty() and bands.all(func(s):return s.color==Color("15181a") and s.depths.size()==s.points.size() and Array(s.depths).all(func(h):return h<=Height.RAIL_PORTAL_M+.001)),"the covered tunnel is a solid 15181a underground-view band at its own depth")
 var reach:=0.0;var x_min:=INF
 for band:Dictionary in bands:
  for point:Vector2 in band.points:reach=maxf(reach,absf(point.y-40));x_min=minf(x_min,point.x)
 check(absf(reach*4-5.0)<.05 and absf(x_min-PORTAL_X)<.01,"tunnel band: 10m structure width from the portal on (%.2fm, x=%.2f)"%[reach*8,x_min])
 var own:Array=geometry.catenary.filter(func(c):return c.get("route_id",-1)==route.id)
 var contacts:Array=own.filter(func(c):return c.kind=="contact")
 check(not contacts.is_empty() and contacts.all(func(c):return absf(c.a_height-3.8-Height.height_at(route,c.a))<.02 and absf(c.b_height-3.8-Height.height_at(route,c.b))<.02),"contact wire stays 3.8m above the rail top down the trench")
 check(not own.is_empty() and own.all(func(c):return maxf(c.a.x,c.b.x)<=PORTAL_X+.01),"no catenary inside the covered tunnel")
 check(contacts.any(func(c):return maxf(c.a.x,c.b.x)>PORTAL_X-.3 and minf(c.a_height,c.b_height)< -2.9),"the trench wire runs down to the portal")
 var poles:Array=own.filter(func(c):return c.kind=="pole")
 check(poles.any(func(c):return c.a_height< -1 and absf(c.b_height-c.a_height-5.3)<.001) and poles.all(func(c):return absf(c.a_height-Height.height_at(route,c.a))<.02),"trench poles stand on the trench floor (top +5.3m)")
 check(own.any(func(c):return c.get("trench",false)) and own.all(func(c):return not c.get("deck",false)),"trench catenary is marked for the trench clip group, never as deck")
func test_line_and_joints():
 var city=ramp_city()
 check(city.add_transit_route(path([Vector2(120,5),Vector2(120,75)])).ok,"ground rail crossing above")
 check(city.add_transit_route(tunnel_points(),"rail",true,heights(DOWN)).ok,"tunnel under it")
 var planner=Planner.new();planner.build_graph(city,"rail")
 check(not planner.nodes.any(func(n):return n.distance_to(Vector2(120,40)*4)<.01),"no switch where the ground track passes over the tunnel")
 var joined=ramp_city()
 check(joined.add_transit_route(path([Vector2(4,40),Vector2(10,40)])).ok,"ground approach")
 var trench:Dictionary=joined.add_transit_route(tunnel_points(),"rail",false,heights(DOWN))
 check(trench.ok,"a trench continues from the end of a ground track: "+str(trench.get("reason","")))
 var jump:Dictionary=joined.add_transit_route(path([Vector2(10,40),Vector2(40,40)]),"rail",false,heights([-10,-10]))
 check(not jump.ok and jump.reason=="높이가 다른 선로와는 이을 수 없습니다","a tunnel cannot join a ground track at a different height: "+str(jump.get("reason","")))
func test_cost_and_grid_off():
 var city=ramp_city()
 var config:Dictionary=Height.config.get("rail_depth_cost",{})
 check(not config.is_empty() and config.get("enabled",true)==false and str(config.get("approval_status","")).contains("pending"),"rail depth cost is a disabled, pending reversible placeholder")
 var factors:Array=[]
 for level in [0,-10,-20]:
  var plan:Dictionary=city.add_transit_route(path([Vector2(20,50),Vector2(80,50)]),"rail",false,heights([level,level]))
  factors.append(float(plan.get("height_cost_factor",-1)))
 check(is_equal_approx(factors[0],1.0) and factors[1]>factors[0] and factors[2]-factors[1]>factors[1]-factors[0],"placeholder factor grows non-linearly with depth: "+str(factors))
 var points:=path([Vector2(20.37,30.11),Vector2(92.37,30.11),Vector2(110.91,30.73)])
 var levels:=heights(DOWN)
 check(city.add_transit_route(points,"rail",true,levels).ok,"off-grid rail tunnel commit")
 check(city.transit_routes[-1].points==points and city.transit_routes[-1].heights_m==levels,"grid OFF keeps every confirmed point and depth exactly")
