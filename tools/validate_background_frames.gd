extends SceneTree
const Model=preload("res://core/city_model.gd")
var city
var population_count:=10000
var speed:=1
var mode:="background"
var duration:=8.0
var measuring:=false
var skip_first:=true
var elapsed:=0.0
var prior_frame:=0
var callback_samples:Array=[]
var frame_samples:Array=[]
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--population="):population_count=int(arg.trim_prefix("--population="))
  if arg.begins_with("--speed="):speed=int(arg.trim_prefix("--speed="))
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
 setup.call_deferred()
func setup():
 Engine.max_fps=0
 city=Model.new(1000,2000,20261116)
 var homes:=ceili(float(population_count)/4);var works:=ceili(float(population_count)/8)
 for i in range(homes+works):
  city.buildings.append({"id":i+1,"x":(i%250)*3,"y":(i/250)*3,"size":2,"level":1,"zone":"residential" if i<homes else "industrial","score":0.0,"asset_id":"","front_road_id":-1,"has_power":true,"has_water":true})
 city.next_id=homes+works+1
 var people:Array=[];var households:Array=[]
 for i in range(ceili(float(population_count)/2)):households.append({"id":i+1,"home_id":i/2+1})
 for i in range(population_count):people.append({"id":i+1,"household_id":i/2+1,"education":i%5,"age_years":30.0,"origin":"frame-fixture","workplace_id":-1,"job_stage":-1})
 city.population.import_fixture_state({"people":people,"households":households,"workplaces":{},"next_person":population_count+1,"next_household":households.size()+1})
 city.population.sync(city.buildings);people.clear();households.clear()
 city.happiness._rebuild(city)
 if mode=="background":city.happiness.enable_background()
 # One accepted tick establishes immutable group and worker/public buffers before sampling.
 city.advance_society(2);city.happiness.suspend_background();city.happiness.publish_boundary()
 print("BACKGROUND_FRAME_READY population=",population_count," speed=",speed)
 measuring=true
func _process(delta:float):
 if not measuring:return false
 if skip_first:skip_first=false;return false
 var start:=Time.get_ticks_usec()
 if prior_frame>0:frame_samples.append((start-prior_frame)/1000.0)
 prior_frame=start
 city.advance_society(delta*speed)
 callback_samples.append((Time.get_ticks_usec()-start)/1000.0)
 elapsed+=delta
 if elapsed>=duration:measuring=false;finish.call_deferred()
 return false
func metrics(values:Array)->Dictionary:
 var sorted:Array=values.duplicate();sorted.sort()
 return {"samples":sorted.size(),"median_ms":sorted[sorted.size()/2],"max_ms":sorted[-1]}
func finish():
 city.happiness.suspend_background();city.happiness.publish_boundary()
 assert(city.population.stats().population==population_count)
 print("BACKGROUND_FRAME_RESULT ",JSON.stringify({"mode":mode,"population":population_count,"speed":speed,"main_callback":metrics(callback_samples),"frame_start_gap":metrics(frame_samples),"frozen_cycles":city.society_frozen_cycles,"status":city.happiness.core.BackgroundStatus(),"scope":"real headless SceneTree main-thread advance_society callback; population/development/happiness production path; no renderer, utilities or HUD; initial loading and first job excluded"}))
 quit()
