extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func make_city(seed_value: int=42):
 var city=Model.new(100,100,seed_value)
 city.population_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 return city
func paint(city,x: int,width: int,depth: int,zone: String="residential"):
 return city.paint_zones(PackedVector2Array([Vector2(x,38-depth),Vector2(x+width,38-depth),Vector2(x+width,38),Vector2(x,38)]),zone)
func _initialize():run.call_deferred()
func run():
 for zone in ["residential","commercial","industrial"]:
  var city=make_city()
  paint(city,4,4,4,zone)
  var built: Array=city.advance_development(2)
  verify(built.size()==1 and built[0].size==4,zone+" automatic wide zoning deterministically prefers 4x4")
  if not built.is_empty():verify(built[0].level==1 and city.catalog.get_asset(built[0].asset_id).density=="small",zone+" 4x4 starts with a stage1 small facade")
 check_growth()
 check_fallback_and_capacity()
 print("RESULT %d/%d lot rule checks passed" % [checks-failures,checks])
 quit(1 if failures else 0)
func check_growth():
 for zone in ["residential","commercial","industrial"]:
  var city=make_city()
  city.add_road(PackedVector2Array([Vector2(2,28),Vector2(90,28)]),"local",true,4)
  paint(city,2,8,8,zone)
  var building: Dictionary=city.advance_development(2)[0]
  for stage in range(2,6):
   building.score=100
   var state: int=city.rng.state
   var result: Dictionary=city.upgrade_chain(building.id)
   verify(result.ok and building.level==stage and building.size==(8 if stage==5 else 4),zone+" largest legal lot at stage%d" % stage)
   verify(city.rng.state==state,"lot selection consumes no random draw without neighbors")
  verify(not city.upgrade_chain(building.id).ok and building.level==5,"stage5 is final without an invented stage6")
  verify(city.catalog.get_asset(building.asset_id).density=="large","stage5 8x8 selects actual original large facade")
 var hold=make_city()
 paint(hold,4,4,4)
 var b: Dictionary=hold.advance_development(2)[0]
 hold.config.size_weights={2:1.0,4:0.0,8:0.0}
 for stage in range(2,6):
  b.score=100;hold.upgrade_chain(b.id)
  verify(b.size==4 and b.level==stage,"insufficient same-use expansion space preserves existing 4x4 without shrinking")
 var blocked=make_city()
 blocked.add_road(PackedVector2Array([Vector2(2,28),Vector2(90,28)]),"local",true,4)
 paint(blocked,2,8,8)
 var first: Dictionary=blocked.advance_development(2)[0]
 var neighbor: Dictionary=blocked.add_building_at(Vector2(8.5,37.5)).building
 var snapshot: Dictionary=neighbor.duplicate(true)
 first.level=4;first.score=100
 verify(blocked.upgrade_chain(first.id).ok and first.level==5 and first.size==4,"stage5 8x8 collision falls back to existing 4x4")
 verify(blocked.buildings.size()==2 and neighbor==snapshot,"no automatic merging or demolition of another building")
 var legacy=make_city()
 legacy.add_road(PackedVector2Array([Vector2(2,28),Vector2(90,28)]),"local",true,4)
 var old: Dictionary=legacy.place_catalog_building("large-8x8-a",2,30).building
 verify(old.level==5,"new authored 8x8 also starts at final stage; only existing legacy data may be earlier")
 old.level=2;old.score=100
 legacy.upgrade_chain(old.id)
 verify(old.size==8 and legacy.catalog.get_asset(old.asset_id).density=="large","legacy early-stage 8x8 keeps its existing large original without shrinking")
func check_fallback_and_capacity():
 for zone in ["residential","commercial","industrial"]:
  var city=make_city()
  paint(city,4,2,2,zone)
  var b: Dictionary=city.advance_development(2)[0]
  verify(b.size==2 and b.level==1,"narrow "+zone+" falls back to actual 2x2 stage1")
  for stage in range(2,6):
   b.score=100;city.upgrade_chain(b.id)
   verify(b.size==2 and b.level==stage,"no same-use 4x4/8x8 space retains 2x2 at stage%d" % stage)
  verify(city.funds==50000,"private construction and manual growth remain free")
 var none=make_city()
 paint(none,4,1,1)
 verify(none.advance_development(2).is_empty() and none.buildings.is_empty(),"neither valid size means no construction")
 var mixed=make_city()
 paint(mixed,4,2,2)
 paint(mixed,4,1,1,"") # Explicitly clear this cell before constructing a mixed-use fixture.
 paint(mixed,4,1,1,"industrial")
 verify(mixed.advance_development(2).is_empty(),"mixed-use 2x2 cannot construct")
 var crossed=make_city()
 paint(crossed,8,4,4)
 verify(crossed.advance_development(2)[0].size==2,"4x4 cannot cross two road blocks even if paint is continuous")
 var priority=make_city()
 paint(priority,4,2,2);paint(priority,20,4,4)
 verify(priority.advance_development(2)[0].size==4,"valid large lot wins over earlier narrow candidate in the same fair scan")
 for seed_value in range(12):
  var city=make_city(seed_value);paint(city,4,4,4)
  var state: int=city.rng.state
  verify(city.advance_development(2)[0].size==4 and city.rng.state==state,"initial lot preference is seed-independent and consumes no growth RNG")
 var rotated=Model.new(100,100)
 rotated.population_enabled=false
 rotated.add_road(PackedVector2Array([Vector2(20,30),Vector2(65,60)]))
 for frame in rotated.zoning_grid.frames.values():
  if rotated.parcel_placement_error(frame,0,0,4)!="":continue
  rotated.paint_zones(rotated.Parcels.polygon(frame,0,0,4),"industrial")
  var b: Dictionary=rotated.advance_development(2)[0]
  verify(b.size==4 and b.frame.id==frame.id and rotated.parcel_placement_error(frame,b.u,b.v,4,b.id)=="","diagonal 4x4 uses same-block shared frontage and collision checks")
  break
 var city=make_city()
 var pop=city.population
 var small: Dictionary={"id":1,"zone":"residential","size":2,"level":1}
 var large: Dictionary={"id":2,"zone":"residential","size":4,"level":1}
 verify(pop.housing_units(large)==4*pop.housing_units(small),"4x4 dwelling capacity equals four 2x2 stage1 buildings without config edits")
 for tick in range(4):pop.advance(48,[large])
 for zone in ["commercial","industrial"]:
  pop.sync([{"id":1,"zone":zone,"size":2,"level":1}]);var slots: Array=pop.workplaces[1].slots.duplicate()
  var before: Dictionary=pop.demand([])
  pop.sync([{"id":1,"zone":zone,"size":4,"level":1}]);var large_slots: Array=pop.workplaces[1].slots
  verify(range(5).all(func(i):return large_slots[i]==4*slots[i]),zone+" all five job bands retain existing area-proportional capacity")
  var after: Dictionary=pop.demand([{"id":1,"zone":zone,"size":4,"level":1}])
  verify(before[zone]>0 and after[zone]>=0 and after[zone]<=before[zone],zone+" populated original demand gate remains nonnegative and does not increase after construction")
 var real=make_city();real.population_enabled=true;paint(real,2,8,8)
 var before: int=real.population.demand(real.buildings).residential
 var initial: Array=real.advance_development(2)
 verify(initial.size()==1 and initial[0].size==4 and real.population.demand(real.buildings).residential<=before,"real residential demand gate permits a large birth without upward demand jump")
 real.population.advance(48,real.buildings)
 verify(real.population.households.size()==1,"larger capacity does not create four immigrant households in one existing tick")
