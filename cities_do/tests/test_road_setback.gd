extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String):
	checks+=1
	if value:print("PASS ",label)
	else:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
	for gap in [0.0,1.49,1.5,1.51,4.0,8.0]:
		var city=Model.new(50,50)
		var y: float=20.0+gap/4
		city.add_road(PackedVector2Array([Vector2(2,y),Vector2(48,y)]))
		var result: Dictionary=city.add_building(10,17)
		check(result.ok==(gap<=1.5),"%.2fm boundary gap correctly accepted/rejected"%gap)
	for angle in [0.0,.37,PI/2]:
		var city=Model.new(100,100)
		var along:=Vector2.from_angle(angle)
		city.add_road(PackedVector2Array([Vector2(50,50)-along*20,Vector2(50,50)+along*20]))
		for side in [-1,1]:
			var selected:={}
			for frame in city.zoning_grid.frames.values():
				if frame.side==side:selected=frame;break
			for depth in range(4):
				var error: String=city.parcel_placement_error(selected,0,depth,2)
				check((error=="")==(depth==0),"only road-adjacent depth is valid %.2f/%d/%d"%[angle,side,depth])
			var result: Dictionary=city.add_building_at(selected.origin+selected.along*.5+selected.outward*.5,"residential",100)
			check(result.ok,"adjacent lot built")
			if result.ok:
				city.config.size_weights={8:1.0,4:0.0,2:0.0}
				check(city.upgrade_chain(result.building.id).ok and result.building.v==0,"large growth keeps its frontage row")
				city.config.size_weights={8:0.0,4:0.0,2:1.0}
				var old_shape: PackedVector2Array=city.footprint(result.building)
				var smaller: Dictionary=city.upgrade_chain(result.building.id)
				check(result.building.v==0 and (smaller.ok or city.footprint(result.building)==old_shape),"shrink either keeps frontage or leaves the original lot untouched")
	var endpoint=Model.new(40,40)
	endpoint.add_road(PackedVector2Array([Vector2(2,20),Vector2(10,20)]))
	check(not endpoint.add_building(10,17).ok,"a close corner at a road endpoint does not grant frontage")
	print("RESULT ",checks-failures,"/",checks," setback checks passed")
	quit(1 if failures else 0)
