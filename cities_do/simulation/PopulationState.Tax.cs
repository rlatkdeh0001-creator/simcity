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
        bool enabled=options.TryGetValue("enabled",out var e)?e.AsBool():_taxEnabled;
        if(options.TryGetValue("rates",out var r)){var a=r.AsGodotArray();if(a.Count!=9)throw new ArgumentException("Nine tax rates required");for(int i=0;i<9;i++){decimal n=TaxNumber(a[i]);if(n>20||n!=decimal.Truncate(n))throw new ArgumentException("Tax rates must be integers 0..20");rates[i]=(int)n;}}
        if(options.TryGetValue("wages",out var w)){var a=w.AsGodotArray();if(a.Count!=5)throw new ArgumentException("Five education wages required");for(int i=0;i<5;i++)wages[i]=TaxNumber(a[i]);}
        if(options.TryGetValue("demand_slope",out var s))slope=TaxNumber(s);
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
        var d=new D{["enabled"]=_taxEnabled,["rates"]=rates,["wages"]=wages,["demand_slope"]=(double)_taxDemandSlope};d.MakeReadOnly();return d;
    }
}
