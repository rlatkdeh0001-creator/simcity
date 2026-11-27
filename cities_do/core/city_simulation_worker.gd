extends RefCounted
## Detached-city adapter. Instantiate one adapter per coordinator; city is worker-only.
const Model=preload("res://core/city_model.gd")
const NON_GEOMETRY=["happiness","happiness_target","happiness_factors"]
var city
var logical_tick:=0
var edit_revision:=0
var previous:Dictionary={}
var transit_operations=preload("res://core/transit_operations.gd").new()

# ONE idle initialization capture, never part of a normal frame/tick.
static func capture(source)->Dictionary:
 if source.simulation!=null:
  # A coherent save is an explicit idle operation, never a routine frame read.
  # Reject unpublished/queued edits instead of mixing main and worker epochs.
  if source.simulation.has_pending() or source.simulation.queued_edit_count()>0 or source.simulation._revision!=source.simulation._submitted_revision:return {}
  var owned:Dictionary=source.simulation.worker.ExportCheckpoint()
  if owned.is_empty():return {}
  # Utilities/realized ledger remain main-owned between accepted publications.
  for key:String in ["funds","power","water","utilities","economic_ledger","_treasury_recovered"]:
   owned.model.values[key]=_capture_value(source.get(key))
  return owned
 var checkpoint:Dictionary={"model":_capture_object(source,["population","happiness","simulation"]),"population":source.population.core.ExportCityCheckpoint(),"population_config":source.population.config.duplicate(true),"happiness":source.happiness.core.ExportCityCheckpoint(),"happiness_vars":_capture_object(source.happiness,["owner","core","bound","records","background_enabled","_read_view"])}
 return checkpoint
static func _capture_object(source,skip:Array=[])->Dictionary:
 var values:Dictionary={}
 for descriptor:Dictionary in source.get_property_list():
  if (int(descriptor.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0:continue
  var key:String=descriptor.name
  if key in skip or key=="city":continue # Computed owner facade is not stored state.
  var value:Variant=source.get(key)
  if value is WeakRef:continue # Existing constructor has already rebound owners.
  values[key]=_capture_value(value)
 return {"__city_object":true,"values":values}
static func _capture_value(value:Variant)->Variant:
 if value is RandomNumberGenerator:return {"__city_rng":true,"seed":value.seed,"state":value.state}
 if value is Object:
  assert(value.get_script()!=null,"Unsupported native object in detached snapshot")
  return _capture_object(value)
 if value is Array:
  var result:Array=[]
  for entry:Variant in value:result.append(_capture_value(entry))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key:Variant in value:result[_capture_value(key)]=_capture_value(value[key])
  return result
 assert(not value is Callable and not value is Signal,"Callable/Signal cannot cross worker snapshot")
 # Packed arrays have copy-on-write backing; force an owned duplicate via serialization.
 return bytes_to_var(var_to_bytes(value))
static func _restore_object(target,snapshot:Dictionary):
 for key:String in snapshot.values:
  var value:Variant=snapshot.values[key]
  var current:Variant=target.get(key)
  if value is Dictionary and value.get("__city_rng",false):
   current.seed=value.seed;current.state=value.state
  elif value is Dictionary and value.get("__city_object",false):
   assert(current is Object,"Fresh model component missing: "+key)
   _restore_object(current,value)
  elif current is Array and value is Array:current.assign(value.duplicate(true))
  else:target.set(key,_copy(value))
static func _copy(value:Variant)->Variant:
 return bytes_to_var(var_to_bytes(value))
func boot(checkpoint:Dictionary)->Dictionary:
 city=Model.new()
 _restore_object(city,checkpoint.model)
 city._detached_worker=true
 if not checkpoint.model.values.has("loans"):
  city.loans.last_day=city.clock.day();city.loans.evaluated_day=city.clock.day()
 city.population.config=checkpoint.population_config.duplicate(true)
 city.population.import_fixture_state(checkpoint.population)
 city.population.rng.seed=checkpoint.population.rng_seed
 city.population.rng.state=checkpoint.population.rng_state
 # Worker geometry can use the original pack path, but stage1 notifications avoid it.
 city.population.enable_geometry_transport(city.buildings)
 if not checkpoint.population.has("tax_policy"):city.enable_taxation()
 _restore_object(city.happiness,checkpoint.happiness_vars)
 city.happiness.background_enabled=false
 city.happiness.core.ImportCityCheckpoint(checkpoint.happiness)
 city.happiness.bound=city.population.core
 city.happiness.records.clear()
 for b:Dictionary in city.buildings:city.happiness.records[b.id]=b
 previous=_geometry_snapshot()
 return {"ok":true}
func _geometry_snapshot()->Dictionary:
 var result:Dictionary={}
 for b:Dictionary in city.buildings:
  var row:Dictionary=b.duplicate(true)
  for key:String in NON_GEOMETRY:row.erase(key)
  result[int(b.id)]=row
 return result
func _error(message:String)->Dictionary:return {"ok":false,"error":message}
func _validate(delta:Dictionary)->String:
 if int(delta.get("base_tick",-1))!=logical_tick:return "stale logical tick"
 if int(delta.get("base_revision",-1))!=edit_revision:return "stale edit revision"
 if int(delta.get("revision",edit_revision))<edit_revision:return "revision went backwards"
 var seen:Dictionary={}
 var existing:Dictionary={}
 for b:Dictionary in city.buildings:existing[int(b.id)]=true
 for lot:Dictionary in city.public_facilities.lots:existing[int(lot.id)]=true
 for op:Dictionary in delta.get("building_ops",[]):
  var kind:String=op.get("kind","");var id:int=op.get("id",-1)
  if kind not in ["create","update","remove"] or seen.has(id):return "invalid/duplicate building operation"
  seen[id]=true
  if kind=="create" and (id<city.next_id or existing.has(id)):return "create ID collides with simulation/public lot or is below next_id"
  if kind!="create" and not previous.has(id):return "unknown building ID"
  if kind!="remove":
   var row:Dictionary=op.get("record",{})
   if int(row.get("id",-2))!=id:return "record ID mismatch"
   for field:String in ["zone","size","level","x","y"]:
    if not row.has(field):return "missing building field: "+field
   if row.zone not in ["residential","commercial","industrial"]:return "invalid building zone"
 for key:Variant in delta.get("meta",{}):
  if str(key) not in ["funds","population_enabled","happiness_enabled","difficulty","city_name","next_transit_route_id","next_transit_line_id","next_road_id"]:return "unsupported meta field"
 for key:Variant in delta.get("world",{}):
  if str(key) not in ["roads","public_lots","power_plants","water_facilities","junctions","road_joins","external_infrastructure","transit_routes","transit_lines"]:return "unsupported world field"
 for key:Variant in delta.get("zones",{}):
  if str(delta.zones[key]) not in ["","residential","commercial","industrial"]:return "invalid zone designation"
 var world:Dictionary=delta.get("world",{})
 if delta.get("meta",{}).has("next_road_id"):
  var watermark:Variant=delta.meta.next_road_id
  if not watermark is int or watermark<city.next_road_id:return "invalid road ID watermark"
 if world.has("transit_lines"):
  var problem:String=Model.validate_transit_lines(world.transit_lines)
  if not problem.is_empty():return problem
 if delta.get("meta",{}).has("next_transit_line_id"):
  var next:Variant=delta.meta.next_transit_line_id
  if not next is int or next<city.next_transit_line_id:return "invalid line ID watermark"
 if world.has("transit_routes"):
  var transit_error:String=Model.TransitRoutes.snapshot_error(world.transit_routes,city.width,city.height)
  if not transit_error.is_empty():return transit_error
 if delta.get("meta",{}).has("next_transit_route_id"):
  var next:Variant=delta.meta.next_transit_route_id
  if not next is int or next<city.next_transit_route_id:return "invalid transit ID watermark"
 if world.has("public_lots"):
  var lot_ids:Dictionary={};var old_lot_ids:Dictionary={}
  for lot:Dictionary in city.public_facilities.lots:old_lot_ids[int(lot.id)]=true
  for lot:Dictionary in world.public_lots:
   var id:int=lot.get("id",-1)
   if lot_ids.has(id) or previous.has(id) or seen.has(id):return "public lot ID collides with a building/edit/lot"
   if not old_lot_ids.has(id) and id<city.next_id:return "new public lot ID is below next_id"
   lot_ids[id]=true
 return ""
func run_step(delta:Dictionary,seconds:float,tick:int)->Dictionary:
 var problem:=_validate(delta)
 if not problem.is_empty():return _error(problem)
 var financing_flush:bool=bool(delta.get("financing_flush",false)) and int(delta.get("revision",edit_revision))>edit_revision
 if tick!=logical_tick+1 or (seconds!=float(city.config.development_interval_seconds) and not (seconds==0 and (not delta.get("loan_commands",[]).is_empty() or financing_flush))):return _error("step must advance exactly one configured interval or a zero-time financing edit prefix")
 var by_id:Dictionary={}
 for b:Dictionary in city.buildings:by_id[int(b.id)]=b
 var geometry_changed:=false
 for op:Dictionary in delta.get("building_ops",[]):
  var id:int=op.id
  if op.kind=="remove":
   city.buildings.erase(by_id[id]);by_id.erase(id);city.population.remove_building(id)
  elif op.kind=="create":
   var row:Dictionary=op.record.duplicate(true);city.buildings.append(row);by_id[id]=row
   city.next_id=maxi(city.next_id,id+1);city.population.record_building(row)
  else:
   var row:Dictionary=by_id[id];row.clear();row.merge(op.record.duplicate(true),true);city.population.record_building(row)
  geometry_changed=true
 for key:Variant in delta.get("zones",{}):
  if str(delta.zones[key]).is_empty():city.zone_designations.erase(key)
  else:city.zone_designations[key]=delta.zones[key]
 for key:Variant in delta.get("meta",{}):city.set(key,delta.meta[key])
 if delta.has("growth_config"):_restore_object(city.config,delta.growth_config)
 if delta.has("population_config"):city.population.config=delta.population_config.duplicate(true)
 var world:Dictionary=delta.get("world",{})
 if world.has("transit_lines"):
  city.transit_lines.assign(world.transit_lines.duplicate(true))
  for line:Dictionary in city.transit_lines:city.next_transit_line_id=maxi(city.next_transit_line_id,int(line.id)+1)
 if world.has("transit_routes"):
  city.transit_routes.assign(world.transit_routes.duplicate(true))
  city._commuting_generation+=1
  for route:Dictionary in city.transit_routes:city.next_transit_route_id=maxi(city.next_transit_route_id,int(route.id)+1)
 if world.has("external_infrastructure"):
  city.external_infrastructure.assign(world.external_infrastructure.duplicate(true))
  city._commuting_generation+=1
  for link:Dictionary in city.external_infrastructure:city.next_external_link_id=maxi(city.next_external_link_id,int(link.id)+1)
 if world.has("public_lots"):
  city.public_facilities.lots.assign(world.public_lots.duplicate(true))
  for lot:Dictionary in city.public_facilities.lots:city.next_id=maxi(city.next_id,int(lot.id)+1)
 if world.has("power_plants"):city.power.plants.assign(world.power_plants.duplicate(true))
 if world.has("water_facilities"):city.water.facilities.assign(world.water_facilities.duplicate(true))
 if world.has("roads"):
  city.roads.assign(world.roads.duplicate(true));city._update_zoning_for_road({})
  for b:Dictionary in city.buildings:city.orient_building(b)
 else:
  if world.has("junctions"):city.junctions=world.junctions.duplicate(true)
  if world.has("road_joins"):city.road_joins=world.road_joins.duplicate(true)
 if geometry_changed or not world.is_empty():city.happiness.mark_dirty();city.utilities.mark_dirty()
 if geometry_changed:
  city._labor_world_dirty=true;city._commuting_generation+=1;city.population.sync(city.buildings)
 for options:Dictionary in delta.get("tax_commands",[]):
  var configured:Dictionary=city.configure_tax_policy(options)
  if not configured.ok:return _error("invalid tax policy command")
 city.power.pending_doth=float(delta.get("utility_carry",0.0));city.water.pending_doth=0.0
 # Count only completed fiscal days after main has metered their final utility interval.
 if bool(delta.get("treasury_recovered",false)):city.loans.observe_balance(0.0)
 city.loans.evaluate_day(mini(city.loans.last_day,int(delta.get("utility_day",0))),city.treasury_balance())
 for target:Variant in delta.get("loan_commands",[]):
  city.loans.last_command_result=city.set_loan_amount(target)
 city.advance_society(seconds)
 transit_operations.advance(city,seconds)
 logical_tick=tick;edit_revision=int(delta.get("revision",edit_revision))
 var current:=_geometry_snapshot();var changed:Array[Dictionary]=[];var removed:=PackedInt64Array()
 for id:Variant in current:
  if not previous.has(id) or previous[id]!=current[id]:changed.append(current[id].duplicate(true))
 for id:Variant in previous:
  if not current.has(id):removed.append(int(id))
 previous=current
 return {"ok":true,"logical_tick":logical_tick,"revision":edit_revision,"building_upserts":changed,"building_removals":removed,
  "clock_seconds":city.clock.game_seconds,"society_elapsed":city.society_elapsed,"development_elapsed":city.development_elapsed,"development_cursor":city.development_cursor,
  "next_id":city.next_id,"rng_seed":city.rng.seed,"rng_state":city.rng.state,"appearance_seed":city.appearance_rng.seed,"appearance_state":city.appearance_rng.state,
  "transit_state":city.transit_state.duplicate(true),"loan_status":city.loan_status(),"loan_checkpoint":_capture_object(city.loans),
  "funds":city.funds,"tax_day_economy":city._tax_day_economy.duplicate(true),"commuting_summary":city.commuting.status(),"commuting_checkpoint":_capture_object(city.commuting),"population_view":city.population.core.CaptureCityReadView(),"happiness_view":city.happiness.core.CaptureCityReadView()}
func export_validation()->Dictionary:
 return {"checkpoint":capture(city),"transit_lines":city.transit_lines.duplicate(true),"transit_state":city.transit_state.duplicate(true),"next_transit_line_id":city.next_transit_line_id,"buildings":city.buildings.duplicate(true),"transit_routes":city.transit_routes.duplicate(true),"next_transit_route_id":city.next_transit_route_id,"external_infrastructure":city.external_infrastructure.duplicate(true),"population":city.population.core.ExportCityCheckpoint(),"happiness":city.happiness.core.ExportCityCheckpoint(),
  "rng_state":city.rng.state,"appearance_state":city.appearance_rng.state,"clock_seconds":city.clock.game_seconds,
  "loans":_capture_object(city.loans),
  "funds":city.funds,"next_id":city.next_id,"development_elapsed":city.development_elapsed,"development_cursor":city.development_cursor,"society_elapsed":city.society_elapsed}
