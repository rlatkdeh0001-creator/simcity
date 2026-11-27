extends "res://bottom_ui.gd"
## Parent-owned single capture: launch this scene with --capture-bottom-ui=<absolute.png>.
## No capture occurs without that explicit argument. Same real fixture as functional tests.
func _ready():
 city=preload("res://tests/budget_fixture.gd").create()
 paused=true
 super._ready()
 open_budget.call_deferred()
