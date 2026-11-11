extends SceneTree
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(value: bool,description: String):
 checks+=1
 if value:print("PASS "+description)
 else:failures+=1;push_error("FAIL "+description)
func run():
 var path:="res://assets/growth_14.json"
 verify(FileAccess.file_exists(path),"fourteen approved growth originals have a runtime registry")
 if FileAccess.file_exists(path):
  var entries: Array=JSON.parse_string(FileAccess.get_file_as_string(path)).assets
  verify(entries.size()==14,"all fourteen source IDs registered")
  for entry: Dictionary in entries:
   verify(ResourceLoader.exists(entry.model) and FileAccess.file_exists(entry.spec),entry.id+" actual GLB and spec exist")
 var catalog=preload("res://core/building_catalog.gd").new()
 verify(catalog.has_method("matching"),"appearance matcher exposes density-aware candidate resolution")
 if catalog.has_method("matching"):
  var match: Dictionary=catalog.matching({"zone":"commercial","size":2,"level":3})
  verify(not match.candidates.is_empty() and match.resolved_density=="medium","commercial 2x2 stage3 selects actual medium appearances")
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 var created: Dictionary=city.add_building(8,36,"commercial",100)
 verify(created.ok and not created.building.asset_id.is_empty(),"existing initial placement assigns the real small commercial facade")
 check_matrix(catalog)
 check_city_growth()
 check_models()
 print("RESULT %d/%d growth appearance checks passed" % [checks-failures,checks])
 quit(1 if failures else 0)

func check_matrix(catalog):
 var rows: Array=[]
 var fallback: Array=[]
 for zone in ["residential","commercial","industrial"]:
  verify(catalog.entries.filter(func(e):return e.zone==zone and e.get("growth_enabled",true)).size()==14,zone+" exactly fourteen approved appearances enabled")
  for size in [2,4,8]:
   for level in range(1,6):
    var result: Dictionary=catalog.matching({"zone":zone,"size":size,"level":level})
    var target: String="small" if level<=2 else ("medium" if level<=4 else "large")
    verify(result.target_density==target and result.candidates.size()==2,"%s %dx%d level%d has its two nearest same-lot original candidates" % [zone,size,size,level])
    for id: String in result.candidates:
     var entry: Dictionary=catalog.get_asset(id)
     verify(entry.zone==zone and entry.footprint==[size,size] and catalog.appearance_density(entry)==result.resolved_density,id+" candidate uses original zone, lot and density")
    verify(result.fallback==(size==8 and level<5),"%s %d level%d fallback only for original 8x8 small/medium appearance gap" % [zone,size,level])
    var row: Dictionary={"zone":zone,"lot_cells":[size,size],"stage":level,"target_density":target,"resolved_density":result.resolved_density,"candidate_ids":result.candidates,"fallback":result.fallback}
    rows.append(row)
    if result.fallback:fallback.append(row)
 verify(catalog.get_asset("mansion-a-4x4-4f").min_level==2 and catalog.get_asset("mansion-b-4x4-4f").min_level==2,"legacy mansion minimum level2 retained")
 verify(not "mansion-a-4x4-4f" in catalog.eligible({"zone":"residential","size":4,"level":1}),"mansion never appears at stage1")
 verify("mansion-a-4x4-4f" in catalog.eligible({"zone":"residential","size":4,"level":3}),"stage3 medium 4x4 matching retains both legacy mansions")
 verify(catalog.eligible({"zone":"residential","size":6,"level":3}).is_empty(),"no same-size source gives honest procedural fallback, not a stretched model")
 var isolated=preload("res://core/building_catalog.gd").new()
 isolated.entries=isolated.entries.filter(func(e):return e.zone=="commercial" and e.density!="medium")
 verify(isolated.matching({"zone":"commercial","size":2,"level":3}).resolved_density=="small","nearest-density tie chooses the lower density deterministically")
 var file:=FileAccess.open(ProjectSettings.globalize_path("res://../docs/growth-appearance-validation/matching-table.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"rows":rows,"fallback_stage_rows":fallback,"no_candidate_rows":[],"scope":"appearance only; early-stage 8x8 rows audit legacy fallback and do not implement or approve new 8x8 spawning"},"  ")+"\n")
 file.close()

func check_city_growth():
 for zone in ["residential","commercial","industrial"]:
  var city=preload("res://core/city_model.gd").new(100,100,81)
  city.population_enabled=false
  city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  var funds: int=city.funds
  var painted: Dictionary=city.paint_zones(PackedVector2Array([Vector2(4,36),Vector2(6,36),Vector2(6,38),Vector2(4,38)]),zone)
  var spawned: Array=city.advance_development(city.config.development_interval_seconds)
  verify(painted.changed==4 and spawned.size()==1,zone+" existing actual paint/development path creates a 2x2 building")
  if spawned.is_empty():continue
  var building: Dictionary=spawned[0]
  verify(not building.asset_id.is_empty() and city.catalog.get_asset(building.asset_id).density=="small",zone+" painted new construction uses a real small building")
  city.config.size_weights={2:1.0,4:0.0,8:0.0}
  for stage in range(2,6):
   building.score=city.config.score_threshold
   var result: Dictionary=city.upgrade_chain(building.id)
   verify(result.ok and building.level==stage and building.size==2,zone+" existing manual growth path changes only its normal stage and footprint outcome")
   verify(building.asset_id in city.catalog.eligible(building),zone+" facade rematches at every stage")
  verify(city.funds==funds,zone+" private zoning, construction and appearance growth remain free")
  var baseline=preload("res://core/city_model.gd").new(100,100,81)
  baseline.catalog.entries=[]
  baseline.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  baseline.add_building(8,36,zone,100)
  var visual=preload("res://core/city_model.gd").new(100,100,81)
  visual.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  visual.add_building(8,36,zone,100)
  baseline.upgrade_chain(1);visual.upgrade_chain(1)
  verify(baseline.rng.state==visual.rng.state and baseline.buildings[0].size==visual.buildings[0].size and baseline.buildings[0].level==visual.buildings[0].level,zone+" appearance selection never changes growth RNG, size or stage rules")
 var catalog=preload("res://core/building_catalog.gd").new()
 var rng:=RandomNumberGenerator.new();rng.seed=42
 var sample:={"zone":"commercial","size":2,"level":1,"asset_id":""}
 catalog.assign(sample,rng);var first: String=sample.asset_id
 sample.level=2;catalog.assign(sample,rng)
 verify(sample.asset_id==first,"same density and lot retain existing eligible facade")
 sample.level=3;catalog.assign(sample,rng)
 verify(sample.asset_id!=first and catalog.get_asset(sample.asset_id).density=="medium","density boundary rematches instead of preserving stale small facade")
 sample.size=4;catalog.assign(sample,rng)
 verify(catalog.get_asset(sample.asset_id).footprint==[4,4],"existing size-change path selects correct lot without stretching")

func check_models():
 var entries: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/growth_14.json")).assets
 for entry: Dictionary in entries:
  var model: Node3D=load(entry.model).instantiate();root.add_child(model)
  var first:=true
  var measured:=AABB()
  for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb()
   measured=box if first else measured.merge(box);first=false
  verify(not first and absf(measured.size.x-entry.width*4)<.05 and absf(measured.size.z-entry.depth*4)<.05 and absf(measured.size.y-entry.height_m)<.05,entry.id+" real GLB dimensions preserve source metre/lot scale")
  verify(absf(measured.position.y)<.05,entry.id+" ground alignment is derivative only")
  var front: Node3D=model.find_child("GrowthFrontage",true,false)
  verify(front!=null and front.position.z>0 and entry.source_metadata.front_blender=="-Y" and entry.source_metadata.front=="+Z",entry.id+" original frontage convention exports to Godot +Z")
  verify(FileAccess.file_exists(entry.texture) and entry.storeys==entry.source_metadata.occupied_storeys,entry.id+" original PNG and occupied-storey metadata preserved including equipment zero storeys")
  model.free()
