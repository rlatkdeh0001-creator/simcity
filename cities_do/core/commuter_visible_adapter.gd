extends RefCounted
## Main-side read-only compatibility adapter for existing renderer simulation API.
## Accept only published detached snapshots; do not call the runtime from main.
var vehicles: Array = []
var game_seconds := 0.0
var tracked := {}
func accept(snapshot: Dictionary):
 vehicles=snapshot.get("vehicles",[]).duplicate(true)
 game_seconds=float(snapshot.get("game_seconds",0))
 tracked=snapshot.get("tracked",{}).duplicate(true)
func position(vehicle: Dictionary) -> Vector2:return vehicle.position_m
func heading(vehicle: Dictionary) -> Vector2:return vehicle.heading
func snapshot() -> Dictionary:return {"vehicles":vehicles.duplicate(true),"game_seconds":game_seconds,"tracked":tracked.duplicate(true)}
