extends SceneTree
const Model=preload("res://core/city_model.gd")
const Parcels=preload("res://core/road_parcels.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String):
	checks+=1
	if value:print("PASS ",label)
	else:
		failures+=1
		push_error(label)
func _initialize():call_deferred("run")
func run():
	var city=Model.new(100,100)
	city.add_road(PackedVector2Array([Vector2(15,20),Vector2(65,55)]),"local",true,2)
	var all_rect:=true
	var all_safe:=true
	for parcel in city.zoning_grid.parcels.values():
		var frame: Dictionary=parcel.frame
		if absf(Vector2(frame.along).dot(frame.outward))>0.00001:all_rect=false
		if absf(Vector2(frame.along).length()-1)>0.00001 or absf(Vector2(frame.outward).length()-1)>0.00001:all_rect=false
		if absf(Parcels.area(parcel.polygon)-1)>0.0001:all_rect=false
		if city._polygon_error(parcel.polygon,-1,false)!="":all_safe=false
	check(all_rect and city.zoning_grid.count()>0,"diagonal road creates square cells orthogonal in world space")
	check(all_safe,"no road-local cell crosses road or map boundary")
	var chosen: Dictionary={}
	for frame in city.zoning_grid.frames.values():
		if frame.columns==8 and city.parcel_placement_error(frame,0,0,2)=="":
			chosen=frame;break
	check(not chosen.is_empty(),"diagonal straight blocks retain full eight-cell frontage")
	if not chosen.is_empty():
		var offset: Vector2=chosen.outward*10
		city.add_road(PackedVector2Array([city.roads[0].points[0]+offset,city.roads[0].points[-1]+offset]))
		var point: Vector2=chosen.origin+chosen.along*.5+chosen.outward*.5
		var result: Dictionary=city.add_building_at(point,"residential",100)
		check(result.ok,"new building snaps to road-local 2x2 lot")
		if result.ok:
			var building: Dictionary=result.building
			check(building.has("frame") and building.size==2 and city.building_at(point).id==building.id,"rotated building footprint is used for picking")
			check(not city.add_building_at(point).ok,"rotated lot overlap rejected")
			city.config.size_weights={8:1.0,4:0.0,2:0.0}
			for stage in range(2,5):city.upgrade_chain(building.id)
			var grown: Dictionary=city.upgrade_chain(building.id)
			check(grown.ok and building.size==8,"8x8 upgrade stays square across opposing aligned four-cell road strips")
			check(city._polygon_error(city.footprint(building),building.id)=="","rotated growth preserves road/neighbor/boundary clearance")
			var center:=Vector2.ZERO
			for p in city.footprint(building):center+=p/4.0
			check(not city.add_road(PackedVector2Array([center-Vector2(10,0),center+Vector2(10,0)])).ok,"new road cannot cut rotated building")
			check(not city.supports_static_sprite(building),"fixed-view asset is not falsely warped to represent rotated architecture")
	var curve=Model.new(100,100)
	var points:=PackedVector2Array()
	for angle in range(-80,31,5):points.append(Vector2(45,55)+Vector2.from_angle(deg_to_rad(angle))*20)
	curve.add_road(points)
	var directions:={}
	var any_overlap:=false
	for frame in curve.zoning_grid.frames.values():directions[roundi(rad_to_deg(Vector2(frame.along).angle()))]=true
	check(directions.size()>3,"curved road produces several locally straight orientations")
	var values: Array=curve.zoning_grid.parcels.values()
	for i in range(values.size()):
		var bounds:=Parcels.bounds(values[i].polygon)
		for other in curve.zoning_grid.parcels_in(Rect2i(Vector2i(bounds.position.floor())-Vector2i.ONE,Vector2i(4,4))):
			if other.id!=values[i].id and Parcels.overlap(values[i].polygon,other.polygon):any_overlap=true
	check(not any_overlap,"curve-inside and block intersections leave gaps instead of overlapping lots")
	var corner=Model.new(100,100)
	corner.add_road(PackedVector2Array([Vector2(15,30),Vector2(45,30),Vector2(45,65)]))
	var axes:={}
	for frame in corner.zoning_grid.frames.values():axes[roundi(rad_to_deg(Vector2(frame.along).angle()))]=true
	check(axes.has(0) and axes.has(90),"right-angle bend changes local grid direction on each leg")
	var before: int=corner.zoning_grid.count()
	corner.add_road(PackedVector2Array([Vector2(10,10),Vector2(70,10)]),"local",false,4)
	check(corner.zoning_grid.count()==before,"road-local preview remains non-mutating")
	var dense:=PackedVector2Array()
	for i in range(101):dense.append(Vector2(10,10)+Vector2(0.4,0.3)*i)
	var sparse:=PackedVector2Array([dense[0],dense[-1]])
	var dense_blocks:=Parcels.blocks(dense,1,0)
	var sparse_blocks:=Parcels.blocks(sparse,1,0)
	check(dense_blocks.size()==sparse_blocks.size(),"collinear mouse samples do not multiply tiny blocks")
	var cascade=Model.new(100,100)
	cascade.add_road(PackedVector2Array([Vector2(15,20),Vector2(65,55)]))
	var pair: Array[Dictionary]=[]
	for frame in cascade.zoning_grid.frames.values():
		if cascade.parcel_placement_error(frame,0,0,2)!="" or cascade.parcel_placement_error(frame,2,0,2)!="":continue
		for u in [0,2]:
			var added: Dictionary=cascade.add_building_at(frame.origin+frame.along*(u+.5)+frame.outward*.5,"residential",100 if u==0 else 0)
			if added.ok:pair.append(added.building)
		break
	cascade.config.size_weights={8:0.0,4:0.0,2:1.0};cascade.config.neighbor_chance=1.0
	check(pair.size()==2 and cascade.adjacent(pair[0],pair[1]),"rotated lots sharing a full edge are adjacent")
	if pair.size()==2:
		check(cascade.upgrade_chain(pair[0].id).events.size()==2 and pair[1].level==2,"neighbor score bypass also works in road-local coordinates")
	var big=Model.new(1024,1024)
	big.add_road(PackedVector2Array([Vector2(500.25,500.75),Vector2(560.25,540.75)]))
	var normal:=Vector2(-40,60).normalized()*10
	big.add_road(PackedVector2Array([Vector2(500.25,500.75)+normal,Vector2(560.25,540.75)+normal]))
	var fit_big:=false
	for frame in big.zoning_grid.frames.values():
		if big.parcel_placement_error(frame,0,0,8)=="":fit_big=true;break
	if not fit_big:
		for frame in big.zoning_grid.frames.values():
			var missing:=0
			for u in range(8):
				for v in range(8):
					if not big.zoning_grid.has_parcel(frame.id,u,v):missing+=1
			print("BIG FRAME ",frame.id," cols ",frame.columns," missing ",missing," spatial ",big._polygon_error(Parcels.polygon(frame,0,0,8)))
	check(fit_big,"road-local eight-cell lots also fit at 1024-map coordinates")
	print("RESULT ",checks-failures,"/",checks," road-local checks passed")
	quit(1 if failures else 0)
