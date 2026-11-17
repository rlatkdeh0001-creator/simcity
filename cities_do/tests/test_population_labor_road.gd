extends SceneTree
func _initialize():
 var result:Dictionary=load("res://tests/LaborProbe.cs").new().Run()
 var regression:Dictionary=load("res://tests/PopulationIncrementalProbe.cs").new().Run()
 var integration:Dictionary=load("res://tests/LaborIntegrationProbe.cs").new().Run()
 print(JSON.stringify({"labor":result,"legacy_incremental":regression,"integration":integration}))
 quit(0 if result.failures.is_empty() and regression.failures.is_empty() and integration.failures.is_empty() else 1)
