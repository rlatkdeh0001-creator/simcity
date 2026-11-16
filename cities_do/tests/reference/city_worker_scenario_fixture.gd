extends SceneTree
const Model=preload("res://core/city_model.gd")
var city
var game
var homes:Array[Dictionary]=[]
var captured:=false
func _initialize():run.call_deferred()
func private_near(point:Vector2,zone:String,size:int=2)->Dictionary:
 var parcels:Array=city.zoning_grid.parcels.values().filter(func(p):return p.v==0)
 parcels.sort_custom(func(a,b):return a.center.distance_squared_to(point)<b.center.distance_squared_to(point))
 for p in parcels:
  if p.center.distance_to(point)>6:continue
  var result:Dictionary=city.add_building_at(p.center,zone,0,size)
  if result.ok:return result.building
 assert(false,"authored scenario lacks a legal lot near "+str(point));return {}
func public_near(asset:String,point:Vector2):
 var result:Dictionary=city.public_facilities.place(asset,point,0,true)
 assert(result.ok,"public facility placement failed "+asset+" "+str(result));return result.record
func setup():
 city=Model.new(180,240,20261115);city.funds=2000000
 # Controlled immigration education profile isolates services/buffering from labor-band shortages.
 city.population.config.immigrant_education_weights=[0,1,0,0,0]
 for y in [45,115,185]:assert(city.add_road(PackedVector2Array([Vector2(12,y),Vector2(150,y)])).ok)
 var people:Array=[];var households:Array=[]
 for district in range(3):
  var y:float=[45,115,185][district]
  var home:Dictionary=private_near(Vector2(50,y+3),"residential");homes.append(home)
  private_near(Vector2(70,y+3),"industrial")
  for x in [90,110,130]:private_near(Vector2(x,y+3),"commercial",4)
  for h in range(2):
   var household:int=households.size()+1;households.append({"id":household,"home_id":home.id})
   for adult in range(2):people.append({"id":people.size()+1,"household_id":household,"education":1,"age_years":30.0,"origin":"scenario","workplace_id":-1,"job_stage":-1})
  if district>0:
   public_near("medical-large-hospital",Vector2(90,y-6));public_near("police-station",Vector2(110,y-5));public_near("small-fire-station",Vector2(130,y-4))
  if district==2:public_near("park-garden-2x2",Vector2(60,y+3))
  var source:=Vector2(18,y+13)*4
  assert(city.power.add_plant(source,100000)>=0)
  assert(city.power.add_wire(PackedVector2Array([source,Vector2(18,y)*4,Vector2(150,y)*4])).ok)
  var intake:=Vector2(12,y+13)*4;var sewage:=Vector2(12,y+17)*4
  assert(city.water.add_facility(intake,"water",100000)>=0);assert(city.water.add_facility(sewage,"sewage",100000)>=0)
  assert(city.water.add_pipe(PackedVector2Array([intake,sewage,Vector2(18,y)*4,Vector2(150,y)*4])).ok)
 city.population.import_fixture_state({"people":people,"households":households,"workplaces":{},"next_person":people.size()+1,"next_household":households.size()+1});city.population.sync(city.buildings)
 city.advance_utilities(0)
 for home in homes:assert(home.has_power and home.has_water,"real network supply, not forced happiness flags")
func run():pass
