extends SceneTree

const Fixture = preload("res://tests/transit_operations_fixture.gd")
const Cross = preload("res://core/terminal_crossover.gd")
const View = preload("res://core/transit_view.gd")
const Ops = preload("res://core/transit_operations.gd")

const ERROR_TEXT := "종점 역 앞에 곧은 복선 8칸이 필요합니다"
var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(condition: bool, label: String):
 checks += 1
 if not condition:
  failures += 1
  printerr("FAIL "+label)

func run():
 for kind: String in ["rail", "metro"]:
  test_create(kind)
 test_obstructions()
 test_through_conflict()
 test_fifo()
 test_connectivity()
 print("TERMINAL_TURNBACK checks=%d failed=%d" % [checks, failures])
 quit(1 if failures else 0)

func test_create(kind: String):
 var city = Fixture.rail_city(kind)
 city.remove_transit_route(city.transit_routes[-1].id)
 var stops: Array = city.public_facilities.lots.map(func(lot): return lot.id)
 var funds: int = city.funds
 var result: Dictionary = city.create_transit_line(kind, stops)
 check(result.ok, "production creation accepts straight out/back "+kind)
 check(city.funds == funds, "automatic terminal X is free "+kind)
 if not result.ok:
  return
 var plan: Dictionary = load("res://core/transit_line_planner.gd").new().rail_plan(city, result.line)
 check(plan.ok, "production planner resolves newly created terminal line "+kind)
 if not plan.ok:
  return
 var switches: Dictionary = city.call("terminal_crossovers") if city.has_method("terminal_crossovers") else {}
 check(switches.size() == 2, "two physical terminal switches "+kind)
 test_geometry(city, kind, switches)
 var second: Dictionary = city.create_transit_line(kind, [stops[1],stops[0]])
 check(second.ok, "reverse ordered line shares terminals "+kind)
 if city.has_method("terminal_crossovers") and second.ok:
  check(city.terminal_crossovers().values().all(func(x):return x.line_ids.size()==2), "shared crossover refcounts "+kind)
  var before := var_to_bytes([city.transit_lines, city.next_transit_line_id, city.funds])
  var rejected: Dictionary = city.update_transit_line(result.line.id, [stops[0],stops[0]])
  check(not rejected.ok and before == var_to_bytes([city.transit_lines, city.next_transit_line_id, city.funds]), "rejected update is atomic "+kind)
  var updated: Dictionary = city.update_transit_line(result.line.id, [stops[1],stops[0]], {"dwell_seconds":2.0})
  check(updated.ok and updated.line.id==result.line.id and city.next_transit_line_id==3, "update keeps id and watermark "+kind)
  city.remove_transit_line(second.line.id)
  check(city.terminal_crossovers().size()==2, "surviving owner retains both switches "+kind)
  city.remove_transit_line(result.line.id)
  check(city.terminal_crossovers().is_empty(), "last deletion removes switches "+kind)
 city = Fixture.rail_city(kind)
 city.remove_transit_route(city.transit_routes[-1].id)
 city.remove_transit_route(city.transit_routes[-1].id)
 var bad: Dictionary = city.create_transit_line(kind, stops)
 check(not bad.ok and bad.reason == ERROR_TEXT and city.next_transit_line_id==1, "missing host rejected with exact message "+kind)
 test_motion(kind)

func test_motion(kind: String):
 var city = Fixture.rail_city(kind)
 city.remove_transit_route(city.transit_routes[-1].id)
 var ids: Array = city.public_facilities.lots.map(func(lot):return lot.id)
 var line: Dictionary = city.create_transit_line(kind,ids,{"dwell_seconds":2.0,"headway_seconds":1.0})
 if not line.ok:return
 var ops = load("res://core/transit_operations.gd").new()
 var previous: Dictionary = {}
 var non_teleport := true
 var reversed := false
 var dwelled := false
 var first: Vector2 = Vector2.ZERO
 var return_near_start := false
 for step in range(300):
  ops.advance(city,0.25)
  var poses: Array = city.transit_state.visible
  if poses.is_empty():continue
  if previous.is_empty():first = poses[0].position
  for pose: Dictionary in poses:
   if previous.has(pose.id):
    var old: Dictionary = previous[pose.id]
    if pose.position.distance_to(old.position)>4.1:non_teleport=false
    if pose.heading.dot(old.heading)<-0.95:reversed=true
   previous[pose.id]=pose
  if reversed and poses[0].position.distance_to(first)<4:return_near_start=true
  if step>12 and city.transit_state.lines[line.line.id].status=="dwelling":dwelled=true
 check(non_teleport and not previous.is_empty(), "stable car IDs move continuously through reversal "+kind)
 check(reversed and dwelled and return_near_start, "dwell and reverse at far terminal and physically return "+kind)

func test_geometry(city, kind: String, switches: Dictionary):
 var geometry := View.build_geometry(city)
 if kind=="metro":
  check(geometry.crossovers.is_empty() and geometry.catenary.is_empty() and not geometry.metro.is_empty(),"metro crossing is operational but has no X artwork")
 else:
  check(geometry.crossovers.size()==2 and geometry.rail[-1].texture=="strip_rails","rail X rails draw over textured ballast")
 for x: Dictionary in switches.values():
  var axis: Vector2 = x.axis
  var center: Vector2 = (x.start+x.end)/2.0
  var radius: float = x.radius_m
  check(absf(radius-(65.0 if kind=="rail" else 32.9))<0.03 and radius>=32,"derived radius within nominal tolerance "+kind)
  var valid := true
  for path: PackedVector2Array in x.paths:
   var mid := int((path.size()-1)/2.0)
   var shift: Vector2 = path[-1]-path[0]
   var sign_value := signf(shift.dot(axis.orthogonal()))
   var arc0: Vector2 = path[0]+axis.orthogonal()*radius*sign_value
   var arc1: Vector2 = path[-1]-axis.orthogonal()*radius*sign_value
   valid = valid and absf(shift.dot(axis)-32.0)<0.002 and absf(absf(shift.dot(axis.orthogonal()))-(4.0 if kind=="rail" else 8.3))<0.002
   valid = valid and path[mid].distance_to(center)<0.002
   for i in range(path.size()):
    if absf(path[i].distance_to(arc0 if i<=mid else arc1)-radius)>0.002:valid=false
  check(valid,"two opposed tangent arcs meet exact 32m host and cross at center "+kind)
  if kind!="rail":continue
  var ground: Array = geometry.catenary
  var contacts: Array = ground.filter(func(c):return c.kind=="contact" and c.get("crossover_key","")==x.key)
  var attached := true
  for path: PackedVector2Array in x.paths:
   var branch: Array = contacts.filter(func(c):return (c.b-c.a).cross(axis)*(path[-1]-path[0]).cross(axis)>0.0)
   if branch.is_empty():attached=false;continue
   var a: Vector2 = branch[0].a
   var b: Vector2 = branch[-1].b
   for endpoint: Vector2 in [a,b]:
    attached = attached and ground.any(func(c):return c.kind=="pull" and c.a.distance_to(endpoint)<0.0005)
   for point: Vector2 in path:
    if (point-a*4.0).dot(axis)>=0.0 and Geometry2D.get_closest_point_to_segment(point/4.0,a,b).distance_to(point/4.0)*4.0>0.62:attached=false
   attached = attached and branch.all(func(c):return c.a_height==3.8 and c.a.distance_to(c.b)<=1.0001)
  check(attached and not contacts.is_empty(),"two straight X contact wires attach to lawful supports and clear pantographs")

func test_through_conflict():
 var city = Fixture.rail_city()
 var loop_points: PackedVector2Array = city.transit_routes[-1].points.duplicate()
 city.remove_transit_route(city.transit_routes[-1].id)
 var ids: Array = city.public_facilities.lots.map(func(lot):return lot.id)
 var reversing: Dictionary = city.create_transit_line("rail",ids,{"dwell_seconds":2.0,"headway_seconds":1.0})
 check(reversing.ok and city.add_transit_route(loop_points).ok,"existing terminal service and real physical loop coexist")
 if not reversing.ok:return
 var straight: Dictionary = city.create_transit_line("rail",[ids[1],ids[0]],{"dwell_seconds":1.0,"headway_seconds":1.0})
 check(straight.ok and not straight.line.has("terminal_ports"),"through train uses legacy loop without crossover ownership")
 if not straight.ok:return
 var ops := Ops.new()
 var zones: Array = []
 for x: Dictionary in city.terminal_crossovers().values():zones.append(Cross.conflict_zone(x))
 var visits: Dictionary = {}
 var safe := true
 for i in range(820):
  ops.advance(city,0.1)
  for zone: Dictionary in zones:
   var occupiers := 0
   for train: Dictionary in city.transit_state.trains.values():
    if train.visible.any(func(pose):return not Geometry2D.intersect_polygons(Ops.body(pose),zone.polygon).is_empty()):
     occupiers+=1
     visits[train.plan.get("turnback",false)] = true
   if occupiers>1:safe=false
 check(safe and visits.has(true) and visits.has(false),"straight-through and switching trains both use the X, never together")

func test_obstructions():
 for obstruction: String in ["road", "branch"]:
  var city = Fixture.rail_city()
  city.remove_transit_route(city.transit_routes[-1].id)
  var ids: Array = city.public_facilities.lots.map(func(lot):return lot.id)
  var old_line: Dictionary = city.create_transit_line("rail",ids)
  if not old_line.ok:check(false,"valid predecessor "+obstruction);continue
  var x: Dictionary = city.terminal_crossovers().values()[0]
  var p: Vector2 = (x.start+x.axis*20.0)/4.0
  var edit: Dictionary
  if obstruction == "road":
   edit = city.add_road(PackedVector2Array([p+Vector2(0,-19),p+Vector2(0,4)]),"local",true,2)
  else:
   var branch := PackedVector2Array()
   for i in range(41):
    var t := float(i)/40.0
    branch.append(p+Vector2(28*t,-8*t*t))
   edit = city.add_transit_route(branch,"rail")
  check(edit.ok, "production obstruction exists "+obstruction+" "+str(edit.get("reason","")))
  var before := var_to_bytes([city.transit_lines, city.next_transit_line_id, city.funds, city.transit_routes])
  var rejected: Dictionary = city.create_transit_line("rail",ids)
  var change: Dictionary = city.update_transit_line(old_line.line.id,ids)
  check(not rejected.ok and rejected.reason==ERROR_TEXT and not change.ok and change.reason==ERROR_TEXT, "exact create/update obstruction message "+obstruction)
  check(before==var_to_bytes([city.transit_lines, city.next_transit_line_id, city.funds, city.transit_routes]), "obstruction leaves city byte-identical "+obstruction)

func test_fifo():
 var city = Fixture.rail_city()
 city.remove_transit_route(city.transit_routes[-1].id)
 var ids: Array = city.public_facilities.lots.map(func(lot):return lot.id)
 var initial_funds: int = city.funds
 city.enable_simulation_worker()
 city.simulation.worker.SetValidationGate(true)
 city.advance_society(2.0)
 check(city.create_transit_line("rail",ids).get("queued",false), "first crossover owner queued")
 check(city.create_transit_line("rail",[ids[1],ids[0]],{"dwell_seconds":1.0}).get("queued",false), "second owner queued")
 check(city.update_transit_line(2,ids,{"dwell_seconds":2.0}).get("queued",false), "update waits behind creation")
 check(city.remove_transit_line(1).get("queued",false), "owner removal waits behind update")
 check(city.transit_lines.is_empty() and city.terminal_crossovers().is_empty(), "pending FIFO cannot mutate ownership")
 city.simulation.validation_publish()
 for i in range(4):
  city.simulation.resume();city.advance_society(2.0);city.simulation.validation_publish()
 var exported: Dictionary = city.simulation.export_validation_state()
 check(exported.get("transit_lines",[])==city.transit_lines and city.transit_lines.size()==1 and city.transit_lines[0].id==2 and city.transit_lines[0].stops==ids, "native worker receives final FIFO order")
 check(exported.get("next_transit_line_id",-1)==3 and city.funds==initial_funds, "native worker watermark and no charge")
 check(city.transit_state.visible.size()==3 and city.terminal_crossovers().values().all(func(x):return x.line_ids==[2]), "one surviving crossover owner with published full consist")
 var adapter = load("res://core/city_simulation_worker.gd").new()
 var boot: Dictionary = adapter.boot(exported.get("checkpoint",{}))
 check(boot.ok and adapter.city.terminal_crossovers()==city.terminal_crossovers(), "checkpoint reconstructs deterministic ownership")
 if boot.ok:
  var resumed: Dictionary = adapter.run_step({"base_tick":0,"base_revision":0},2.0,1)
  city.simulation.resume();city.advance_society(2.0);city.simulation.validation_publish()
  check(resumed.transit_state==city.transit_state, "checkpoint exactly continues published terminal movement")
 city.simulation.resume()
 city.remove_transit_line(2)
 city.advance_society(2.0);city.simulation.validation_publish()
 check(city.transit_state.visible.is_empty() and city.terminal_crossovers().is_empty() and city.simulation.export_validation_state().get("transit_lines",[1]).is_empty(), "last owner and consist removed from native worker")
 city.simulation.shutdown()

func test_connectivity():
 var city = load("res://tests/test_transit_commuting.gd").fixture()
 city.remove_transit_route(city.transit_routes[3].id)
 # Replace the old loop and its disconnected stub with a straight boundary
 # feeder on the opposite port of the far station. Inbound must use B -> A.
 city.remove_transit_route(city.transit_routes[-1].id)
 var lot: Dictionary = city.public_facilities.lots[1]
 var points: PackedVector2Array = lot.internal_points.duplicate()
 if points[0].x>points[-1].x:points.reverse()
 check(city.add_transit_route(PackedVector2Array([points[-1],Vector2(city.width,points[-1].y)]),"rail").ok, "terminal line has real boundary feeder")
 var ends: Array = city.public_facilities.lots.map(func(item):return item.id)
 city.remove_transit_route(city.transit_routes[2].id)
 var mid: Dictionary = city.public_facilities.place("train-station-01",Vector2(50,33),0,true)
 check(mid.ok,"P4 fixture places real intermediate station")
 if not mid.ok:return
 var ordered: Array = city.public_facilities.lots.duplicate()
 ordered.sort_custom(func(a,b):return a.position.x<b.position.x)
 for i in range(1,ordered.size()):
  var a: PackedVector2Array = ordered[i-1].internal_points.duplicate()
  var b: PackedVector2Array = ordered[i].internal_points.duplicate()
  if a[0].x>a[-1].x:a.reverse()
  if b[0].x>b[-1].x:b.reverse()
  check(city.add_transit_route(PackedVector2Array([a[-1],b[0]]),"rail").ok,"P4 actual straight connection %d" % i)
 var ids: Array = [ends[0],mid.record.id,ends[1]]
 var line: Dictionary = city.create_transit_line("rail",ids)
 check(line.ok,"P4 fixture operates terminal line")
 if not line.ok:return
 var context: Dictionary = {"workplaces":[{"workplace_id":city.buildings[0].id}],"unemployed":[],"outbound":[]}
 # Existing P4 fixture workplace is near B; put a real work site by A.
 for parcel: Dictionary in city.zoning_grid.parcels.values():
  if parcel.center.x<22 or parcel.center.x>33 or parcel.center.y<40:continue
  var work: Dictionary = city.add_building_at(parcel.center,"industrial")
  if work.ok:context.workplaces=[{"workplace_id":work.building.id}];break
 var routes: Array = city.commuting._proven_routes(city,city.regional_exchange(),context)
 check(routes.any(func(route):
  var legs: Array = route.legs.filter(func(leg):return leg.get("line_id",-1)==line.line.id)
  return legs.size()==2 and legs[0].from_stop==ids[2] and legs[0].to_stop==ids[1] and legs[1].from_stop==ids[1] and legs[1].to_stop==ids[0]), "P4 finds a physical return-leg commute via the intermediate stop")
 city.population_enabled=true
 city.enable_simulation_worker()
 city.simulation.worker.Suspend() # Complete boot before testing the first accepted interval.
 city.simulation.resume();city.advance_society(2.0);city.simulation.validation_publish()
 check(city.commuting_status().get("inbound",0)>0 and city.commuting.last_plan.get("flows",[]).any(func(flow):return flow.mode=="rail"),"current native publication reserves P4 terminal-line passengers")
 city.simulation.shutdown()
