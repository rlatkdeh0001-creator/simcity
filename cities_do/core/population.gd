extends RefCounted
const Clock=preload("res://core/city_clock.gd")
const EDUCATION := ["미취학","초등교육","고등교육","전문대학","대학"]
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/population_config.json"))
var people: Array[Dictionary]=[]
var households: Array[Dictionary]=[]
var workplaces := {}
var rng := RandomNumberGenerator.new()
var next_person := 1
var next_household := 1
var elapsed_days := 0.0
var birth_day := 0
func _init(seed_value: int=42):rng.seed=seed_value^0x71294
func housing_units(b: Dictionary) -> int:
 return int(b.size*b.size/4)*maxi(1,int(b.level))*int(config.households_per_2x2)
func random_education() -> int:
 var total := 0.0
 for weight in config.immigrant_education_weights:total+=float(weight)
 var roll := rng.randf()*total
 for stage in range(5):
  roll-=float(config.immigrant_education_weights[stage])
  if roll<0:return stage
 return 4
func add_person(household: Dictionary,education: int,age: float,origin: String) -> Dictionary:
 var person := {"id":next_person,"household_id":household.id,"education":education,"age_years":age,"origin":origin,"workplace_id":-1,"job_stage":-1}
 next_person+=1
 people.append(person)
 return person
func birth(household_id: int) -> Dictionary:
 for household in households:
  if household.id!=household_id:continue
  var members=people.filter(func(p):return p.household_id==household_id)
  if members.size()>=int(config.household_max_members) or not members.any(func(p):return p.age_years>=18):return {}
  return add_person(household,0,0,"local")
 return {}
func complete_education(person_id: int,stage: int) -> bool:
 # Future school engine records successful completion here; age alone never graduates.
 if stage<1 or stage>4:return false
 for person in people:
  if person.id==person_id and person.education==stage-1 and person.age_years>=float(config.education_min_ages[stage]):
   person.education=stage
   return true
 return false
func sync(buildings: Array) -> void:
 var homes := {}
 var jobs := {}
 for b in buildings:
  if b.zone=="residential":homes[b.id]=b
  else:
   var base: Array=config.commercial_jobs if b.zone=="commercial" else config.industrial_jobs
   var multiplier := int(b.size*b.size/4)*maxi(1,int(b.level))
   var slots := []
   for value in base:slots.append(int(value)*multiplier)
   jobs[b.id]={"id":b.id,"slots":slots,"filled":[0,0,0,0,0],"zone":b.zone}
 # Demolished homes release their households; people are not silently deleted.
 for household in households:
  if not homes.has(household.home_id):household.home_id=-1
 for household in households:
  if household.home_id!=-1:continue
  for id in homes:
   if households.filter(func(h):return h.home_id==id).size()<housing_units(homes[id]):
    household.home_id=id
    break
 workplaces=jobs
 match_jobs()
func match_jobs() -> void:
 # Preserve valid incumbents first; never count one citizen twice.
 for work in workplaces.values():work.filled=[0,0,0,0,0]
 for person in people:
  var work: Dictionary=workplaces.get(person.workplace_id,{})
  var stage: int=person.job_stage
  if person.age_years>=float(config.working_age_years) and stage>=0 and stage<5 and absi(person.education-stage)<=1 and not work.is_empty() and work.filled[stage]<work.slots[stage]:
   work.filled[stage]+=1
  else:person.workplace_id=-1;person.job_stage=-1
 for distance in [0,1]:
  for person in people:
   if person.workplace_id!=-1 or person.age_years<float(config.working_age_years):continue
   for id in workplaces:
    var work: Dictionary=workplaces[id]
    for stage in range(5):
     if absi(person.education-stage)==distance and work.filled[stage]<work.slots[stage]:
      person.workplace_id=id;person.job_stage=stage;work.filled[stage]+=1
      break
    if person.workplace_id!=-1:break
func advance(game_seconds: float,buildings: Array) -> void:
 if game_seconds<=0 or not is_finite(game_seconds):return
 elapsed_days+=game_seconds/Clock.GAME_SECONDS_PER_DAY
 for person in people:person.age_years+=game_seconds/(Clock.GAME_SECONDS_PER_DAY*Clock.DAYS_PER_YEAR)
 sync(buildings)
 # One immigrant household per population tick, provided a real dwelling is available.
 if not households.any(func(h):return h.home_id==-1):
  for b in buildings:
   if b.zone!="residential":continue
   if households.filter(func(h):return h.home_id==b.id).size()>=housing_units(b):continue
   var household := {"id":next_household,"home_id":b.id}
   next_household+=1;households.append(household)
   for i in range(int(config.immigrant_adults_per_household)):add_person(household,random_education(),rng.randf_range(20,50),"immigrant")
   break
 while birth_day<floori(elapsed_days):
  birth_day+=1
  for household in households:
   if household.home_id!=-1 and rng.randf()<float(config.birth_probability_per_household_day):birth(household.id)
 match_jobs()
func demand(buildings: Array) -> Dictionary:
 var counts := {"residential":0,"commercial":0,"industrial":0}
 var vacancies := 0
 for b in buildings:
  counts[b.zone]+=1
  if b.zone=="residential":vacancies+=maxi(0,housing_units(b)-households.filter(func(h):return h.home_id==b.id).size())
 var job_count := 0
 for work in workplaces.values():
  for value in work.slots:job_count+=int(value)
 var target: int=maxi(int(config.initial_housing_target),ceili(job_count/4.0))
 return {"residential":maxi(0,target-households.size()-vacancies),"commercial":maxi(0,ceili(people.size()/float(config.residents_per_commercial))-counts.commercial),"industrial":maxi(0,ceili(people.size()/float(config.residents_per_industrial))-counts.industrial)}
func stats() -> Dictionary:
 var eligible := 0
 var employed := 0
 for p in people:
  if p.age_years>=float(config.working_age_years):eligible+=1
  if p.workplace_id!=-1:employed+=1
 return {"population":people.size(),"households":households.size(),"employed":employed,"unemployed":eligible-employed}
