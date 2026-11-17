using System;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;
public partial class LaborProbe : RefCounted
{
    private int _checks; private readonly A _failures=new();
    private void Check(bool ok,string label){_checks++;if(!ok)_failures.Add(label);}
    private static PopulationState New(bool enabled=true)
    {
        var p=new PopulationState();p.Initialize(51);
        var c=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        c["birth_probability_per_household_day"]=0.0;p.Configure(c);
        // Reflection keeps the initial RED executable against the unmodified source.
        typeof(PopulationState).GetMethod("ConfigureLaborPolicy")?.Invoke(p,new object[]{new D{["enabled"]=enabled}});
        return p;
    }
    private static A People(int adults,int children=0)
    {
        var a=new A();for(int i=0;i<adults+children;i++)a.Add(new D{["id"]=i+1,["household_id"]=1,["education"]=1,["age_years"]=i<adults?25.0:8.0,["origin"]="fixture",["workplace_id"]=-1,["job_stage"]=-1});return a;
    }
    private static A Homes()=>new(){new D{["id"]=1,["home_id"]=1}};
    private static D B(long id,string zone,float x,float y,long road=10)=>new(){["id"]=id,["zone"]=zone,["position"]=new Vector2(x,y),["front_road_id"]=road};
    private static D R(long id,params Vector2[] points)=>new(){["parcel_id"]=id,["kind"]="local",["points"]=points};
    private static void Prep(PopulationState p,A buildings,A roads)=>typeof(PopulationState).GetMethod("PrepareLaborWorld")?.Invoke(p,new object[]{buildings,roads});
    private static long Job(PopulationState p)=>p.ExportState()["people"].AsGodotArray()[0].AsGodotDictionary()["workplace_id"].AsInt64();
    private void MoreRoadTests(D custom)
    {
        long[] packed={1,0,2,1,3,2,2,1,2,1,2,1};
        using var p=New();p.Configure(custom);p.ImportState(People(1),Homes(),new D());
        var road=new A{R(10,new Vector2(0,0),new Vector2(0,10),new Vector2(1,10),new Vector2(1,0))};
        var world=new A{B(1,"residential",0,0),B(2,"commercial",1,0),B(3,"industrial",0,5)};
        Prep(p,world,road);p.SyncPacked(packed);p.MatchJobs();
        Check(Job(p)==3,"road-nearest differs from Euclidean-nearest around U detour");
        Check(p.GetLaborRoadDistance(1,2)==84&&p.GetLaborRoadDistance(1,3)==20,"exact polyline road distances include 4 metres per cell");
        var before=p.LaborRoadDiagnostics();p.MatchJobs();Prep(p,world,road);p.MatchJobs();var after=p.LaborRoadDiagnostics();
        Check(before["topology_builds"].AsInt64()==after["topology_builds"].AsInt64()&&before["route_searches"].AsInt64()==after["route_searches"].AsInt64(),"unchanged prep and matching reuse topology and home routes");
        world[1]=B(2,"commercial",0,1);Prep(p,world,road);p.MatchJobs();
        Check(Job(p)==3,"valid incumbent retained even if a nearer compatible vacancy appears");
        Check(p.GetLaborRoadDistance(1,2)==4&&p.LaborRoadDiagnostics()["topology_builds"].AsInt64()==1,"building anchor edit invalidates routing/order only, not topology");
        Prep(p,world,new A());p.MatchJobs();Check(Job(p)==3,"road deletion affects commuting but does not fire a valid incumbent");
        var disconnected=new A{R(10,new Vector2(0,0),new Vector2(0,10)),R(20,new Vector2(1,0),new Vector2(1,10))};
        world[1]=B(2,"commercial",1,0,20);world[2]=B(3,"industrial",1,5,20);Prep(p,world,disconnected);p.MatchJobs();
        Check(Job(p)==3&&p.GetLaborRoadDistance(1,2)==-1,"disconnected local roads keep incumbent; new road route remains unreachable");
        disconnected.Add(R(30,new Vector2(0,5),new Vector2(1,5)));Prep(p,world,disconnected);p.MatchJobs();
        Check(Job(p)==3&&p.GetLaborRoadDistance(1,3)==24,"unsampled T crossings split real segment interior anchors exactly");
        var saved=p.ExportState();p.ImportState(saved["people"].AsGodotArray(),saved["households"].AsGodotArray(),saved["workplaces"].AsGodotDictionary());
        bool blocked=false;try{p.MatchJobs();}catch(InvalidOperationException){blocked=true;}
        Check(blocked,"restored worker cannot match against stale/unprepared world");Prep(p,world,disconnected);p.MatchJobs();Check(Job(p)==3,"restored incumbent retained after world reprepare");
        using var tie=New();tie.Configure(custom);tie.ImportState(People(1),Homes(),new D());
        var line=new A{R(10,new Vector2(0,0),new Vector2(10,0))};var equal=new A{B(1,"residential",5,0),B(3,"industrial",6,0),B(2,"commercial",4,0)};
        Prep(tie,equal,line);tie.SyncPacked(packed);tie.MatchJobs();Check(Job(tie)==2,"equal road distance tie uses stable workplace ID, not array order or same education");
        var native=new A{new D{["id"]=1,["zone"]="residential",["x"]=0,["y"]=0,["size"]=2,["front_road_id"]=10},
            new D{["id"]=2,["zone"]="commercial",["frame"]=new D{["origin"]=new Vector2(0,0),["along"]=Vector2.Right,["outward"]=Vector2.Down},["u"]=4,["v"]=0,["size"]=2,["front_road_id"]=10}};
        bool nativeAccepted=true;try{tie.PrepareLaborWorld(native,line);}catch(ArgumentException){nativeAccepted=false;}
        Check(nativeAccepted&&tie.GetLaborRoadDistance(1,2)==16,"raw model x/y and frame/u/v building records accepted without main-thread geometry packing");
        var crossWorld=new A{B(1,"residential",0,0),B(2,"commercial",10,0,20)};
        var crossRoads=new A{R(10,new Vector2(0,0),new Vector2(10,10)),R(20,new Vector2(0,10),new Vector2(10,0))};
        tie.PrepareLaborWorld(crossWorld,crossRoads);Check(Math.Abs(tie.GetLaborRoadDistance(1,2)-40*Math.Sqrt(2))<1e-9,"diagonal X crossing routes through exact intersection, not nearest endpoint");
        crossRoads[1].AsGodotDictionary()["elevation_m"]=10.0;tie.PrepareLaborWorld(crossWorld,crossRoads);
        Check(tie.GetLaborRoadDistance(1,2)==-1,"different constant road elevations never join at an XY crossing");
        var gapRoads=new A{R(10,new Vector2(0,0),new Vector2(1,0)),R(20,new Vector2(1.001f,0),new Vector2(2,0))};
        crossWorld[1]=B(2,"commercial",2,0,20);tie.PrepareLaborWorld(crossWorld,gapRoads);Check(tie.GetLaborRoadDistance(1,2)==-1,"visually nearby endpoints do not form a teleport edge");
        crossWorld[1]=B(2,"commercial",0,0,-1);tie.PrepareLaborWorld(crossWorld,gapRoads);Check(tie.GetLaborRoadDistance(1,2)==-1,"missing frontage road never falls back to nearest unrelated road");
        var eduPeople=People(1);eduPeople[0].AsGodotDictionary()["education"]=4;tie.ImportState(eduPeople,Homes(),new D());Prep(tie,equal,line);tie.SyncPacked(packed);tie.MatchJobs();
        Check(Job(tie)==-1,"education absolute difference above one is rejected even at nearest workplace");
        var lower=custom.Duplicate(true);lower["commercial_jobs"]=new A{1,0,1,0,0};tie.Configure(lower);tie.ImportState(People(1),Homes(),new D());Prep(tie,equal,line);tie.SyncPacked(packed);tie.MatchJobs();
        Check(Job(tie)==2&&tie.ExportState()["people"].AsGodotArray()[0].AsGodotDictionary()["job_stage"].AsInt64()==0,"same workplace equal-distance stage tie uses lower eligible stage deterministically");
        long searches=tie.LaborRoadDiagnostics()["route_searches"].AsInt64();tie.SyncPacked(new long[]{1,0,2,1,3,2,2,1,2,1,2,2});tie.MatchJobs();
        Check(tie.LaborRoadDiagnostics()["route_searches"].AsInt64()==searches,"capacity-only stage/level edits reuse exact road distances");
        tie.ConfigureLaborPolicy(new D{["max_cached_home_routes"]=1});
        equal.Add(B(4,"residential",8,0));tie.PrepareLaborWorld(equal,line);tie.GetLaborRoadDistance(1,2);tie.GetLaborRoadDistance(4,2);
        Check(tie.LaborRoadDiagnostics()["cached_homes"].AsInt64()==1,"routing/order caches obey configured home budget instead of unbounded all-pairs retention");
        foreach(var state in new[]{p,tie})state.GetRng().Dispose();
    }
    private void MoreCommutingTests(D custom)
    {
        long[] packed={1,0,2,1,2,1,2,1,3,2,2,1};
        var world=new A{B(1,"residential",0,0),B(2,"commercial",1,0),B(3,"industrial",2,0)};
        var roads=new A{R(10,new Vector2(0,0),new Vector2(10,0))};
        using var p=New();p.Configure(custom);p.ImportState(People(3),Homes(),new D());Prep(p,world,roads);p.SyncPacked(packed);
        var inbound=new A{new D{["workplace_id"]=2,["stage"]=2,["count"]=10}};
        var outbound=new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=0}};
        var applied=p.ApplyLaborCommutingPlan(inbound,outbound);Check(applied["inbound"].AsInt64()==1&&applied["rejected_inbound"].AsInt64()==9,"inbound requests clamp to actual per-stage free slots");
        p.MatchJobs();var context=p.GetLaborCommutingContext();
        Check(context["unemployed"].AsGodotArray().Count==1&&context["outbound"].AsGodotArray().Count==1,"context separates eligible unemployed from existing external assignments");
        var unemployed=context["unemployed"].AsGodotArray()[0].AsGodotDictionary();
        Check(unemployed["person_id"].AsInt64()==3&&unemployed["home_id"].AsInt64()==1&&unemployed["education"].AsInt64()==1,"context carries concrete deterministic person/home/education");
        bool zeroFree=true;foreach(var value in context["workplaces"].AsGodotArray())foreach(var n in value.AsGodotDictionary()["free_slots"].AsGodotArray())zeroFree&=n.AsInt64()==0;
        Check(zeroFree,"free-slot context subtracts local incumbents AND inbound reservations");
        Check(p.GetNeighborCommuters()["inbound"].AsInt64()==1&&p.GetNeighborCommuters()["outbound"].AsInt64()==1,"counts API reports actual reservations/assignments, not estimates");
        var population=p.ExportState();var policy=p.ExportLaborPolicyState();
        using var restored=New();restored.Configure(custom);restored.ImportState(population["people"].AsGodotArray(),population["households"].AsGodotArray(),population["workplaces"].AsGodotDictionary());
        restored.ImportLaborPolicyState(policy);
        Check(Json.Stringify(restored.ExportLaborPolicyState())==Json.Stringify(policy),"idle checkpoint re-export preserves pending commuter plan before first restored matching");
        Prep(restored,world,roads);restored.SyncPacked(packed);restored.MatchJobs();
        Check(Json.Stringify(restored.ExportLaborPolicyState())==Json.Stringify(policy),"checkpoint restores exact commuter plans before local matching can steal reserved slots");
        Check(restored.Stats()["employed"].AsInt64()==2&&restored.HappinessGroups()[1].Employed==2,"restored external jobs appear in resident stats and home happiness");
        p.HappinessGroups();p.ConfigureLaborPolicy(new D{["enabled"]=false});
        Check(p.HappinessGroups()[1].Employed==1,"disabling production policy invalidates external employment happiness membership");
        p.ConfigureLaborPolicy(new D{["enabled"]=true});
        var preserve=p.ApplyLaborCommutingPlan(new A{new D{["workplace_id"]=3,["stage"]=1,["count"]=1}},new A());
        Check(preserve["inbound"].AsInt64()==0&&preserve["rejected_inbound"].AsInt64()==1,"inbound cannot displace valid local incumbent");
        p.MatchJobs();Check(p.GetNeighborCommuters()["outbound"].AsInt64()==0,"empty replacement plan releases external resident for subsequent local matching");
        var current=Json.Stringify(p.ExportLaborPolicyState());bool rejected=false;
        try{p.ApplyLaborCommutingPlan(new A{new D{["workplace_id"]=2,["stage"]=9,["count"]=1}},new A());}catch(ArgumentException){rejected=true;}
        Check(rejected&&Json.Stringify(p.ExportLaborPolicyState())==current,"malformed plan rejected atomically");
        // An incompatible external education stage must not fabricate employment.
        var bad=p.ApplyLaborCommutingPlan(new A(),new A{new D{["person_id"]=3,["neighbor_id"]="north",["stage"]=4}});
        Check(bad["outbound"].AsInt64()==0&&bad["rejected_outbound"].AsInt64()==1,"outbound plan enforces education +/-1");
        restored.SyncPacked(new long[]{1,0,2,1,3,2,2,1});restored.MatchJobs();
        Check(restored.GetNeighborCommuters()["inbound"].AsInt64()==0,"workplace demolition drops inbound reserved slots");
        using var demand=New();demand.ImportState(People(2),Homes(),new D());Prep(demand,world,roads);demand.SyncPacked(packed);
        demand.ApplyLaborCommutingPlan(new A{new D{["workplace_id"]=2,["stage"]=0,["count"]=3},new D{["workplace_id"]=2,["stage"]=1,["count"]=2},new D{["workplace_id"]=3,["stage"]=0,["count"]=2},new D{["workplace_id"]=3,["stage"]=1,["count"]=2},new D{["workplace_id"]=3,["stage"]=2,["count"]=1}},new A());
        Check(demand.Demand(packed)["residential"].AsInt64()==1,"10 actual inbound reservations lower residential building demand from 3 to 1");
        demand.ApplyLaborCommutingPlan(demand.ExportLaborPolicyState()["inbound"].AsGodotArray(),new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=1},new D{["person_id"]=2,["neighbor_id"]="north",["stage"]=1}});
        Check(demand.LaborDemandDiagnostics()["surplus_jobs"].AsInt64()==5&&demand.Stats()["unemployed"].AsInt64()==0,"actual outbound assignments remove unemployed before net housing surplus");
        demand.EnableGeometryTransport(packed);demand.SyncManaged();demand.MatchJobs();
        var read=demand.CaptureCityReadView();Check(read.Stats()["employed"].AsInt64()==2&&read.Demand()["residential"].AsInt64()==1,"existing immutable publication sees actual external-employment stats and new demand");
        demand.RecordBuilding(2,1,4,2);demand.SyncManaged();demand.MatchJobs();
        Check(demand.DemandManaged()["commercial"].AsInt64()==0&&demand.DemandManaged()["residential"].AsInt64()==13,"managed geometry capacity edits invalidate job-based demand cache");
        Check(read.Demand()["residential"].AsInt64()==1,"earlier read view stays frozen after worker demand updates");
        foreach(var state in new[]{p,restored,demand})state.GetRng().Dispose();
    }
    public D Run()
    {
        using var p=New();p.ImportState(People(20,10),Homes(),new D());
        var d=p.Demand(System.Array.Empty<long>());
        Check(d["commercial"].AsInt64()==2,"20 workers need 12.6 commercial jobs / actual 7 slots = 2 buildings (children excluded)");
        Check(d["industrial"].AsInt64()==2,"20 workers need 8.4 industrial jobs / actual 8 slots = 2 buildings");
        using var empty=New();Check(empty.Demand(System.Array.Empty<long>())["residential"].AsInt64()==4,"zero-worker bootstrap: 8 household units / 2 per 2x2 = 4 new buildings");
        Check(empty.Demand(new long[]{1,0,2,1})["residential"].AsInt64()==3,"bootstrap subtracts vacant household capacity");
        Check(p.Demand(new long[]{2,1,4,2})["commercial"].AsInt64()==0,"actual size and level capacities replace raw building counts before sync");
        using var surplus=New();surplus.ImportState(People(2),Homes(),new D());
        var supply=new long[]{1,0,2,1,2,1,2,1,3,2,2,1};
        Check(surplus.Demand(supply)["residential"].AsInt64()==3,"15 vacancies - 2 unemployed -> ceil(13/2) households minus 1 empty unit -> 3 buildings");
        typeof(PopulationState).GetMethod("SetNeighborCommuters")?.Invoke(surplus,new object[]{10,0});
        Check(surplus.Demand(supply)["residential"].AsInt64()==3,"counts-only estimates cannot allocate vacancies or alter concrete-plan demand");
        typeof(PopulationState).GetMethod("SetNeighborCommuters")?.Invoke(surplus,new object[]{10,2});
        Check(surplus.Demand(supply)["residential"].AsInt64()==3,"counts-only outbound estimates never fabricate employed residents");
        using var legacy=New(false);Check(legacy.Demand(System.Array.Empty<long>())["residential"].AsInt64()==8,"explicit legacy path preserves original demand units");
        using var near=New();var custom=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        custom["commercial_jobs"]=new A{0,0,1,0,0};custom["industrial_jobs"]=new A{0,1,0,0,0};near.Configure(custom);
        near.ImportState(People(1),Homes(),new D());
        var world=new A{B(1,"residential",0,0),B(3,"industrial",10,0),B(2,"commercial",1,0)};
        var roads=new A{R(10,new Vector2(0,0),new Vector2(10,0))};
        Prep(near,world,roads);near.SyncPacked(new long[]{1,0,2,1,3,2,2,1,2,1,2,1});ulong rng=near.GetRng().State;near.MatchJobs();
        Check(Job(near)==2,"near stage+1 job beats farther same-stage job by exact road distance");
        Check(near.GetRng().State==rng,"matching does not consume RNG");
        using var commute=New();commute.Configure(custom);commute.ImportState(People(3),Homes(),new D());
        Prep(commute,world,roads);commute.SyncPacked(new long[]{1,0,2,1,3,2,2,1,2,1,2,1});
        var inbound=new A{new D{["workplace_id"]=2,["stage"]=2,["count"]=1}};
        var outbound=new A{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=0}};
        typeof(PopulationState).GetMethod("ApplyLaborCommutingPlan")?.Invoke(commute,new object[]{inbound,outbound});commute.MatchJobs();
        var commutePeople=commute.ExportState()["people"].AsGodotArray();
        Check(commutePeople[0].AsGodotDictionary()["workplace_id"].AsInt64()==-1,"outbound resident is not simultaneously matched to a local workplace");
        Check(commute.WorkplaceInfo(2)["filled"].AsGodotArray()[2].AsInt64()==0,"inbound reservation prevents local double-fill");
        Check(commute.Stats()["employed"].AsInt64()==2&&commute.Stats()["unemployed"].AsInt64()==1,"stats count one external and one local job, not inbound as resident");
        Check(commute.HappinessGroups()[1].Employed==2,"external employment contributes to home happiness employed count");
        Check(typeof(PopulationState).GetMethod("GetLaborCommutingContext")!=null,"worker exposes real commuting context");
        MoreRoadTests(custom);MoreCommutingTests(custom);
        foreach(var state in new[]{p,empty,surplus,legacy,near,commute})state.GetRng().Dispose();return new D{["checks"]=_checks,["failures"]=_failures};
    }
}
