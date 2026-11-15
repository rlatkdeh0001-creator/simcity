using System;
using Godot;
using D=Godot.Collections.Dictionary;

[GlobalClass]
public partial class HappinessCore:RefCounted
{
    private double _goods=10,_commute,_garbage,_tax;
    private int _fireMultiplier=100;
    public void Configure(D config)
    {
        _goods=config["goods"].AsDouble();_commute=config["commute"].AsDouble();
        _garbage=config["garbage"].AsDouble();_tax=config["tax"].AsDouble();
        _fireMultiplier=(int)config["fire_buildings_per_incident"].AsInt64();
    }
    private static double Number(D d,string key)=>d.TryGetValue(key,out var v)?v.AsDouble():0;
    public D Score(D input)
    {
        var factors=new D {["base"]=20.0,["money"]=-10+30*Math.Clamp(Number(input,"employment"),0,1),
            ["goods"]=_goods,["commute"]=_commute,["garbage"]=_garbage,["tax"]=_tax,
            ["electricity"]=0.0,["water"]=0.0};
        foreach(string key in new[]{"health","police","fire","education"})factors[key]=Math.Clamp(Number(input,key),0,10);
        factors["park"]=Math.Clamp(Number(input,"park"),0,5);factors["housing"]=Math.Clamp(Number(input,"housing"),0,5);
        factors["pollution_noise"]=Math.Clamp(Number(input,"pollution_noise"),-15,0);
        double target=0;foreach(var value in factors.Values)target+=value.AsDouble();
        if(!input["power"].AsBool()||!input["water"].AsBool())target=0;
        return new D {["target"]=Math.Clamp(target,0,100),["factors"]=factors};
    }
}
