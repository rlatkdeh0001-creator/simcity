extends SceneTree
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var p=load("res://simulation/PopulationCore.cs").new()
 p.Configure(JSON.parse_string(FileAccess.get_file_as_string("res://core/population_config.json")))
 p.ImportState([{"id":1,"household_id":1,"education":0,"age_years":25.0,"origin":"fixture","workplace_id":2,"job_stage":0}],[{"id":1,"home_id":75}],{})
 p.SyncPacked(PackedInt64Array([75,0,2,2,2,1,2,1]))
 p.ConfigureTaxPolicy({"enabled":true})
 var h=load("res://simulation/HappinessCore.cs").new();h.BindPopulation(p)
 h.Configure({"goods":10.0,"commute":0.0,"garbage":0.0,"tax":0.0,"fire_buildings_per_incident":100})
 h.SetWorld([{"id":75,"position":Vector2(100,20),"polygon":PackedVector2Array([Vector2(96,16),Vector2(104,16),Vector2(104,24),Vector2(96,24)]),"road":0,"zone":"residential","level":2,"power":true,"water":true}],[{"id":500,"kind":"health","road":0,"position":Vector2(100,20),"capacity":1000}],PackedFloat64Array([0,0,0,2000,0]))
 h.Tick(48,PackedInt64Array());h.Tick(40000,PackedInt64Array())
 check(h.Inspect(75).actual==60 and h.Inspect(75).held_seconds==40000,"level2 has real partially earned growth hold")
 check(h.has_method("NotifyTaxPolicyChanged"),"tax threshold notification API")
 if true:
  p.ConfigureTaxPolicy({"rates":[9,20,9,9,9,9,9,9,9]})
  if h.has_method("NotifyTaxPolicyChanged"):h.NotifyTaxPolicyChanged()
  else:h.Tick(1,PackedInt64Array())
  check(h.Inspect(75).held_seconds==0,"raising tax resets previously qualifying hold immediately")
  var grown:Array=[]
  for i in range(75):grown.append_array(h.Tick(1200,PackedInt64Array()).upgrades)
  check(grown.is_empty() and h.Inspect(75).held_seconds==0,"cannot grow below new threshold even after full day")
  check(h.Inspect(75).actual==60 and h.Inspect(75).factors.tax==0,"tax threshold never deducts happiness score")
  p.ConfigureTaxPolicy({"rates":[9,9,9,9,9,9,9,9,9]})
  if h.has_method("NotifyTaxPolicyChanged"):h.NotifyTaxPolicyChanged()
  for i in range(75):h.Tick(1,PackedInt64Array())
  check(h.Inspect(75).held_seconds<75,"lowering tax starts fresh hold instead of restoring credit")
  grown.clear()
  for i in range(75):grown.append_array(h.Tick(1100,PackedInt64Array()).upgrades)
  check(grown.is_empty(),"fresh full continuous day required")
  for i in range(75):grown.append_array(h.Tick(100,PackedInt64Array()).upgrades)
  check(grown==[75],"exactly one growth request after fresh continuous day")
 print("TAX_GROWTH_CONTINUITY checks=%d failed=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
