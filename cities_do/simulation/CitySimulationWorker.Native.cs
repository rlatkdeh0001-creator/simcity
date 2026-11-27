using System;
using Godot;
using D=Godot.Collections.Dictionary;

// Opt-in native transport; the legacy coordinator implementation is unchanged.
public partial class CitySimulationWorker
{
    private ulong _nativeMailboxId;
    private bool _nativeBooted;
    public void InitializeNative(GodotObject adapter,D ownedCheckpoint,GodotObject mailbox)
    {
        if(_thread!=null)throw new InvalidOperationException("Already initialized");
        _ownerThread=System.Environment.CurrentManagedThreadId;
        _adapter=adapter;_checkpoint=ownedCheckpoint;_nativeMailboxId=mailbox.GetInstanceId();
        _thread=ClassDB.Instantiate("Thread").AsGodotObject();
        StartNative();
    }
    private void StartNative()
    {
        var error=(Error)_thread!.Call("start",Callable.From(NativeRunLoop)).AsInt64();
        if(error!=Error.Ok)throw new InvalidOperationException($"Godot.Thread.Start failed: {error}");
    }
    public void JoinNative()
    {
        RequireOwner();
        if(_thread!=null&&_thread.Call("is_started").AsBool())_thread.Call("wait_to_finish");
    }
    public void ResumeNative(){RequireOwner();StartNative();}
    private static D ScalarEnvelope(D result)
    {
        var p=(PopulationReadView)result["population_view"].AsGodotObject();
        var h=(HappinessReadView)result["happiness_view"].AsGodotObject();
        using var stats=p.Stats();stats.MakeReadOnly();using var demand=p.Demand();demand.MakeReadOnly();
        var envelope=new D {
            ["stats"]=stats,["demand"]=demand,["tax_status"]=p.GetTaxStatus(),
            ["next_person"]=p.GetNextPerson(),["next_household"]=p.GetNextHousehold(),
            ["elapsed_days"]=p.GetElapsedDays(),["birth_day"]=p.GetBirthDay(),
            ["rng_seed"]=p.GetRngSeed(),["rng_state"]=p.GetRngState(),
            ["happiness_average"]=h.CityHappiness()
        };
        envelope.MakeReadOnly();return envelope;
    }
    private void NativeRunLoop()
    {
        System.Threading.Volatile.Write(ref _workerThread,System.Environment.CurrentManagedThreadId);
        var mailbox=GodotObject.InstanceFromId(_nativeMailboxId)??throw new InvalidOperationException("Mailbox owner released before joining worker");
        try
        {
            var adapter=_adapter??throw new InvalidOperationException("Missing adapter");
            if(!_nativeBooted)
            {
                using var boot=adapter.Call("boot",_checkpoint!).AsGodotDictionary();Check(boot);
                _checkpoint=null;_nativeBooted=true;
            }
            mailbox.Call("native_ready");
            while(true)
            {
                using var command=mailbox.Call("native_take").AsGodotDictionary();
                var kind=command.TryGetValue("kind",out var v)?v.AsString():"";
                if(kind=="stop")break;
                if(kind=="export")
                {
                    mailbox.Call("native_export",adapter.Call("export_validation"));continue;
                }
                if(kind!="step")continue;
                using var result=adapter.Call("run_step",command["delta"],command["seconds"],command["tick"]).AsGodotDictionary();
                Check(result);
                if(result.ContainsKey("population_view")&&result.ContainsKey("happiness_view"))
                {
                    using var envelope=ScalarEnvelope(result);result["scalars"]=envelope;
                }
                mailbox.Call("native_complete",result);
            }
        }
        catch(Exception ex){mailbox.Call("native_fault",ex.ToString());}
        finally{_checkpoint=null;}
    }
}
