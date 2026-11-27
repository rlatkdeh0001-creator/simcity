extends "res://tests/test_road_demolition_input.gd"
func _initialize():
 capture_path=ProjectSettings.globalize_path("res://../docs/road-demolition-d-validation/demolition-drag.png")
 DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
 run.call_deferred()
