using Godot;

[GlobalClass]
public partial class PopulationCore : RefCounted
{
    private readonly RandomNumberGenerator _rng = new();
    public string Echo(string value) => value;
    public void Initialize(long seed) => _rng.Seed = unchecked((ulong)(seed ^ 0x71294));
    public RandomNumberGenerator GetRng() => _rng;
    public double ValidationRandom() => _rng.Randf();
}
