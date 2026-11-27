using System;
using System.Runtime.ExceptionServices;
using System.Threading;
using Godot;
using D=Godot.Collections.Dictionary;
// Thread is excluded from Godot's managed bindings; use the native ClassDB object.

// A Godot.Thread is mandatory: CLR Task threads do not register GDScript language state.
// One outstanding slot includes completed-but-unpublished work. No queued simulation ticks.
public partial class CitySimulationWorker:RefCounted
{
    private readonly object _gate=new();
    private readonly SemaphoreSlim _wake=new(0,1);
    private readonly ManualResetEventSlim _validationGate=new(true);
    private GodotObject? _thread;
    private GodotObject? _adapter;
    private D? _checkpoint,_input,_completed,_published,_retired;
    private ExceptionDispatchInfo? _fault;
    private bool _ready,_pending,_complete,_stop,_exportRequested;
    private D? _export;
    private double _seconds;
    private long _submitted,_publishedTick,_revision;
    private int _ownerThread,_workerThread;
    private void RequireOwner(){if(_ownerThread!=System.Environment.CurrentManagedThreadId)throw new InvalidOperationException("Coordinator controls are owner-thread only");}
    private void Rethrow(){_fault?.Throw();}
    // adapter must be a NEW res://core/city_simulation_worker.gd instance, not a live CityModel.
    // Initialization snapshot already owns its deep-copied data. Start is outside frame timing.
    public void Initialize(GodotObject adapter,D ownedCheckpoint)
    {
        if(_thread!=null)throw new InvalidOperationException("Already initialized");
        _ownerThread=System.Environment.CurrentManagedThreadId;_adapter=adapter;_checkpoint=ownedCheckpoint;
        _thread=ClassDB.Instantiate("Thread").AsGodotObject();var error=(Error)_thread.Call("start",Callable.From(RunLoop)).AsInt64();
        if(error!=Error.Ok)throw new InvalidOperationException($"Godot.Thread.Start failed: {error}");
    }
    public bool IsReady(){RequireOwner();lock(_gate){Rethrow();return _ready;}}
    public bool HasPending(){RequireOwner();lock(_gate){Rethrow();return _pending;}}
    public bool IsBusy(){RequireOwner();lock(_gate){Rethrow();return !_ready||(_pending&&!_complete);}}
    public bool IsComplete(){RequireOwner();lock(_gate){Rethrow();return _pending&&_complete;}}
    public string GetFault(){RequireOwner();lock(_gate){return _fault?.SourceException.ToString()??"";}}
    public long GetPublishedTick(){RequireOwner();return _publishedTick;}
    public long GetPublishedRevision(){RequireOwner();return _revision;}
    public int GetWorkerThread()=>Volatile.Read(ref _workerThread);
    // Transfer ownership: after true, caller may neither mutate nor recycle any input child.
    // Rejection never consumes input, advances IDs, or queues a second step.
    public bool Submit(D ownedDelta,double seconds)
    {
        RequireOwner();lock(_gate)
        {
            Rethrow();if(!_ready||_pending||_stop)return false;
            if(ownedDelta["base_tick"].AsInt64()!=_publishedTick||ownedDelta["base_revision"].AsInt64()!=_revision)
                throw new InvalidOperationException("Delta is not based on the published boundary");
            if(!double.IsFinite(seconds)||seconds<=0)throw new ArgumentOutOfRangeException(nameof(seconds));
            _input=ownedDelta;_seconds=seconds;_submitted=_publishedTick+1;
            _pending=true;_complete=false;_wake.Release();return true;
        }
    }
    // Boundary-only caller. Does NOT join or wait; completion is not publication.
    // Return {} when unavailable. Keep result/view handles immutable on the main side.
    public D PublishBoundary()
    {
        RequireOwner();lock(_gate)
        {
            Rethrow();if(!_pending||!_complete)return new D();
            _retired=_published;_published=_completed;_completed=null;
            _publishedTick=_published!["logical_tick"].AsInt64();_revision=_published["revision"].AsInt64();
            _pending=false;_complete=false;return _published;
        }
    }
    public void SetValidationGate(bool closed){RequireOwner();if(closed)_validationGate.Reset();else _validationGate.Set();}
    // Tests/scene exit only. Does not publish/consume the pending slot.
    public void Suspend()
    {
        RequireOwner();_validationGate.Set();
        lock(_gate){while(!_ready&&_fault==null)Monitor.Wait(_gate);while(_pending&&!_complete&&_fault==null)Monitor.Wait(_gate);Rethrow();}
    }
    // Explicit idle compatibility export. Blocking and O(people); forbidden in normal frames.
    public D ExportValidationState()
    {
        RequireOwner();Suspend();lock(_gate)
        {
            if(_pending)throw new InvalidOperationException("Publish pending boundary before validation export");
            _exportRequested=true;_wake.Release();while(_exportRequested&&_fault==null)Monitor.Wait(_gate);Rethrow();
            var result=_export!;_export=null;return result;
        }
    }
    public void Shutdown()
    {
        RequireOwner();_validationGate.Set();lock(_gate)
        {
            // Scene transitions join outstanding work, but never publish it.
            while(!_ready&&_fault==null)Monitor.Wait(_gate);
            while(_pending&&!_complete&&_fault==null)Monitor.Wait(_gate);
            _stop=true;if(_wake.CurrentCount==0)_wake.Release();
        }
        if(_thread!=null&&_thread.Call("is_started").AsBool())_thread.Call("wait_to_finish");
        lock(_gate){Rethrow();}
    }
    // Retained construction sessions keep the private model and pending slot.
    // Restart the native language-registered thread; do not clone stale main facades.
    public void Resume()
    {
        RequireOwner();lock(_gate){Rethrow();if(!_stop)return;_stop=false;}
        if(_thread==null)throw new InvalidOperationException("Worker was not initialized");
        var error=(Error)_thread.Call("start",Callable.From(RunLoop)).AsInt64();
        if(error!=Error.Ok)throw new InvalidOperationException($"Godot.Thread resume failed: {error}");
    }
    private static void Check(D result){if(!result.TryGetValue("ok",out var ok)||!ok.AsBool())throw new InvalidOperationException(result.TryGetValue("error",out var e)?e.AsString():"Worker adapter did not return ok");}
    private void RunLoop()
    {
        Volatile.Write(ref _workerThread,System.Environment.CurrentManagedThreadId);
        try
        {
            var adapter=_adapter??throw new InvalidOperationException("Missing worker adapter");
            if(!_ready)
            {
                var boot=adapter.Call("boot",_checkpoint!).AsGodotDictionary();Check(boot);_checkpoint=null;
            }
            lock(_gate){_ready=true;Monitor.PulseAll(_gate);}
            while(true)
            {
                _wake.Wait();_validationGate.Wait();D? input;double seconds;long tick;bool export;
                lock(_gate){if(_stop)break;input=_input;_input=null;seconds=_seconds;tick=_submitted;export=_exportRequested;}
                // Retire old native result ownership on the worker, not during publication.
                _retired=null;
                if(export)
                {
                    var state=adapter.Call("export_validation").AsGodotDictionary();
                    lock(_gate){_export=state;_exportRequested=false;Monitor.PulseAll(_gate);}continue;
                }
                if(input==null)continue;
                var result=adapter.Call("run_step",input,seconds,tick).AsGodotDictionary();Check(result);
                lock(_gate){_completed=result;_complete=true;Monitor.PulseAll(_gate);}
            }
        }
        catch(Exception exception){lock(_gate){_fault=ExceptionDispatchInfo.Capture(exception);Monitor.PulseAll(_gate);}}
        finally{_checkpoint=null;_input=null;_retired=null;}
    }
}
