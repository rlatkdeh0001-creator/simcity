extends RefCounted
var managed_view
var _average:Variant
func _init(view,average:Variant):managed_view=view;_average=average
func CityHappiness()->Variant:return _average
func Inspect(id:int)->Dictionary:return managed_view.Inspect(id)
func Preview(id:int)->Dictionary:return managed_view.Preview(id)
# Explicit boot only, never a normal main frame/boundary.
static func capture_boot(view):
 return load("res://core/native_happiness_view.gd").new(view,view.CityHappiness())
