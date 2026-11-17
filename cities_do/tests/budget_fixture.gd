extends RefCounted
## Authored capture fixture: actual employment, tax assessment and utility metering.
static func create():
 var c=preload("res://core/city_model.gd").new(100,100)
 c.happiness_enabled=false;c.population.configure_labor_policy({"enabled":false})
 assert(c.add_road(PackedVector2Array([Vector2(10,40),Vector2(80,40)])).ok)
 var homes:Array=[];var works:Array=[]
 for zone in ["residential","commercial","industrial"]:
  for band in range(3):
   for parcel in c.zoning_grid.parcels.values():
    var result:Dictionary=c.add_building_at(parcel.center,zone)
    if not result.ok:continue
    result.building.level=[1,3,5][band]
    if zone=="residential":homes.append(result.building)
    else:works.append(result.building)
    break
 var people:Array=[];var households:Array=[]
 for i in range(6):
  households.append({"id":i+1,"home_id":homes[i%3].id})
  people.append({"id":i+1,"household_id":i+1,"education":i%5,"age_years":25.0,"origin":"fixture","workplace_id":works[i].id,"job_stage":i%5})
 c.population.import_fixture_state({"people":people,"households":households,"next_person":7,"next_household":7})
 c.population.enable_geometry_transport(c.buildings);c.population.sync(c.buildings)
 var port:Vector2=c.power.ports[0].position;var end:=Vector2(96,200)
 assert(c.power.add_wire(PackedVector2Array([port,end])).ok)
 assert(c.water.add_pipe(PackedVector2Array([port,end])).ok)
 c.power.add_plant(end,200);c.water.add_facility(end,"water",100);c.water.add_facility(Vector2(64,200),"sewage",100)
 c.enable_taxation()
 for i in range(3600):c.advance_utilities(1)
 c.clock.game_seconds=86400;c._assess_tax_boundary()
 return c
