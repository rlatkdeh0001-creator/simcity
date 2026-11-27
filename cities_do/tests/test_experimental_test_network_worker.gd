extends SceneTree
const Runtime=preload("res://core/commuter_runtime.gd")
const Component=preload("res://core/neighbor_commuting.gd")
const Adapter=preload("res://core/commuter_visible_adapter.gd")
var checks:=0
var failed:=0
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failed+=1;push_error(label)
func _initialize():run.call_deferred()
func road(id: int,points: Array) -> Dictionary:return {"parcel_id":id,"kind":"local","lanes":2,"width":3.0,"points":PackedVector2Array(points)}
func world() -> Dictionary:
 return {"width":100,"height":100,"roads":[road(7,[Vector2(0,20),Vector2(45,20),Vector2(50,23),Vector2(100,23)]),road(8,[Vector2(75,0),Vector2(75,100)])],"buildings":[{"id":11,"x":76.75,"y":70.0,"size":2,"front_road_id":8,"front_direction":Vector2.LEFT}]}
func flow(people: int,ordinal: int=1) -> Dictionary:
 return {"id":"junction-flow","count":people,"day":0,"direction":"inbound","mode":"road","neighbor_id":"west","neighbor_edge":"x_min","home_id":"neighbor:west:home","workplace_id":11,"population_ordinal_start":ordinal,"route":{"boundary":Vector2(0,20),"road_id":7,"local_id":11,"direction":"inbound"}}
func thread_run() -> Dictionary:
 var runtime=Runtime.new()
 var ok: bool=runtime.prepare_world(world()).ok
 var plan_result: Dictionary=runtime.apply_plan(Component.new(),{"flows":[flow(4)]})
 runtime.advance(20*3600)
 return {"ok":ok and plan_result.ok,"stats":runtime.stats(),"thread":OS.get_thread_caller_id()}
func run():
 var a=Runtime.new()
 check(a.prepare_world(world()).ok,"curved authored network plus actual at-grade crossing")
 var proof: Dictionary=a.prove_route(flow(1).route)
 check(proof.get("reachable",false),"directed curved turn route and reverse proved")
 check(a.validate_route(proof.outbound) and a.validate_route(proof.return_route),"all curved/junction lane seams continuous")
 var has_turn:=false
 for id in proof.outbound.lanes:
  var lane: Dictionary=a.routes.network.lanes[id]
  if lane.get("junction",-1)>=0 and lane.get("junction",-1)<100000:has_turn=true
 check(has_turn,"real road-junction connector required, no straightline shortcut")
 check(proof.distance_m>450 and proof.return_route.distance_m>450,"length follows bend and intersection instead of Euclidean distance")
 var bad: Dictionary=flow(1).route.duplicate(true);bad.boundary=Vector2(1,20)
 check(not a.prove_route(bad).reachable,"near-boundary proxy endpoint rejected")
 bad=flow(1).route.duplicate(true);bad.road_id=8
 check(not a.prove_route(bad).reachable,"wrong stable boundary road rejected")
 var disconnected:=world();disconnected.roads[1].points=PackedVector2Array([Vector2(75,30),Vector2(75,100)])
 var d=Runtime.new();d.prepare_world(disconnected)
 check(not d.prove_route(flow(1).route).reachable,"disconnected local frontage cannot teleport to boundary")
 a.apply_plan(Component.new(),{"flows":[flow(4)]})
 a.advance(5*3600+10)
 var adapter=Adapter.new();adapter.accept(a.visible_snapshot())
 check(not adapter.vehicles.is_empty() and adapter.position(adapter.vehicles[0]).is_finite() and adapter.heading(adapter.vehicles[0]).is_normalized(),"pure adapter exposes real metre position and heading")
 var copy:=adapter.snapshot();copy.vehicles.clear()
 check(not adapter.vehicles.is_empty(),"adapter snapshots detached")
 var spawn_ids:=[]
 for car in a.micro.vehicles:spawn_ids.append(car.id)
 var overlap_safe:=true
 for i in range(a.micro.vehicles.size()):
  for j in range(i+1,a.micro.vehicles.size()):
   var x: Dictionary=a.micro.vehicles[i];var y: Dictionary=a.micro.vehicles[j]
   if x.lane==y.lane and absf(x.progress-y.progress)<(x.length+y.length)*.5+1.999:overlap_safe=false
 check(overlap_safe,"same-boundary simultaneous starts keep protected body gaps")
 a.advance(20*3600-a.now())
 check(a.totals.physical_arrivals==8 and a.micro.vehicles.is_empty() and a.micro.reservations.is_empty(),"real turn reservations complete both entry and return exit")
 var all=Runtime.new({"display_enabled":false});all.prepare_world(world());all.apply_plan(Component.new(),{"flows":[flow(120,10001)]});all.advance(20*3600)
 var conserved:=true
 for load in all.loads.values():conserved=conserved and load.booked==120 and load.entered==120 and load.exited==120 and load.active==0
 check(all.totals.arrived==120 and all.totals.returned==120 and conserved,"all 120 nondisplayed persons contribute to congestion and road load")
 var thread=Thread.new();thread.start(thread_run)
 var result: Dictionary=thread.wait_to_finish()
 check(result.ok and result.thread!=OS.get_thread_caller_id() and result.stats.returned==4 and result.stats.physical_arrivals==8,"actual native worker owns moving cars through full curved roundtrip")
 print("RESULT %d/%d network-worker" % [checks-failed,checks])
 quit(1 if failed else 0)
