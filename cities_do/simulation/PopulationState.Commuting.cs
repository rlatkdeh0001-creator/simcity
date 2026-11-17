using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    private readonly record struct ExternalJob(string Neighbor,int Stage);
    private readonly Dictionary<long,ExternalJob> _laborOutbound=new();
    private readonly Dictionary<long,int[]> _laborInbound=new();
    private D? _pendingLaborPlan;
    // A changed home is a new job search, even within the same road component.
    // Release immediately so a sync/rehousing boundary cannot expose stale staffing.
    private void ReleaseLaborHomeJobs(Household household)
    {
        if(!_laborEnabled)return;
        if(_families.TryGetValue(household.Id,out var family))foreach(var p in family)
        {
            if(_works.TryGetValue(p.Work,out var work)&&p.Stage>=0&&p.Stage<5&&work.Filled[p.Stage]>0)work.Filled[p.Stage]--;
            p.Work=-1;p.Stage=-1;_laborOutbound.Remove(p.Id);
            if(_pendingLaborPlan!=null)
            {
                var outbound=_pendingLaborPlan["outbound"].AsGodotArray();
                for(int i=outbound.Count-1;i>=0;i--)if(Id(outbound[i].AsGodotDictionary(),"person_id")==p.Id)outbound.RemoveAt(i);
            }
            UpdateHappiness(p);
        }
        _laborCursors.Clear();InvalidateManagedSnapshots();
    }
    private bool LaborExternal(Person p)=>_laborEnabled&&_laborOutbound.ContainsKey(p.Id);
    private int InboundReserved(long work,int stage)=>_laborEnabled&&_laborInbound.TryGetValue(work,out var slots)?slots[stage]:0;
    private int[] FreeLaborSlots(Work work)=>Enumerable.Range(0,5).Select(stage=>Math.Max(0,work.Slots[stage]-work.Filled[stage]-InboundReserved(work.Id,stage))).ToArray();

    /// <summary>Worker-only owned copies. Daily neighbor planner must preserve or
    /// replace existing assignments explicitly; no connectivity/vehicle simulation
    /// is claimed here. Parent must validate connected road/rail/metro corridors.</summary>
    public D GetLaborCommutingContext()
    {
        RequireLaborWorld();ReconcileLaborCommuters();
        var unemployed=new A();var workplaces=new A();var external=new A();
        foreach(var p in _people.OrderBy(p=>p.Id))
        {
            if(p.Age<_workingAge||p.Work!=-1)continue;
            var person=new D{["person_id"]=p.Id,["home_id"]=_laborHouseholdHomes.GetValueOrDefault(p.Household,-1),["education"]=p.Education};
            if(_laborOutbound.TryGetValue(p.Id,out var job)){person["neighbor_id"]=job.Neighbor;person["stage"]=job.Stage;external.Add(person);}
            else unemployed.Add(person);
        }
        foreach(var w in _works.Values.OrderBy(w=>w.Id))workplaces.Add(new D{["workplace_id"]=w.Id,["free_slots"]=ToArray(FreeLaborSlots(w))});
        return new D{["unemployed"]=unemployed,["workplaces"]=workplaces,["outbound"]=external,["inbound"]=ExportInbound()};
    }
    private A ExportInbound()
    {
        var result=new A();foreach(var pair in _laborInbound.OrderBy(p=>p.Key))for(int stage=0;stage<5;stage++)if(pair.Value[stage]>0)result.Add(new D{["workplace_id"]=pair.Key,["stage"]=stage,["count"]=pair.Value[stage]});return result;
    }
    private A ExportOutbound()
    {
        var result=new A();foreach(var pair in _laborOutbound.OrderBy(p=>p.Key))result.Add(new D{["person_id"]=pair.Key,["neighbor_id"]=pair.Value.Neighbor,["stage"]=pair.Value.Stage});return result;
    }
    // Whole-plan replacement, deterministic independent of input ordering. Capacity
    // shortages clamp inbound, never displace any valid local incumbent. Outbound
    // may only take eligible locally unemployed residents (education +/-1).
    public D ApplyLaborCommutingPlan(A inbound,A outbound)
    {
        if(!_laborEnabled)throw new InvalidOperationException("Enable labor policy before applying a commuting plan");RequireLaborWorld();
        var requestedInbound=new Dictionary<long,int[]>();var requestedOutbound=new Dictionary<long,ExternalJob>();
        foreach(var value in inbound)
        {
            var d=value.AsGodotDictionary();long work=Id(d,"workplace_id");int stage=Int(d,"stage"),count=Int(d,"count");
            if(stage<0||stage>4||count<0)throw new ArgumentException("Invalid inbound stage/count");
            if(!requestedInbound.TryGetValue(work,out var slots))requestedInbound[work]=slots=new int[5];slots[stage]=checked(slots[stage]+count);
        }
        foreach(var value in outbound)
        {
            var d=value.AsGodotDictionary();long person=Id(d,"person_id");int stage=Int(d,"stage");string neighbor=Str(d,"neighbor_id");
            if(stage<0||stage>4||string.IsNullOrEmpty(neighbor))throw new ArgumentException("Invalid external job");
            if(!requestedOutbound.TryAdd(person,new(neighbor,stage)))throw new ArgumentException("Duplicate outbound person_id");
        }
        var people=_people.ToDictionary(p=>p.Id);int rejectedOutbound=0,rejectedInbound=0;
        var acceptedOutbound=new Dictionary<long,ExternalJob>();var acceptedInbound=new Dictionary<long,int[]>();
        foreach(var pair in requestedOutbound.OrderBy(p=>p.Key))
        {
            if(people.TryGetValue(pair.Key,out var p)&&p.Work==-1&&p.Age>=_workingAge&&Math.Abs(p.Education-pair.Value.Stage)<=1&&_laborHouseholdHomes.GetValueOrDefault(p.Household,-1)>=0)acceptedOutbound.Add(pair.Key,pair.Value);
            else rejectedOutbound++;
        }
        foreach(var pair in requestedInbound.OrderBy(p=>p.Key))
        {
            var accepted=new int[5];_works.TryGetValue(pair.Key,out var work);
            for(int stage=0;stage<5;stage++){accepted[stage]=work==null?0:Math.Min(pair.Value[stage],Math.Max(0,work.Slots[stage]-work.Filled[stage]));rejectedInbound+=pair.Value[stage]-accepted[stage];}
            if(accepted.Any(n=>n>0))acceptedInbound[pair.Key]=accepted;
        }
        _pendingLaborPlan=null;
        _laborOutbound.Clear();foreach(var pair in acceptedOutbound)_laborOutbound.Add(pair.Key,pair.Value);
        _laborInbound.Clear();foreach(var pair in acceptedInbound)_laborInbound.Add(pair.Key,pair.Value);
        // Home happiness memberships include external employment; no fake work ID
        // can accidentally attach an external employee to a local building.
        foreach(var p in _people)UpdateHappiness(p);
        _laborCursors.Clear();InvalidateManagedSnapshots();
        return new D{["inbound"]=_laborInbound.Values.Sum(a=>a.Sum()),["outbound"]=_laborOutbound.Count,["rejected_inbound"]=rejectedInbound,["rejected_outbound"]=rejectedOutbound};
    }
    private void ReconcileLaborCommuters()
    {
        if(!_laborEnabled)return;
        var people=_laborOutbound.Count==0?null:_people.ToDictionary(p=>p.Id);
        foreach(long id in _laborOutbound.Keys.ToArray())
        {
            var job=_laborOutbound[id];
            if(!people!.TryGetValue(id,out var p)||p.Work!=-1||p.Age<_workingAge||Math.Abs(p.Education-job.Stage)>1||_laborHouseholdHomes.GetValueOrDefault(p.Household,-1)<0)
            {_laborOutbound.Remove(id);if(p!=null)UpdateHappiness(p);}
        }
        foreach(long id in _laborInbound.Keys.ToArray())
        {
            if(!_works.TryGetValue(id,out var w)){_laborInbound.Remove(id);continue;}
            var slots=_laborInbound[id];for(int stage=0;stage<5;stage++)slots[stage]=Math.Min(slots[stage],Math.Max(0,w.Slots[stage]-w.Filled[stage]));
            if(!slots.Any(n=>n>0))_laborInbound.Remove(id);
        }
        _laborCursors.Clear();InvalidateManagedSnapshots();
    }
    // Export with the city checkpoint. Import AFTER ImportState; it intentionally
    // does not persist topology/candidate caches. Prepare world, sync, then MatchJobs
    // installs the pending plan between incumbent validation and new local matching.
    public D ExportLaborPolicyState()
    {
        return new D{["enabled"]=_laborEnabled,["jobs_per_worker"]=(double)_jobsPerWorker,["commercial_share"]=(double)_commercialShare,["max_cached_home_routes"]=_laborCacheLimit,
            ["inbound"]=_pendingLaborPlan==null?ExportInbound():_pendingLaborPlan["inbound"].AsGodotArray().Duplicate(true),
            ["outbound"]=_pendingLaborPlan==null?ExportOutbound():_pendingLaborPlan["outbound"].AsGodotArray().Duplicate(true)};
    }
    public void ImportLaborPolicyState(D state)
    {
        ConfigureLaborPolicy(state);_laborInbound.Clear();_laborOutbound.Clear();
        _pendingLaborPlan=state.Duplicate(true);_laborWorldPrepared=false;InvalidateHappiness();InvalidateManagedSnapshots();
    }
    private void PrepareLaborCommutersForMatching()
    {
        if(!_laborEnabled)return;
        if(_pendingLaborPlan!=null)
        {
            var pending=_pendingLaborPlan;
            ApplyLaborCommutingPlan(pending["inbound"].AsGodotArray(),pending["outbound"].AsGodotArray());_pendingLaborPlan=null;
        }
        else ReconcileLaborCommuters();
    }
}
