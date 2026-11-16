extends SceneTree
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
const Coordinator=preload("res://simulation/CitySimulationWorker.cs")
func _initialize():run.call_deferred()
func run():
 var source=Model.new(100,100,42)
 assert(source.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok)
 var parcel:Dictionary=source.zoning_grid.parcels.values()[0]
 var first:Dictionary=source.add_building_at(parcel.center).building
 source.population.enable_geometry_transport(source.buildings)
 for i in range(90):source.advance_society(2)
 var checkpoint:Dictionary=Adapter.capture(source)
 var validator=Adapter.new();assert(validator.boot(checkpoint).ok)
 assert(not validator.run_step({"base_tick":9,"base_revision":0},2,1).ok)
 assert(not validator.run_step({"base_tick":0,"base_revision":3},2,1).ok)
 assert(not validator.run_step({"base_tick":0,"base_revision":0,"building_ops":[{"kind":"update","id":999,"record":{}}]},2,1).ok)
 assert(not validator.run_step({"base_tick":0,"base_revision":0,"building_ops":[{"kind":"create","id":first.id,"record":first}]},2,1).ok)
 assert(not validator.run_step({"base_tick":0,"base_revision":0,"zones":{"x":"bad"}},2,1).ok)
 var worker=Coordinator.new();worker.Initialize(Adapter.new(),checkpoint)
 while not worker.IsReady():await process_frame
 first.level+=1;source.population.record_building(first);source.population.sync(source.buildings);source.happiness.mark_dirty()
 assert(worker.Submit({"base_tick":0,"base_revision":0,"revision":1,"building_ops":[{"kind":"update","id":first.id,"record":first.duplicate(true)}]},2))
 source.advance_society(2)
 while not worker.IsComplete():await process_frame
 var publication:Dictionary=worker.PublishBoundary()
 assert(publication.building_upserts.size()==1 and publication.building_upserts[0].level==2)
 assert(not publication.building_upserts[0].has("happiness"))
 var actual:Dictionary=worker.ExportValidationState()
 assert(actual.buildings==source.buildings and actual.population==source.population.core.ExportCityCheckpoint())
 var removed:int=first.id
 source.population.remove_building(removed);assert(source.demolish("building",removed).ok);source.happiness.mark_dirty()
 assert(worker.Submit({"base_tick":1,"base_revision":1,"revision":2,"building_ops":[{"kind":"remove","id":removed}]},2))
 source.advance_society(2)
 while not worker.IsComplete():await process_frame
 publication=worker.PublishBoundary();assert(publication.building_removals==PackedInt64Array([removed]))
 actual=worker.ExportValidationState()
 assert(actual.buildings==source.buildings and actual.population==source.population.core.ExportCityCheckpoint())
 assert(actual.happiness==source.happiness.core.ExportCityCheckpoint())
 var created:Dictionary=source.add_building_at(parcel.center).building;source.population.sync(source.buildings)
 assert(worker.Submit({"base_tick":2,"base_revision":2,"revision":3,"building_ops":[{"kind":"create","id":created.id,"record":created.duplicate(true)}]},2))
 source.advance_society(2)
 while not worker.IsComplete():await process_frame
 publication=worker.PublishBoundary();assert(publication.building_upserts.size()==1 and publication.building_upserts[0].id==created.id)
 assert(publication.next_id==source.next_id)
 actual=worker.ExportValidationState();assert(actual.buildings==source.buildings and actual.population==source.population.core.ExportCityCheckpoint())
 worker.Shutdown();print("STAGE2_EDITS_PASS create/update/remove/stale-revision/unknown-ID/collision/zone-validation");quit(0)
