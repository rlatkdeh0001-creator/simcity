using System;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    // Idle checkpoint includes stale scoring world + exact service assignments. Rebuilding
    // from current geometry alone would change the oracle's delayed rebuild semantics.
    public D ExportCityCheckpoint()
    {
        RequireBackgroundMain();
        if(_pendingBackground!=null)throw new InvalidOperationException("Publish happiness before checkpoint capture");
        // A boundary can enqueue upgrade acknowledgements after publishing its job.
        // Drain those typed commands without another tick before changing ownership.
        if(_backgroundCommands.Count!=0)
        {
            _backgroundWorkerContext.Value=true;
            try
            {
                foreach(var command in _backgroundCommands)
                    switch(command)
                    {
                        case ConfigureCommand config:ApplyConfiguration(config.Configuration);break;
                        case WorldCommand world:ApplyWorld(world.World);break;
                        case AcknowledgeCommand ack:Acknowledge(ack.Id,ack.Success,ack.Level);break;
                    }
                _backgroundCommands.Clear();
            }
            finally{_backgroundWorkerContext.Value=false;}
        }
        var buildings=new A();var facilities=new A();var states=new D();var assignments=new A();
        foreach(var b in _buildings.Values)
            buildings.Add(new D {["id"]=b.Id,["road"]=b.Road,["level"]=b.Level,["zone"]=b.Zone,["position"]=b.Position,["polygon"]=b.Polygon,
                ["power"]=b.Power,["water"]=b.Water,["noise"]=b.Noise,["occupants"]=b.Fixture.Count,["eligible"]=b.Fixture.Eligible,["employed"]=b.Fixture.Employed,
                ["students"]=new A(b.Fixture.Students.Select(n=>Variant.From(n)))});
        foreach(var f in _facilities.Values)
            facilities.Add(new D {["id"]=f.Id,["road"]=f.Road,["kind"]=f.Kind,["school_stage"]=f.School,
                ["capacity"]=f.Capacity,["position"]=f.Position,["polygon"]=f.Polygon});
        foreach(var pair in _states)
        {
            var s=pair.Value;states[pair.Key]=new D {["initialized"]=s.Initialized,["pending"]=s.Pending,["level"]=s.Level,["actual"]=s.Actual,["target"]=s.Target,
                ["housing"]=s.Housing,["since"]=s.Since.HasValue?Variant.From(s.Since.Value):default,["factors"]=s.Factors.Duplicate(true)};
        }
        foreach(var p in _assignments)assignments.Add(new D {["building"]=p.Key.Building,["kind"]=p.Key.Kind,["school"]=p.Key.School,["facility"]=p.Value});
        return new D {["configuration"]=new D {["goods"]=_goods,["commute"]=_commute,["garbage"]=_garbage,["tax"]=_tax,["fire_buildings_per_incident"]=_fireMultiplier},
            ["buildings"]=buildings,["facilities"]=facilities,["roads"]=(double[])_indexedRoads.Clone(),["states"]=states,["assignments"]=assignments,
            ["elapsed"]=_elapsed,["next_day"]=_nextDay,["bucket"]=_bucket,["assigned"]=_assigned,["city_happiness"]=_cityHappiness};
    }
    public void ImportCityCheckpoint(D checkpoint)
    {
        if(_backgroundEnabled)throw new InvalidOperationException("Import requires a fresh synchronous core");
        Configure(checkpoint["configuration"].AsGodotDictionary());
        SetWorld(checkpoint["buildings"].AsGodotArray(),checkpoint["facilities"].AsGodotArray(),checkpoint["roads"].AsFloat64Array());
        // Checkpoint capacities are already scaled; preserve their exact binary values.
        foreach(var item in checkpoint["facilities"].AsGodotArray())
        {var d=item.AsGodotDictionary();_facilities[d["id"].AsInt64()].Capacity=d["capacity"].AsDouble();}
        _states.Clear();var states=checkpoint["states"].AsGodotDictionary();
        foreach(var key in states.Keys)
        {
            var d=states[key].AsGodotDictionary();
            _states[key.AsInt64()]=new State {Initialized=d["initialized"].AsBool(),Pending=d["pending"].AsBool(),Level=(int)d["level"].AsInt64(),
                Actual=d["actual"].AsDouble(),Target=d["target"].AsDouble(),Housing=d["housing"].AsDouble(),
                Since=d["since"].VariantType==Variant.Type.Nil?null:d["since"].AsDouble(),Factors=d["factors"].AsGodotDictionary().Duplicate(true)};
        }
        _assignments.Clear();foreach(var item in checkpoint["assignments"].AsGodotArray())
        {var d=item.AsGodotDictionary();_assignments[(d["building"].AsInt64(),d["kind"].AsString(),(int)d["school"].AsInt64())]=d["facility"].AsInt64();}
        _elapsed=checkpoint["elapsed"].AsDouble();_nextDay=checkpoint["next_day"].AsDouble();_bucket=(int)checkpoint["bucket"].AsInt64();
        _assigned=checkpoint["assigned"].AsBool();_cityHappiness=checkpoint["city_happiness"];
        _targetCache.Clear();_cityReadSources.Clear();
    }
}
