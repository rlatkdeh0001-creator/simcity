extends SceneTree
var checks:=0
var failures:=0
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=preload("res://core/city_model.gd").new(100,100,42)
 verify(city.get("public_facilities")!=null,"public placements have a separate real city model, not inspection scenes")
 if city.get("public_facilities")!=null:
  verify(city.public_facilities.entries.size()==34,"all thirty-four approved service/infrastructure/park cards are placeable, excluding hydro")
  verify(city.public_facilities.has_method("place"),"public placement commits real geometry and charges construction cost")
  if city.public_facilities.has_method("place"):
   city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
   var result: Dictionary=city.public_facilities.place("fire-station",Vector2(12,35),0)
   verify(result.ok and city.public_facilities.lots.size()==1,"6x6 fire station places adjacent to local road")
   verify(city.funds==30000,"fire station immediately charges approved CSV 20000 doth")
   check_lifecycle()
   check_utilities()
   check_diagonal()
   var fallback=preload("res://core/public_balance.gd").new()
   verify(fallback.reload("res://assets/economy/ECONOMY_BALANCE.csv.txt") and fallback.number("power.wind.construction")==15000 and fallback.capacities("power-wind").average_output_kw==1000,"packaged plain-text CSV mirror loads the same approved prices and capacities without translation importing")
 print("RESULT %d/%d public placement checks passed" % [checks-failures,checks])
 quit(1 if failures else 0)
func town():
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.funds=1000000
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 return city
func check_lifecycle():
 var ids: Array=town().public_facilities.entries.keys()
 for id: String in ids:
  var city=town();var public=city.public_facilities;var e: Dictionary=public.entries[id]
  var position:=Vector2(12,38-float(e.depth)/2)
  verify(not public.preview(id,Vector2(12,10)).ok,id+" rejects disconnected frontage")
  verify(not public.preview(id,position,2).ok,id+" rejects model front away from road")
  city.funds=0
  verify(public.preview(id,position).get("code")=="insufficient_funds",id+" cannot build without cash")
  city.funds=1000000
  var before: int=city.funds;var preview: Dictionary=public.preview(id,position)
  verify(preview.ok and public.lots.is_empty() and city.funds==before,id+" ghost validation has no city or money side effects")
  var placed: Dictionary=public.place(id,position)
  verify(placed.ok and city.funds==before-int(public.price(id)),id+" real placement charges CSV once")
  if not placed.ok:continue
  verify(not public.place(id,position).ok and public.lots.size()==1,id+" overlapping public building rejected")
  verify(not city.add_building(12,36).ok,id+" private building cannot occupy public lot")
  verify(not city.add_road(PackedVector2Array([Vector2(12,10),Vector2(12,70)])).ok,id+" new road cannot cut public footprint")
  var funds: int=city.funds;var fee: int=int(public.upkeep(id))
  city.clock.advance_real(3599)
  verify(city.funds==funds,id+" no monthly charge before game-day boundary")
  city.clock.advance_real(1)
  verify(city.funds==funds-fee,id+" approved upkeep charged at game-day/month boundary")
  city.clock.advance_real(7200)
  verify(city.funds==funds-3*fee,id+" crossed month boundaries each charge exactly once")
  var snapshot: Dictionary=placed.record.duplicate(true)
  city.demolish("road",0)
  verify(placed.record==snapshot,id+" road deletion never relocates or turns placed public model")
  verify(city.demolish("public_facility",placed.record.id).ok and public.lots.is_empty(),id+" common bulldozer removes public building")
  funds=city.funds;city.clock.advance_real(3600)
  verify(city.funds==funds,id+" demolished facility no longer bills maintenance")
func check_utilities():
 for id in ["power-wind","power-solar","power-coal","power-oil","power-nuclear"]:
  var city=town();var p=city.public_facilities;var e: Dictionary=p.entries[id]
  var record: Dictionary=p.place(id,Vector2(12,38-float(e.depth)/2)).record
  verify(city.power.plants.size()==1 and record.utility_id>=0,id+" joins real power engine")
  if record.utility_id<0:continue
  verify(city.power.plants[0].output_kw==record.capacity.average_output_kw,id+" actual average generation comes from CSV, rated output remains separate")
  city.add_building(40,36,"residential")
  verify(not city.power_state().consumers[city.buildings[0].id].powered,"generation without connected wire cannot supply houses")
  city.power.add_wire(PackedVector2Array([record.position*4,Vector2(164,148)]))
  verify(city.power_state().consumers[city.buildings[0].id].powered,id+" actual wire supplies a real private building")
  city.demolish("public_facility",record.id)
  verify(city.power.plants.is_empty() and not city.power_state().consumers[city.buildings[0].id].powered,id+" demolition removes source and service")
 for id in ["water-sewage-outfall","water-sewage-treatment"]:
  var city=town();var p=city.public_facilities
  var supply: Dictionary=p.place("water-intake",Vector2(12,36)).record
  var e: Dictionary=p.entries[id];var sink: Dictionary=p.place(id,Vector2(28,38-float(e.depth)/2)).record
  verify(city.water.facilities.size()==2 and supply.utility_id>=0 and sink.utility_id>=0,id+" actual intake and sewage sink are registered")
  if supply.utility_id<0 or sink.utility_id<0:continue
  verify(city.water.facilities[0].capacity_m3_day==1000 and city.water.facilities[1].capacity_m3_day==sink.capacity.sewage_m3_day,"water/sewage real capacities read approved CSV")
  city.add_building(40,36,"residential")
  city.water.add_pipe(PackedVector2Array([supply.position*4,sink.position*4,Vector2(164,148)]))
  var state: Dictionary=city.water_state().consumers[city.buildings[0].id]
  verify(state.has_water and state.has_sewage,id+" paired real pipes deliver water and handle sewage")
  city.demolish("public_facility",sink.id)
  verify(city.water.facilities.size()==1 and not city.water_state().consumers[city.buildings[0].id].has_sewage,"bulldozing sink removes its actual treatment capacity")
 for id in ["water-water-tower","waste-incinerator","waste-recycling-center"]:
  var city=town();var p=city.public_facilities;var e: Dictionary=p.entries[id]
  var result: Dictionary=p.place(id,Vector2(12,38-float(e.depth)/2))
  verify(result.ok and not result.record.capacity.is_empty(),id+" places and stores approved capacity data")
  verify(city.power.plants.is_empty() and city.water.facilities.is_empty(),id+" creates no infinite water or unfuelled generation/processing")
func check_diagonal():
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.add_road(PackedVector2Array([Vector2(20,30),Vector2(80,70)]),"local",true,4)
 var tested:=false
 for frame in city.zoning_grid.frames.values():
  if frame.columns<6:continue
  var center: Vector2=frame.origin+frame.along*3+frame.outward*3
  var result: Dictionary=city.public_facilities.place("fire-station",center)
  verify(result.ok,"public 6x6 snaps to a diagonal road-local frame without warping its square lot")
  if result.ok:verify(Vector2(result.record.front_direction).dot(-frame.outward)>.999 and absf(city.Parcels.area(result.record.polygon)-36)<.001,"actual +Z model front faces diagonal road and lot area remains 6x6")
  tested=true;break
 verify(tested,"diagonal geometry fixture has a full roadside block")
