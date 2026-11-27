using System;
using System.Collections.Generic;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    private readonly Dictionary<long,(bool Initialized,double Actual,double Target,double Housing,double? Since,D Factors)> _cityReadSources=new();
    // Called only by the detached city's Godot.Thread, with nested background disabled.
    public HappinessReadView CaptureCityReadView()
    {
        if(_backgroundEnabled)throw new InvalidOperationException("Full-city worker must use synchronous happiness");
        RefreshGroups();
        foreach(var pair in _states)
        {
            var s=pair.Value;
            var now=(s.Initialized,s.Actual,s.Target,s.Housing,s.Since,s.Factors);
            if(!_cityReadSources.TryGetValue(pair.Key,out var old)||old.Initialized!=s.Initialized||old.Actual!=s.Actual||old.Target!=s.Target||old.Housing!=s.Housing||old.Since!=s.Since||!ReferenceEquals(old.Factors,s.Factors))
                _backgroundDirtyStates.Add(pair.Key);
            _cityReadSources[pair.Key]=now;
        }
        // Removed source entries must not pin native factor dictionaries.
        var removed=new List<long>();foreach(long id in _cityReadSources.Keys)if(!_states.ContainsKey(id))removed.Add(id);
        foreach(long id in removed)_cityReadSources.Remove(id);
        var published=CapturePublishedBackground();_workerBackground=published;
        return new HappinessReadView {AverageValue=published.CityHappiness,
            InspectValue=id=>ReadCityInspect(published,id),PreviewValue=id=>ReadCityPreview(published,id)};
    }
    private static D ReadCityInspect(PublishedBackground p,long id)
    {
        if(!p.States.TryGetValue(id,out var s))return new D();
        return new D {["initialized"]=s.Initialized,["actual"]=s.Actual,["target"]=s.Target,["housing"]=s.Housing,
            ["held_seconds"]=s.Since.HasValue?Math.Max(0,p.Elapsed-s.Since.Value):0,["factors"]=ThawFactors(s.Factors)};
    }
    private static D ReadCityPreview(PublishedBackground p,long id)=>p.Previews.TryGetValue(id,out var s)?new D {["target"]=s.Target,["factors"]=ThawFactors(s.Factors)}:new D();
}
