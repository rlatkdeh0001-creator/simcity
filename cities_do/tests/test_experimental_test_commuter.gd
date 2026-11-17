extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
 else: print("PASS "+label)
func _initialize():
 run.call_deferred()
func run():
 check(FileAccess.file_exists("res://core/commuter_runtime.gd"), "worker runtime source exists")
 if failures:
  print("RESULT %d/%d" % [checks-failures,checks])
  quit(1)
  return
 var runtime = load("res://core/commuter_runtime.gd").new()
 var world = {"width":100,"height":100,"roads":[{"parcel_id":7,"kind":"local","lanes":2,"width":3.0,"points":PackedVector2Array([Vector2(0,20),Vector2(100,20)])}],"buildings":[{"id":11,"x":60.0,"y":21.75,"size":2,"front_road_id":7,"front_direction":Vector2.UP}]}
 check(runtime.prepare_world(world).ok,"prepare real roads and frontage")
 var proof: Dictionary = runtime.prove_route({"boundary":Vector2(0,20),"road_id":7,"local_id":11,"direction":"inbound"})
 check(proof.get("reachable",false),"continuous directed boundary entry and return exit")
 if proof.get("reachable",false):
  check(proof.outbound.distance_m > 240.0 and proof.return_route.distance_m > 240.0,"length includes real directed lanes and frontage access")
  check(runtime.validate_route(proof.outbound) and runtime.validate_route(proof.return_route),"every lane seam continuous and directed")
 check(runtime.has_method("apply_plan") and runtime.has_method("advance") and runtime.has_method("visible_snapshot"),"worker movement and pure snapshot API exists")
 print("RESULT %d/%d" % [checks-failures,checks])
 quit(1 if failures else 0)
