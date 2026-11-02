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
	for angle in [0.0,PI/2,PI,PI*1.5,.37,PI/4,2.17]:
		for reverse in [false,true]:
			var city=Model.new(100,100)
			var along:=Vector2.from_angle(angle)
			var points:=PackedVector2Array([Vector2(50,50)-along*20,Vector2(50,50)+along*20])
			if reverse:points.reverse()
			check(city.add_road(points).ok,"road angle %.2f reverse %s"%[angle,reverse])
			var sides:={}
			for frame in city.zoning_grid.frames.values():
				if sides.has(frame.side):continue
				var result: Dictionary=city.add_building_at(frame.origin+frame.along*.5+frame.outward*.5,"residential",100)
				if not result.ok:continue
				var b: Dictionary=result.building
				sides[frame.side]=true
				check(city.front_direction(b).distance_to(-frame.outward)<.00001,"front faces road on side %d"%frame.side)
				check(b.front_road_id==frame.road_index,"stable frontage road ID")
				city.config.size_weights={8:0.0,4:1.0,2:0.0}
				var direction: Vector2=city.front_direction(b)
				check(city.upgrade_chain(b.id).ok and city.front_direction(b)==direction,"growth preserves frontage")
			check(sides.size()==2,"both sides support road-facing construction")
	var city=Model.new(60,60)
	city.add_road(PackedVector2Array([Vector2(2,20),Vector2(50,20)]))
	var b: Dictionary=city.place_catalog_building("mansion-a-4x4-4f",10,14).building
	check(city.front_direction(b)==Vector2.DOWN and city.supports_static_sprite(b),"original front image faces southern road")
	city.add_road(PackedVector2Array([Vector2(2,12),Vector2(50,12)]))
	check(city.front_direction(b)==Vector2.DOWN and b.front_road_id==0,"corner/second road does not flip an existing frontage")
	city.demolish("road",0)
	check(city.front_direction(b)==Vector2.UP and b.front_road_id==1,"removed frontage rebinds to surviving local road")
	check(not city.supports_static_sprite(b),"opposite front never uses fixed original image")
	var previous: Vector2=city.front_direction(b)
	city.demolish("road",1)
	check(b.front_road_id==-1 and city.front_direction(b)==previous,"disconnected building retains direction and lot")
	var other=Model.new(50,50)
	other.add_road(PackedVector2Array([Vector2(2,22),Vector2(48,22)]),"highway")
	other.add_road(PackedVector2Array([Vector2(2,14),Vector2(48,14)]))
	var house: Dictionary=other.place_catalog_building("mansion-a-4x4-4f",10,17).building
	check(house.front_road_id==1 and other.front_direction(house)==Vector2.UP,"highways cannot become entrance roads")
	for asset in city.catalog.entries:
		check(Vector2(asset.front_axis[0],asset.front_axis[1])==Vector2.DOWN and ResourceLoader.exists(asset.model),asset.id+" has a metre-based real directional model")
		var model=load(asset.model).instantiate()
		var extent:=model_bounds(model,Transform3D.IDENTITY)
		check(absf(extent.end.y-float(asset.height_m))<.001,asset.id+" exported height remains in metres")
		model.free()

	print("RESULT ",checks-failures,"/",checks," frontage checks passed")
	quit(1 if failures else 0)

func model_bounds(node: Node,parent: Transform3D) -> AABB:
	var transform:=parent
	if node is Node3D:transform=parent*node.transform
	var extent:=AABB()
	if node is MeshInstance3D:extent=transform*node.mesh.get_aabb()
	for child in node.get_children():
		var child_extent:=model_bounds(child,transform)
		if child_extent.size!=Vector3.ZERO:extent=child_extent if extent.size==Vector3.ZERO else extent.merge(child_extent)
	return extent
