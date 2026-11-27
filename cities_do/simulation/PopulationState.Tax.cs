using System;
using System.Linq;
using System.Globalization;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    private bool _taxEnabled;
    private int[] _taxRates=Enumerable.Repeat(9,9).ToArray();
    private decimal[] _taxWages={30m,40m,55m,75m,100m};
    private decimal _taxDemandSlope=.06m;
    private static decimal TaxNumber(Variant v)
    {
        if(v.VariantType!=Variant.Type.Int&&v.VariantType!=Variant.Type.Float)throw new ArgumentException("Expected numeric tax value");
        double n=v.AsDouble();if(!double.IsFinite(n)||n<0||n>1000000000)throw new ArgumentException("Invalid tax value");return (decimal)n;
    }
    private static int TaxZone(string zone){int i=System.Array.IndexOf(Zones,zone);return i<0?throw new ArgumentException("Unknown tax zone"):i;}
    private static int TaxBand(int level)=>level is <1 or >5?throw new ArgumentException("Tax level must be 1..5"):level<=2?0:level<=4?1:2;
    public void ConfigureTaxPolicy(D options)
    {
        var rates=(int[])_taxRates.Clone();var wages=(decimal[])_taxWages.Clone();decimal slope=_taxDemandSlope;
        decimal initial=options.TryGetValue("initial_household_cash",out var cash)?TaxNumber(cash):_initialHouseholdCash;
        decimal needs=options.TryGetValue("necessities_per_person",out var goods)?TaxNumber(goods):_necessitiesPerPerson;
        var infrastructure=(double[])_fringeInfrastructureWeights.Clone();
        if(options.TryGetValue("fringe_infrastructure_weights",out var iw)){var a=iw.AsGodotArray();if(a.Count!=10)throw new ArgumentException("Ten infrastructure weights required");for(int i=0;i<10;i++)infrastructure[i]=(double)TaxNumber(a[i]);if(infrastructure.Sum()<=0)throw new ArgumentException("Positive infrastructure weight sum required");}
        double access=options.TryGetValue("fringe_access_metres",out var am)?(double)TaxNumber(am):_fringeAccessMetres;
        double workFraction=options.TryGetValue("workplace_move_fraction",out var wf)?(double)TaxNumber(wf):_workplaceMoveFraction;
        if(workFraction>1)throw new ArgumentException("Workplace move fraction must be 0..1");
        decimal workDays=options.TryGetValue("workplace_low_days",out var wd)?TaxNumber(wd):_workplaceLowDays;
        if(workDays<1||workDays>365||workDays!=decimal.Truncate(workDays))throw new ArgumentException("Workplace low days must be integer 1..365");
        bool enabled=options.TryGetValue("enabled",out var e)?e.AsBool():_taxEnabled;
        if(options.TryGetValue("rates",out var r)){var a=r.AsGodotArray();if(a.Count!=9)throw new ArgumentException("Nine tax rates required");for(int i=0;i<9;i++){decimal n=TaxNumber(a[i]);if(n>20||n!=decimal.Truncate(n))throw new ArgumentException("Tax rates must be integers 0..20");rates[i]=(int)n;}}
        if(options.TryGetValue("wages",out var w)){var a=w.AsGodotArray();if(a.Count!=5)throw new ArgumentException("Five education wages required");for(int i=0;i<5;i++)wages[i]=TaxNumber(a[i]);}
        if(options.TryGetValue("demand_slope",out var s))slope=TaxNumber(s);
        _initialHouseholdCash=initial;_necessitiesPerPerson=needs;
        _fringeInfrastructureWeights=infrastructure;_fringeAccessMetres=access;_workplaceMoveFraction=workFraction;
        _workplaceLowDays=(int)workDays;
        _taxRates=rates;_taxWages=wages;_taxDemandSlope=slope;_taxEnabled=enabled;InvalidateManagedSnapshots();
    }
    private decimal TaxMultiplier(string zone)=>_taxEnabled?Math.Clamp(1-_taxDemandSlope*(_taxRates[TaxZone(zone)*3]-9),0,1.5m):1;
    public double TaxDemandMultiplier(string zone)=>(double)TaxMultiplier(zone);
    // Floor AFTER scaling existing new-building counts; never change their unit.
    public int TaxNewBuildingDemand(string zone,int count)=>checked((int)decimal.Floor(Math.Max(0,count)*TaxMultiplier(zone)));
    public double TaxGrowthThreshold(string zone,int targetLevel,double baseline)
    {
        int index=TaxZone(zone)*3+TaxBand(targetLevel);
        return baseline+(_taxEnabled&&targetLevel>=3?Math.Clamp((_taxRates[index]-9)*2,0,20):0);
    }
    public D GetTaxPolicy()
    {
        var rates=ToArray(_taxRates);rates.MakeReadOnly();var wages=new A();foreach(var w in _taxWages)wages.Add((double)w);wages.MakeReadOnly();
        var weights=new A();foreach(var weight in _fringeInfrastructureWeights)weights.Add(weight);weights.MakeReadOnly();
        var d=new D{["enabled"]=_taxEnabled,["rates"]=rates,["wages"]=wages,["initial_household_cash"]=(double)_initialHouseholdCash,["necessities_per_person"]=(double)_necessitiesPerPerson,["demand_slope"]=(double)_taxDemandSlope,["fringe_infrastructure_weights"]=weights,["fringe_access_metres"]=_fringeAccessMetres,["workplace_move_fraction"]=_workplaceMoveFraction,["workplace_low_days"]=_workplaceLowDays};d.MakeReadOnly();return d;
    }
}
