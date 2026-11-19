extends SceneTree
## Review fix 3 (P5 MAJOR; user rule 2026-11-19, ASSET_REQUEST_RAIL_PARK_KO.md 5절 12번): when a rail,
## metro or freight line's route path changes for any reason, its consist (the same object, load and
## counters kept) is moved to the line start and leaves by the first-stop rules (clear check, headway).
## A cut path stops it where it is; once rejoined it is moved to the start. Schedule-only edits and
## buses keep running. Consists sent to one start leave one after another and are never drawn overlapping.
const City=preload("res://core/city_model.gd")
const Operations=preload("res://core/transit_operations.gd")
const Planner=preload("res://core/transit_line_planner.gd")
const Fixture=preload("res://tests/transit_operations_fixture.gd")
const LIMIT:=150
## Consists carry no load fields yet (P4 routes commuters per step), so plant some to prove they ride along.
const LOAD:={"passengers":37,"cargo_tonnes":12.5}
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func run():
 test_rail_line()
 for kind:String in ["metro","freight"]:test_loop_kind(kind)
 test_bus()
 test_shared_start()
 print("REVIEW_FIX_REGEN checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
## Three real stations in a row (A-B-C) joined by ground track: a terminal turnback line.
func row_city()->Dictionary:
 var city=City.new(160,90,42)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(150,40)]),"local",true,4)
 for x:float in [30.0,70.0,110.0]:
  if not city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok:return {}
 var tracks:Array=[]
 for lot:Dictionary in city.public_facilities.lots:
  var p:PackedVector2Array=lot.internal_points
  if p[0].x>p[-1].x:p.reverse()
  tracks.append(p)
 var joins:Array=[]
 for i in range(2):
  var join:=PackedVector2Array([tracks[i][-1],tracks[i+1][0]])
  if not city.add_transit_route(join).ok:return {}
  joins.append(join)
 return {"city":city,"ids":city.public_facilities.lots.map(func(lot):return lot.id),"joins":joins}
func line_of(city,id:int)->Dictionary:
 for line:Dictionary in city.transit_lines:
  if int(line.id)==id:return line
 return {}
func train(city,id:int)->Dictionary:return city.transit_state.trains.get(id,{})
func status(city,id:int)->String:return str(city.transit_state.lines.get(id,{}).get("status",""))
func plan_of(city,id:int)->Dictionary:return Planner.new().rail_plan(city,line_of(city,id))
func describe(t:Dictionary)->String:
 return "none" if t.is_empty() else "stops=%s distance=%.1f drawn=%d"%[str(t.plan.stops.map(func(s):return s.id)),float(t.distance),t.visible.size()]
func station_centre(city,id:int)->Vector2:
 for lot:Dictionary in city.public_facilities.lots:
  if int(lot.id)==id:return (lot.internal_points[0]+lot.internal_points[-1])*2.0
 return Vector2.INF
func centre(poses:Array)->Vector2:
 var sum:=Vector2.ZERO;var count:=0
 for pose:Dictionary in poses:
  if not pose.get("cargo",false):sum+=pose.position;count+=1
 return sum/maxi(count,1)
## The consist sits on the line's current plan at its first stop and is drawn there.
func at_start(city,id:int)->bool:
 var t:Dictionary=train(city,id);var plan:Dictionary=plan_of(city,id)
 if t.is_empty() or t.visible.is_empty() or t.plan!=plan or float(t.distance)!=0.0 or int(t.next_stop)!=1:return false
 return t.visible==Operations.poses(id,t) and centre(t.visible).distance_to(station_centre(city,int(plan.stops[0].id)))<8.0
## The same object as `ref`, with the planted load and its counters (not a fresh consist).
func kept(city,id:int,ref:Dictionary,before:Dictionary)->bool:
 var t:Dictionary=train(city,id)
 return is_same(ref,t) and t.get("passengers")==LOAD.passengers and t.get("cargo_tonnes")==LOAD.cargo_tonnes and t.kind==before.kind and int(before.departures)>=1 and int(t.departures)>=int(before.departures)
## Seconds until the consist leaves its first stop again on the line's current plan (-1 if never).
func departs_within(city,operation,id:int,limit:int)->int:
 var plan:Dictionary=plan_of(city,id);var start:=int(train(city,id).get("departures",0))
 for i in range(limit):
  operation.advance(city,1.0)
  var t:Dictionary=train(city,id)
  if not t.is_empty() and t.plan==plan and int(t.departures)>start and float(t.distance)>5.0 and status(city,id)!="blocked":return i+1
 return -1
func test_rail_line():
 var built:=row_city()
 check(not built.is_empty(),"fixture: three real stations joined in a row")
 if built.is_empty():return
 var city=built.city;var ids:Array=built.ids
 var made:Dictionary=city.create_transit_line("rail",ids,{"dwell_seconds":4.0,"headway_seconds":20.0})
 check(made.ok,"line A-B-C operates: "+str(made.get("reason","")))
 if not made.ok:return
 var id:int=int(made.line.id)
 var operation=Operations.new()
 for i in range(60):operation.advance(city,1.0)
 var ref:Dictionary=train(city,id)
 check(not ref.is_empty() and float(ref.distance)>5.0 and int(ref.departures)>=1,"a consist is running before the edits: "+describe(ref))
 if ref.is_empty():return
 ref.merge(LOAD,true)
 # Schedule-only edit (87bc12e contract): no re-plan, the same consist keeps running.
 var running:Dictionary=ref.duplicate(true)
 check(city.update_transit_line(id,ids,{"dwell_seconds":6.0}).ok,"dwell-only edit accepted")
 var last:=float(running.distance);var kept_running:=true
 for i in range(20):
  operation.advance(city,1.0)
  var t:Dictionary=train(city,id)
  if not is_same(ref,t) or t.plan!=running.plan or float(t.distance)<last or status(city,id)=="blocked":kept_running=false;break
  last=float(t.distance)
 check(kept_running and last>float(running.distance)+5.0,"a dwell-only edit keeps the same consist running on its route: "+describe(train(city,id)))
 # Stop B removed while running: the same consist moves to the start of the new path.
 var before:Dictionary=ref.duplicate(true)
 check(city.update_transit_line(id,[ids[0],ids[2]]).ok,"stop B removed while the consist runs")
 var saved:PackedByteArray=var_to_bytes([city.transit_lines,city.transit_state])
 operation.advance(city,1.0)
 check(at_start(city,id),"the running consist is moved to the first stop A of the new route: "+describe(train(city,id))+" was "+describe(before))
 check(kept(city,id,ref,before) and int(train(city,id).departures)==int(before.departures),"it is the same consist, passengers %s and cargo %s kept"%[train(city,id).get("passengers"),train(city,id).get("cargo_tonnes")])
 check(status(city,id)=="dwelling","the moved consist waits at the first stop, the line is not blocked: "+status(city,id))
 var took:=departs_within(city,operation,id,LIMIT)
 check(took>0 and kept(city,id,ref,before),"it leaves A and runs the route without B within %ds: %d"%[LIMIT,took])
 # Save round trip at the edit: restored state and a fresh runtime give the same consist.
 var expected:=var_to_bytes(city.transit_state.trains)
 var restored:Array=bytes_to_var(saved)
 city.transit_lines=restored[0];city.transit_state=restored[1]
 operation=Operations.new()
 for i in range(1+maxi(took,0)):operation.advance(city,1.0)
 check(var_to_bytes(city.transit_state.trains)==expected,"after a save round trip the same consist runs the new route: "+describe(train(city,id)))
 ref=train(city,id)
 # Stop B added back: moved to the start again, now on the A-B-C route.
 before=ref.duplicate(true)
 check(city.update_transit_line(id,ids).ok,"stop B added back while the consist runs")
 operation.advance(city,1.0)
 check(at_start(city,id) and kept(city,id,ref,before) and plan_of(city,id).stops.map(func(s):return s.id).has(ids[1]),"adding B back moves the same consist to the start of the A-B-C route: "+describe(train(city,id)))
 took=departs_within(city,operation,id,LIMIT)
 check(took>0,"it runs the route with B again within %ds: %d"%[LIMIT,took])
 # Track B-C cut: the consist stops where it is. Rejoined: moved to the start, runs again.
 var gap:int=int(city.transit_routes[-1].id)
 for route:Dictionary in city.transit_routes:
  if route.points==built.joins[1]:gap=int(route.id)
 var removed:Dictionary=city.remove_transit_route(gap)
 check(removed.get("ok",false),"track B-C demolished: "+str(removed.get("reason","")))
 before=ref.duplicate(true)
 operation.advance(city,1.0)
 var held:Dictionary=train(city,id).duplicate(true)
 var frozen:bool=is_same(ref,train(city,id)) and status(city,id)=="blocked" and held.visible==before.visible and float(held.distance)==float(before.distance)
 for i in range(5):
  operation.advance(city,1.0)
  if not is_same(ref,train(city,id)) or status(city,id)!="blocked" or train(city,id).visible!=held.visible:frozen=false
 check(frozen and not held.visible.is_empty(),"a cut path stops the same consist where it is, still drawn: %s %s"%[status(city,id),describe(train(city,id))])
 check(city.add_transit_route(built.joins[1]).ok,"track B-C rebuilt")
 operation.advance(city,1.0)
 check(at_start(city,id) and kept(city,id,ref,before),"once rejoined the same consist is moved to the first stop: "+describe(train(city,id)))
 took=departs_within(city,operation,id,LIMIT)
 check(took>0,"after the track is rejoined it runs again within %ds: %d"%[LIMIT,took])
 # A block lifted onto the identical path (e.g. an obstructed terminal X) still restarts from the start.
 var stops:Array=line_of(city,id).stops.duplicate()
 before=ref.duplicate(true)
 line_of(city,id).stops=stops+[-1]
 operation.advance(city,1.0)
 check(status(city,id)=="blocked" and is_same(ref,train(city,id)) and train(city,id).visible==before.visible,"a blocked plan holds the consist where it is")
 line_of(city,id).stops=stops
 operation.advance(city,1.0)
 check(plan_of(city,id)==before.plan and at_start(city,id) and kept(city,id,ref,before),"when the same path runs again the consist still restarts from the first stop: "+describe(train(city,id)))
## Metro and freight follow the same rule (loop fixture, stop order A-B changed to B-A).
func test_loop_kind(kind:String):
 var city=Fixture.rail_city("metro" if kind=="metro" else "rail")
 var ids:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 var made:Dictionary=city.create_transit_line(kind,ids,{"dwell_seconds":2.0,"headway_seconds":20.0})
 check(made.ok,kind+" loop line A-B operates: "+str(made.get("reason","")))
 if not made.ok:return
 var id:int=int(made.line.id)
 var operation=Operations.new()
 for i in range(30):operation.advance(city,1.0)
 var ref:Dictionary=train(city,id)
 check(not ref.is_empty() and float(ref.distance)>5.0 and int(ref.departures)>=1,kind+" consist is running before the edit: "+describe(ref))
 if ref.is_empty():return
 ref.merge(LOAD,true)
 var before:Dictionary=ref.duplicate(true)
 var cargo:int=before.visible.filter(func(pose):return pose.get("cargo",false)).size()
 check(cargo==(1 if kind=="freight" else 0),kind+" consist draws its cargo containers: %d"%cargo)
 check(city.update_transit_line(id,[ids[1],ids[0]]).ok,kind+" stop order changed to B-A")
 operation.advance(city,1.0)
 var t:Dictionary=train(city,id)
 check(at_start(city,id) and int(plan_of(city,id).stops[0].id)==int(ids[1]),kind+" consist is moved to the new first stop B: "+describe(t))
 check(kept(city,id,ref,before) and int(t.departures)==int(before.departures) and t.visible.size()==before.visible.size() and t.visible.filter(func(pose):return pose.get("cargo",false)).size()==cargo,kind+" same consist with its load, cars and cargo containers")
 check(departs_within(city,operation,id,LIMIT)>0,kind+" moved consist runs the B-A route within %ds"%LIMIT)
## Buses are not part of the rule: a bus line edit keeps the existing bus behaviour.
func test_bus():
 var city=load("res://tests/test_scheduled_buses.gd").fixture(4)
 var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 var made:Dictionary=city.create_transit_line("bus",stops,{"dwell_seconds":1.0})
 check(made.ok,"bus line operates: "+str(made.get("reason","")))
 if not made.ok:return
 var id:int=int(made.line.id)
 var operation=Operations.new()
 for i in range(5):operation.advance(city,1.0)
 var vehicles:Array=city.transit_state.bus.get("vehicles",[])
 check(vehicles.size()==1 and float(vehicles[0].distance)>0.0,"a bus is running before the edit")
 if vehicles.size()!=1:return
 var before:Dictionary=vehicles[0].duplicate(true)
 var drawn:Vector2=city.transit_state.bus.visible[0].position
 var edited:Dictionary=city.update_transit_line(id,[stops[1],stops[0]])
 check(edited.ok,"bus stop order changed: "+str(edited.get("reason","")))
 operation.advance(city,1.0)
 vehicles=city.transit_state.bus.get("vehicles",[])
 var moved_by:float=city.transit_state.bus.visible[0].position.distance_to(drawn) if not city.transit_state.bus.get("visible",[]).is_empty() else INF
 check(vehicles.size()==1 and vehicles[0].id==before.id and vehicles[0].route==before.route and float(vehicles[0].distance)>=float(before.distance) and moved_by<15.0 and city.transit_state.trains.is_empty(),"the bus is not moved to the line start: same bus on its route, %.1fm in 1s"%moved_by)
## Consists of two lines sent to the same start: placed one at a time, never drawn overlapping,
## and they leave one after another by the first-stop clear check and headway.
func test_shared_start():
 var built:=row_city()
 check(not built.is_empty(),"shared-start fixture")
 if built.is_empty():return
 var city=built.city;var ids:Array=built.ids
 var lines:Array=[]
 for i in range(2):
  var made:Dictionary=city.create_transit_line("rail",ids,{"dwell_seconds":4.0,"headway_seconds":20.0})
  if made.ok:lines.append(int(made.line.id))
 check(lines.size()==2,"two lines A-B-C share the first stop A")
 if lines.size()!=2:return
 var operation=Operations.new()
 var both:=false
 for i in range(LIMIT):
  operation.advance(city,1.0)
  if lines.all(func(id):return float(train(city,id).get("distance",0.0))>40.0):both=true;break
 check(both,"both consists run before the edit")
 if not both:return
 var refs:Dictionary={};var counts:Dictionary={}
 for id:int in lines:
  refs[id]=train(city,id);refs[id].merge(LOAD,true);counts[id]=int(refs[id].departures)
 for id:int in lines:check(city.update_transit_line(id,[ids[0],ids[2]]).ok,"line %d: stop B removed"%id)
 operation.advance(city,1.0)
 var placed:Array=lines.filter(func(id):return not train(city,id).visible.is_empty())
 var waiting:Array=lines.filter(func(id):return train(city,id).visible.is_empty())
 check(placed.size()==1 and waiting.size()==1 and at_start(city,placed[0]) and status(city,waiting[0])=="waiting","one consist is placed at the shared start, the other waits undrawn: placed=%s waiting=%s"%[placed,waiting])
 check(lines.all(func(id):return is_same(refs[id],train(city,id)) and train(city,id).get("passengers")==LOAD.passengers),"both stay the same consists with their load")
 if placed.size()!=1:return
 var overlap:=false;var shown:=false;var entered:=false;var left:Dictionary={}
 for i in range(LIMIT):
  for id:int in lines:
   var t:Dictionary=train(city,id)
   if not t.visible.is_empty() and not Operations.clear(t.visible,city.transit_state.trains,id):overlap=true
   if not left.has(id) and int(t.departures)>int(counts[id]):left[id]=float(t.last_departure)
  if left.size()==2:break
  operation.advance(city,1.0)
  if not shown and not train(city,waiting[0]).visible.is_empty():shown=true;entered=at_start(city,waiting[0])
 check(not overlap,"consists sent to one start are never drawn overlapping")
 check(shown and entered,"the waiting consist is placed at the start once it is clear")
 check(left.size()==2 and float(left.get(placed[0],INF))<float(left.get(waiting[0],-INF)),"they leave the start one after another: %s"%str(left))
 check(lines.all(func(id):return is_same(refs[id],train(city,id)) and train(city,id).plan==plan_of(city,id)),"both run the new route as the same consists")
