extends SceneTree
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
static func fixture(kind:String="rail"):
 var city=load("res://tests/transit_operations_fixture.gd").rail_city(kind)
 var first:Dictionary=city.public_facilities.lots[0]
 var p:PackedVector2Array=first.internal_points
 var left:Vector2=p[0] if p[0].x<p[-1].x else p[-1]
 var linked:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(0,left.y),Vector2(16,left.y)]),kind)
 assert(linked.ok,str(linked))
 var work:Dictionary={}
 for parcel:Dictionary in city.zoning_grid.parcels.values():
  if parcel.center.x<74 or parcel.center.y<40:continue
  work=city.add_building_at(parcel.center,"industrial")
  if work.ok:break
 assert(work.get("ok",false),str(work))
 city.population.sync(city.buildings)
 city.population.core.PrepareLaborWorld(city.buildings,city.roads)
 return city
func test_walk_graph():
 var graph=load("res://core/transit_access_graph.gd").new()
 var paths:Array=[{"id":1,"points":PackedVector2Array([Vector2(0,0),Vector2(20,0)])},{"id":2,"points":PackedVector2Array([Vector2(10,0),Vector2(10,10)])}]
 var requests:Array=[{"key":"a","host":1,"point":Vector2(1,0)},{"key":"b","host":2,"point":Vector2(10,8)}]
 graph.build(paths,requests)
 check(is_equal_approx(graph.distances("a").get("b",-1),68.0),"walking uses actual unsampled T path in metres")
 check(graph.has_method("rail_distances"),"regional rail feeders require directed smooth reachability")
 if graph.has_method("rail_distances"):check(not graph.rail_distances("a").has("b"),"rail cannot use a ninety-degree walking junction")
 paths[1].points[0]=Vector2(10,.01);graph.build(paths,requests)
 check(not graph.distances("a").has("b"),"nearby disconnected sidewalks cannot become transfer links")
 paths[1].points[0]=Vector2(10,0);paths[1].height=10.0;graph.build(paths,requests)
 check(not graph.distances("a").has("b"),"grade-separated XY crossings cannot transfer")
func test_transfer():
 var city=fixture();city.width=320;city.height=180
 city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 var road:Dictionary=city.add_road(PackedVector2Array([Vector2(110,40),Vector2(300,40)]),"local",true,4)
 check(road.ok,"transfer fixture extends actual local sidewalk")
 var ids:Array=[]
 for x:float in [96.0,230.0]:
  var placed:Dictionary=city.public_facilities.place("subway-entrance-01",Vector2(x,36.5),0,true)
  check(placed.ok,"transfer fixture places metro entrance")
  if not placed.ok:return
  ids.append(placed.record.id if placed.has("record") else city.public_facilities.lots[-1].id)
 var a:PackedVector2Array=city.public_facilities.lots[-2].internal_points.duplicate()
 var b:PackedVector2Array=city.public_facilities.lots[-1].internal_points.duplicate()
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 var join:Dictionary=city.add_transit_route(PackedVector2Array([a[-1],b[0]]),"metro")
 check(join.ok,"metro stations physically connected")
 var path:=PackedVector2Array([b[-1],Vector2(260,a[0].y)])
 for i in range(1,49):
  var angle:float=-PI/2+PI*i/48;path.append(Vector2(260,a[0].y+15)+Vector2(cos(angle),sin(angle))*15)
 path.append(Vector2(84,a[0].y+30))
 for i in range(1,49):
  var angle:float=PI/2+PI*i/48;path.append(Vector2(84,a[0].y+15)+Vector2(cos(angle),sin(angle))*15)
 path.append(a[0])
 var loop:Dictionary=city.add_transit_route(path,"metro")
 check(loop.ok,"metro has physical P3 return loop "+str(loop))
 check(city.create_transit_line("metro",ids).ok,"transfer metro line operates")
 var work:Dictionary={}
 for parcel:Dictionary in city.zoning_grid.parcels.values():
  if parcel.center.x<234 or parcel.center.y<40:continue
  work=city.add_building_at(parcel.center,"industrial")
  if work.ok:break
 check(work.get("ok",false),"remote workplace placed on actual parcel")
 city.population.sync(city.buildings)
 var context:Dictionary=city.population.labor_commuting_context()
 var choices:Array=city.commuting._proven_routes(city,city.regional_exchange(),context)
 var transfers:Array=choices.filter(func(route):return route.local_id==work.building.id and route.mode=="rail" and route.legs.any(func(leg):return leg.kind=="metro" and leg.has("line_id")))
 check(not transfers.is_empty(),"regional rail transfers on physical sidewalk to operating metro for distant workplace")
 if not transfers.is_empty():
  check(transfers[0].legs.any(func(leg):return leg.kind=="walk" and leg.has("from_stop")),"transfer route retains explicit walk leg")
 city.remove_transit_line(2)
 choices=city.commuting._proven_routes(city,city.regional_exchange(),context)
 check(not choices.any(func(route):return route.local_id==work.building.id),"physical metro track without operating line cannot complete transfer")
func run():
 var city=fixture()
 var context:Dictionary=city.population.labor_commuting_context()
 var routes:Array=city.commuting._proven_routes(city,city.regional_exchange(),context)
 check(routes.is_empty(),"physical rail alone grants no passenger commute")
 city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 routes=city.commuting._proven_routes(city,city.regional_exchange(),context)
 check(routes.any(func(route):return route.mode=="rail" and route.local_id==city.buildings[0].id),"operating line and physical boundary path provide walk-access rail commute")
 for lot:Dictionary in city.public_facilities.lots:
  lot.position+=Vector2(0,20)
  for i in range(lot.polygon.size()):lot.polygon[i]+=Vector2(0,20)
 var far:Array=city.commuting._proven_routes(city,city.regional_exchange(),context)
 check(far.is_empty(),"stale host ID cannot teleport a station entrance onto a distant road")
 city=fixture();city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 context=city.population.labor_commuting_context()
 city.transit_lines[0].enabled=false
 check(city.commuting._proven_routes(city,city.regional_exchange(),context).is_empty(),"disabled lines grant no passenger access")
 city.transit_lines[0].enabled=true
 var before:Array=city.commuting._proven_routes(city,city.regional_exchange(),context)
 city.public_facilities.lots.reverse();city.transit_routes.reverse()
 var after:Array=city.commuting._proven_routes(city,city.regional_exchange(),context)
 before.sort_custom(func(a,b):return a.route_id<b.route_id);after.sort_custom(func(a,b):return a.route_id<b.route_id)
 check(before==after,"physical route choices deterministic under record permutation")
 test_walk_graph();test_transfer()
 city.population_enabled=true
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.commuting_status().inbound>0,"native worker reserves actual rail-only inbound employment")
 check(not city.commuting.last_plan.get("flows",[]).is_empty(),"native publication carries authoritative choices for checkpoint capture")
 var Adapter=load("res://core/city_simulation_worker.gd")
 city.funds-=7 # Main-owned utility/transaction debit after the published boundary.
 city.power.pending_doth=.25
 var saved:Dictionary=Adapter.capture(city)
 check(saved.model.values.funds==city.funds and saved.model.values.power.values.pending_doth==city.power.pending_doth,"checkpoint retains main-owned treasury debit and utility carry")
 var authoritative:Dictionary=city.simulation.worker.ExportValidationState()
 check(saved.population==authoritative.population,"checkpoint exports worker-owned population rather than stale main core")
 var restored=Adapter.new();restored.boot(saved)
 var next:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},2.0,1)
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(next.commuting_summary==city.commuting_status(),"native checkpoint restores authoritative employment and mode choices")
 check(next.transit_state==city.transit_state,"native checkpoint resumes the exact P3 consist")
 city.simulation.resume();city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var frozen:float=city.clock.game_seconds
 check(Adapter.capture(city).is_empty(),"checkpoint refuses an unpublished native result")
 check(city.remove_transit_line(1).get("queued",false),"line removal waits in native FIFO")
 city.advance_society(100)
 check(city.clock.game_seconds==frozen,"busy native worker freezes logical commuting time")
 city.simulation.validation_publish()
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.commuting_status().inbound==0,"same-day line removal invalidates passenger routes and reservations")
 city.simulation.resume()
 check(city.add_road(PackedVector2Array([Vector2(110,40),Vector2(120,40)]),"local",true,4).ok,"fallback has a real boundary road")
 check(Adapter.capture(city).is_empty(),"checkpoint refuses accepted but unsubmitted world edits")
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.commuting_status().inbound>0 and city.commuting.last_plan.flows.all(func(flow):return flow.mode=="road"),"native passengers fall back to connected automobiles without rail service")
 var old:Dictionary=Adapter.capture(city)
 old.model.values.erase("transit_lines");old.model.values.erase("transit_state");old.model.values.erase("commuting")
 var legacy=Adapter.new();check(legacy.boot(old).ok,"old checkpoint with no P3/P4 fields boots")
 var legacy_result:Dictionary=legacy.run_step({"base_tick":0,"base_revision":0},2.0,1)
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(legacy_result.commuting_summary==city.commuting_status(),"old checkpoint retains road fallback employment")
 check(legacy_result.funds==city.funds and legacy_result.loan_status==city.loan_status(),"old restore does not duplicate fiscal settlement")
 city.simulation.shutdown()
 print("TRANSIT_COMMUTING checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
