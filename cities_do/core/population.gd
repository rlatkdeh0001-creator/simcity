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
var tick_active:=false
var demand_full_scans:=0
var _demand_valid:=false
var _demand_prepared:=false
var _counts:Dictionary={}
var _vacancies:=0
var _job_count:=0
var _homes:Dictionary={}
var _home_counts:Dictionary={}
var _building_states:Dictionary={}
var _defer_matching:=false
var _cohort_end:=-1
var _vacancy_lists:Array=[]
var _vacancy_cursor:Array=[]
var _work_order:Dictionary={}
func _init(seed_value: int=42):rng.seed=seed_value^0x71294
func begin_tick()->void:tick_active=true;_demand_valid=false;_demand_prepared=false
func end_tick()->void:tick_active=false;_demand_valid=false;_demand_prepared=false
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
func _slots(b:Dictionary)->Array:
 var base:Array=config.commercial_jobs if b.zone=="commercial" else config.industrial_jobs
 var multiplier:=int(b.size*b.size/4)*maxi(1,int(b.level));var result:Array=[]
 for value in base:result.append(int(value)*multiplier)
 return result
func _index_households()->void:
 _home_counts.clear()
 for h in households:_home_counts[h.home_id]=int(_home_counts.get(h.home_id,0))+1
func _vacant(id:int)->int:return maxi(0,int(_homes[id])-int(_home_counts.get(id,0)))
func _move_household(h:Dictionary,id:int)->void:
 var old:int=h.home_id
 if old==id:return
 var counting:bool=_demand_valid or _demand_prepared
 if counting and _homes.has(old):_vacancies-=_vacant(old)
 if old!=-1:_home_counts[old]=maxi(0,int(_home_counts.get(old,0))-1)
 if counting and _homes.has(old):_vacancies+=_vacant(old)
 if counting and _homes.has(id):_vacancies-=_vacant(id)
 h.home_id=id
 if id!=-1:_home_counts[id]=int(_home_counts.get(id,0))+1
 if counting and _homes.has(id):_vacancies+=_vacant(id)
func _rehouse()->void:
 var available:Array=[]
 for id in _homes:
  if _vacant(id)>0:available.append(id)
 var cursor:=0
 for h in households:
  if h.home_id!=-1:continue
  while cursor<available.size() and _vacant(available[cursor])==0:cursor+=1
  if cursor==available.size():break
  _move_household(h,available[cursor])
func sync(buildings: Array) -> void:
 if tick_active and (_demand_valid or _demand_prepared):
  _sync_changes(buildings)
  return
 _demand_valid=false;_homes.clear();var jobs:Dictionary={};_demand_prepared=tick_active
 if _demand_prepared:_counts={"residential":0,"commercial":0,"industrial":0};_vacancies=0;_job_count=0;_building_states.clear()
 for b in buildings:
  if _demand_prepared:_building_states[b.id]=_building_state(b);_counts[b.zone]+=1
  if b.zone=="residential":_homes[b.id]=housing_units(b)
  else:
   var slots:=_slots(b);jobs[b.id]={"id":b.id,"slots":slots,"filled":[0,0,0,0,0],"zone":b.zone}
   if _demand_prepared:
    for n in slots:_job_count+=int(n)
 # Preserve displaced households and the original home insertion-order priority.
 for h in households:
  if not _homes.has(h.home_id):h.home_id=-1
 _index_households()
 if _demand_prepared:
  for id in _homes:_vacancies+=_vacant(id)
 _rehouse();workplaces=jobs
 if not _defer_matching:match_jobs()
func _building_state(b:Dictionary)->Dictionary:
 return {"zone":b.zone,"units":housing_units(b) if b.zone=="residential" else 0}
func _remove_contribution(id:int,state:Dictionary)->void:
 _counts[state.zone]-=1
 if state.zone=="residential":
  _vacancies-=maxi(0,int(state.units)-int(_home_counts.get(id,0)));_homes.erase(id)
func _reconcile_work(id:int)->void:
 var work:Dictionary=workplaces.get(id,{})
 if not work.is_empty():work.filled=[0,0,0,0,0]
 for p in people:
  if p.workplace_id!=id:continue
  var stage:int=p.job_stage
  if not work.is_empty() and stage>=0 and stage<5 and p.age_years>=float(config.working_age_years) and absi(p.education-stage)<=1 and work.filled[stage]<work.slots[stage]:work.filled[stage]+=1
  else:p.workplace_id=-1;p.job_stage=-1
func _sync_changes(buildings:Array)->void:
 # The aggregate is never invalidated by a building event within this tick.
 var seen:Dictionary={};var jobs_changed:=false
 for b in buildings:
  var id:int=b.id;seen[id]=true;var state:=_building_state(b);var old:Dictionary=_building_states.get(id,{})
  if state!=old:
   if not old.is_empty():_remove_contribution(id,old)
   _counts[state.zone]+=1
   if state.zone=="residential":_homes[id]=int(state.units);_vacancies+=maxi(0,int(state.units)-int(_home_counts.get(id,0)))
   _building_states[id]=state
  if b.zone!="residential":
   var slots:=_slots(b);var previous:Dictionary=workplaces.get(id,{})
   if previous.is_empty() or previous.slots!=slots:
    if not previous.is_empty():
     for n in previous.slots:_job_count-=int(n)
    for n in slots:_job_count+=int(n)
    workplaces[id]={"id":id,"slots":slots,"filled":[0,0,0,0,0],"zone":b.zone};_reconcile_work(id);jobs_changed=true
 for id in _building_states.keys():
  if not seen.has(id):_remove_contribution(id,_building_states[id]);_building_states.erase(id)
 for id in workplaces.keys():
  if not seen.has(id) or _building_states[id].zone=="residential":
   for n in workplaces[id].slots:_job_count-=int(n)
   workplaces.erase(id);_reconcile_work(id);jobs_changed=true
 for h in households:
  if not _homes.has(h.home_id):_move_household(h,-1)
 _rehouse()
 if jobs_changed and not _defer_matching:
  _index_vacancies();_fill_waiting(0,people.size())
func _index_vacancies()->void:
 _vacancy_lists=[[],[],[],[],[]];_vacancy_cursor=[0,0,0,0,0];_work_order.clear()
 var order:=0
 for id in workplaces:
  _work_order[id]=order;order+=1
  for stage in range(5):
   if workplaces[id].filled[stage]<workplaces[id].slots[stage]:_vacancy_lists[stage].append(id)
func _candidate(stage:int)->int:
 if stage<0 or stage>=5:return -1
 var list:Array=_vacancy_lists[stage];var cursor:int=_vacancy_cursor[stage]
 while cursor<list.size():
  var id:int=list[cursor]
  if workplaces[id].filled[stage]<workplaces[id].slots[stage]:break
  cursor+=1
 _vacancy_cursor[stage]=cursor
 return int(list[cursor]) if cursor<list.size() else -1
func _fill_waiting(first:int,last:int)->void:
 var waiting:Array[Dictionary]=[];var working_age:float=config.working_age_years
 for index in range(first,last):
  var p:Dictionary=people[index]
  if p.workplace_id==-1 and p.age_years>=working_age:waiting.append(p)
 for distance in [0,1]:
  for p:Dictionary in waiting:
   if p.workplace_id!=-1:continue
   var lower:int=p.education-distance;var upper:int=p.education+distance
   var id:int=_candidate(lower);var stage:int=lower
   if distance==1:
    var other:int=_candidate(upper)
    if other!=-1 and (id==-1 or int(_work_order[other])<int(_work_order[id])):id=other;stage=upper
   if id!=-1:p.workplace_id=id;p.job_stage=stage;workplaces[id].filled[stage]+=1
func match_jobs() -> void:
 # Preserve valid incumbents, workplace order, then lower-stage tie breaking.
 for work in workplaces.values():work.filled=[0,0,0,0,0]
 for person in people:
  var work: Dictionary=workplaces.get(person.workplace_id,{})
  var stage: int=person.job_stage
  if person.age_years>=float(config.working_age_years) and stage>=0 and stage<5 and absi(person.education-stage)<=1 and not work.is_empty() and work.filled[stage]<work.slots[stage]:work.filled[stage]+=1
  else:person.workplace_id=-1;person.job_stage=-1
 _index_vacancies()
 var boundary:int=mini(_cohort_end,people.size()) if _cohort_end>=0 else people.size()
 # Old sync hired existing citizens before immigration; keep that priority in one solve.
 _fill_waiting(0,boundary)
 if boundary<people.size():_fill_waiting(boundary,people.size())
func advance(game_seconds: float,buildings: Array) -> void:
 if game_seconds<=0 or not is_finite(game_seconds):return
 elapsed_days+=game_seconds/Clock.GAME_SECONDS_PER_DAY
 for person in people:person.age_years+=game_seconds/(Clock.GAME_SECONDS_PER_DAY*Clock.DAYS_PER_YEAR)
 _cohort_end=people.size();_defer_matching=true;sync(buildings);_defer_matching=false
 # One immigrant household per population tick, provided a real dwelling is available.
 if not households.any(func(h):return h.home_id==-1):
  for b in buildings:
   if b.zone!="residential":continue
   if int(_home_counts.get(b.id,0))>=int(_homes[b.id]):continue
   var household := {"id":next_household,"home_id":-1}
   next_household+=1;households.append(household);_move_household(household,b.id)
   for i in range(int(config.immigrant_adults_per_household)):add_person(household,random_education(),rng.randf_range(20,50),"immigrant")
   break
 while birth_day<floori(elapsed_days):
  birth_day+=1
  for household in households:
   if household.home_id!=-1 and rng.randf()<float(config.birth_probability_per_household_day):birth(household.id)
 match_jobs();_cohort_end=-1
func _calculate_demand(buildings:Array)->void:
 if _demand_prepared:
  demand_full_scans+=1;_demand_valid=true;_demand_prepared=false;return
 demand_full_scans+=1;_counts={"residential":0,"commercial":0,"industrial":0};_vacancies=0;_job_count=0
 _index_households();_homes.clear();_building_states.clear()
 for b in buildings:
  var state:=_building_state(b);_building_states[b.id]=state;_counts[b.zone]+=1
  if b.zone=="residential":_homes[b.id]=int(state.units);_vacancies+=maxi(0,int(state.units)-int(_home_counts.get(b.id,0)))
 for work in workplaces.values():
  for value in work.slots:_job_count+=int(value)
 _demand_valid=true
func demand(buildings: Array) -> Dictionary:
 if not tick_active or not _demand_valid:_calculate_demand(buildings)
 var target:int=maxi(int(config.initial_housing_target),ceili(_job_count/4.0))
 return {"residential":maxi(0,target-households.size()-_vacancies),"commercial":maxi(0,ceili(people.size()/float(config.residents_per_commercial))-_counts.commercial),"industrial":maxi(0,ceili(people.size()/float(config.residents_per_industrial))-_counts.industrial)}
func stats() -> Dictionary:
 var eligible := 0
 var employed := 0
 for p in people:
  if p.age_years>=float(config.working_age_years):eligible+=1
  if p.workplace_id!=-1:employed+=1
 return {"population":people.size(),"households":households.size(),"employed":employed,"unemployed":eligible-employed}
