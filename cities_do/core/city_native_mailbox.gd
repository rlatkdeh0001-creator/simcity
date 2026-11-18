extends RefCounted
## Main API is GDScript/native only, except Initialize/Shutdown/Resume.
## Submit transfers deep-owned delta; PublishBoundary transfers an immutable result.
## All shared slot/state transitions use one native mutex. No simulation queue.
var _mutex:=Mutex.new()
var _wake:=Semaphore.new()
var _changed:=Semaphore.new()
var _gate_wake:=Semaphore.new()
var _coordinator
var _owner:=0
var _ready:=false
var _pending:=false
var _complete:=false
var _stop:=false
var _closed:=false
var _fault:=""
var _input:Dictionary={}
var _result:Dictionary={}
var _published:Dictionary={}
var _retired:Dictionary={}
var _export:Dictionary={}
var _export_requested:=false
var _tick:=0
var _revision:=0
var _seconds:=0.0
var _submitted_revision:=0
var _contract_error:=""
var _worker_thread:=0
func GetWorkerThread()->int:return _worker_thread
static func _freeze(value:Variant):
 if value is Dictionary:
  for child:Variant in value.values():_freeze(child)
  value.make_read_only()
 elif value is Array:
  for child:Variant in value:_freeze(child)
  value.make_read_only()
func _require_owner()->bool:
 return OS.get_thread_caller_id()==_owner
func Initialize(adapter,owned_checkpoint:Dictionary):
 assert(_coordinator==null)
 _owner=OS.get_thread_caller_id()
 _coordinator=load("res://simulation/CitySimulationWorker.cs").new()
 _coordinator.InitializeNative(adapter,owned_checkpoint,self)
func AdoptBootViews(population_view,happiness_view):
 assert(_require_owner() and _tick==0 and not _pending)
 _published={"population_view":population_view,"happiness_view":happiness_view}
func IsReady()->bool:
 _mutex.lock();var value:=_ready and _fault.is_empty();_mutex.unlock();return value
func GetFault()->String:
 _mutex.lock();var value:=_fault;_mutex.unlock();return value
func GetContractError()->String:return _contract_error
func HasPending()->bool:
 _mutex.lock();var value:=_pending;_mutex.unlock();return value
func IsBusy()->bool:
 _mutex.lock();var value:=not _ready or (_pending and not _complete) or not _fault.is_empty();_mutex.unlock();return value
func IsComplete()->bool:
 _mutex.lock();var value:=_pending and _complete;_mutex.unlock();return value
func GetPublishedTick()->int:return _tick
func GetPublishedRevision()->int:return _revision
func Submit(owned_delta:Dictionary,seconds:float)->bool:
 if not _require_owner():return false
 _contract_error=""
 _mutex.lock()
 if not _ready or _pending or _stop or not _fault.is_empty():
  _mutex.unlock();return false
 if int(owned_delta.get("base_tick",-1))!=_tick or int(owned_delta.get("base_revision",-1))!=_revision:
  _contract_error="Delta is not based on the published boundary";_mutex.unlock();return false
 var financing_flush:bool=bool(owned_delta.get("financing_flush",false)) and int(owned_delta.get("revision",_revision))>_revision
 if not is_finite(seconds) or seconds<0 or (seconds==0 and owned_delta.get("loan_commands",[]).is_empty() and not financing_flush):
  _contract_error="seconds must be positive, or zero for a financing edit prefix";_mutex.unlock()
  return false
 _freeze(owned_delta)
 _input=owned_delta;_seconds=seconds;_submitted_revision=int(owned_delta.get("revision",_revision))
 _pending=true;_complete=false
 _mutex.unlock();_wake.post();return true
func PublishBoundary()->Dictionary:
 if not _require_owner():return {}
 _mutex.lock()
 if not _pending or not _complete or not _fault.is_empty():
  _mutex.unlock();return {}
 if int(_result.get("logical_tick",-1))!=_tick+1 or int(_result.get("revision",-1))!=_submitted_revision:
  _fault="Rejected stale/out-of-order native mailbox publication";_mutex.unlock();return {}
 # Previous publication remains strongly held until worker takes the NEXT command.
 _retired=_published;_published=_result;_result={}
 _tick=int(_published.logical_tick);_revision=int(_published.revision)
 _pending=false;_complete=false
 var value:=_published
 _mutex.unlock();return value
func SetValidationGate(closed:bool):
 assert(_require_owner())
 _mutex.lock();var was:=_closed;_closed=closed;_mutex.unlock()
 if was and not closed:_gate_wake.post()
func Suspend():
 assert(_require_owner())
 SetValidationGate(false)
 while true:
  _mutex.lock();var done:=(_ready and (not _pending or _complete)) or not _fault.is_empty();_mutex.unlock()
  if done:return
  _changed.wait()
func Shutdown():
 assert(_require_owner())
 Suspend()
 _mutex.lock();var was:=_stop;_stop=true;_mutex.unlock()
 if not was:_wake.post()
 _coordinator.JoinNative()
func Resume():
 assert(_require_owner())
 if not GetFault().is_empty():return
 _mutex.lock();var was:=_stop;_stop=false;_mutex.unlock()
 if was:_coordinator.ResumeNative()
func ExportCheckpoint()->Dictionary:
 # Export uses the existing native worker-owned request/join path, not stale CLR views.
 return ExportValidationState().get("checkpoint",{}).duplicate(true)
func ExportValidationState()->Dictionary:
 assert(_require_owner())
 Suspend()
 _mutex.lock()
 if _pending or _stop or not _fault.is_empty():_mutex.unlock();return {}
 _export_requested=true;_mutex.unlock();_wake.post()
 while true:
  _mutex.lock();var done:=not _export_requested or not _fault.is_empty();_mutex.unlock()
  if done:break
  _changed.wait()
 _mutex.lock();var value:=_export;_export={};_mutex.unlock();return value
# Following entry points are worker-only. Never invoke on a routine main path.
func native_ready():
 _worker_thread=OS.get_thread_caller_id()
 _mutex.lock();_ready=true;_mutex.unlock();_changed.post()
func native_take()->Dictionary:
 _wake.wait()
 while true:
  _mutex.lock();var closed:=_closed and not _stop;_mutex.unlock()
  if not closed:break
  _gate_wake.wait()
 _mutex.lock()
 # Keep retirement outside the mutex and off main, including final RefCounted releases.
 var retired:=_retired;_retired={}
 var command:Dictionary={}
 if _stop:command={"kind":"stop"}
 elif _export_requested:command={"kind":"export"}
 elif _pending and not _complete:
  command={"kind":"step","delta":_input,"seconds":_seconds,"tick":_tick+1};_input={}
 _mutex.unlock()
 retired={}
 return command
func native_complete(result:Dictionary):
 if result.has("scalars"):
  result.population_view=load("res://core/native_population_view.gd").new(result.population_view,result.scalars)
  result.happiness_view=load("res://core/native_happiness_view.gd").new(result.happiness_view,result.scalars.happiness_average)
 _freeze(result)
 _mutex.lock();_result=result;_complete=true;_mutex.unlock();_changed.post()
func native_export(result:Dictionary):
 _mutex.lock();_export=result;_export_requested=false;_mutex.unlock();_changed.post()
func native_fault(message:String):
 _mutex.lock();_fault=message;_mutex.unlock();_changed.post()
