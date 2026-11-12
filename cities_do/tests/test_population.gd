extends SceneTree
const Model=preload("res://core/city_model.gd")
const Clock=preload("res://core/city_clock.gd")
const Population=preload("res://core/population.gd")
var passed := 0
var failed := 0
func check(value: bool,label: String):
 if value:passed+=1;print("PASS "+label)
 else:failed+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var clock=Clock.new()
 clock.advance_real(600)
 check(is_equal_approx(clock.game_seconds,14400),"ten real minutes equal four game hours")
 clock.advance_real(150)
 check(clock.commuting() and is_equal_approx(clock.hour(),5),"05 commute begins after 750 real seconds")
 clock.advance_real(600)
 check(not clock.commuting() and is_equal_approx(clock.hour(),9),"09 commute ends ten real minutes later")
 clock=Clock.new();clock.advance_real(43200)
 check(clock.year()==2 and clock.day()==12,"twelve real hours complete one twelve-day year")
 var c=Model.new(64,64,42)
 check(c.population.demand(c.buildings)=={"residential":8,"commercial":0,"industrial":0},"empty city has only residential demand")
 c.add_road(PackedVector2Array([Vector2(10,30),Vector2(50,30)]))
 var f: Dictionary=c.zoning_grid.frames.values()[0]
 c.paint_zones(c.Parcels.polygon(f,0,0,2),"commercial")
 check(c.advance_development(2).is_empty(),"commercial zoning waits for real residents")
 c.paint_zones(c.Parcels.polygon(f,0,0,2),"") # Zone changes require explicit erasure.
 c.paint_zones(c.Parcels.polygon(f,0,0,2),"residential")
 c.advance_society(2)
 check(c.buildings.size()==1 and c.population.people.is_empty(),"house construction precedes immigration")
 c.advance_society(2)
 check(c.population.people.size()==2 and c.population.households.size()==1,"immigrants occupy actual household capacity")
 check(c.population.demand(c.buildings).commercial==1 and c.population.demand(c.buildings).industrial==1,"residents generate both commercial and industrial demand")
 c.advance_society(2);c.advance_society(2)
 check(c.population.households.size()==2,"dwelling household capacity prevents overfill")
 var resident=c.population.people[0]
 resident.education=0
 var jobs := [{"id":100,"zone":"commercial","size":2,"level":1}]
 c.population.sync(c.buildings+jobs)
 check(resident.workplace_id==100 and resident.job_stage==0,"uneducated adult can fill food retail job")
 var stages := {}
 for i in range(100):stages[c.population.random_education()]=true
 check(stages.size()==5,"immigration can draw all five configured education levels")
 var child: Dictionary=c.population.birth(c.population.households[0].id)
 check(not child.is_empty() and child.origin=="local" and child.education==0 and child.age_years==0,"local newborn starts uneducated rather than inheriting parent degree")
 c.population.match_jobs()
 check(child.workplace_id==-1,"children cannot work despite education eligibility")
 check(not c.population.complete_education(child.id,1),"age prerequisites prevent instant infant graduation")
 child.age_years=22
 check(not c.population.complete_education(child.id,3),"education cannot skip completed levels")
 for stage in range(1,5):check(c.population.complete_education(child.id,stage),"completed education advances one level "+str(stage))
 for education in range(5):
  for stage in range(5):
   var pop=Population.new(5)
   pop.config.working_age_years=18
   var household={"id":1,"home_id":1}
   var person=pop.add_person(household,education,25,"immigrant")
   var slots=[0,0,0,0,0];slots[stage]=1
   pop.workplaces={1:{"slots":slots,"filled":[0,0,0,0,0]}}
   pop.match_jobs()
   check((person.workplace_id==1)==(absi(education-stage)<=1),"education tolerance %d to %d" % [education,stage])
 c.population.sync(c.buildings)
 check(c.population.people.all(func(p):return p.workplace_id==-1),"demolished workplace clears old assignments")
 var before: int=c.population.people.size()
 c.buildings.clear();c.population.sync(c.buildings)
 check(c.population.people.size()==before and c.population.households.all(func(h):return h.home_id==-1),"demolished home preserves residents as displaced households")
 var fertility=Population.new(42)
 fertility.config.birth_probability_per_household_day=1.0
 var home: Array=[{"id":1,"zone":"residential","size":2,"level":1}]
 fertility.advance(1,home)
 var adult: Dictionary=fertility.people[0]
 var age: float=adult.age_years
 fertility.advance(86400,home)
 check(fertility.people.any(func(p):return p.origin=="local"),"daily birth scheduling creates local citizens when eligible")
 check(is_equal_approx(adult.age_years-age,1.0/12),"one game day ages citizens by one twelfth of a year")
 var a=Model.new();var b=Model.new()
 for town in [a,b]:town.buildings.append({"id":1,"zone":"residential","size":2,"level":1})
 for i in range(8):a.advance_society(.5)
 b.advance_society(4)
 check(a.population.people==b.population.people and a.clock.game_seconds==b.clock.game_seconds,"fixed population ticks are frame independent")
 var view=load("res://bottom_ui_preview.tscn").instantiate()
 root.add_child(view);await process_frame
 view.city.population.sync(view.city.buildings)
 var target: Dictionary=view.city.buildings[0]
 target.zone="commercial"
 view.city.population.sync(view.city.buildings)
 view.selected=target.id;view.refresh()
 check(view.labor_panel.visible and view.labor_rings.work.slots.size()==5,"business inspector exposes five labor rings")
 view.paused=true
 var seconds: float=view.city.clock.game_seconds
 view._process(10)
 check(view.city.clock.game_seconds==seconds,"pause freezes unified city clock")
 view.queue_free();await process_frame
 print("RESULT %d/%d population checks passed" % [passed,passed+failed])
 quit(1 if failed else 0)
