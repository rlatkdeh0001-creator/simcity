using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    private readonly record struct ConfigurationSnapshot(double Goods,double Commute,double Garbage,double Tax,int FireMultiplier);
    private sealed record BuildingSnapshot(long Id,long Road,int Level,string Zone,Vector2 Position,
        ImmutableArray<Vector2> Polygon,bool Power,bool Water,bool Noise,HappinessPeople Fixture);
    private sealed record FacilitySnapshot(long Id,long Road,string Kind,int School,double Capacity,
        Vector2 Position,ImmutableArray<Vector2> Polygon);
    private sealed record WorldSnapshot(ImmutableArray<BuildingSnapshot> Buildings,
        ImmutableArray<FacilitySnapshot> Facilities,ImmutableArray<double> Roads);
    private abstract record BackgroundCommand;
    private sealed record ConfigureCommand(ConfigurationSnapshot Configuration):BackgroundCommand;
    private sealed record WorldCommand(WorldSnapshot World):BackgroundCommand;
    private sealed record AcknowledgeCommand(long Id,bool Success,int Level):BackgroundCommand;
    private sealed record PublishedState(bool Initialized,double Actual,double Target,double Housing,double? Since,
        ImmutableDictionary<string,double> Factors);
    private sealed record PublishedPreviewState(double Target,ImmutableDictionary<string,double> Factors);
    private sealed record PublishedBackground(ImmutableDictionary<long,PublishedState> States,
        ImmutableDictionary<long,PublishedPreviewState> Previews,double Elapsed,Variant CityHappiness);
    // Result's native containers are detached from both worker fields and immutable buffers.
    // They transfer to the main thread only after the Task has completed.
    private sealed record BackgroundCompletion(D Result,PublishedBackground Published);

    private bool _backgroundEnabled;
    private int _backgroundMainThread,_backgroundWorkerThread;
    // ExecutionContext flows through the existing nested Parallel.For score preparation.
    private readonly AsyncLocal<bool> _backgroundWorkerContext=new();
    private bool IsBackgroundWorker=>_backgroundWorkerContext.Value;
    private ConfigurationSnapshot _mainConfiguration;
    private readonly List<BackgroundCommand> _backgroundCommands=new();
    private Task<BackgroundCompletion>? _pendingBackground;
    private readonly ManualResetEventSlim _backgroundGate=new(true);
    private long _backgroundSubmitted,_backgroundPublished,_backgroundSkipped;
    private IReadOnlyDictionary<long,HappinessPeople>? _submittedGroups;
    private readonly HashSet<long> _backgroundDirtyStates=new();
    private readonly Dictionary<long,D> _backgroundPreviewSources=new();
    private PublishedBackground _publishedBackground=new(ImmutableDictionary<long,PublishedState>.Empty,
        ImmutableDictionary<long,PublishedPreviewState>.Empty,0,default);
    private PublishedBackground _workerBackground=new(ImmutableDictionary<long,PublishedState>.Empty,
        ImmutableDictionary<long,PublishedPreviewState>.Empty,0,default);

    private void RequireBackgroundOwner()
    {
        if(_backgroundEnabled&&!IsBackgroundWorker&&System.Environment.CurrentManagedThreadId!=_backgroundMainThread)
            throw new InvalidOperationException("Background happiness API must be called on its enabling thread");
    }
    private void RequireBackgroundMain()
    {
        RequireBackgroundOwner();
        if(IsBackgroundWorker)throw new InvalidOperationException("Background control is main-thread-only");
    }
    public void EnableBackground()
    {
        RequireBackgroundMain();
        if(_backgroundEnabled)return;
        _backgroundMainThread=System.Environment.CurrentManagedThreadId;
        _mainConfiguration=new(_goods,_commute,_garbage,_tax,_fireMultiplier);
        // Initial construction is outside the running job, and happens only once.
        RefreshGroups();
        foreach(long id in _states.Keys)_backgroundDirtyStates.Add(id);
        _workerBackground=CapturePublishedBackground();
        _publishedBackground=_workerBackground;
        _backgroundEnabled=true;
    }
    public bool IsBackgroundEnabled()=>_backgroundEnabled;
    public bool IsBackgroundBusy()
    {RequireBackgroundMain();return _pendingBackground!=null&&!_pendingBackground.IsCompleted;}
    public void RecordSkippedBackgroundCycle()
    {RequireBackgroundMain();_backgroundSkipped++;}
    public D BackgroundStatus()
    {
        RequireBackgroundMain();
        return new D {["submitted"]=_backgroundSubmitted,["published"]=_backgroundPublished,["skipped"]=_backgroundSkipped,
            ["main_thread"]=_backgroundMainThread,["worker_thread"]=Volatile.Read(ref _backgroundWorkerThread)};
    }
    public bool SubmitBackgroundTick(double seconds,long[] supplies)
    {
        RequireBackgroundMain();
        if(!_backgroundEnabled)throw new InvalidOperationException("Call EnableBackground before submitting happiness work");
        // A completed but unpublished job also owns the slot: never overtake a boundary.
        if(_pendingBackground!=null){_backgroundSkipped++;return false;}
        var commands=_backgroundCommands.ToImmutableArray();
        var groups=_population?.HappinessGroupSnapshot();
        var ownedSupplies=(long[])supplies.Clone();
        long logicalTick=_backgroundSubmitted+1;
        var job=Task.Run(()=>RunBackgroundTick(seconds,ownedSupplies,groups,commands,logicalTick));
        _pendingBackground=job;
        _backgroundCommands.Clear();_backgroundSubmitted=logicalTick;
        return true;
    }
    public D PublishBackgroundTick()
    {
        RequireBackgroundMain();
        var job=_pendingBackground;
        if(job==null||!job.IsCompleted)return new D();
        // Faults propagate and leave the pending slot intact, rather than pretending success.
        var completed=job.GetAwaiter().GetResult();
        _publishedBackground=completed.Published;
        _pendingBackground=null;_backgroundPublished++;
        return completed.Result;
    }
    public void SuspendBackground()
    {
        RequireBackgroundMain();
        // Joining must not deadlock a validation gate, publish, reset, or consume the slot.
        _backgroundGate.Set();
        _pendingBackground?.GetAwaiter().GetResult();
    }
    public void SetBackgroundGateForValidation(bool closed)
    {RequireBackgroundMain();if(closed)_backgroundGate.Reset();else _backgroundGate.Set();}

    private BackgroundCompletion RunBackgroundTick(double seconds,long[] supplies,IReadOnlyDictionary<long,HappinessPeople>? groups,
        ImmutableArray<BackgroundCommand> commands,long logicalTick)
    {
        _backgroundWorkerContext.Value=true;
        Volatile.Write(ref _backgroundWorkerThread,System.Environment.CurrentManagedThreadId);
        try
        {
            _backgroundGate.Wait();
            // These references and commands were frozen before scheduling, not after the gate.
            _submittedGroups=groups;
            // Acknowledgements preceding a world command observe the previous logical
            // tick's groups, as the synchronous API does; Tick refreshes the next groups.
            foreach(var command in commands)
            {
                switch(command)
                {
                    case ConfigureCommand config:ApplyConfiguration(config.Configuration);break;
                    case WorldCommand world:
                        ApplyWorld(world.World);
                        foreach(long id in _states.Keys)_backgroundDirtyStates.Add(id);
                        break;
                    case AcknowledgeCommand ack:
                        Acknowledge(ack.Id,ack.Success,ack.Level);_backgroundDirtyStates.Add(ack.Id);break;
                }
            }
            var result=Tick(seconds,supplies);
            foreach(var key in result["updates"].AsGodotDictionary().Keys)_backgroundDirtyStates.Add(key.AsInt64());
            // Tick already detaches factors through Inspect; duplication guarantees full ownership
            // even if another result field gains a container in the synchronous implementation.
            result=result.Duplicate(true);result["logical_tick"]=logicalTick;
            var published=CapturePublishedBackground();
            _workerBackground=published;
            return new BackgroundCompletion(result,published);
        }
        finally {_submittedGroups=null;_backgroundWorkerContext.Value=false;}
    }
    private static ImmutableDictionary<string,double> FreezeFactors(D factors)
    {
        var result=ImmutableDictionary.CreateBuilder<string,double>();
        foreach(var key in factors.Keys)result[key.AsString()]=factors[key].AsDouble();
        return result.ToImmutable();
    }
    private PublishedBackground CapturePublishedBackground()
    {
        var states=_workerBackground.States.ToBuilder();
        // World commands may remove states; no main-thread map walk is needed at publication.
        foreach(long id in _workerBackground.States.Keys)
            if(!_states.ContainsKey(id))states.Remove(id);
        foreach(long id in _backgroundDirtyStates)
            if(_states.TryGetValue(id,out var s))states[id]=new(s.Initialized,s.Actual,s.Target,s.Housing,s.Since,FreezeFactors(s.Factors));
        _backgroundDirtyStates.Clear();
        var previews=_workerBackground.Previews.ToBuilder();
        foreach(long id in _workerBackground.Previews.Keys)
            if(!_buildings.ContainsKey(id)){previews.Remove(id);_backgroundPreviewSources.Remove(id);}
        // Preview is a calculation rather than the last bucket target. Capture its current
        // value on the worker, so main-thread queries never touch world/cache/group fields.
        // Cached result identity avoids copying unchanged factor maps into persistent roots.
        foreach(var building in _buildings.Values)
        {
            var preview=Calculate(building);
            if(_backgroundPreviewSources.TryGetValue(building.Id,out var old)&&ReferenceEquals(old,preview))continue;
            previews[building.Id]=new(preview["target"].AsDouble(),FreezeFactors(preview["factors"].AsGodotDictionary()));
            _backgroundPreviewSources[building.Id]=preview;
        }
        return new(states.ToImmutable(),previews.ToImmutable(),_elapsed,_cityHappiness);
    }
    private static D ThawFactors(ImmutableDictionary<string,double> factors)
    {var result=new D();foreach(var pair in factors)result[pair.Key]=pair.Value;return result;}
    private D PublishedInspect(long id)
    {
        var published=_publishedBackground;var s=published.States[id];
        return new D {["initialized"]=s.Initialized,["actual"]=s.Actual,["target"]=s.Target,["factors"]=ThawFactors(s.Factors),
            ["housing"]=s.Housing,["held_seconds"]=s.Since.HasValue?Math.Max(0,published.Elapsed-s.Since.Value):0};
    }
    private D PublishedPreview(long id)
    {
        var preview=_publishedBackground.Previews[id];
        return new D {["target"]=preview.Target,["factors"]=ThawFactors(preview.Factors)};
    }
    private static WorldSnapshot CaptureWorld(A buildings,A facilities,double[] roads)
    {
        var ownedBuildings=ImmutableArray.CreateBuilder<BuildingSnapshot>(buildings.Count);
        foreach(var value in buildings)
        {
            var d=value.AsGodotDictionary();var students=ImmutableArray.CreateBuilder<int>(4);
            for(int i=0;i<4;i++)students.Add(d.TryGetValue("students",out var values)?(int)values.AsGodotArray()[i].AsInt64():0);
            var fixture=new HappinessPeople((int)Long(d,"occupants"),(int)Long(d,"eligible"),(int)Long(d,"employed"),students.MoveToImmutable());
            ownedBuildings.Add(new(Long(d,"id"),Long(d,"road"),(int)Long(d,"level"),d["zone"].AsString(),d["position"].AsVector2(),
                ImmutableArray.CreateRange(Polygon(d)),Flag(d,"power"),Flag(d,"water"),Flag(d,"noise"),fixture));
        }
        var ownedFacilities=ImmutableArray.CreateBuilder<FacilitySnapshot>(facilities.Count);
        foreach(var value in facilities)
        {
            var d=value.AsGodotDictionary();
            ownedFacilities.Add(new(Long(d,"id"),Long(d,"road"),d["kind"].AsString(),(int)Long(d,"school_stage"),Number(d,"capacity"),
                d["position"].AsVector2(),ImmutableArray.CreateRange(Polygon(d))));
        }
        return new(ownedBuildings.MoveToImmutable(),ownedFacilities.MoveToImmutable(),ImmutableArray.CreateRange(roads));
    }
}
