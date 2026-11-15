extends SceneTree
func _initialize():run.call_deferred()
func run():
 if not FileAccess.file_exists("res://simulation/PopulationCore.cs"):
  push_error("FAIL C# population bridge is not installed");quit(1);return
 var core=load("res://simulation/PopulationCore.cs").new()
 assert(core.Echo("gd-to-managed") == "gd-to-managed")
 var rng:=RandomNumberGenerator.new();rng.seed=20261114^0x71294;core.Initialize(20261114)
 assert(core.GetRng().state==rng.state)
 for i in range(20):assert(core.ValidationRandom()==rng.randf() and core.GetRng().state==rng.state)
 print("RESULT 22/22 C# bridge and native RNG checks passed")
 quit()
