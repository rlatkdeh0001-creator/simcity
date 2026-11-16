extends RefCounted
## Managed production state. Mutable array/dictionary views are explicit compatibility mode.
const Clock=preload("res://core/city_clock.gd")
const EDUCATION := ["미취학","초등교육","고등교육","전문대학","대학"]
var core=preload("res://simulation/PopulationCore.cs").new()
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/population_config.json"))
var rng:RandomNumberGenerator
var _people:Array[Dictionary]=[]
var _households:Array[Dictionary]=[]
var _workplaces:Dictionary={}
var _views:=false
var _legacy_hash:=0
var _config_hash:=-1
var _depth:=0
signal geometry_transport_recovered(expected_count:int,actual_count:int)
var _geometry_transport:=false
var people:Array[Dictionary]:
 get:_expose();return _people
 set(value):_expose();_people.assign(value)
var households:Array[Dictionary]:
 get:_expose();return _households
 set(value):_expose();_households.assign(value)
var workplaces:Dictionary:
 get:_expose();return _workplaces
 set(value):_expose();_workplaces=value
var next_person:int:
 get:return core.GetNextPerson()
 set(value):core.SetNextPerson(value)
var next_household:int:
 get:return core.GetNextHousehold()
 set(value):core.SetNextHousehold(value)
var elapsed_days:float:
 get:return core.GetElapsedDays()
 set(value):core.SetElapsedDays(value)
var birth_day:int:
 get:return core.GetBirthDay()
 set(value):core.SetBirthDay(value)
var tick_active:bool:
 get:return core.IsTickActive()
var demand_full_scans:int:
 get:return core.GetDemandScans()
func _init(seed_value:int=42):
 core.Initialize(seed_value);rng=core.GetRng();_configure()
func backend_name()->String:return "CSharp"
func _configure():
 var fingerprint:int=hash(config)
 if fingerprint!=_config_hash:core.Configure(config);_config_hash=fingerprint
func _expose():
 if not _views:_views=true;_refresh_views()
func _merge_records(target:Array[Dictionary],incoming:Array):
 var old:Dictionary={}
 for record in target:old[record.id]=record
 var ordered:Array[Dictionary]=[]
 for record:Dictionary in incoming:
  var item:Dictionary=old.get(record.id,{})
  item.clear();item.merge(record,true);ordered.append(item)
 target.assign(ordered)
func _refresh_views():
 var snapshot:Dictionary=core.ExportState()
 _merge_records(_people,snapshot.people);_merge_records(_households,snapshot.households)
 var next:Dictionary={}
 for id in snapshot.workplaces:
  var work:Dictionary=_workplaces.get(id,{})
  work.clear();work.merge(snapshot.workplaces[id],true);next[id]=work
 _workplaces.clear();_workplaces.merge(next,true)
 _legacy_hash=hash([_people,_households,_workplaces])
func _enter():
 if _depth==0:
  _configure()
  if _views and hash([_people,_households,_workplaces])!=_legacy_hash:core.ImportState(_people,_households,_workplaces)
 _depth+=1
func _leave(changed:bool=true):
 _depth-=1
 if _depth==0 and _views and changed:_refresh_views()
func release_compatibility_views():
 # Fixtures may seed mutable views, then explicitly stop snapshot transport before benchmarking/play.
 _enter();_leave(false);_views=false;_people=[];_households=[];_workplaces={}
func import_fixture_state(snapshot:Dictionary):
 _configure();core.ImportState(snapshot.people,snapshot.households,snapshot.get("workplaces",{}))
 if snapshot.has("next_person"):next_person=snapshot.next_person
 if snapshot.has("next_household"):next_household=snapshot.next_household
 if snapshot.has("rng_state"):rng.state=snapshot.rng_state
 if snapshot.has("elapsed_days"):elapsed_days=snapshot.elapsed_days
 if snapshot.has("birth_day"):birth_day=snapshot.birth_day
 _views=false;_people=[];_households=[];_workplaces={}
func begin_tick()->void:_enter();core.BeginTick();_leave(false)
func end_tick()->void:_enter();core.EndTick();_leave(false)
func housing_units(b:Dictionary)->int:_configure();return core.HousingUnits(b)
func _slots(b:Dictionary)->Array:_configure();return core.BuildingSlots(b)
func random_education()->int:_configure();return core.RandomEducation()
func add_person(household:Dictionary,education:int,age:float,origin:String)->Dictionary:
 _expose();_enter();var result:Dictionary=core.AddPerson(household.id,education,age,origin);_leave()
 for person in _people:
  if person.id==result.id:return person
 return result
func birth(household_id:int)->Dictionary:
 _expose();_enter();var result:Dictionary=core.Birth(household_id);_leave()
 if result.is_empty():return result
 for person in _people:
  if person.id==result.id:return person
 return result
func complete_education(person_id:int,stage:int)->bool:
 _enter();var result:bool=core.CompleteEducation(person_id,stage);_leave();return result
func _pack_buildings(buildings:Array)->PackedInt64Array:
 var values:=PackedInt64Array();values.resize(buildings.size()*4);var cursor:=0
 for b:Dictionary in buildings:
  values[cursor]=b.id;values[cursor+1]=0 if b.zone=="residential" else (1 if b.zone=="commercial" else 2)
  values[cursor+2]=b.size;values[cursor+3]=b.level;cursor+=4
 return values
func enable_geometry_transport(buildings:Array)->void:
 # Opt in only when the model owns all geometry edits and forwards notifications.
 # Mutable fixture arrays remain on the legacy full-pack path by default.
 _enter();core.EnableGeometryTransport(_pack_buildings(buildings));_geometry_transport=true;_leave(false)
func record_building(b:Dictionary)->void:
 if not _geometry_transport:return
 core.RecordBuilding(b.id,0 if b.zone=="residential" else (1 if b.zone=="commercial" else 2),b.size,b.level)
func remove_building(id:int)->void:
 if _geometry_transport:core.RemoveBuilding(id)
func _check_geometry(buildings:Array)->void:
 var expected:int=core.GetGeometryCount()
 if expected==buildings.size():return
 # Missed add/remove notification: a full seed is recovery, never normal cadence.
 # Equal-count unnotified edits cannot be detected without defeating delta transport.
 core.EnableGeometryTransport(_pack_buildings(buildings))
 push_warning("Population geometry count mismatch: reseeded %d -> %d; check model notifications"%[expected,buildings.size()])
 geometry_transport_recovered.emit(expected,buildings.size())
func sync(buildings:Array)->void:
 _enter()
 if _geometry_transport:
  _check_geometry(buildings)
  if core.SyncManaged():match_jobs()
 elif core.SyncPacked(_pack_buildings(buildings)):match_jobs()
 _leave()
func match_jobs()->void:_enter();core.MatchJobs();_leave()
func advance(game_seconds:float,buildings:Array)->void:
 if game_seconds<=0 or not is_finite(game_seconds):return
 _enter()
 if _geometry_transport:_check_geometry(buildings);core.AdvanceManaged(game_seconds)
 else:core.AdvancePacked(game_seconds,_pack_buildings(buildings))
 match_jobs();_leave()
func demand(buildings:Array)->Dictionary:
 _enter()
 var result:Dictionary
 if _geometry_transport:_check_geometry(buildings);result=core.DemandManaged()
 else:result=core.Demand(_pack_buildings(buildings) if core.NeedsDemandBuildings() else PackedInt64Array())
 _leave(false);return result
func workplace_info(id:int)->Dictionary:
 _enter();var result:Dictionary=core.WorkplaceInfo(id);_leave(false);return result
func stats()->Dictionary:
 _enter();var result:Dictionary=core.StatsManaged() if _geometry_transport else core.Stats();_leave(false);return result
