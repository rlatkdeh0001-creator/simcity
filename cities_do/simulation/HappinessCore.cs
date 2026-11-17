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
        RequireBackgroundOwner();
        var snapshot=new ConfigurationSnapshot(config["goods"].AsDouble(),config["commute"].AsDouble(),
            config["garbage"].AsDouble(),config["tax"].AsDouble(),(int)config["fire_buildings_per_incident"].AsInt64());
        if(_backgroundEnabled&&!IsBackgroundWorker)
        {_mainConfiguration=snapshot;_backgroundCommands.Add(new ConfigureCommand(snapshot));return;}
        ApplyConfiguration(snapshot);
    }
    private void ApplyConfiguration(ConfigurationSnapshot config)
    {_goods=config.Goods;_commute=config.Commute;_garbage=config.Garbage;_tax=config.Tax;_fireMultiplier=config.FireMultiplier;_targetCache.Clear();}
    private static double Number(D d,string key)=>d.TryGetValue(key,out var v)?v.AsDouble():0;
    public D Score(D input)
    {
        RequireBackgroundOwner();
        var config=_backgroundEnabled&&!IsBackgroundWorker?_mainConfiguration:new ConfigurationSnapshot(_goods,_commute,_garbage,_tax,_fireMultiplier);
        var factors=new D {["base"]=20.0,["money"]=-10+30*Math.Clamp(Number(input,"employment"),0,1),
            ["goods"]=input.ContainsKey("goods")?Math.Clamp(Number(input,"goods"),-15,10):config.Goods,["garbage"]=config.Garbage,["tax"]=input.ContainsKey("tax")?Math.Clamp(Number(input,"tax"),-10,0):config.Tax,
            ["electricity"]=0.0,["water"]=0.0};
        foreach(string key in new[]{"health","police","fire","education"})factors[key]=Math.Clamp(Number(input,key),0,10);
        factors["park"]=Math.Clamp(Number(input,"park"),0,5);factors["housing"]=Math.Clamp(Number(input,"housing"),0,5);
        factors["pollution_noise"]=Math.Clamp(Number(input,"pollution_noise"),-15,0);
        double target=0;foreach(var value in factors.Values)target+=value.AsDouble();
        if(!input["power"].AsBool()||!input["water"].AsBool())target=0;
        return new D {["target"]=Math.Clamp(target,0,100),["factors"]=factors};
    }
}
