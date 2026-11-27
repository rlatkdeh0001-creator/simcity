extends "res://tests/test_lot_rules.gd"
var baseline
func make_city(seed_value:int=42):
 if baseline==null:
  baseline=GDScript.new();baseline.source_code=FileAccess.get_file_as_string("D:/project/simcity/docs/population-optimization-validation/reference/city_model.gd.txt");assert(baseline.reload()==OK)
 var city=baseline.new(100,100,seed_value);city.population_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 return city
