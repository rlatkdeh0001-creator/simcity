extends RefCounted
## Main-thread coordinator. Default-off: CityModel's legacy path is untouched until initialize().
## One outstanding simulation step (including completed/unpublished); editor intents are NOT ticks.
const Clock=preload("res://core/city_clock.gd")
const WORLD_KEYS=["roads","public_lots","power_plants","water_facilities","junctions","road_joins","external_infrastructure"]
const META_KEYS=["funds","population_enabled","happiness_enabled","difficulty","city_name"]
const HAPPINESS_KEYS=["happiness","happiness_target","happiness_factors"]
var owner:WeakRef
var worker
var enabled:=false
var suspended:=false
var is_publishing_clock:=false # Parent bill_months handler MUST return while this is true.
var _stopped:=false
var _publishing:=false
var _replaying:=false
var _elapsed:=0.0
var _revision:=0
var _submitted_revision:=0
var _submitted_funds:=0
var _published_tick:=0
var _by_id:Dictionary={}
var _published_ids:Dictionary={}
var _building_changes:Dictionary={}
var _supplies:Dictionary={}
var _zones:Dictionary={}
var _zones_dirty:=false
var _known_zones:Dictionary={}
var _world_dirty:Dictionary={}
var _meta:Dictionary={}
var _population_config_dirty:=false
var _growth_config_dirty:=false
var _edits:Array[Callable]=[]
var _adapter_script
var _fault:=""
var _boot_ready:=false
signal edit_completed(result:Variant)
func _init(city):
 owner=weakref(city)
 initialize() # Model opt-in constructs this facade; legacy models never construct one.
func initialize()->bool:
 if enabled:return not _stopped
 var city=owner.get_ref()
 if city==null:return false
 _adapter_script=load("res://core/city_simulation_worker.gd")
 var worker_script=load("res://core/city_native_mailbox.gd")
 if _adapter_script==null or worker_script==null:return false
 # Explicit idle initialization only. Flush mutable fixture edits BEFORE freezing the source.
 city.population.release_compatibility_views()
 city.population.enable_geometry_transport(city.buildings)
 if city.happiness.background_enabled:
  city.happiness.suspend_background();city.happiness.publish_boundary()
  city.happiness.background_enabled=false
 # Do not recursively capture the facade (which contains Callables and the live owner).
 var checkpoint:Dictionary={
  "model":_adapter_script._capture_object(city,["population","happiness","simulation"]),
  "population":city.population.core.ExportCityCheckpoint(),
  "population_config":city.population.config.duplicate(true),
  "happiness":city.happiness.core.ExportCityCheckpoint(),
  "happiness_vars":_adapter_script._capture_object(city.happiness,["owner","core","bound","records","background_enabled","_read_view"])}
 for b:Dictionary in city.buildings:_by_id[int(b.id)]=b;_published_ids[int(b.id)]=true
 _known_zones=city.zone_designations.duplicate(true)
 # Boot has a published T0 read surface as well; no stale main-core reads during boot.
 city.population.attach_read_view(load("res://core/native_population_view.gd").capture_boot(city.population.core.CaptureCityReadView()))
 city.happiness.attach_read_view(load("res://core/native_happiness_view.gd").capture_boot(city.happiness.core.CaptureCityReadView()))
 worker=worker_script.new()
 worker.Initialize(_adapter_script.new(),checkpoint)
 worker.AdoptBootViews(city.population.published_read_view(),city.happiness.published_read_view())
 enabled=true
 return true
func enable()->bool:return initialize()
func get_fault()->String:
 if not _fault.is_empty():return _fault
 if worker!=null:_fault=worker.GetFault()
 return _fault
func is_ready()->bool:
 if not enabled or _stopped or not _fault.is_empty():return false
 if not _boot_ready:
  if not get_fault().is_empty():return false
  _boot_ready=worker.IsReady()
 return _boot_ready
func is_busy()->bool:
 return enabled and (suspended or _stopped or not get_fault().is_empty() or worker.IsBusy())
func has_pending()->bool:
 return worker!=null and get_fault().is_empty() and worker.HasPending()
func is_applying_publication()->bool:return _publishing
func get_published_tick()->int:return _published_tick
func queued_edit_count()->int:return _edits.size()
func defer_edit(intent:Callable)->bool:
 # Parent calls this BEFORE validation, money, ID allocation or any structural write.
 # true = saved an UNALLOCATED intent; return a deferred UI result. false = execute now.
 if not enabled or _replaying:return false
 if _publishing or _stopped or suspended or not get_fault().is_empty() or not is_ready() or has_pending() or not _edits.is_empty():
  _edits.append(intent);return true
 return false
func _replay_edits():
 _replaying=true
 # Clear before invocation; hooks on each original method execute normally during replay.
 var intents:Array[Callable]=_edits;_edits=[]
 var results:Array=[]
 for intent:Callable in intents:
  if intent.is_valid():results.append(intent.call())
  else:results.append({"ok":false,"code":"expired_intent","reason":"편집 대상이 사라졌습니다"})
 _replaying=false
 # Observers see the whole FIFO already replayed; they cannot interleave an old intent.
 for result:Variant in results:edit_completed.emit(result)
func _changed():_revision+=1
func note_building(building:Dictionary):
 if not enabled or _publishing:return
 var id:int=building.id
 # Parent's generic building hook also carries utility supply changes during a job.
 # Structural writes must already have been deferred; only these fields may race publication.
 if has_pending():_supplies[id]={"has_power":building.get("has_power",false),"has_water":building.get("has_water",false)}
 _by_id[id]=building;_building_changes[id]=building;_changed()
func note_remove(id:int):
 if not enabled or _publishing:return
 _by_id.erase(id);_supplies.erase(id)
 if _published_ids.has(id):_building_changes[id]=null
 else:_building_changes.erase(id) # Create then delete before submission is a no-op.
 _changed()
func note_supply(building:Dictionary):
 if not enabled or _publishing:return
 # Utility supply is allowed to change during a job. Preserve it across geometry publication.
 _supplies[int(building.id)]={"has_power":building.get("has_power",false),"has_water":building.get("has_water",false)}
 _by_id[int(building.id)]=building;_building_changes[int(building.id)]=building;_changed()
func note_zone(parcel_id:String,zone:String):
 if not enabled or _publishing:return
 _zones[parcel_id]=zone;_changed()
func note_world_dirty(key:String):
 assert(key in WORLD_KEYS,"Unknown worker world field: "+key)
 if not enabled or _publishing:return
 _world_dirty[key]=true;_changed()
func note_roads():note_world_dirty("roads")
func remove_building(id:int):note_remove(id)
func note_world():
 for key:String in WORLD_KEYS:note_world_dirty(key)
func note_zones():
 if enabled and not _publishing:_zones_dirty=true;_changed()
func note_meta(key:String,value:Variant):
 assert(key in META_KEYS,"Unknown worker metadata field: "+key)
 if not enabled or _publishing:return
 _meta[key]=value;_changed()
func note_population_config():
 if enabled and not _publishing:_population_config_dirty=true;_changed()
func note_growth_config():
 if enabled and not _publishing:_growth_config_dirty=true;_changed()
func _world_value(city,key:String)->Variant:
 match key:
  "public_lots":return city.public_facilities.lots
  "power_plants":return city.power.plants
  "water_facilities":return city.water.facilities
 return city.get(key)
func _make_delta(city)->Dictionary:
 var delta:Dictionary={"base_tick":worker.GetPublishedTick(),"base_revision":worker.GetPublishedRevision(),"revision":_revision}
 var ops:Array=[]
 for id:Variant in _building_changes:
  var row:Variant=_building_changes[id]
  if row==null:ops.append({"kind":"remove","id":id})
  else:
   var record:Dictionary=row.duplicate(true)
   for key:String in HAPPINESS_KEYS:record.erase(key)
   ops.append({"kind":"update" if _published_ids.has(id) else "create","id":id,"record":record})
 if not ops.is_empty():delta.building_ops=ops
 if _zones_dirty:
  for id:Variant in city.zone_designations:
   if _known_zones.get(id,"")!=city.zone_designations[id]:_zones[id]=city.zone_designations[id]
  for id:Variant in _known_zones:
   if not city.zone_designations.has(id):_zones[id]=""
 if not _zones.is_empty():delta.zones=_zones.duplicate(true)
 var meta:Dictionary=_meta.duplicate(true)
 # Always a scalar, never a main-state export. Result money is a DELTA against this value.
 meta.funds=city.funds;delta.meta=meta
 var world:Dictionary={}
 for key:String in _world_dirty:world[key]=_world_value(city,key).duplicate(true)
 if not world.is_empty():delta.world=world
 if _population_config_dirty:delta.population_config=city.population.config.duplicate(true)
 if _growth_config_dirty:delta.growth_config=_adapter_script._capture_object(city.config)
 return delta
func _submit(city)->bool:
 var delta:=_make_delta(city)
 if not worker.Submit(delta,float(city.config.development_interval_seconds)):return false
 _submitted_funds=int(delta.meta.funds);_submitted_revision=_revision
 _building_changes={};_supplies={};_zones={};_world_dirty={};_meta={}
 _population_config_dirty=false;_growth_config_dirty=false
 if _zones_dirty:_known_zones=city.zone_designations.duplicate(true);_zones_dirty=false
 return true
func advance(seconds:float)->void:advance_society(seconds)
func advance_society(seconds:float)->void:
 if not enabled or suspended or _stopped or seconds<=0 or not is_finite(seconds):return
 var city=owner.get_ref()
 if city==null or not _fault.is_empty():return
 if not is_ready():_elapsed=0.0;return # Boot cannot accrue time or tick debt.
 var interval:float=city.config.development_interval_seconds
 _elapsed+=seconds
 if _elapsed<interval:return
 if not get_fault().is_empty():return
 var attempts:=floori(_elapsed/interval)
 _elapsed=fposmod(_elapsed,interval) # Drop physical attempts: never a simulation tick queue.
 if worker.IsBusy():city.society_frozen_cycles+=attempts;return
 if not _publish():
  if has_pending():return # Failed/stale publication must never authorize another submission.
 if not get_fault().is_empty():return
 _replay_edits() # New IDs allocated only AFTER publication's next_id, BEFORE Submit.
 if _submit(city):city.society_frozen_cycles+=maxi(0,attempts-1)
func allowed_utility_seconds(seconds:float)->float:
 # Utility clocks consume only already PUBLISHED credit, including during a pending step.
 # This keeps accepted metering chunks alive; zeroing every pending frame would starve them.
 if not enabled:return seconds
 if suspended or _stopped or not is_ready() or seconds<=0 or not is_finite(seconds):return 0.0
 var city=owner.get_ref()
 if city==null:return 0.0
 return minf(seconds,maxf(0.0,city.clock.game_seconds-city.utilities.elapsed)/Clock.SCALE)
func _publish()->bool:
 var result:Dictionary=worker.PublishBoundary()
 if result.is_empty():return false
 if int(result.logical_tick)!=_published_tick+1 or int(result.revision)!=_submitted_revision:
  _fault="Rejected stale/out-of-order full-city publication";return false
 var city=owner.get_ref()
 if city==null:return false
 _publishing=true
 # Stable surviving dictionary identity and array order. Scan ONLY on an actual removal.
 var removed:Dictionary={}
 for value:Variant in result.building_removals:
  var id:int=int(value);removed[id]=true;_by_id.erase(id);_published_ids.erase(id)
  _building_changes.erase(id);_supplies.erase(id)
 if not removed.is_empty():
  var survivors:Array[Dictionary]=[]
  for b:Dictionary in city.buildings:
   if not removed.has(int(b.id)):survivors.append(b)
  city.buildings.assign(survivors)
 for incoming:Dictionary in result.building_upserts:
  var id:int=incoming.id
  var row:Dictionary=_by_id.get(id,{})
  var existing:bool=_by_id.has(id)
  var saved:Dictionary={}
  for key:String in HAPPINESS_KEYS:
   if row.has(key):saved[key]=row[key]
  row.clear();row.merge(incoming.duplicate(true),true);row.merge(saved,true)
  if _supplies.has(id):row.merge(_supplies[id],true)
  if not existing:city.buildings.append(row)
  _by_id[id]=row;_published_ids[id]=true
 city.population.attach_read_view(result.population_view)
 city._commuting_summary=result.get("commuting_summary",{}).duplicate(true)
 city.happiness.attach_read_view(result.happiness_view)
 city.next_id=maxi(city.next_id,int(result.next_id))
 city.rng.seed=result.rng_seed;city.rng.state=result.rng_state
 city.appearance_rng.seed=result.appearance_seed;city.appearance_rng.state=result.appearance_state
 city.development_elapsed=result.development_elapsed;city.development_cursor=result.development_cursor
 city.society_elapsed=result.society_elapsed
 city.funds+=int(result.funds)-_submitted_funds
 _published_tick=int(result.logical_tick)
 is_publishing_clock=true
 city.clock.game_seconds=result.clock_seconds # Parent suppresses duplicate upkeep, not UI events.
 is_publishing_clock=false
 if not result.building_upserts.is_empty() or not removed.is_empty():city.utilities.mark_dirty()
 _publishing=false
 city.society_changed.emit()
 return true
func suspend():
 if not enabled or _stopped:return
 worker.Suspend();suspended=true;_elapsed=0.0 # Join is NOT publication.
func resume():
 if not enabled or (not _stopped and not suspended):return
 worker.Resume();suspended=false;_stopped=false;_elapsed=0.0
func shutdown():
 if not enabled or _stopped:return
 worker.Shutdown();_stopped=true;suspended=true;_elapsed=0.0
func validation_publish()->bool:
 # Tests only: deterministic barrier + explicit publication. Never called by normal frames.
 if not enabled or _stopped or not get_fault().is_empty():return false
 worker.Suspend();suspended=true;_elapsed=0.0
 return _publish()
func export_validation_state()->Dictionary:
 # Do NOT join/export completed-unpublished mutable worker state into the read facade.
 # Caller must explicitly validation_publish first. Joining alone never makes it visible.
 if not enabled or _stopped or not get_fault().is_empty() or has_pending():return {}
 return worker.ExportValidationState()
