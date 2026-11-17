using System;
using System.Linq;
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
    private void HouseholdFinanceTests()
    {
        var inspect=typeof(PopulationState).GetMethod("GetHouseholdFinances");
        Check(inspect!=null,"T3 household cash settlement exists");if(inspect==null)return;
        using var p=new PopulationState();p.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());
        p.ConfigureTaxPolicy(new D{["enabled"]=true});
        var people=new Godot.Collections.Array();
        for(int i=1;i<=4;i++)people.Add(new D{["id"]=i,["household_id"]=1,["education"]=0,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=i<=2?2:-1,["job_stage"]=i<=2?0:-1});
        p.ImportState(people,new Godot.Collections.Array{new D{["id"]=1,["home_id"]=1}},new D());
        long[] buildings={1,0,2,1,2,1,2,1};p.SyncPacked(buildings);
        D Cash()=>(D)inspect.Invoke(p,new object[]{1L})!;
        p.AssessTaxesThroughDay(1,buildings);
        Check(Math.Abs(Cash()["cash"].AsDouble()-22.6)<1e-9,"T3 actual wages minus tax then necessities carry 22.6");
        Check(Cash()["income"].AsDouble()==60&&Cash()["goods_ratio"].AsDouble()==1,"T3 income only employed and all four residents consume");
        p.AssessTaxesThroughDay(1,buildings);Check(Math.Abs(Cash()["cash"].AsDouble()-22.6)<1e-9,"T3 repeated day no second wages or consumption");
        var saved=p.ExportCityCheckpoint();using var restored=new PopulationState();
        restored.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());
        restored.ImportState(saved["people"].AsGodotArray(),saved["households"].AsGodotArray(),saved["workplaces"].AsGodotDictionary());restored.ImportTaxCheckpoint(saved["tax_policy"].AsGodotDictionary());restored.SyncPacked(buildings);
        Check(Json.Stringify(Cash())==Json.Stringify((D)inspect.Invoke(restored,new object[]{1L})!),"T3 checkpoint preserves exact cash and last settlement");
        p.ConfigureTaxPolicy(new D{["wages"]=new Godot.Collections.Array{0,0,0,0,0}});p.AssessTaxesThroughDay(2,buildings);
        Check(Cash()["cash"].AsDouble()==0&&Math.Abs(Cash()["goods_ratio"].AsDouble()-22.6/32)<1e-9,"T3 savings drawn before proportional shortages");
        using var happiness=new HappinessCore();happiness.BindPopulation(p);
        happiness.SetWorld(new Godot.Collections.Array{new D{["id"]=1,["zone"]="residential",["level"]=1,["position"]=Vector2.Zero,["power"]=true,["water"]=true}},new Godot.Collections.Array(),System.Array.Empty<double>());
        var factors=happiness.Preview(1)["factors"].AsGodotDictionary();
        Check(factors.Count==14&&!factors.ContainsKey("commute"),"T3 thirteen factors plus base, no obsolete commute factor");
        Check(Math.Abs(factors["goods"].AsDouble()-(-15+25*22.6/32))<1e-9,"T3 actual family necessities drive building happiness");
        p.AssessTaxesThroughDay(3,buildings);Check(happiness.Preview(1)["factors"].AsGodotDictionary()["goods"].AsDouble()==-15,"T3 score cache sees newly exhausted savings");
        var legacy=p.ExportState();var beforeCash=Json.Stringify(Cash());p.ImportState(legacy["people"].AsGodotArray(),legacy["households"].AsGodotArray(),legacy["workplaces"].AsGodotDictionary());
        Check(Json.Stringify(Cash())==beforeCash,"T3 legacy population roundtrip preserves settled cash");
        var cp=restored.ExportTaxCheckpoint();var arrears=cp.Duplicate(true);var household=arrears["household_finances"].AsGodotDictionary()[1].AsGodotDictionary();household["assessed"]="30";household["paid"]="2";restored.ImportTaxCheckpoint(arrears);
        using var penalty=new HappinessCore();penalty.BindPopulation(restored);penalty.SetWorld(new Godot.Collections.Array{new D{["id"]=1,["zone"]="residential",["level"]=1,["position"]=Vector2.Zero,["power"]=true,["water"]=true}},new Godot.Collections.Array(),System.Array.Empty<double>());
        Check(penalty.Preview(1)["factors"].AsGodotDictionary()["tax"].AsDouble()==-10,"T3 unpaid residential assessment causes tax minus ten, independent of rate");
        restored.GetRng().Dispose();p.GetRng().Dispose();
    }
    private void MovingTests()
    {
        using var p=new PopulationState();p.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());p.ConfigureTaxPolicy(new D{["enabled"]=true});
        var people=new Godot.Collections.Array();var households=new Godot.Collections.Array();
        for(int i=1;i<=5;i++){households.Add(new D{["id"]=i,["home_id"]=1});people.Add(new D{["id"]=i,["household_id"]=i,["education"]=0,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=3,["job_stage"]=0});}
        long[] buildings={1,0,4,5,2,0,4,1,3,1,4,1};p.ImportState(people,households,new D());p.SyncPacked(buildings);p.AssessTaxesThroughDay(1,buildings);
        using var h=new HappinessCore();h.BindPopulation(p);
        h.SetWorld(new Godot.Collections.Array{new D{["id"]=1,["zone"]="residential",["level"]=5,["position"]=Vector2.Zero,["power"]=false,["water"]=true},new D{["id"]=2,["zone"]="residential",["level"]=1,["position"]=new Vector2(1000,0),["power"]=true,["water"]=true}},new Godot.Collections.Array(),System.Array.Empty<double>());
        for(int i=0;i<75;i++)h.Tick(.001,System.Array.Empty<long>());
        h.Tick(86400,System.Array.Empty<long>());h.Tick(86400,System.Array.Empty<long>());
        int At(long id)=>p.ExportState()["households"].AsGodotArray().Count(v=>v.AsGodotDictionary()["home_id"].AsInt64()==id);
        Check(At(1)==5,"T3 no environmental moves before third consecutive day");
        var checkpoint=p.ExportCityCheckpoint();using var restored=new PopulationState();restored.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());
        restored.ImportState(checkpoint["people"].AsGodotArray(),checkpoint["households"].AsGodotArray(),checkpoint["workplaces"].AsGodotDictionary());restored.ImportTaxCheckpoint(checkpoint["tax_policy"].AsGodotDictionary());restored.SyncPacked(buildings);
        using var restoredHappiness=new HappinessCore();restoredHappiness.BindPopulation(restored);restoredHappiness.ImportCityCheckpoint(h.ExportCityCheckpoint());
        restoredHappiness.Tick(86400,System.Array.Empty<long>());
        Check(restored.ExportState()["households"].AsGodotArray().Count(v=>v.AsGodotDictionary()["home_id"].AsInt64()==2)==1,"T3 restore preserves two-day moving streak");
        h.Tick(86400,System.Array.Empty<long>());Check(At(1)==4&&At(2)==1,"T3 third low day moves ceil twenty percent to better target");
        var recovered=new System.Collections.Generic.Dictionary<long,PopulationState.HousingCondition>{{1,new(5,60,0,0)},{2,new(1,50,50,50)}};
        p.ApplyHousingHappiness(4,recovered);Check(At(1)==4,"T3 stage five exact retention threshold stops moves");
        recovered[1]=new(5,59,0,0);p.ApplyHousingHappiness(5,recovered);p.ApplyHousingHappiness(6,recovered);Check(At(1)==4,"T3 recovery resets consecutive low-day streak");
        p.ApplyHousingHappiness(7,recovered);Check(At(1)==3,"T3 renewed third low day resumes migration");p.ApplyHousingHappiness(7,recovered);Check(At(1)==3,"T3 repeated migration boundary idempotent");
        recovered[2]=new(1,0,0,50);p.ApplyHousingHappiness(8,recovered);Check(At(1)==3,"T3 employed households stay when no strictly better target exists");
        restored.GetRng().Dispose();p.GetRng().Dispose();
        PovertyTests();
        WorkplaceMovingTests();
    }
    private void WorkplaceMovingTests()
    {
        using var p=new PopulationState();p.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());p.ConfigureTaxPolicy(new D{["enabled"]=true});
        var person=new D{["id"]=1,["household_id"]=1,["education"]=0,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=2,["job_stage"]=0};
        long[] buildings={1,0,2,1,2,1,2,1,3,1,2,1};p.ImportState(new Godot.Collections.Array{person},new Godot.Collections.Array{new D{["id"]=1,["home_id"]=1}},new D());p.SyncPacked(buildings);p.MatchJobs();p.AssessTaxesThroughDay(1,buildings);
        var conditions=new System.Collections.Generic.Dictionary<long,PopulationState.HousingCondition>{{1,new(1,50,50,80)},{2,new(1,0,0,10)},{3,new(1,50,50,50)}};
        for(int day=1;day<=3;day++)p.ApplyHousingHappiness(day,conditions);
        Check(p.ExportState()["people"].AsGodotArray()[0].AsGodotDictionary()["workplace_id"].AsInt64()==3,"T3 unhappy workplace transfers worker to better eligible vacancy");
        Check(p.WorkplaceInfo(2)["filled"].AsGodotArray().All(v=>v.AsInt64()==0),"T3 vacant workplace retains building but no workers");
        p.SetNextPerson(10);p.AddPerson(1,0,25,"fixture");p.MatchJobs();
        Check(p.WorkplaceInfo(2)["filled"].AsGodotArray().All(v=>v.AsInt64()==0),"T3 newly empty unhappy workplace cannot immediately refill");
        p.GetRng().Dispose();
    }
    private void PovertyTests()
    {
        using var p=new PopulationState();p.Configure(Json.ParseString(FileAccess.GetFileAsString("res://core/population_config.json")).AsGodotDictionary());p.ConfigureTaxPolicy(new D{["enabled"]=true});
        var person=new D{["id"]=1,["household_id"]=1,["education"]=0,["age_years"]=25.0,["origin"]="fixture",["workplace_id"]=-1,["job_stage"]=-1};
        long[] buildings={1,0,2,1,2,0,2,1};p.ImportState(new Godot.Collections.Array{person},new Godot.Collections.Array{new D{["id"]=1,["home_id"]=1}},new D());p.SyncPacked(buildings);p.AssessTaxesThroughDay(1,buildings);
        var conditions=new System.Collections.Generic.Dictionary<long,PopulationState.HousingCondition>{{1,new(1,20,0,80)},{2,new(1,0,0,10)}};
        for(int day=1;day<=3;day++)p.ApplyHousingHappiness(day,conditions);
        Check(p.ExportState()["households"].AsGodotArray()[0].AsGodotDictionary()["home_id"].AsInt64()==2,"T3 no income moves to lower infrastructure even without happy target");
        for(int day=4;day<=10;day++)p.ApplyHousingHappiness(day,conditions);
        Check(p.Stats()["population"].AsInt64()==0&&p.Stats()["households"].AsInt64()==0,"T3 repeated poverty after fringe reset departs cleanly");
        p.SetNextPerson(10);p.SetNextHousehold(10);p.AdvancePacked(48,buildings);p.MatchJobs();
        Check(p.Stats()["population"].AsInt64()==0,"T3 empty low-target housing cannot instantly refill without jobs");
        conditions[1]=new(1,100,100,80);conditions[2]=new(1,100,100,10);p.ApplyHousingHappiness(11,conditions);p.AdvancePacked(48,buildings);p.MatchJobs();
        Check(p.Stats()["population"].AsInt64()==0,"T3 recovered vacant houses cannot recruit unemployed replacements without jobs");
        Check(p.GetTaxStatus()["moving"].AsGodotDictionary()["departed_households"].AsInt64()==1,"T3 departure statistics published");
        var policy=p.GetTaxPolicy();Check(policy.ContainsKey("fringe_infrastructure_weights"),"T3 missing infrastructure coefficients are reversible policy values");
        Check(policy.ContainsKey("workplace_low_days"),"T3 unspecified workplace persistence duration is reversible policy");
        var settled=typeof(PopulationState).GetMethod("SettleHouseholdPayment",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
        Check(settled!=null,"T3 limited-cash payment primitive available");
        if(settled!=null){var paid=((decimal Cash,decimal Tax,decimal Goods))settled.Invoke(null,new object[]{1m,2m,8m,8m})!;Check(paid.Cash==0&&paid.Tax==3&&paid.Goods==0,"T3 short tax paid before necessities, never negative cash");}
        person["workplace_id"]=2;person["job_stage"]=0;p.ImportState(new Godot.Collections.Array{person},new Godot.Collections.Array{new D{["id"]=1,["home_id"]=-1}},new D());
        long[] homeless={2,1,2,1};p.SyncPacked(homeless);p.AssessTaxesThroughDay(2,homeless);
        Check(p.GetHouseholdFinances(1)["cash"].AsDouble()==22,"T3 displaced household still earns wages and consumes without residential tax");
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
        AssessmentTests(p);CommutingTests();HouseholdFinanceTests();MovingTests();
        p.GetRng().Dispose();return new D{["checks"]=checks,["failures"]=failures};
    }
}
