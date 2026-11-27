extends SceneTree
const Runtime=preload("res://core/commuter_runtime.gd")
const Component=preload("res://core/neighbor_commuting.gd")
var count:=0
var failed:=0
var component=Component.new()
func check(ok: bool,label: String):
 count+=1
 if ok:print("PASS "+label)
 else:failed+=1;push_error(label)
func _initialize():run.call_deferred()
func fixture() -> Dictionary:
 return {"width":100,"height":100,"roads":[{"parcel_id":7,"kind":"local","lanes":2,"width":3.0,"points":PackedVector2Array([Vector2(0,20),Vector2(100,20)])}],"buildings":[{"id":11,"x":60.0,"y":21.75,"size":2,"front_road_id":7,"front_direction":Vector2.UP}]}
func plan(people: int=12,ordinal: int=1,direction: String="inbound") -> Dictionary:
 return {"flows":[{"id":"actual-commute-"+direction,"day":0,"count":people,"direction":direction,"neighbor_id":"west","neighbor_edge":"x_min","home_id":"neighbor:west:homes" if direction=="inbound" else 11,"workplace_id":11 if direction=="inbound" else "neighbor:west:jobs","mode":"road","population_ordinal_start":ordinal,"route":{"boundary":Vector2(0,20),"road_id":7,"local_id":11,"direction":direction}}]}
func make(parameters: Dictionary={}) -> RefCounted:
 var runtime=Runtime.new(parameters)
 check(runtime.prepare_world(fixture()).ok,"detached worker world")
 return runtime
func run():
 var a=make()
 var p:=plan()
 check(a.apply_plan(component,p).added==12,"all logical people admitted")
 check(a.apply_plan(component,p).duplicate_flows==1 and a.records.size()==12,"plan replay is idempotent")
 var earliest:=999999999
 for row in a.records.values():earliest=mini(earliest,row.departure_tick)
 a.advance(float(earliest)/30+2)
 var first: Dictionary=a.visible_snapshot()
 check(not first.vehicles.is_empty(),"actual ACC cars spawned at boundary")
 var moved:=false
 for sample in first.vehicles:
  if sample.speed>0 and sample.progress>0:moved=true
 check(moved,"cars actually advance on lane curves, not presentation-only records")
 var frozen: Dictionary=a.export_state()
 a.advance(500,true)
 check(a.export_state()==frozen,"busy accepted time frozen without backlog")
 var clone=Runtime.new()
 var packed: PackedByteArray=var_to_bytes(frozen)
 check(clone.import_state(bytes_to_var(packed)),"nonempty binary checkpoint rebuilds directed graph and moving cars")
 var snap=a.visible_snapshot()
 snap.vehicles[0].progress=-999
 check(a.visible_snapshot().vehicles[0].progress>=0,"published visible snapshots detached")
 var sample_file=FileAccess.open("res://visible_sample.gdvar",FileAccess.WRITE)
 sample_file.store_var(first);sample_file.close()
 var json_file=FileAccess.open("res://visible_sample.json",FileAccess.WRITE)
 json_file.store_string(JSON.stringify(first,"  "));json_file.close()
 a.advance(200);clone.advance(200)
 check(a.export_state()==clone.export_state(),"deterministic mid-movement checkpoint replay")
 a.advance(20*3600-a.now());clone.advance(20*3600-clone.now())
 check(a.export_state()==clone.export_state(),"identical complete roundtrip replay")
 print("FINAL ",a.stats())
 check(a.totals.arrived==12 and a.totals.returned==12 and a.totals.logical_legs==24,"all people arrive and return")
 check(a.totals.physical_arrivals==24 and a.micro.vehicles.is_empty() and a.pending.is_empty(),"actual cars reach frontage and return exit; all occupants cleaned")
 check(a.micro.reservations.is_empty() and a.micro.waiting.is_empty(),"no leaked junction reservations after physical arrivals")
 var conservation:=true
 for load in a.loads.values():conservation=conservation and load.booked==load.entered and load.entered==load.exited and load.active==0
 check(conservation,"all unsampled road entries/exits conserved")
 check(int(a.parking.get("11",0))==0,"inbound roadside occupancy released on return")
 var hidden=make({"display_enabled":false,"fade_game_seconds":0})
 hidden.apply_plan(component,p);hidden.advance(20*3600)
 check(hidden.logical_snapshot()==a.logical_snapshot(),"display/fade cannot change trip demand, road loads, arrivals or late flags")
 var outbound=make()
 outbound.apply_plan(component,plan(3,1,"outbound"));outbound.advance(20*3600)
 check(outbound.totals.returned==3 and outbound.totals.physical_arrivals==6,"outbound home-boundary and boundary-home physical roundtrip")
 check(Runtime.display_ordinal(1) and Runtime.display_ordinal(1000) and not Runtime.display_ordinal(1001) and Runtime.display_ordinal(1010) and not Runtime.display_ordinal(10001) and Runtime.display_ordinal(10100),"approved tier sampling boundaries")
 var tracked=make()
 tracked.apply_plan(component,plan(1,10001))
 var row: Dictionary=tracked.records.values()[0]
 tracked.advance(float(row.departure_tick)/30+15)
 check(tracked.micro.vehicles.is_empty(),"unsampled trip still logically moving")
 tracked.set_tracked(row.person_id)
 check(tracked.micro.vehicles.size()==1 and tracked.visible_snapshot().vehicles[0].tracked,"tracked exception promotes to actual ACC vehicle")
 tracked.advance(20*3600-tracked.now())
 check(tracked.totals.returned==1 and tracked.totals.physical_arrivals==2,"tracked citizen persists through roundtrip")
 var slow=make({"display_enabled":false,"macro_speed_m_per_game_second":0.01})
 slow.apply_plan(component,plan(1))
 var slow_record: Dictionary=slow.records.values()[0]
 slow.advance(float(slow_record.deadline_tick+1)/30)
 check(slow_record.status=="travelling" and slow_record.late and slow.totals.late==1,"late flag fires after four hours before delayed arrival")
 print("RESULT %d/%d movement" % [count-failed,count])
 quit(1 if failed else 0)
