extends SceneTree

const City=preload("res://core/city_model.gd")
const Parcels=preload("res://core/road_parcels.gd")
const Grid=preload("res://core/road_grid_snap.gd")
const Frontage=preload("res://core/building_frontage.gd")
const EPS:=.0005
var checks:=0
var failures:=0

func _initialize() -> void:
	run.call_deferred()

func verify(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)

func run() -> void:
	straight_strips()
	seam_and_cut()
	frontage_after_bend()
	frontage_samples()
	development_and_rebinding()
	print("RESULT %d/%d one-way frontage checks passed"%[checks-failures,checks])
	quit(1 if failures else 0)

func build_road(city,points:PackedVector2Array,lanes:int,grid:Dictionary={},travel:int=1) -> bool:
	return city.add_road(points,"local",true,lanes,false,false,1,grid,travel).ok

func straight_strips() -> void:
	for lanes in [1,2,3,4]:
		for reverse in [false,true]:
			var city:=City.new(72,72)
			var points:=PackedVector2Array([Vector2(16,36),Vector2(40,36)])
			if reverse:points.reverse()
			var label:="%d lanes, reversed=%s"%[lanes,reverse]
			verify(build_road(city,points,lanes),label+": road constructed")
			var along:Vector2=(points[1]-points[0]).normalized()
			var right:=Vector2(-along.y,along.x)
			var half:float=[.75,1.5,1.5,2.5][lanes-1]
			var sides:Array=[1] if lanes==1 else [-1,1]
			var expected:={}
			for block in range(3):
				for side in sides:
					var frame:={"origin":points[0]+along*(block*8)+right*side*half,"along":along,"outward":right*side}
					for u in range(8):
						for v in range(4):expected["0:%d:%d:%d:%d"%[block,side,u,v]]=Parcels.polygon(frame,u,v)
			verify(parcel_polygons(city)==expected,label+": exact road-local IDs, curb positions and four rows only on sidewalk sides")
			var basis:Dictionary=Grid.frame_near(city,points[0]+along*12)
			verify(basis.origin.is_equal_approx(points[0]+right*half) and basis.outward.is_equal_approx(right),label+": snapping still uses the unchanged +1 board phase")
			for side in sides:
				var result:=city.add_building_at(points[0]+along*2.5+right*side*(half+.5))
				verify(result.ok and result.building.front_road_id==0 and city.front_direction(result.building).is_equal_approx(-right*side),label+": road-local building faces its exact sidewalk on side %d"%side)

func parcel_polygons(city) -> Dictionary:
	var result:={}
	for parcel in city.zoning_grid.parcels.values():result[parcel.id]=parcel.polygon
	return result

func shape_set(city) -> Dictionary:
	var result:={}
	for parcel in city.zoning_grid.parcels.values():result[parcel.polygon]=true
	return result

func seam_and_cut() -> void:
	var start:=Vector2(10,30)
	var seam:=Vector2(26,30)
	var finish:=Vector2(42,30)
	var board:={"origin":Vector2(10.5,30.75),"along":Vector2.RIGHT,"outward":Vector2.DOWN}
	var whole:=City.new(64,64)
	var split:=City.new(64,64)
	verify(build_road(whole,PackedVector2Array([start,finish]),1,board),"one-shot half-phase fixture constructed")
	verify(build_road(split,PackedVector2Array([start,seam]),1,board),"first half-phase record constructed")
	var before:=parcel_polygons(split)
	var designated:="0:0:1:2:0"
	verify(split.paint_zones(Parcels.polygon(board,2,0),"residential").changed==1,"designate a retained cell on the right")
	verify(build_road(split,PackedVector2Array([seam,finish]),1,board),"second half-phase record constructed")
	verify(shape_set(split)==shape_set(whole) and split.zoning_grid.count()==31*4,"split and one-shot match across internal block and authored record seams")
	for x in [18.0,26.0,34.0]:
		var cell:Dictionary=split.zoning_grid.parcel_at(Vector2(x,31.25))
		var unsupported:Dictionary=split.zoning_grid.parcel_at(Vector2(x,28.0))
		verify(not cell.is_empty() and cell.polygon[0].is_equal_approx(Vector2(x-.5,30.75)) and unsupported.is_empty(),"straddling column at x=%s has pavement support and only a right-side parcel"%x)
	var split_polygons:=parcel_polygons(split)
	verify(before.keys().all(func(id):return split_polygons.get(id)==before[id]) and split.zone_designations.get(designated)=="residential","extension preserves existing parcel IDs, polygons and designation")
	var before_cut:=parcel_polygons(whole)
	var far_building:=whole.add_building_at(Vector2(36,31.25))
	verify(far_building.ok and far_building.building.front_road_id==0,"right-side building initially faces the unsplit road")
	var cut:=whole.road_demolition_selection(0,Vector2(21,30),Vector2(23,30))
	verify(whole.demolish_road_selection(cut).ok and whole.roads.size()==2,"drag demolition splits the original record")
	var retained:=parcel_polygons(whole)
	var expected:Dictionary={}
	for id in before_cut:
		if before_cut[id][1].x<=21+EPS or before_cut[id][0].x>=23-EPS:expected[id]=before_cut[id]
	verify(retained==expected,"both fragments preserve all fully supported original parcel IDs and polygons")
	var far:Dictionary=whole.zoning_grid.parcel_at(Vector2(34,31.25))
	verify(far.get("id")=="0:2:1:7:0" and whole.roads[-1].travel_dir==1,"far fragment keeps its source frame ID and authored direction")
	verify(whole.zoning_grid.parcel_at(Vector2(22,31.25)).is_empty() and whole.zoning_grid.parcel_at(Vector2(34,28)).is_empty(),"neither the cut gap nor the sidewalkless side acquires parcels")
	verify(far_building.ok and far_building.building.front_road_id==whole.roads[-1].parcel_id and whole.front_direction(far_building.building)==Vector2.UP,"building rebinds to the actual surviving fragment, not the parcel's source road ID")

func frontage_after_bend() -> void:
	for reverse in [false,true]:
		var city:=City.new(64,64)
		var points:=PackedVector2Array([Vector2(16,20),Vector2(32,20),Vector2(32,48)])
		if reverse:points.reverse()
		verify(build_road(city,points,1),"bent one-way road built, reversed=%s"%reverse)
		# The lot lies east/west of the actual vertical arm, not the overall road chord.
		var left_x:=29 if reverse else 33
		var right_x:=33 if reverse else 29
		var allowed:=city.add_building(right_x,30)
		verify(allowed.ok and allowed.building.front_road_id==0 and city.front_direction(allowed.building)==(Vector2.LEFT if reverse else Vector2.RIGHT),"authored lot has the exact road-facing front after the bend, reversed=%s"%reverse)
		var denied:=city.add_building(left_x,30)
		verify(not denied.ok and denied.reason=="도로 바로 옆 구획이 필요합니다","sidewalkless lot is denied frontage after the bend, reversed=%s"%reverse)

func frontage_samples() -> void:
	var city:=City.new(64,64)
	verify(build_road(city,PackedVector2Array([Vector2(10,30),Vector2(42,30)]),1),"frontage sample fixture built")
	var road:Dictionary=city.roads[0]
	# A thin polygon isolates the sample rule from the model's independent collision check.
	# One endpoint is left of the centreline, although the midpoint and far endpoint are right.
	var a:=Vector2(18,29.9)
	var b:=Vector2(20,30.7)
	var edge_front:Vector2=Vector2(.8,-2).normalized()
	var straddle:=PackedVector2Array([a,b,b-edge_front*.2,a-edge_front*.2])
	verify(not Frontage.candidates(straddle,[road],.375).any(func(c):return c.front.is_equal_approx(edge_front)),"one unsupported endpoint invalidates the edge even when its midpoint is on the right")
	var frame:={"origin":Vector2(18,31.125),"along":Vector2.RIGHT,"outward":Vector2.DOWN}
	var at_limit:=Frontage.candidates(Parcels.polygon(frame,0,0,2),[road],.375)
	verify(at_limit.size()==1 and at_limit[0].road==0 and at_limit[0].front==Vector2.UP and absf(at_limit[0].gap-.375)<EPS,"right-side frontage accepts the exact 1.5m gap from the sidewalk-inclusive edge")
	frame.origin.y+=.005
	verify(Frontage.candidates(Parcels.polygon(frame,0,0,2),[road],.375).is_empty(),"right-side frontage rejects a gap beyond 1.5m")

func development_and_rebinding() -> void:
	var city:=City.new(64,64)
	var points:=PackedVector2Array([Vector2(10,29.25),Vector2(42,29.25)])
	verify(build_road(city,points,1),"development's right-side road built")
	var right:={"origin":Vector2(12,30),"along":Vector2.RIGHT,"outward":Vector2.DOWN}
	verify(city.paint_zones(Parcels.polygon(right,0,0,4),"residential").changed==16,"paint a whole 4x4 lot on the sidewalk side")
	var left:={"origin":Vector2(12,28.5),"along":Vector2.RIGHT,"outward":Vector2.UP}
	verify(city.paint_zones(Parcels.polygon(left,0,0,4),"residential").changed==0,"painting the sidewalkless side designates nothing")
	var built:=city.advance_development(city.config.development_interval_seconds)
	verify(built.size()==1 and built[0].size==4 and built[0].front_road_id==0 and city.front_direction(built[0])==Vector2.UP,"automatic development uses the real sidewalk frontage")
	if built.is_empty():return
	var house:=built[0]
	var footprint:=city.footprint(house)
	# The road behind the lot is one-way with its sidewalk facing away.
	verify(build_road(city,PackedVector2Array([Vector2(10,34.75),Vector2(42,34.75)]),1),"sidewalkless backup road built")
	verify(city.demolish("road",0).ok and house.front_road_id==-1 and city.front_direction(house)==Vector2.UP and city.footprint(house)==footprint,"losing the real sidewalk does not bind to the back road or move the building")
	verify(city.demolish("road",1).ok and build_road(city,PackedVector2Array([Vector2(10,35.5),Vector2(42,35.5)]),2,{},0),"legitimate two-way replacement road built")
	verify(house.front_road_id==2 and city.front_direction(house)==Vector2.DOWN and city.footprint(house)==footprint,"building rebinds to valid mixed-road alternative without moving")
