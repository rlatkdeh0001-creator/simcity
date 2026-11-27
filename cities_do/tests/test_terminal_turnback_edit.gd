extends SceneTree
## P5 review BLOCK 1: line edits while a terminal-turnback consist is actually
## running in the native worker. An unchanged stop list is a schedule-only edit
## (no re-plan); only a changed stop list re-plans and moves the running consist
## to the start of the new path (user rule 2026-11-19, replaces the P3 freeze).

const Fixture = preload("res://tests/transit_operations_fixture.gd")
const Planner = preload("res://core/transit_line_planner.gd")
var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(ok: bool, label: String):
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL "+label)

func step(city):
 city.simulation.resume();city.advance_society(2.0);city.simulation.validation_publish()

func train_of(city, id: int) -> Dictionary:
 for key: Variant in city.transit_state.trains:
  if int(key)==id:return city.transit_state.trains[key]
 return {}

func status_of(city, id: int) -> String:
 for key: Variant in city.transit_state.lines:
  if int(key)==id:return str(city.transit_state.lines[key].get("status",""))
 return ""

func line_of(city, id: int) -> Dictionary:
 for line: Dictionary in city.transit_lines:
  if line.id==id:return line
 return {}

func finish(city):
 if city.simulation!=null:city.simulation.shutdown()
 print("TERMINAL_TURNBACK_EDIT checks=%d failed=%d" % [checks, failures])
 quit(1 if failures else 0)

func run():
 var city = Fixture.rail_city()
 var loop_points: PackedVector2Array = city.transit_routes[-1].points.duplicate()
 city.remove_transit_route(city.transit_routes[-1].id)
 var ids: Array = city.public_facilities.lots.map(func(lot):return lot.id)
 var created: Dictionary = city.create_transit_line("rail",ids,{"dwell_seconds":2.0,"headway_seconds":1.0})
 check(created.ok and created.line.get("turnback",false),"straight A-B line operates as a terminal turnback line")
 if not created.ok:
  finish(city);return
 var id: int = created.line.id
 var stored: Dictionary = line_of(city,id).duplicate(true)
 var switches: Array = city.terminal_crossovers().keys()
 check(switches.size()==2,"both terminal X crossovers owned before the edit")
 city.enable_simulation_worker()
 city.simulation.worker.Suspend() # Complete boot before the first accepted interval.
 var train: Dictionary = {}
 for i in range(10):
  step(city)
  train = train_of(city,id)
  if not train.is_empty() and train.departures>=1 and train.distance>8.0:break
 check(city.simulation.get_fault().is_empty() and not train.is_empty() and train.distance>8.0 and status_of(city,id)=="running","native worker consist is actually running before the edit")
 if train.is_empty():
  finish(city);return
 var plan: Dictionary = train.plan.duplicate(true)
 var forward: float = float(plan.legs[0].length)
 test_schedule_only(city,id,ids,loop_points,stored,switches,plan,forward)
 test_stop_change(city,id,ids,stored,switches,plan)
 finish(city)

func test_schedule_only(city, id: int, ids: Array, loop_points: PackedVector2Array, stored: Dictionary, switches: Array, plan: Dictionary, forward: float):
 # Review scenario: a real physical loop appears, then only the dwell time changes.
 var routes: int = city.transit_routes.size()
 check(city.add_transit_route(loop_points).get("queued",false),"physical loop edit queued behind the running worker")
 check(city.update_transit_line(id,ids,{"dwell_seconds":3.0}).get("queued",false),"schedule-only edit queued in FIFO order")
 var distance: float = train_of(city,id).distance
 step(city)
 check(city.transit_routes.size()==routes+1,"real physical return loop now exists")
 var line: Dictionary = line_of(city,id)
 check(line.get("dwell_seconds",0.0)==3.0 and line.get("headway_seconds",0.0)==stored.headway_seconds and line.get("stops",[])==stored.stops,"schedule-only edit applies the new dwell time")
 check(line.get("turnback",false) and line.get("terminal_ports",[])==stored.terminal_ports,"schedule-only edit keeps the stored turnback mode and terminal ports")
 check(city.terminal_crossovers().keys()==switches,"schedule-only edit keeps both terminal X crossovers")
 var replanned: Dictionary = Planner.new().rail_plan(city,line)
 check(replanned.get("turnback",false) and replanned==plan,"stored turnback route is not moved onto the new loop")
 var running := true
 var monotonic := true
 var turned := false
 for i in range(40):
  if status_of(city,id)=="blocked":running=false
  var train: Dictionary = train_of(city,id)
  if train.is_empty() or train.plan!=plan:running=false;break
  if train.distance<distance-0.0001:monotonic=false
  distance = train.distance
  # Past the far terminal X centre on the return leg: dwell, reverse, cross.
  if distance>forward+40.0:turned=true;break
  step(city)
 check(running and monotonic,"running consist is never frozen or respawned by the schedule-only edit")
 check(turned,"same consist reverses at the far terminal through its retained X")

## Same consist as `before` (worker state is copied, so compare its counters): a respawn starts at 0/-INF.
func same_consist(train: Dictionary, before: Dictionary) -> bool:
 return not train.is_empty() and train.kind==before.kind and before.departures>=1 and train.departures>=before.departures and train.last_departure>=before.last_departure

func test_stop_change(city, id: int, ids: Array, stored: Dictionary, switches: Array, plan: Dictionary):
 # Only a changed stop list re-plans. User rule 2026-11-19 (replaces the P3 freeze):
 # the running consist itself is moved to the start of the new path and runs it.
 var before: Dictionary = train_of(city,id).duplicate(true)
 check(city.update_transit_line(id,[ids[1],ids[0]]).get("queued",false),"stop-changing edit queued")
 step(city)
 var line: Dictionary = line_of(city,id)
 check(line.get("stops",[])==[ids[1],ids[0]] and not line.has("terminal_ports") and city.terminal_crossovers().is_empty(),"stop-changing edit re-plans the line (now onto the physical loop)")
 var replanned: Dictionary = Planner.new().rail_plan(city,line)
 var moved: Dictionary = train_of(city,id).duplicate(true)
 check(status_of(city,id)!="blocked" and same_consist(moved,before) and moved.departures==before.departures and moved.plan==replanned and moved.distance==0.0 and moved.visible!=before.visible,"existing consist is moved to the start of the new route, not frozen or respawned")
 var ran := false
 for i in range(10):
  step(city)
  var train: Dictionary = train_of(city,id)
  if not same_consist(train,before) or train.plan!=replanned:break
  if train.distance>8.0 and status_of(city,id)=="running":ran=true;break
 check(ran,"the moved consist runs the new route from its start")
 var loop_id: int = city.transit_routes[-1].id
 check(city.remove_transit_route(loop_id).get("queued",false) and city.update_transit_line(id,ids).get("queued",false),"loop removal and original stop order queued")
 step(city)
 line = line_of(city,id)
 check(line.get("terminal_ports",[])==stored.terminal_ports and city.terminal_crossovers().keys()==switches,"restored stop order re-plans the same terminal ports")
 var back: Dictionary = train_of(city,id)
 check(status_of(city,id)!="blocked" and same_consist(back,before) and back.plan==plan and back.distance==0.0,"restored route moves the same consist to its start again")
 var resumed := false
 for i in range(10):
  step(city)
  var train: Dictionary = train_of(city,id)
  if same_consist(train,before) and train.plan==plan and status_of(city,id)=="running" and train.distance>8.0:resumed=true;break
 check(resumed,"the consist runs the restored turnback route from its start")
