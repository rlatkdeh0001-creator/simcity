extends SceneTree
## Read-only diagnosis of existing rules and authored scenarios; no product rule changes.
const Model=preload("res://core/city_model.gd")
const Showcase=preload("res://core/residential_showcase.gd")
func _initialize():run.call_deferred()
func gap_m(city,b: Dictionary) -> float:
	var distance:=INF
	for road in city.roads:
		if road.kind=="local":distance=minf(distance,city._polygon_road_distance(city.footprint(b),road))
	return distance*4.0
func run():
	var report:={"unit":"metres","metres_per_cell":4,"access_limit_m":Model.new().config.road_access_distance*4,"parcel_samples":[],"frontage_capture":[],"showcase":[]}
	for angle in [0.0,.37,PI/2]:
		for side in [-1,1]:
			for depth in range(4):
				var city=Model.new(100,100)
				var along:=Vector2.from_angle(angle)
				assert(city.add_road(PackedVector2Array([Vector2(50,50)-along*20,Vector2(50,50)+along*20])).ok)
				var selected:={}
				for frame in city.zoning_grid.frames.values():
					if frame.side==side:selected=frame;break
				var point: Vector2=selected.origin+selected.along*.5+selected.outward*(depth+.5)
				var result: Dictionary=city.add_building_at(point)
				var polygon: PackedVector2Array=city.Parcels.polygon(selected,0,depth,2)
				var gap: float=city._polygon_road_distance(polygon,city.roads[0])*4.0
				report.parcel_samples.append({"angle_radians":angle,"side":side,"depth_cells":depth,"lot_gap_m":gap,"built":result.ok,"reason":result.get("reason","")})
				assert(result.ok==(depth<=2),"Existing rule accepts detached v=1,2 lots")
	var city=Model.new(70,70)
	for points in [PackedVector2Array([Vector2(7,16),Vector2(18,16)]),PackedVector2Array([Vector2(21,8),Vector2(32,8)]),PackedVector2Array([Vector2(8,21),Vector2(8,32)]),PackedVector2Array([Vector2(30,21),Vector2(30,32)])]:
		assert(city.add_road(points).ok)
	for p in [Vector2i(10,10),Vector2i(24,10),Vector2i(10,24),Vector2i(24,24)]:
		var result: Dictionary=city.place_catalog_building("mansion-a-4x4-4f",p.x,p.y)
		assert(result.ok)
		report.frontage_capture.append({"id":result.building.id,"lot_gap_m":gap_m(city,result.building),"front_direction":[city.front_direction(result.building).x,city.front_direction(result.building).y]})
	var showcase=Showcase.create_city()
	for b in showcase.buildings:report.showcase.append({"id":b.asset_id,"lot_gap_m":gap_m(showcase,b)})
	var output:=OS.get_cmdline_user_args()[0]
	var file:=FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("GAP_AUDIT samples=",report.parcel_samples.size()," capture=",report.frontage_capture.size()," showcase=",report.showcase.size()," max_access_m=",report.access_limit_m)
	quit()
