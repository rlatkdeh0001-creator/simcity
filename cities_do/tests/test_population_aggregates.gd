extends SceneTree
func _initialize():
 var probe=load("res://tests/PopulationIncrementalProbe.cs").new()
 var result:Dictionary=probe.Run()
 for failure in result.failures:push_error(str(failure))
 print("RESULT %d/%d population aggregate checks passed"%[result.checks-result.failures.size(),result.checks])
 quit(0 if result.failures.is_empty() else 1)
