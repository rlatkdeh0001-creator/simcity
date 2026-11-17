using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    // No starting endowment is specified in the design: reversible policy default 0.
    private decimal _initialHouseholdCash, _necessitiesPerPerson=8m;
    private sealed class HouseholdFinance
    {
        internal decimal Cash,Income,Assessed,Paid,GoodsCost,GoodsPaid;
        internal bool Settled;
        internal decimal Ratio=>GoodsCost>0?GoodsPaid/GoodsCost:1;
    }
    private readonly Dictionary<long,HouseholdFinance> _finances=new();
    private HouseholdFinance Finance(long id)
    {
        if(!_finances.TryGetValue(id,out var f))_finances[id]=f=new(){Cash=_initialHouseholdCash};
        return f;
    }
    public D GetHouseholdFinances(long id)
    {
        if(!_households.Any(h=>h.Id==id))return new D();
        var f=Finance(id);
        var d=new D{["cash"]=(double)f.Cash,["income"]=(double)f.Income,["tax_assessed"]=(double)f.Assessed,
            ["tax_paid"]=(double)f.Paid,["tax_arrears"]=(double)(f.Assessed-f.Paid),["goods_cost"]=(double)f.GoodsCost,
            ["goods_paid"]=(double)f.GoodsPaid,["goods_ratio"]=(double)f.Ratio,["settled"]=f.Settled};d.MakeReadOnly();return d;
    }
    private void SettleHouseholds(List<Building> buildings,long days,decimal[] collected)
    {
        var homes=buildings.Where(b=>b.Zone=="residential").ToDictionary(b=>b.Id);
        for(int i=0;i<3;i++)collected[i]=0;
        foreach(var h in _households)
        {
            bool housed=homes.TryGetValue(h.Home,out var home);
            var f=Finance(h.Id);int band=housed?TaxBand(home.Level):-1;
            _families.TryGetValue(h.Id,out var family);
            f.Income=family?.Where(p=>p.Age>=_workingAge&&((p.Work>=0&&_works.ContainsKey(p.Work))||LaborExternal(p))).Sum(ResidentWage)??0;
            f.Assessed=housed?f.Income*_taxRates[band]/100m:0;f.GoodsCost=(family?.Count??0)*_necessitiesPerPerson;
            // Sequential days matter when savings run out. Ordinary worker steps settle one day.
            for(long i=0;i<days;i++)
            {
                (f.Cash,f.Paid,f.GoodsPaid)=SettleHouseholdPayment(f.Cash,f.Income,f.Assessed,f.GoodsCost);if(housed)collected[band]+=f.Paid;
            }
            f.Settled=true;
        }
        RebuildFinanceFactors();InvalidateManagedSnapshots();
    }
    private readonly Dictionary<long,(double Goods,double Tax)> _financeFactors=new();
    private static (decimal Cash,decimal Tax,decimal Goods) SettleHouseholdPayment(decimal savings,decimal income,decimal assessed,decimal necessities)
    {
        decimal available=savings+income,tax=Math.Min(available,assessed);available-=tax;
        decimal goods=Math.Min(available,necessities);return (available-goods,tax,goods);
    }
    private D? _financeSummary;
    internal (double Goods,double Tax) FinanceFactors(long building)=>_taxEnabled?_financeFactors.GetValueOrDefault(building,(10,0)):(10,0);
    private D FinanceSummary()
    {
        if(_financeSummary==null){_financeSummary=new D{["cash"]=0.0,["income"]=0.0,["tax_arrears"]=0.0,["goods_cost"]=0.0,["goods_paid"]=0.0};_financeSummary.MakeReadOnly();}
        return _financeSummary;
    }
    private void RebuildFinanceFactors()
    {
        _financeFactors.Clear();var groups=new Dictionary<long,(double Goods,double Tax,int Count)>();
        decimal cash=0,income=0,arrears=0,cost=0,paid=0;
        void Add(long id,double goods,double tax,int count)
        {if(id<0||count==0)return;var old=groups.GetValueOrDefault(id);groups[id]=(old.Goods+goods*count,old.Tax+tax*count,old.Count+count);}
        foreach(var h in _households)
        {
            if(!_finances.TryGetValue(h.Id,out var f)||!f.Settled)continue;
            cash+=f.Cash;income+=f.Income;arrears+=f.Assessed-f.Paid;cost+=f.GoodsCost;paid+=f.GoodsPaid;
            double goods=-15+25*(double)f.Ratio,tax=f.Paid<f.Assessed?-10:0;
            if(!_families.TryGetValue(h.Id,out var family))continue;
            Add(h.Home,goods,tax,family.Count);foreach(var p in family)Add(p.Work,goods,tax,1);
        }
        foreach(var pair in groups)_financeFactors[pair.Key]=(pair.Value.Goods/pair.Value.Count,pair.Value.Tax/pair.Value.Count);
        _financeSummary=new D{["cash"]=(double)cash,["income"]=(double)income,["tax_arrears"]=(double)arrears,["goods_cost"]=(double)cost,["goods_paid"]=(double)paid};_financeSummary.MakeReadOnly();
    }
    private static D ExportFinance(HouseholdFinance f)=>new(){["cash"]=f.Cash.ToString(System.Globalization.CultureInfo.InvariantCulture),
        ["income"]=f.Income.ToString(System.Globalization.CultureInfo.InvariantCulture),["assessed"]=f.Assessed.ToString(System.Globalization.CultureInfo.InvariantCulture),
        ["paid"]=f.Paid.ToString(System.Globalization.CultureInfo.InvariantCulture),["goods_cost"]=f.GoodsCost.ToString(System.Globalization.CultureInfo.InvariantCulture),
        ["goods_paid"]=f.GoodsPaid.ToString(System.Globalization.CultureInfo.InvariantCulture),["settled"]=f.Settled};
    private D ExportFinances(){var result=new D();foreach(var pair in _finances.OrderBy(p=>p.Key))result[pair.Key]=ExportFinance(pair.Value);return result;}
    private static HouseholdFinance ParseFinance(D d)
    {
        var f=new HouseholdFinance{Cash=ParseTaxExact(d["cash"]),Income=ParseTaxExact(d["income"]),Assessed=ParseTaxExact(d["assessed"]),Paid=ParseTaxExact(d["paid"]),GoodsCost=ParseTaxExact(d["goods_cost"]),GoodsPaid=ParseTaxExact(d["goods_paid"]),Settled=d["settled"].AsBool()};
        if(f.Paid>f.Assessed||f.GoodsPaid>f.GoodsCost)throw new ArgumentException("Invalid household settlement");return f;
    }
    private static Dictionary<long,HouseholdFinance> ParseFinances(D state)
    {var result=new Dictionary<long,HouseholdFinance>();foreach(var key in state.Keys){long id=TaxInteger(key);if(id<0)throw new ArgumentException("Invalid household ID");result.Add(id,ParseFinance(state[key].AsGodotDictionary()));}return result;}
}
