extends RefCounted
## Cached scalar methods are native GDScript; only ID queries enter the retained CLR view.
var managed_view
var scalars:Dictionary
func _init(view,envelope:Dictionary):managed_view=view;scalars=envelope
func Stats()->Dictionary:return scalars.stats.duplicate(true)
func Demand()->Dictionary:return scalars.demand.duplicate(true)
func GetNextPerson()->int:return int(scalars.next_person)
func GetNextHousehold()->int:return int(scalars.next_household)
func GetElapsedDays()->float:return float(scalars.elapsed_days)
func GetBirthDay()->int:return int(scalars.birth_day)
func GetRngSeed()->int:return int(scalars.rng_seed)
func GetRngState()->int:return int(scalars.rng_state)
func WorkplaceInfo(id:int)->Dictionary:return managed_view.WorkplaceInfo(id)
# Explicit boot only: caller has not yet entered the frame loop.
static func capture_boot(view):
 return load("res://core/native_population_view.gd").new(view,{"stats":view.Stats(),"demand":view.Demand(),"next_person":view.GetNextPerson(),"next_household":view.GetNextHousehold(),"elapsed_days":view.GetElapsedDays(),"birth_day":view.GetBirthDay(),"rng_seed":view.GetRngSeed(),"rng_state":view.GetRngState()})
