using System;
using System.Collections;
using System.Reflection;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class LaborIntegrationProbe : RefCounted
{
    private int _checks; private readonly A _failures=new();
    private void Check(bool ok,string label){_checks++;if(!ok)_failures.Add(label);}
    private static D B(long id,string zone,float x)=>new(){["id"]=id,["zone"]=zone,["position"]=new Vector2(x,0),["front_road_id"]=10};
    private static A World()=>new(){B(1,"residential",0),B(4,"residential",9),B(2,"commercial",1),B(3,"industrial",10)};
    private static A Roads()=>new(){new D{["parcel_id"]=10,["kind"]="local",["points"]=new Vector2[]{new(0,0),new(10,0)}}};
    private static readonly long[] Packed={1,0,2,1,4,0,2,1,2,1,2,1,3,2,2,1};
    private static PopulationState New(bool enabled=true)
    {
        var p=new PopulationState();p.Initialize(51);
        var c=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        c["birth_probability_per_household_day"]=0.0;c["commercial_jobs"]=new A{0,1,0,0,0};c["industrial_jobs"]=new A{0,1,0,0,0};p.Configure(c);
        p.ConfigureLaborPolicy(new D{["enabled"]=enabled});
        p.ImportState(new A{new D{["id"]=1,["household_id"]=1,["education"]=1,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=-1,["job_stage"]=-1}},new A{new D{["id"]=1,["home_id"]=1}},new D());
        p.PrepareLaborWorld(World(),Roads());p.EnableGeometryTransport(Packed);p.SyncManaged();return p;
    }
    private static long Job(PopulationState p)=>p.ExportState()["people"].AsGodotArray()[0].AsGodotDictionary()["workplace_id"].AsInt64();
    // Exercise the actual private move primitive without adding a production fixture API.
    private static void Move(PopulationState p,long home)
    {
        var homes=(IList)typeof(PopulationState).GetField("_households",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(p)!;
        typeof(PopulationState).GetMethod("Move",BindingFlags.NonPublic|BindingFlags.Instance)!.Invoke(p,new object[]{homes[0]!,home});
    }
    private void MoveTests()
    {
        using var p=New();p.MatchJobs();p.HappinessGroups();Check(Job(p)==2,"original home chooses nearest eligible local job");
        Move(p,1);Check(Job(p)==2&&p.WorkplaceInfo(2)["filled"].AsGodotArray()[1].AsInt64()==1,"same-home no-op does not release incumbent");
        var closer=World();closer.Add(B(5,"commercial",0));p.PrepareLaborWorld(closer,Roads());p.RecordBuilding(5,1,2,1);p.SyncManaged();p.MatchJobs();
        Check(Job(p)==2,"new closer vacancy never displaces incumbent without moving");
        Move(p,4);
        Check(Job(p)==-1&&p.WorkplaceInfo(2)["filled"].AsGodotArray()[1].AsInt64()==0,"connected move releases local incumbent and filled slot immediately");
        Check(!p.HappinessGroups().ContainsKey(2)&&p.HappinessGroups()[4].Employed==0,"connected move removes old work happiness and updates new home before matching");
        p.MatchJobs();p.MatchJobs();
        Check(Job(p)==3&&p.WorkplaceInfo(3)["filled"].AsGodotArray()[1].AsInt64()==1&&p.HappinessGroups()[4].Employed==1,"moved household rematches nearest eligible job exactly once");
        using var external=New();external.ApplyLaborCommutingPlan(new A(),new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=1}});external.HappinessGroups();Move(external,4);
        Check(external.GetNeighborCommuters()["outbound"].AsInt64()==0&&external.HappinessGroups()[4].Employed==0,"connected move releases external employment and happiness immediately");
        external.MatchJobs();Check(Job(external)==3&&external.Stats()["employed"].AsInt64()==1,"moved external worker can take nearest local job without dual employment");
        using var rehouse=New();rehouse.MatchJobs();rehouse.HappinessGroups();var remaining=World();remaining.RemoveAt(0);rehouse.PrepareLaborWorld(remaining,Roads());rehouse.RemoveBuilding(1);rehouse.SyncManaged();
        Check(Job(rehouse)==-1&&rehouse.WorkplaceInfo(2)["filled"].AsGodotArray()[1].AsInt64()==0&&rehouse.HappinessGroups()[4].Employed==0,"demolition rehousing releases filled slots and happiness before matching");
        rehouse.MatchJobs();Check(Job(rehouse)==3&&rehouse.WorkplaceInfo(3)["filled"].AsGodotArray()[1].AsInt64()==1,"demolition rehousing selects nearest job without double filling");
        using var disconnected=New();disconnected.MatchJobs();disconnected.PrepareLaborWorld(World(),new A());disconnected.MatchJobs();
        Check(Job(disconnected)==2&&disconnected.Stats()["employed"].AsInt64()==1,"commute route loss does not fire a valid incumbent");
        Move(disconnected,4);disconnected.MatchJobs();Check(Job(disconnected)==-1,"after moving new job search requires reachable roads");
        using var pending=New();pending.ApplyLaborCommutingPlan(new A(),new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=1}});
        var saved=pending.ExportState();var plan=pending.ExportLaborPolicyState();
        pending.ImportState(saved["people"].AsGodotArray(),saved["households"].AsGodotArray(),saved["workplaces"].AsGodotDictionary());pending.ImportLaborPolicyState(plan);
        pending.PrepareLaborWorld(remaining,Roads());pending.EnableGeometryTransport(new long[]{4,0,2,1,2,1,2,1,3,2,2,1});pending.SyncManaged();
        Check(pending.ExportLaborPolicyState()["outbound"].AsGodotArray().Count==0,"initial restore rehousing removes moved person's pending external assignment");
        pending.MatchJobs();Check(Job(pending)==3&&pending.HappinessGroups()[4].Employed==1,"full-rebuild rehousing rematches before stale pending employment can return");
        using var lost=New();lost.MatchJobs();var withoutJob=World();withoutJob.RemoveAt(2);lost.PrepareLaborWorld(withoutJob,Roads());lost.RemoveBuilding(2);lost.SyncManaged();lost.MatchJobs();
        Check(Job(lost)==3,"actual workplace removal releases incumbent and allows a new eligible search");
        using var disabled=New(false);disabled.MatchJobs();long oldJob=Job(disabled);Move(disabled,4);disabled.MatchJobs();
        Check(Job(disabled)==oldJob,"disabled direct fixtures retain baseline incumbent semantics across moving");
        foreach(var s in new[]{p,external,rehouse,disconnected,pending,lost,disabled})s.GetRng().Dispose();
    }
    private void ViewCheckpointTests()
    {
        using var p=New();
        var before=p.CaptureCityReadView();
        Check(before.WorkplaceInfo(2).ContainsKey("inbound_reserved")&&before.WorkplaceInfo(2).ContainsKey("free_slots"),"enabled immutable workplace publishes optional reservation/free arrays");
        var inbound=new A{new D{["workplace_id"]=2,["stage"]=1,["count"]=1}};
        var outbound=new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=1}};
        p.SetNeighborCommuters(7,8);p.ApplyLaborCommutingPlan(inbound,outbound);p.MatchJobs();
        var reserved=p.CaptureCityReadView();var w=reserved.WorkplaceInfo(2);
        Check(w.TryGetValue("inbound_reserved",out var slots)&&slots.AsGodotArray()[1].AsInt64()==1,"reservation-only changes replace cached immutable workplace root");
        Check(w.TryGetValue("free_slots",out var free)&&free.AsGodotArray()[1].AsInt64()==0,"immutable free slots subtract inbound reservations");
        Check(before.WorkplaceInfo(2).TryGetValue("inbound_reserved",out var old)&&old.AsGodotArray()[1].AsInt64()==0,"earlier immutable root remains unchanged after reservation-only edit");
        if(w.ContainsKey("inbound_reserved")){w["inbound_reserved"].AsGodotArray()[1]=99;w["free_slots"].AsGodotArray()[1]=99;}
        Check(reserved.WorkplaceInfo(2).TryGetValue("inbound_reserved",out var own)&&own.AsGodotArray()[1].AsInt64()==1,"thawed workplace arrays cannot mutate immutable publication");
        var policyMethod=typeof(PopulationReadView).GetMethod("LaborPolicyInfo");
        var commuterMethod=typeof(PopulationReadView).GetMethod("GetNeighborCommuters");
        Check(policyMethod!=null&&commuterMethod!=null,"immutable view exposes typed frozen policy and aggregate commuter APIs");
        if(policyMethod!=null&&commuterMethod!=null)
        {
            var policy=(D)policyMethod.Invoke(reserved,null)!;var commuters=(D)commuterMethod.Invoke(reserved,null)!;
            Check(policy["enabled"].AsBool()&&policy["jobs_per_worker"].AsDouble()==1.05&&policy["commercial_share"].AsDouble()==0.6&&policy["max_cached_home_routes"].AsInt64()==128,"immutable policy preserves bool double and integer types");
            Check(commuters["inbound"].AsInt64()==1&&commuters["outbound"].AsInt64()==1&&commuters["requested_inbound"].AsInt64()==7&&commuters["requested_outbound"].AsInt64()==8,"immutable commuter summary carries requested estimates and actual assignments separately");
        }
        var checkpoint=p.ExportCityCheckpoint();
        Check(checkpoint.ContainsKey("labor_policy"),"city checkpoint includes complete labor policy and concrete commuter plan");
        if(checkpoint.ContainsKey("labor_policy"))
        {
            var policy=checkpoint["labor_policy"].AsGodotDictionary();
            Check(Json.Stringify(policy)==Json.Stringify(p.ExportLaborPolicyState()),"checkpoint labor payload exactly matches explicit export");
            using var restored=New();restored.ImportState(checkpoint["people"].AsGodotArray(),checkpoint["households"].AsGodotArray(),checkpoint["workplaces"].AsGodotDictionary());restored.ImportLaborPolicyState(policy);
            Check(Json.Stringify(restored.ExportCityCheckpoint()["labor_policy"])==Json.Stringify(policy),"checkpoint can re-export pending plans before first restored matching");
            bool blocked=false;try{restored.MatchJobs();}catch(InvalidOperationException){blocked=true;}
            Check(blocked,"restored checkpoint cannot match before world preparation");
            restored.PrepareLaborWorld(World(),Roads());restored.EnableGeometryTransport(Packed);restored.SyncManaged();restored.MatchJobs();
            Check(restored.GetNeighborCommuters()["inbound"].AsInt64()==1&&restored.GetNeighborCommuters()["outbound"].AsInt64()==1&&Job(restored)==-1,"restore installs plan before local matching can steal reserved slots or external person");
            Check(Json.Stringify(restored.ExportCityCheckpoint()["labor_policy"])==Json.Stringify(policy),"restored checkpoint preserves concrete labor config and assignments");restored.GetRng().Dispose();
        }
        p.ApplyLaborCommutingPlan(new A(),new A());var released=p.CaptureCityReadView();
        Check(released.WorkplaceInfo(2).TryGetValue("inbound_reserved",out var empty)&&empty.AsGodotArray()[1].AsInt64()==0&&reserved.WorkplaceInfo(2).TryGetValue("inbound_reserved",out var frozen)&&frozen.AsGodotArray()[1].AsInt64()==1,"reservation release refreshes cached roots without mutating old view");
        p.ConfigureLaborPolicy(new D{["enabled"]=false});var disabled=p.CaptureCityReadView();
        Check(!disabled.WorkplaceInfo(2).ContainsKey("inbound_reserved")&&!disabled.WorkplaceInfo(2).ContainsKey("free_slots"),"disabling policy removes optional immutable workplace fields");
        using var legacy=New(false);var legacyView=legacy.CaptureCityReadView();
        Check(Json.Stringify(legacyView.WorkplaceInfo(2))==Json.Stringify(legacy.WorkplaceInfo(2)),"disabled direct and immutable workplace dictionary shapes remain baseline-compatible");
        p.GetRng().Dispose();legacy.GetRng().Dispose();
    }
    public D Run(){MoveTests();ViewCheckpointTests();return new D{["checks"]=_checks,["failures"]=_failures};}
}
