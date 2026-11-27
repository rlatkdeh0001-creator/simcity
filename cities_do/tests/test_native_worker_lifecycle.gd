extends SceneTree
const Worker=preload("res://core/city_native_mailbox.gd")
class Adapter:
 extends RefCounted
 var calls:=0
 var boots:=0
 func boot(_checkpoint:Dictionary)->Dictionary:boots+=1;return {"ok":true}
 func run_step(delta:Dictionary,_seconds:float,tick:int)->Dictionary:
  calls+=1
  return {"ok":true,"logical_tick":tick,"revision":delta.revision,"calls":calls,"boots":boots}
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var happiness=load("res://simulation/HappinessCore.cs").new()
 happiness.EnableBackground()
 happiness.Configure({"goods":4.0,"commute":0.0,"garbage":0.0,"tax":0.0,"fire_buildings_per_incident":100.0})
 var checkpoint:Dictionary=happiness.ExportCityCheckpoint()
 check(checkpoint.configuration.goods==4.0,"ownership checkpoint drains queued configuration without a logical tick")
 check(int(happiness.BackgroundStatus().submitted)==0,"checkpoint capture never submits an extra happiness tick")
 var worker=Worker.new()
 worker.Initialize(Adapter.new(),{})
 worker.Suspend()
 check(worker.IsReady(),"worker boot completed")
 check(worker.Submit({"base_tick":0,"base_revision":0,"revision":0},2.0),"first logical step accepted")
 worker.Suspend()
 check(worker.IsComplete() and worker.GetPublishedTick()==0,"join never publishes completed step")
 worker.Shutdown()
 check(worker.has_method("Resume"),"stopped native worker supports resume without checkpoint reconstruction")
 if worker.has_method("Resume"):
  worker.Resume()
  check(worker.HasPending() and worker.IsComplete(),"resume preserves completed-unpublished slot")
  var first:Dictionary=worker.PublishBoundary()
  check(first.logical_tick==1 and first.calls==1 and first.boots==1,"resume does not rerun boot or step")
  check(worker.Submit({"base_tick":1,"base_revision":0,"revision":0},2.0),"next logical step accepted after resume")
  worker.Suspend()
  var second:Dictionary=worker.PublishBoundary()
  check(second.logical_tick==2 and second.calls==2 and second.boots==1,"private adapter state survives native thread restart")
  worker.Shutdown();worker.Shutdown()
 for failure in failures:push_error(str(failure))
 print("RESULT %d/%d coordinator lifecycle checks passed"%[checks-failures.size(),checks])
 quit(0 if failures.is_empty() else 1)
