extends "res://bottom_ui.gd"
## Authored review fixture only; the main scene never calls make_town.
func _ready():
 showcase_view=true
 make_town()
 super._ready()
 select_category("power")

func make_town():
 for y in [30,50,70]:
  city.add_road(PackedVector2Array([Vector2(15,y),Vector2(85,y)]),"local",true,4 if y==50 else 2)
 # Existing review examples retain their positions, now with real opposite frontage.
 # Claim their aligned strips before perpendicular review roads, using normal ownership rules.
 for x in [24,55]:city.add_road(PackedVector2Array([Vector2(x,40),Vector2(x+8,40)]))
 for x in [20,50,80]: city.add_road(PackedVector2Array([Vector2(x,20),Vector2(x,80)]))
 var examples := [
  ["small-4x4-a",24,25],["small-4x4-b",32,25],["mansion-a-4x4-4f",40,25],
  ["small-2x2-a",55,27],["small-2x2-b",60,27],["small-4x4-a",66,25],["mansion-b-4x4-4f",72,25],
  ["large-8x8-a",24,31],["mansion-b-4x4-4f",38,31],["small-4x4-a",43,31],
  ["small-2x2-b",24,46],["small-2x2-a",29,46],["small-4x4-b",35,44],["mansion-a-4x4-4f",42,44],
  ["large-8x8-b",55,31],["small-4x4-b",66,31],["small-4x4-a",73,31],
  ["mansion-b-4x4-4f",55,44],["small-2x2-b",64,46],["small-2x2-a",69,46],["small-2x2-b",74,46],
  ["small-4x4-b",24,52],["mansion-a-4x4-4f",32,52],["small-4x4-a",40,52],
  ["small-2x2-a",25,67],["small-4x4-b",32,65],["mansion-b-4x4-4f",40,65],
  ["large-4x4-a",55,52],["small-4x4-a",63,52],["mansion-a-4x4-4f",72,52],
  ["small-4x4-b",55,65],["small-2x2-a",63,67],["small-2x2-b",68,67],["small-4x4-a",73,65]]
 for entry in examples:
  var result: Dictionary=city.place_catalog_building(entry[0],entry[1],entry[2])
  if not result.ok: push_error("Invalid UI preview lot: %s %s" % [entry[0],result.reason])
 city.add_power_plant(Vector2(17,44),1500)
 city.power.add_wire(PackedVector2Array([Vector2(72,180),Vector2(320,180)]))
 city.power.add_wire(PackedVector2Array([Vector2(128,180),Vector2(128,116)]))
 city.add_water_facility(Vector2(17,60),"water",1000)
 city.add_water_facility(Vector2(81,60),"sewage",2400)
 city.water.add_pipe(PackedVector2Array([Vector2(72,244),Vector2(328,244)]))
 city.water.add_pipe(PackedVector2Array([Vector2(128,244),Vector2(128,116)]))
