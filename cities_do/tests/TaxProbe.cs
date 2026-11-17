using System;
using Godot;
using D=Godot.Collections.Dictionary;
public partial class TaxProbe:RefCounted
{
    private int checks; private readonly Godot.Collections.Array failures=new();
    private void Check(bool ok,string label){checks++;if(!ok)failures.Add(label);}
    private void AssessmentTests(PopulationState p)
    {
        var settle=typeof(PopulationState).GetMethod("AssessTaxesThroughDay");Check(settle!=null,"daily assessment API exists");if(settle==null)return;
        var config=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();p.Configure(config);
        p.ConfigureTaxPolicy(new D{["enabled"]=true,["rates"]=new Godot.Collections.Array{9,9,9,9,9,9,9,9,9}});
        var people=new Godot.Collections.Array();
        people.Add(new D{["id"]=1,["household_id"]=1,["education"]=0,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=2,["job_stage"]=1});
        people.Add(new D{["id"]=2,["household_id"]=1,["education"]=4,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=-1,["job_stage"]=-1});
        p.ImportState(people,new Godot.Collections.Array{new D{["id"]=1,["home_id"]=1}},new D());
        long[] buildings={1,0,2,3,2,1,2,5};p.SyncPacked(buildings);
        D Run(long day)=>(D)settle.Invoke(p,new object[]{day,buildings})!;
        var first=Run(1);Check(first["collected"].AsDouble()==5.4,"actual residential and business worker wage basis; unemployed excluded");
        Check(first["posted"].AsInt64()==5&&Math.Abs(first["carry"].AsDouble()-.4)<1e-9,"fraction carry not lost");
        Check(first["cells"].AsGodotArray()[1].AsGodotDictionary()["basis"].AsDouble()==30,"residential middle band");
        Check(first["cells"].AsGodotArray()[5].AsGodotDictionary()["basis"].AsDouble()==30,"business high band resident education not job stage");
        Check(Run(1)["collected"].AsDouble()==0&&Run(0)["collected"].AsDouble()==0,"repeated and backward days no double assessment");
        var multi=Run(4);Check(multi["days"].AsInt64()==3&&Math.Abs(multi["collected"].AsDouble()-16.2)<1e-9,"multi-day monotonic assessment");
        Check(multi["posted"].AsInt64()==16&&Math.Abs(multi["carry"].AsDouble()-.6)<1e-9,"multi-day fractional conservation");
        var export=typeof(PopulationState).GetMethod("ExportTaxCheckpoint")!;var import=typeof(PopulationState).GetMethod("ImportTaxCheckpoint")!;
        var checkpoint=(D)export.Invoke(p,null)!;using var restored=new PopulationState();import.Invoke(restored,new object[]{checkpoint});
        Check(Json.Stringify(checkpoint)==Json.Stringify((D)export.Invoke(restored,null)!),"checkpoint exact decimals and policy roundtrip");
        Check(((D)settle.Invoke(restored,new object[]{4L,buildings})!)["collected"].AsDouble()==0,"restore does not rebill settled day");restored.GetRng().Dispose();
        Check(first.IsReadOnly&&first["cells"].AsGodotArray().IsReadOnly&&first["cells"].AsGodotArray()[1].AsGodotDictionary().IsReadOnly,"nested publication immutable");
        p.ConfigureTaxPolicy(new D{["enabled"]=false});Check(Run(10)["collected"].AsDouble()==0,"disabled advances watermark without collection");
        p.ConfigureTaxPolicy(new D{["enabled"]=true});Check(Run(11)["days"].AsInt64()==1,"re-enable never retro-bills disabled days");
        var managed=typeof(PopulationState).GetMethod("AssessTaxesManaged");Check(managed!=null,"worker managed day API exists");
        var viewTax=typeof(PopulationReadView).GetMethod("GetTaxStatus");Check(viewTax!=null,"read view tax publication API exists");
        if(managed!=null&&viewTax!=null)
        {
            p.EnableGeometryTransport(buildings);p.SyncManaged();
            var result=(D)managed.Invoke(p,new object[]{12L})!;using var view=p.CaptureCityReadView();var status=(D)viewTax.Invoke(view,null)!;
            Check(result["last_day"].AsInt64()==12&&status["last_day"].AsInt64()==12,"managed geometry settlement published");
            using var happiness=new HappinessReadView();
            var envelope=(D)typeof(CitySimulationWorker).GetMethod("ScalarEnvelope",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static)!.Invoke(null,new object[]{new D{["population_view"]=view,["happiness_view"]=happiness}})!;
            Check(envelope.IsReadOnly&&envelope["tax_status"].AsGodotDictionary()["last_day"].AsInt64()==12,"native scalar envelope includes immutable tax publication");
            managed.Invoke(p,new object[]{13L});Check(status["last_day"].AsInt64()==12&&status.IsReadOnly,"old immutable publication detached from worker advance");
            var baselineManaged=p.DemandManaged();p.ConfigureTaxPolicy(new D{["rates"]=new Godot.Collections.Array{9,9,9,9,9,9,9,9,9}});
            Check(p.DemandManaged()["residential"].AsInt64()>=baselineManaged["residential"].AsInt64(),"configuration invalidates managed demand cache");
        }
        Check(p.ExportCityCheckpoint().ContainsKey("tax_policy"),"city checkpoint includes tax policy and ledger");
        long[] empty=System.Array.Empty<long>();p.ConfigureTaxPolicy(new D{["enabled"]=false});var baseline=p.Demand(empty)["residential"].AsInt64();
        p.ConfigureTaxPolicy(new D{["enabled"]=true,["rates"]=new Godot.Collections.Array{20,9,9,9,9,9,9,9,9}});
        Check(p.Demand(empty)["residential"].AsInt64()==(long)Math.Floor(baseline*.34),"actual demand path applies tax preserving new-building units");
        var old=p.ExportTaxCheckpoint();var bad=old.Duplicate(true);bad["carry"]="1.2";bool rejected=false;try{p.ImportTaxCheckpoint(bad);}catch(ArgumentException){rejected=true;}
        Check(rejected&&Json.Stringify(old)==Json.Stringify(p.ExportTaxCheckpoint()),"invalid checkpoint atomic");
        bad=old.Duplicate(true);bad["carry"]="0.123456";rejected=false;try{p.ImportTaxCheckpoint(bad);}catch(ArgumentException){rejected=true;}
        Check(rejected&&Json.Stringify(old)==Json.Stringify(p.ExportTaxCheckpoint()),"checkpoint rejects carry inconsistent with cumulative collections");
        bad=old.Duplicate(true);bad["last_day"]=14.5;rejected=false;try{p.ImportTaxCheckpoint(bad);}catch(ArgumentException){rejected=true;}
        Check(rejected,"checkpoint day must be integer, never truncated");
    }
    private void CommutingTests()
    {
        using var p=new PopulationState();var c=Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary();p.Configure(c);
        p.ConfigureLaborPolicy(new D{["enabled"]=true});p.ConfigureTaxPolicy(new D{["enabled"]=true});
        var people=new Godot.Collections.Array{new D{["id"]=1,["household_id"]=1,["education"]=1,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=-1,["job_stage"]=-1}};
        p.ImportState(people,new Godot.Collections.Array{new D{["id"]=1,["home_id"]=1}},new D());
        var world=new Godot.Collections.Array{new D{["id"]=1,["zone"]="residential",["position"]=new Vector2(0,0),["front_road_id"]=10},new D{["id"]=2,["zone"]="commercial",["position"]=new Vector2(1,0),["front_road_id"]=10}};
        p.PrepareLaborWorld(world,new Godot.Collections.Array{new D{["parcel_id"]=10,["kind"]="local",["points"]=new Vector2[]{new(0,0),new(10,0)}}});
        long[] buildings={1,0,2,1,2,1,2,1};p.SyncPacked(buildings);
        p.ApplyLaborCommutingPlan(new Godot.Collections.Array{new D{["workplace_id"]=2,["stage"]=1,["count"]=1}},new Godot.Collections.Array{new D{["person_id"]=1,["neighbor_id"]="north",["stage"]=0}});
        Check(p.GetHouseholdTaxBasis(1)==40,"external resident uses education wage, not external job stage");
        Check(p.GetBusinessTaxBasis(2)==40,"inbound job stage proxy wage counted");
        var result=p.AssessTaxesThroughDay(1,buildings);Check(result["collected"].AsDouble()==7.2,"external residential and inbound business assessment");
        var cell=result["zones"].AsGodotDictionary();Check(cell["residential"].AsGodotDictionary()["collected"].AsDouble()==3.6&&cell["commercial"].AsGodotDictionary()["collected"].AsDouble()==3.6,"zone totals reconcile");
        p.ConfigureTaxPolicy(new D{["wages"]=new Godot.Collections.Array{1,2,3,4,5}});Check(p.GetHouseholdTaxBasis(1)==2&&p.GetBusinessTaxBasis(2)==2,"configurable wage table applies to both bases");
        p.GetRng().Dispose();
    }
    public D Run()
    {
        using var p=new PopulationState();
        var method=typeof(PopulationState).GetMethod("GetTaxPolicy");
        Check(method!=null,"tax policy API exists");
        if(method!=null){var d=(D)method.Invoke(p,null)!;Check(!d["enabled"].AsBool(),"fixture default off");Check(d["rates"].AsGodotArray().Count==9,"nine rates");foreach(var v in d["rates"].AsGodotArray())Check(v.AsInt64()==9,"default nine");}
        var configure=typeof(PopulationState).GetMethod("ConfigureTaxPolicy");
        Check(configure!=null,"configurable policy API exists");
        if(configure!=null)
        {
            configure.Invoke(p,new object[]{new D{["enabled"]=true}});
            var multiplier=typeof(PopulationState).GetMethod("TaxDemandMultiplier")!;
            var threshold=typeof(PopulationState).GetMethod("TaxGrowthThreshold")!;
            var scale=typeof(PopulationState).GetMethod("TaxNewBuildingDemand")!;
            Check((double)multiplier.Invoke(p,new object[]{"residential"})! ==1,"baseline multiplier one");
            var rates=new Godot.Collections.Array{20,14,19,0,0,0,9,9,9};
            configure.Invoke(p,new object[]{new D{["rates"]=rates}});
            Check(Math.Abs((double)multiplier.Invoke(p,new object[]{"residential"})!-.34)<1e-9,"high low-band rate multiplier");
            Check((double)multiplier.Invoke(p,new object[]{"commercial"})! ==1.5,"multiplier upper clamp");
            Check((double)threshold.Invoke(p,new object[]{"residential",3,60.0})! ==70,"middle target3");
            Check((double)threshold.Invoke(p,new object[]{"residential",4,70.0})! ==80,"middle target4");
            Check((double)threshold.Invoke(p,new object[]{"residential",5,80.0})! ==100,"high target5 cap");
            Check((double)threshold.Invoke(p,new object[]{"commercial",5,80.0})! ==80,"low tax never lowers base");
            Check((double)threshold.Invoke(p,new object[]{"residential",2,50.0})! ==50,"low band no growth penalty");
            Check((int)scale.Invoke(p,new object[]{"residential",10})! ==3,"building demand floors explicit integer counts");
            var before=Json.Stringify(p.Call("GetTaxPolicy"));bool invalid=false;
            try{configure.Invoke(p,new object[]{new D{["rates"]=new Godot.Collections.Array{9.5,9,9,9,9,9,9,9,9}}});}catch(System.Reflection.TargetInvocationException){invalid=true;}
            Check(invalid&&before==Json.Stringify(p.Call("GetTaxPolicy")),"fractional rate rejected atomically");
        }
        foreach(double value in new[]{-1.0,21.0,9.25,double.NaN,double.PositiveInfinity})
        {
            bool rejected=false;var before=Json.Stringify(p.GetTaxPolicy());try{p.ConfigureTaxPolicy(new D{["rates"]=new Godot.Collections.Array{value,9,9,9,9,9,9,9,9}});}catch(ArgumentException){rejected=true;}
            Check(rejected&&before==Json.Stringify(p.GetTaxPolicy()),"invalid tax rate rejected atomically "+value);
        }
        p.ConfigureTaxPolicy(new D{["demand_slope"]=1.0});Check(p.TaxDemandMultiplier("residential")==0,"configurable slope lower clamps to zero");
        p.ConfigureTaxPolicy(new D{["enabled"]=false});Check(p.TaxDemandMultiplier("residential")==1&&p.TaxGrowthThreshold("residential",5,80)==80,"fixture disable removes all policy effects");
        var fileConfig=Json.ParseString(FileAccess.GetFileAsString("res://core/tax_config.json")).AsGodotDictionary();p.ConfigureTaxPolicy(fileConfig);
        Check(!p.GetTaxPolicy()["enabled"].AsBool()&&p.GetTaxPolicy()["wages"].AsGodotArray()[4].AsDouble()==100,"explicit resource config uses approved education wages and opt-in");
        AssessmentTests(p);CommutingTests();
        p.GetRng().Dispose();return new D{["checks"]=checks,["failures"]=failures};
    }
}
