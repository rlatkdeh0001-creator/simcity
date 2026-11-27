using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

// Invoked by test_population_incremental.gd; no scene/UI or performance timing.
public partial class PopulationIncrementalProbe : RefCounted
{
    private int _checks;
    private readonly A _failures=new();
    private void Check(bool condition,string label) {_checks++;if(!condition)_failures.Add(label);}
    private static object Field(PopulationState p,string name)=>typeof(PopulationState).GetField(name,BindingFlags.Instance|BindingFlags.NonPublic)!.GetValue(p)!;
    private static PopulationState New()
    {
        var p=new PopulationState();p.Initialize(51);
        var config=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        config["birth_probability_per_household_day"]=0.0;p.Configure(config);return p;
    }
    private static D Person(long id,long household,double age,int education=0,long work=-1,int stage=-1)=>new()
    { ["id"]=id,["household_id"]=household,["education"]=education,["age_years"]=age,["origin"]="fixture",["workplace_id"]=work,["job_stage"]=stage };
    private static A Homes(params (long Id,long Home)[] rows)
    {var result=new A();foreach(var row in rows)result.Add(new D {["id"]=row.Id,["home_id"]=row.Home});return result;}
    private void CompareGroups(PopulationState p,string label,D? configured=null)
    {
        var snapshot=p.ExportState();var homes=new Dictionary<long,long>();
        foreach(var value in snapshot["households"].AsGodotArray()) {var h=value.AsGodotDictionary();homes[h["id"].AsInt64()]=h["home_id"].AsInt64();}
        var expected=new Dictionary<long,int[]>();
        var config=configured??Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        var ages=config["education_min_ages"].AsGodotArray();double working=config["working_age_years"].AsDouble();
        foreach(var value in snapshot["people"].AsGodotArray())
        {
            var person=value.AsGodotDictionary();double age=person["age_years"].AsDouble();long work=person["workplace_id"].AsInt64();
            void Add(long id)
            {
                if(id<0)return;if(!expected.TryGetValue(id,out var counts))expected[id]=counts=new int[7];
                counts[0]++;if(age>=working)counts[1]++;if(work>=0)counts[2]++;
                if(age>=6&&age<ages[1].AsDouble())counts[3]++;
                for(int i=1;i<4;i++)if(age>=ages[i].AsDouble()&&age<ages[i+1].AsDouble())counts[3+i]++;
            }
            if(homes.TryGetValue(person["household_id"].AsInt64(),out long home))Add(home);if(work>=0)Add(work);
        }
        var actual=p.HappinessGroups();bool equal=actual.Count==expected.Count;
        foreach(var pair in expected)
        {
            if(!actual.TryGetValue(pair.Key,out var group)) {equal=false;continue;}
            equal&=group.Count==pair.Value[0]&&group.Eligible==pair.Value[1]&&group.Employed==pair.Value[2];
            for(int i=0;i<4;i++)equal&=group.Students[i]==pair.Value[3+i];
        }
        Check(equal,label);
    }
    public D Run()
    {
        _checks=0;_failures.Clear();using var p=New();
        long[] buildings={1,0,2,1,2,1,2,1,3,0,2,1,4,2,2,1};
        p.ImportState(new A {Person(1,1,25),Person(2,1,5.99999),Person(3,2,17.99999)},Homes((1,1),(2,3)),new D());p.SetNextPerson(4);p.SetNextHousehold(3);
        p.SyncPacked(buildings);p.MatchJobs();CompareGroups(p,"initial groups match an independent exported-state oracle");
        var groups=p.HappinessGroups();Check(ReferenceEquals(groups,p.HappinessGroups()),"unchanged happiness reads reuse the aggregate cache");
        var works=(IDictionary)Field(p,"_works");object work=works[2]!;
        p.BeginTick();p.AdvancePacked(48,buildings);p.MatchJobs();p.Demand(buildings);p.EndTick();
        Check(ReferenceEquals(work,works[2]),"a new tick retains unchanged workplace records");CompareGroups(p,"age thresholds, immigration and employment update cached groups");
        p.AddPerson(1,0,30,"fixture");p.Birth(1);CompareGroups(p,"explicit additions and births update cached groups");
        Check(p.CompleteEducation(1,1),"education fixture completes a real stage");p.MatchJobs();CompareGroups(p,"education and rematching keep cached groups exact");
        p.BeginTick();p.SyncPacked(buildings);p.Demand(buildings);
        long[] changed={4,2,2,2,3,0,2,2,2,0,2,1};
        p.SyncPacked(changed);CompareGroups(p,"rehouse, workplace removal, conversion and capacity changes update groups");p.Demand(changed);p.EndTick();
        var snapshot=p.ExportState();snapshot["people"].AsGodotArray()[0].AsGodotDictionary()["age_years"]=6.0;
        p.ImportState(snapshot["people"].AsGodotArray(),snapshot["households"].AsGodotArray(),snapshot["workplaces"].AsGodotDictionary());
        CompareGroups(p,"compatibility import invalidates cached membership");p.BeginTick();p.SyncPacked(changed);p.MatchJobs();CompareGroups(p,"sync following import rebuilds safe authoritative indices");p.EndTick();
        p.BeginTick();p.Demand(System.Array.Empty<long>());p.SyncPacked(System.Array.Empty<long>());
        bool unhoused=true;foreach(var value in p.ExportState()["households"].AsGodotArray())unhoused&=value.AsGodotDictionary()["home_id"].AsInt64()==-1;
        Check(unhoused,"demand before sync cannot hide a removed home's required reconciliation");CompareGroups(p,"demand-first demolition updates cached home roles");p.EndTick();
        // Overlapping roles and orphan households are supported by imported fixtures.
        p.ImportState(new A {Person(1,1,12,0,2,0),Person(2,999,20,2,2,2),Person(3,3,22)},Homes((1,2),(3,-1)),new D());
        CompareGroups(p,"same home/work ID counts both roles and homeless/orphan fixtures remain exact");
        var config=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();
        config["working_age_years"]=30.0;config["education_min_ages"]=new A {0.0,10.0,15.0,25.0,35.0};p.Configure(config);
        CompareGroups(p,"configuration changes invalidate cached age and employment bands",config);
        using var ages=New();ages.ImportState(new A {Person(1,1,5.99999),Person(2,1,11.99999),Person(3,1,17.99999),Person(4,1,19.99999),Person(5,1,21.99999)},Homes((1,1)),new D());ages.SetNextPerson(6);ages.SetNextHousehold(2);
        ages.SyncPacked(buildings);ages.MatchJobs();CompareGroups(ages,"all student age bands seeded immediately below their boundaries");
        ages.BeginTick();ages.AdvancePacked(48,buildings);ages.MatchJobs();CompareGroups(ages,"every school and working-age boundary incrementally matches the oracle");ages.EndTick();
        // Dispose native RNGs while the engine is still alive; these fixtures are constructed
        // directly from C# rather than owned by a GDScript/scene reference.
        ages.GetRng().Dispose();p.GetRng().Dispose();
        return new D {["checks"]=_checks,["failures"]=_failures};
    }
}
