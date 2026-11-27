extends SceneTree
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var c=load("res://core/city_model.gd").new(100,100)
 check(c.has_method("commuting_status"),"production model exposes authoritative neighbor employment summary")
 if not c.has_method("commuting_status"):finish();return
 c.add_road(PackedVector2Array([Vector2(0,30),Vector2(60,30)]))
 for parcel:Dictionary in c.zoning_grid.parcels.values():
  var made:Dictionary=c.add_building_at(parcel.center,"industrial")
  if made.ok:break
 c.enable_simulation_worker();c.simulation.worker.Suspend()
 c.advance_society(2);c.simulation.validation_publish();c.simulation.resume()
 var status:Dictionary=c.commuting_status()
 check(status.get("inbound",0)>0,"actual boundary road produces concrete foreign slot reservations")
 var work:Dictionary=c.population.workplace_info(c.buildings[0].id)
 var reserved:=0
 for n in work.get("inbound_reserved",[]):reserved+=int(n)
 check(reserved==status.inbound and c.population.stats().population==0,"inbound staffing never creates fake local residents")
 c.demolish("road",0)
 c.advance_society(2);c.simulation.validation_publish()
 check(c.commuting_status().inbound==0,"last boundary road removal clears foreign employment at next boundary")
 c.simulation.shutdown()
 # Real housed residents can take external jobs without fake local workplaces.
 c=load("res://core/city_model.gd").new(100,100)
 c.add_road(PackedVector2Array([Vector2(0,30),Vector2(60,30)]))
 var home:Dictionary={}
 for parcel:Dictionary in c.zoning_grid.parcels.values():
  var made:Dictionary=c.add_building_at(parcel.center,"residential")
  if made.ok:home=made.building;break
 c.population.import_fixture_state({"people":[{"id":1,"household_id":1,"education":0,"age_years":30.0,"origin":"test","workplace_id":-1,"job_stage":-1}],"households":[{"id":1,"home_id":home.id}],"workplaces":{},"next_person":2,"next_household":2})
 c.enable_simulation_worker();c.simulation.worker.Suspend()
 c.advance_society(2);c.simulation.validation_publish();c.simulation.resume()
 status=c.commuting_status()
 check(status.outbound>0 and c.population.stats().employed==status.outbound,"outbound residents become employed without consuming local job slots")
 c.demolish("road",0);c.advance_society(2);c.simulation.validation_publish()
 check(c.commuting_status().outbound==0 and c.population.stats().employed==0,"disconnected foreign corridor removes stale external assignments")
 c.simulation.shutdown()
 finish()
func finish():print("NEIGHBOR_MODEL checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
