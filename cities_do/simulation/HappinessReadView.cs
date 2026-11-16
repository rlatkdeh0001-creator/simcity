using System;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class HappinessReadView:RefCounted
{
    // Each delegate closes over an immutable publication, NEVER a HappinessCore.
    internal Func<long,D> InspectValue=null!,PreviewValue=null!;
    internal Variant AverageValue;
    public D Inspect(long id)=>InspectValue(id);
    public D Preview(long id)=>PreviewValue(id);
    public Variant CityHappiness()=>AverageValue;
}
