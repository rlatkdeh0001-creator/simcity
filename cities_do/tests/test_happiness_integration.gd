extends SceneTree
const Model=preload("res://core/city_model.gd")
var passed:=0
func check(ok:bool,label:String):
 assert(ok,label);passed+=1;print("PASS "+label)
func _initialize():run.call_deferred()
func run():
 var city=Model.new(160,160,42)
 check(city.has_method("advance_happiness"),"production society exposes happiness integration")
 if not city.has_method("advance_happiness"):quit(1);return
 check(city.add_road(PackedVector2Array([Vector2(10,40),Vector2(140,40)])).ok,"real supporting road")
 var home:Dictionary={};var work:Dictionary={}
 for p in city.zoning_grid.parcels.values():
  var result:Dictionary=city.add_building_at(p.center,"residential" if home.is_empty() else "commercial")
  if not result.ok:continue
  if home.is_empty():home=result.building
  else:work=result.building;break
 check(not home.is_empty() and not work.is_empty(),"legal dwelling and workplace placement")
 var people:Array=[]
 for i in range(2):people.append({"id":i+1,"household_id":1,"age_years":30.0,"education":0,"origin":"test","workplace_id":-1,"job_stage":-1})
 city.population.import_fixture_state({"people":people,"households":[{"id":1,"home_id":home.id}],"workplaces":{},"next_person":3,"next_household":2});city.population.sync(city.buildings)
 home.has_power=true;home.has_water=true;work.has_power=true;work.has_water=true
 for i in range(75):city.advance_happiness(48)
 check(home.happiness==50,"population employment feeds actual building target")
 var before:int=home.level
 for i in range(1800):city.advance_happiness(48)
 check(home.level==before+1,"automatic approved spatial upgrade after a full qualifying day")
 check(home.size>=2 and home.level==2,"growth uses existing lot/level application")
 for i in range(3600):city.advance_happiness(48)
 check(home.level==2,"50 happiness cannot satisfy the next 60 threshold")
 home.has_water=false;city.advance_happiness(48)
 check(home.happiness==0,"production water shortage immediately propagates to happiness")
 var frozen:float=city.happiness.core.Inspect(home.id).held_seconds
 city.advance_society(0)
 check(city.happiness.core.Inspect(home.id).held_seconds==frozen,"zero real delta cannot advance happiness time")
 check(not city.population.get("_views"),"happiness reads managed populations without exposing mutable compatibility views")
 var population=preload("res://core/population.gd").new(42);var demographic_people:Array=[]
 for age in [1,8,13,19,21]:demographic_people.append({"id":demographic_people.size()+1,"household_id":1,"age_years":float(age),"education":0,"origin":"test","workplace_id":-1,"job_stage":-1})
 population.import_fixture_state({"people":demographic_people,"households":[{"id":1,"home_id":75}],"workplaces":{}})
 var evaluator=load("res://simulation/HappinessCore.cs").new();evaluator.BindPopulation(population.core)
 var facilities:Array=[]
 for stage in range(4):facilities.append({"id":stage+10,"road":0,"position":Vector2(100,0),"kind":"education","school_stage":stage,"capacity":1})
 facilities.append({"id":20,"road":0,"position":Vector2(100,0),"kind":"police","capacity":4})
 evaluator.SetWorld([{"id":75,"road":0,"position":Vector2(0,0),"zone":"residential","level":1,"power":true,"water":true}],facilities,PackedFloat64Array([0,0,0,200,0]));evaluator.Tick(48,PackedInt64Array())
 check(evaluator.Preview(75).factors.education==10,"actual age cohorts reserve one place in each matching school, excluding infants")
 check(evaluator.Preview(75).factors.police==0,"police quotas count all residents rather than only employed adults")
 print("RESULT %d/%d happiness integration checks passed"%[passed,passed]);quit()
