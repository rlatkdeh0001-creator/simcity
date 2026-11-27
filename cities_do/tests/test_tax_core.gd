extends SceneTree
func _initialize():
	var probe = load("res://tests/TaxProbe.cs").new()
	var result = probe.Run()
	print(JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
