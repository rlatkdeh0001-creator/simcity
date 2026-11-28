extends SceneTree

const Profile = preload("res://core/road_profile.gd")
const City = preload("res://core/city_model.gd")
const Transitions = preload("res://core/road_transitions.gd")
const Construction = preload("res://core/road_construction.gd")
const Topology = preload("res://core/road_junctions.gd")
const Height = preload("res://core/road_height.gd")
const Geometry = preload("res://core/road_geometry.gd")
const Parcels = preload("res://core/road_parcels.gd")
const Net = preload("res://core/traffic_network.gd")
const Buses = preload("res://core/scheduled_bus_network.gd")
const Frontage = preload("res://core/building_frontage.gd")
const Adapter = preload("res://core/city_simulation_worker.gd")
const Mailbox = preload("res://core/city_native_mailbox.gd")
const Transit = preload("res://core/transit_operations.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func path(a: Vector2,b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a,b])

func run() -> void:
	sections()
	producer()
	ordinary_record_layout()
	continuations()
	crossing_order()
	stripe_ownership()
	stripe_continuity()
	stripe_around_authored_corner()
	stripe_at_closed_seam()
	stripe_at_inside_closed_seam()
	stripe_at_boxed_bend()
	frontage_and_stops()
	warning_b()
	worker_checkpoint()
	print("RESULT %d/%d branch one-way checks passed" % [checks-failures, checks])
	quit(1 if failures else 0)

func sections() -> void:
	for row in [["branch-one-way-6m", 1, 6.0, Vector2(-3,2.25), .75, 1.75, [-1.25]],
			["branch-one-way-8m", 2, 8.0, Vector2(-4,3), 1.0, 0.0, [-2.25,1.25]]]:
		var road := {"road_variant":row[0], "kind":"local", "lanes":row[1], "width":row[2]/4.0, "travel_dir":1}
		verify(absf(Profile.width_for_record(road)*4-row[2]) <= .001, "%s effective full width" % row[0])
		for direction in [1,-1]:
			road.travel_dir=direction
			var edges: Vector2 = row[3] if direction==1 else Vector2(-row[3].y,-row[3].x)
			verify((Profile.asphalt_edges(road)*4).distance_to(edges) <= .001, "%s signed asphalt %d" % [row[0], direction])
			verify(Profile.sidewalk_width(road,-direction)==0 and absf(Profile.sidewalk_width(road,direction)*4-row[4]) <= .001, "%s outside-only sidewalk %d" % [row[0],direction])
			verify(Profile.shoulder_width(road,-direction)==0 and absf(Profile.shoulder_width(road,direction)*4-row[5]) <= .001, "%s outside shoulder %d" % [row[0],direction])
			var lane_centres: Array = []
			for index in range(row[1]):
				lane_centres.append(Profile.lane_center_metres(road,direction,index))
			verify(lane_centres==row[6] and Profile.direction_count(road,-direction)==0, "%s directed lane centres %d" % [row[0],direction])
		var adjacent := {"kind":"local","lanes":4,"width":5.0}
		verify(Transitions.allowed(road,adjacent)==(row[1]==2), "%s transition to 20m uses explicit width grade" % row[0])

func producer() -> void:
	var a := Vector2(20,40); var b := Vector2(40,40); var c := Vector2(60,40)
	var branch := {"kind":"local","width":1.5,"lanes":1,"travel_dir":1,"points":path(a,b),"road_variant":Profile.BRANCH_IDS[0]}
	var normal := branch.duplicate(); normal.erase("road_variant"); normal.points=path(a,c)
	verify(not Construction.plan([branch],normal).ok,"same geometry is not permission to overpaint a different road variant")
	var wrong := branch.duplicate(); wrong.lanes=2; wrong.heights_m=PackedFloat64Array([0,0])
	verify(not Height.validate(wrong,Vector2(100,100)).is_empty(),"mismatched branch lanes rejected by shared validation")
	var narrow := branch.duplicate(); narrow.merge({"width":2.0,"lanes":2,"road_variant":Profile.BRANCH_IDS[1]},true)
	normal.merge({"width":3.0,"lanes":2,"points":path(b,c)},true)
	var join: Dictionary = Topology.analyze([narrow,normal]).joins[0]
	var arm: Dictionary = join.arms[0]
	verify(arm.get("road_variant")==Profile.BRANCH_IDS[1] and (Profile.asphalt_edges(arm)*4).distance_to(Vector2(-3,4))<.001,"derived taper arm carries reversed asymmetric section")
	var city: Variant = City.new(100,100)
	if not city.has_method("add_branch_one_way"):
		verify(false,"hidden branch producer is available")
		return
	for variant in [Profile.BranchVariant.SIX_METRE,Profile.BranchVariant.EIGHT_METRE]:
		city=City.new(100,100)
		var original: Array = [city.next_road_id,city.road_topology_revision]
		var preview: Dictionary = city.add_branch_one_way(path(a,b),variant,false)
		verify(preview.ok and preview.new_roads.size()==1 and city.roads.is_empty() and original==[city.next_road_id,city.road_topology_revision],"branch preview is detached %d" % variant)
		verify(not city.add_branch_one_way(path(a,b),99).ok and original==[city.next_road_id,city.road_topology_revision],"invalid branch selection does not allocate")
		var result: Dictionary = city.add_branch_one_way(path(a,b),variant)
		verify(result.ok and city.roads.size()==1 and city.roads[0].points==path(a,b) and city.roads[0].road_variant==Profile.BRANCH_IDS[variant] and city.roads[0].travel_dir==1,"branch transaction commits named authored section %d" % variant)
		if result.ok:
			var profile: Variant = Profile.new()
			verify(city.roads[0].width*4==[6,8][variant] and not profile.allows_roadside_parking(city.roads[0],1) and not profile.allows_roadside_parking(city.roads[0],-1),"stored width and branch parking policy %d" % variant)
	var six := City.new(100,100); var ordinary := City.new(100,100)
	verify(six.add_branch_one_way(path(a,b),Profile.BranchVariant.SIX_METRE).ok and normal(ordinary,path(a,b),1).ok and six.road_pavement==ordinary.road_pavement and six.road_asphalt==ordinary.road_asphalt and six.road_lane_marks==ordinary.road_lane_marks,"6m branch and ordinary one-way 1 have identical ribbon and white markings")
	for lanes in range(1,5):
		var regular := {"kind":"local","width":Profile.width_for("local",lanes,2,1),"lanes":lanes,"travel_dir":1}
		verify(Profile.allows_roadside_parking(regular,1)==(lanes!=3),"ordinary one-way %d parking retains its shoulder policy" % lanes)

func normal(city,points: PackedVector2Array,lanes: int,direction: int=1, commit: bool=true) -> Dictionary:
	return city.add_elevated_road(points,PackedFloat64Array([0,0]),"local",commit,lanes,false,1,{},null,direction)

func ordinary_record_layout() -> void:
	for direction in [0,1]:
		var city := City.new(100,100)
		var points := path(Vector2(20,40),Vector2(40,40))
		var result := normal(city,points,2,direction)
		var expected := {"points":points,"heights_m":PackedFloat64Array([0.0,0.0]),"kind":"local","lanes":2,"width":3.0}
		if direction==0:expected["major_side"]=1
		else:expected.travel_dir=1
		verify(result.ok and var_to_bytes(city.roads[0].keys().slice(0,6))==var_to_bytes(expected.keys()) and not city.roads[0].has("road_variant"),"ordinary height-road record keeps serialized key types and order (direction %d)" % direction)

func continuations() -> void:
	for spec in [[0,1,1],[0,2,0],[1,2,1]]:
		for heading in [1,-1]:
			for reverse_order in [false,true]:
				var b := Vector2(50,40)
				var a := b-Vector2(20*heading,0); var c := b+Vector2(24*heading,0)
				var city := City.new(100,100)
				var add_branch := func(commit):return city.add_branch_one_way(path(a,b),spec[0],commit)
				var add_normal := func(commit):return normal(city,path(b,c),spec[1],spec[2],commit)
				var builders := [add_normal,add_branch] if reverse_order else [add_branch,add_normal]
				var label := "%s heading %d reverse order %s" % [spec,heading,reverse_order]
				var ok: bool = builders[0].call(true).ok and builders[1].call(false).ok and builders[1].call(true).ok
				verify(ok and city.junctions.is_empty() and city.road_crosswalks.is_empty() and city.road_stop_lines.is_empty(),"ordinary continuation is legal and uncontrolled " + label)
				if not ok:continue
				var from := int(reverse_order); var to := 1-from
				verify(not city.roads[to].has("road_variant") and Profile.allows_roadside_parking(city.roads[to],1),"ordinary continuation retains own profile and parking " + label)
				var network := Net.new(); var built := network.build(city.roads)
				var incoming := network.lanes.filter(func(l):return l.road==from)
				var outgoing := network.lanes.filter(func(l):return l.road==to and l.direction==1)
				var reverse := network.lanes.filter(func(l):return l.road==to and l.direction==-1)
				var surfaces: Array[PackedVector2Array] = city.road_asphalt+city.junction_asphalt
				var legal: bool = built and incoming.size()==spec[0]+1 and outgoing.size()==spec[0]+1 and reverse.all(func(l):return l.next.is_empty())
				for lane in incoming:
					for target in outgoing:
						var route := network.route(lane.id,target.id)
						legal = legal and lane.direction==1 and route.is_empty()==(lane.index!=target.index) and network.route(target.id,lane.id).is_empty()
						if lane.index!=target.index or route.size()<3:continue
						var connector: Dictionary = network.lanes[route[1]]
						legal = legal and connector.transition and connector.from==lane.id and connector.to==target.id
						legal = legal and network.sample(connector.id,0).distance_to(network.sample(lane.id,lane.length))<.001
						legal = legal and network.sample(connector.id,connector.length).distance_to(network.sample(target.id,0))<.001
						legal = legal and network._on_asphalt(connector.curve,surfaces)
					legal = legal and (lane.next.size()==1)
				var connectors := 0 if spec==[0,1,1] else incoming.size()
				verify(legal and network.lanes.size()==incoming.size()+outgoing.size()+reverse.size()+connectors,"exact directed lane pairings, joins and full baked asphalt chords " + label)
	for variant in [0,1]:
		var city := City.new(100,100)
		verify(city.add_branch_one_way(path(Vector2(20,40),Vector2(40,40)),variant).ok,"dead-end branch admits variant %d" % variant)
		var saved := city.roads.duplicate(true)
		verify(not normal(city,path(Vector2(40,40),Vector2(60,40)),4 if variant==0 else 6,0).ok and city.roads==saved,"two-grade jump rejected without mutation %d" % variant)
		verify(not normal(city,path(Vector2(60,40),Vector2(40,40)),variant+1).ok and city.roads==saved,"opposing two-arm flow rejected without mutation %d" % variant)

func stripe_at(stripes: Array,point: Vector2) -> bool:
	return stripes.any(func(polygon):return Geometry2D.is_point_in_polygon(point,polygon))

func polygon_key(shapes: Array) -> Array:
	var result := []
	for polygon in shapes:
		var vertices := Array(polygon).map(func(p):return str((p*1000).round()))
		vertices.sort()
		result.append(str(vertices))
	result.sort()
	return result

func crossing_order() -> void:
	for variant in [0,1]:
		for x_crossing in [false,true]:
			var straight := path(Vector2(20,45),Vector2(80,45))
			var crossing := path(Vector2(50,20 if x_crossing else 45),Vector2(50,70))
			var first: Array = []
			for reversed in [false,true]:
				var city := City.new(100,100)
				var add_branch := func():return city.add_branch_one_way(straight,variant).ok
				var add_crossing := func():return normal(city,crossing,2,0).ok
				var ok: bool = (add_crossing.call() and add_branch.call()) if reversed else (add_branch.call() and add_crossing.call())
				var network := Net.new()
				verify(ok and city.junctions.size()==1 and network.build(city.roads),"true T/X builds in either order %d/%s/%s" % [variant,x_crossing,reversed])
				if not ok:continue
				var shapes := []
				var asphalt: Array[PackedVector2Array] = city.road_asphalt+city.junction_asphalt
				var legal := true
				for connector in network.lanes.filter(func(lane):return lane.road<0):
					var baked: PackedVector3Array=connector.curve.get_baked_points()
					var polyline := PackedVector2Array()
					for p in baked:polyline.append(Vector2(p.x,p.z)/4)
					shapes.append(polyline)
					legal=legal and network._on_asphalt(connector.curve,asphalt)
				var observed := [polygon_key(city.junction_asphalt),polygon_key(shapes)]
				verify(legal and not shapes.is_empty(),"real junction connector chords stay on rendered asphalt")
				if not reversed:first=observed
				else:verify(first==observed,"junction asphalt and connectors invariant to insertion order")

func stripe_ownership() -> void:
	var a := Vector2(20,40); var b := Vector2(40,40); var c := Vector2(60,40)
	for variant in [0,1]:
		var city: Variant = City.new(100,100)
		verify(city.add_branch_one_way(path(a,b),variant).ok and normal(city,path(b,c),variant+1).ok,"branch-to-ordinary stripe fixture %d" % variant)
		var stripes: Variant = city.get("road_branch_edge_marks")
		if not stripes is Array:
			verify(false,"branch emits retained curb stripe %d" % variant)
			continue
		var outside := .5625 if variant==0 else .75
		verify(stripe_at(stripes,Vector2(30,40+outside-.04)) and not stripe_at(stripes,Vector2(30,40-outside+.04)),"one stripe immediately inside the travel-right curb %d" % variant)
		var shift := (1.3125-outside)/4 if variant==1 else 0.0
		verify(stripe_at(stripes,Vector2(39.98,40+outside+1.98*shift-.04)) and not stripe_at(stripes,Vector2(40.02,40+outside+2.02*shift-.04)),"stripe follows final asphalt through taper and ends at authored seam %d" % variant)
		verify(normal(city,path(Vector2(30,20),Vector2(30,60)),2,0).ok,"controlled crossing fixture %d" % variant)
		stripes=city.road_branch_edge_marks
		var clear := true
		for polygon in stripes:
			for control in city.road_stop_lines+city.road_crosswalks+city.junctions.map(func(j):return j.asphalt):
				for piece in Geometry2D.intersect_polygons(polygon,control):clear=clear and Parcels.area(piece)<.000001
		verify(clear and stripe_at(stripes,Vector2(24,40+outside-.04)) and stripe_at(stripes,Vector2(36,40+outside-.04)),"solid stripe resumes on both approaches outside all junction paint %d" % variant)

func stripe_continuity() -> void:
	for variant in [0,1]:
		for heading in [1,-1]:
			var b := Vector2(50,40)
			var a := b-Vector2(20*heading,0); var c := b+Vector2(20*heading,5)
			var first := path(a,b); var last := path(b,c)
			var expected: Array[float] = []
			for order in [[first,last],[last,first]]:
				var city := City.new(100,100)
				verify(city.add_branch_one_way(order[0],variant).ok and city.add_branch_one_way(order[1],variant).ok and city.road_visuals.size()==1,"bent branch seam shares a retained path %d/%d" % [variant,heading])
				if city.road_visuals.size()!=1:continue
				var visual: Dictionary = city.road_visuals[0]
				var offset: float = ((.5625 if variant==0 else .75)-.04)*heading*signf(visual.points[-1].x-visual.points[0].x)
				var curb := Profile.offset_path(visual.points,offset)
				var continuous := true
				for i in range(1,curb.size()):
					for t in [.01,.5,.99]:
						continuous=continuous and stripe_at(city.road_branch_edge_marks,curb[i-1].lerp(curb[i],t))
				var area := 0.0
				var stripe := city.road_branch_edge_marks
				for i in range(stripe.size()):
					area+=Parcels.area(stripe[i])
					for j in range(i+1,stripe.size()):
						for overlap in Geometry2D.intersect_polygons(stripe[i],stripe[j]):continuous=continuous and Parcels.area(overlap)<.000001
				expected.append(area)
				verify(continuous,"curb paint covers bends with no gaps or duplicated positive area %d/%d" % [variant,heading])
			if expected.size()==2:verify(absf(expected[0]-expected[1])<.0001,"curb paint invariant to insertion order %d/%d" % [variant,heading])

func samples_inset_stripe(city,origin: Vector2,outward: Vector2) -> bool:
	var rim := origin
	for surface: PackedVector2Array in city.road_asphalt:
		for j in range(surface.size()):
			var hit: Variant = Geometry2D.segment_intersects_segment(origin,origin+outward*2,surface[j],surface[(j+1)%surface.size()])
			if hit!=null and origin.distance_squared_to(hit)>origin.distance_squared_to(rim):rim=hit
	return origin.distance_to(rim)>.4 and stripe_at(city.road_branch_edge_marks,rim-outward*.04) and not stripe_at(city.road_branch_edge_marks,rim-outward*.008)

func stripe_around_authored_corner() -> void:
	# A sharp vertex within one authored path is not a filleted two-record seam.
	for variant in [0,1]:
		for heading in [1,-1]:
			var city := City.new(100,100)
			var corner := Vector2(50,40)
			var authored := PackedVector2Array([corner-Vector2(30*heading,0),corner,corner-Vector2(0,20*heading)])
			var label := "%dm heading %d" % [6+2*variant,heading]
			var built: bool = city.add_branch_one_way(authored,variant).ok
			verify(built and city.road_joins.is_empty() and city.roads[0].points==authored,"authored outer-corner fixture " + label)
			if not built:continue
			var stripes := city.road_branch_edge_marks
			var covered := true
			for i in range(1,16):
				covered=covered and samples_inset_stripe(city,corner,Vector2.from_angle(PI/2-i*PI/32)*heading)
			var approaches := samples_inset_stripe(city,corner-Vector2(.02,0)*heading,Vector2.DOWN*heading) and samples_inset_stripe(city,corner-Vector2(0,.02)*heading,Vector2.RIGHT*heading)
			verify(covered and approaches,"stripe continuously follows actual rounded curb with a clear inset " + label)
			var contained := not stripes.is_empty()
			for i in range(stripes.size()):
				for j in range(i+1,stripes.size()):
					for overlap in Geometry2D.intersect_polygons(stripes[i],stripes[j]):contained=contained and Parcels.area(overlap)<.000001
				for surface in city.road_asphalt:
					for excess in Geometry2D.clip_polygons(stripes[i],surface):contained=contained and Parcels.area(excess)<.000001
			verify(contained,"outer-corner stripe polygons have no duplicated area or asphalt spill " + label)

func stripe_at_closed_seam() -> void:
	for variant in [0,1]:
		for heading in [1,-1]:
			var city := City.new(100,100)
			var seam := Vector2(40,40)
			var authored := PackedVector2Array([seam,seam+Vector2(6,0)*heading,seam+Vector2(6,-6)*heading,seam+Vector2(0,-6)*heading,seam])
			var label := "%dm heading %d" % [6+2*variant,heading]
			var built: bool = city.add_branch_one_way(authored,variant).ok
			var closed: bool = built and city.roads[0].points==authored and city.road_visuals.size()==1 and city.road_joins.is_empty() and city.junctions.is_empty() and city.road_stop_lines.is_empty() and city.road_crosswalks.is_empty()
			verify(closed,"authored closed curb has no control or width join " + label)
			if not closed:continue
			var stripe := city.road_branch_edge_marks
			var covered := samples_inset_stripe(city,seam-Vector2(0,.02)*heading,Vector2.LEFT*heading) and samples_inset_stripe(city,seam+Vector2(.02,0)*heading,Vector2.DOWN*heading)
			for i in range(1,16):
				covered=covered and samples_inset_stripe(city,seam,Vector2.from_angle(PI/2+i*PI/32)*heading)
			verify(covered,"closing corner follows the actual curb with no gap " + label)
			var straight := true
			for segment in range(4):
				var tangent := (authored[segment+1]-authored[segment]).normalized()
				for t in [.25,.49,.5,.51,.75]:
					straight=straight and samples_inset_stripe(city,authored[segment].lerp(authored[segment+1],t),Vector2(-tangent.y,tangent.x))
			verify(straight,"closed branch keeps continuous inset paint across all straight cross-sections " + label)
			var clean := not stripe.is_empty()
			for i in range(stripe.size()):
				for j in range(i+1,stripe.size()):
					for overlap in Geometry2D.intersect_polygons(stripe[i],stripe[j]):clean=clean and Parcels.area(overlap)<.000001
				var excess: Array[PackedVector2Array] = [stripe[i]]
				for surface in city.road_asphalt:
					var remaining: Array[PackedVector2Array] = []
					for polygon in excess:remaining.append_array(Geometry2D.clip_polygons(polygon,surface))
					excess=remaining
				for piece in excess:
					# A second Clipper operation can leave lattice-rounding slivers.
					# Bound both their area and their distance from final asphalt.
					clean=clean and Parcels.area(piece)<.00001
					for vertex in piece:
						var distance:=INF
						for surface in city.road_asphalt:
							for k in range(surface.size()):
								var edge:=Geometry2D.get_closest_point_to_segment(vertex,surface[k],surface[(k+1)%surface.size()])
								distance=minf(distance,vertex.distance_to(edge))
						clean=clean and distance<=.00002
			verify(clean,"closed loop stripe has no duplicate area or asphalt spill " + label)
			var center: Vector2 = seam+Vector2(3,-3)*heading
			verify(not stripe_at(city.road_asphalt,center) and not stripe_at(city.road_pavement,center),"closed branch leaves loop interior uncovered " + label)

func stripe_at_inside_closed_seam() -> void:
	for variant in [0,1]:
		var city := City.new(100,100)
		var seam := Vector2(40,40)
		var reversed := PackedVector2Array([seam,seam+Vector2(0,-6),seam+Vector2(6,-6),seam+Vector2(6,0),seam])
		var built: bool = city.add_branch_one_way(reversed,variant).ok
		verify(built and city.road_joins.is_empty() and city.junctions.is_empty(),"inside closing-corner fixture %d" % variant)
		if not built:continue
		var stripe := city.road_branch_edge_marks
		var covered := samples_inset_stripe(city,seam+Vector2(1,0),Vector2.UP) and samples_inset_stripe(city,seam+Vector2(0,-1),Vector2.RIGHT)
		var inset := (.5625 if variant==0 else .75)-.04
		verify(covered and stripe_at(stripe,seam+Vector2(inset,-inset)),"inside closing corner joins both inset curb legs %d" % variant)
		var unique := true
		for i in range(stripe.size()):
			for j in range(i+1,stripe.size()):
				for overlap in Geometry2D.intersect_polygons(stripe[i],stripe[j]):unique=unique and Parcels.area(overlap)<.000001
		verify(unique,"inside closing corner has no duplicate paint %d" % variant)

func stripe_at_boxed_bend() -> void:
	for heading in [1,-1]:
		var seam := Vector2(50,40)
		var branch := path(seam-Vector2(30,0)*heading,seam)
		var ordinary := path(seam,seam+Vector2(24,7)*heading)
		var first: Array = []
		for reversed in [false,true]:
			var city := City.new(100,100)
			var add_branch := func():return city.add_branch_one_way(branch,Profile.BranchVariant.EIGHT_METRE).ok
			var add_normal := func():return normal(city,ordinary,2).ok
			var built: bool = (add_normal.call() and add_branch.call()) if reversed else (add_branch.call() and add_normal.call())
			var label := "8→12 bent join heading %d reversed %s" % [heading,reversed]
			var boxed: bool = built and city.road_joins.size()==1 and city.road_joins[0].has("box") and not city.road_joins[0].get("taper",false)
			verify(boxed and city.junctions.is_empty() and city.road_stop_lines.is_empty() and city.road_crosswalks.is_empty(),"passive boxed-bend fixture " + label)
			if not boxed:continue
			var stripes := city.road_branch_edge_marks
			var covered := true
			for x in [2.0,1.5,1.0,.5,.25,.05]:
				covered=covered and stripe_at(stripes,seam+Vector2(-x,.71)*heading)
			verify(covered,"branch stripe reaches the authored seam inside the passive box " + label)
			var surfaces: Array[PackedVector2Array] = city.road_asphalt+city.junction_asphalt
			var clean := not stripes.is_empty()
			for i in range(stripes.size()):
				for point in stripes[i]:clean=clean and (point.x-seam.x)*heading<=.0001
				for j in range(i+1,stripes.size()):
					for overlap in Geometry2D.intersect_polygons(stripes[i],stripes[j]):clean=clean and Parcels.area(overlap)<.000001
				var excess: Array[PackedVector2Array] = [stripes[i]]
				for surface in surfaces:
					var remaining: Array[PackedVector2Array] = []
					for polygon in excess:remaining.append_array(Geometry2D.clip_polygons(polygon,surface))
					excess=remaining
				for piece in excess:clean=clean and Parcels.area(piece)<.000001
			verify(clean,"no duplicated stripe, ordinary-side spill, or paint outside final asphalt " + label)
			if not reversed:first=polygon_key(stripes)
			else:verify(first==polygon_key(stripes),"boxed stripe polygons invariant to insertion order " + label)
			var network := Net.new()
			var legal := network.build(city.roads)
			var connectors := network.lanes.filter(func(lane):return lane.road<0)
			legal=legal and connectors.size()==2
			for connector in connectors:
				var start: Dictionary = network.lanes[connector.from]; var finish: Dictionary = network.lanes[connector.to]
				legal=legal and start.road==int(reversed) and finish.road==1-int(reversed) and start.index==finish.index
				legal=legal and connector.transition and network.route(start.id,finish.id)==[start.id,connector.id,finish.id] and network.route(finish.id,start.id).is_empty()
				legal=legal and network.sample(start.id,start.length).distance_to(network.sample(connector.id,0))<.001 and network.sample(finish.id,0).distance_to(network.sample(connector.id,connector.length))<.001
				legal=legal and network._on_asphalt(connector.curve,surfaces)
			verify(legal,"both directed baked connectors join exactly and stay on final asphalt " + label)

func frontage_and_stops() -> void:
	for variant in [0,1]:
		for heading in [1,-1]:
			var city := City.new(100,100)
			var a := Vector2(20 if heading>0 else 80,40); var b := Vector2(80 if heading>0 else 20,40)
			var authored := path(a,b)
			var ok: bool = city.add_branch_one_way(authored,variant).ok
			verify(ok,"frontage stop host committed %d/%d" % [variant,heading])
			if not ok:continue
			var road: Dictionary=city.roads[0]
			var cells: Array = city.zoning_grid.parcels.values()
			verify(not cells.is_empty() and cells.all(func(p):return (p.center.y-40)*heading>0) and cells.any(func(p):return p.v==3) and cells.all(func(p):return p.v<4),"exactly four available outside parcel rows and no inner cells")
			var half := .75 if variant==0 else 1.0
			var front: float = 40+(half+.1)*heading
			var back: float = 40-(half+.1)*heading
			var outside := PackedVector2Array([Vector2(29,front),Vector2(31,front),Vector2(31,front+2*heading),Vector2(29,front+2*heading)])
			var inside := PackedVector2Array([Vector2(29,back),Vector2(31,back),Vector2(31,back-2*heading),Vector2(29,back-2*heading)])
			var building := {}
			Frontage.resolve(building,outside,city.roads,.375)
			verify(building.front_road_id==road.parcel_id and building.front_direction==Vector2(0,-heading) and Frontage.candidates(inside,city.roads,.375).is_empty(),"outside building faces the branch ID; no inside frontage")
			city.funds=ceili(city.public_facilities.price("bus-stop-01"))*2
			var outer_curb := Vector2(65,40+(.5625 if variant==0 else .75)*heading)
			verify(not city.public_facilities.place("bus-stop-01",Vector2(65,40-half*heading),0,false).ok,"no inside stop even at inner asphalt edge")
			var placed: Dictionary=city.public_facilities.place("bus-stop-01",outer_curb,0,true)
			verify(placed.ok and city.public_facilities.lots.size()==1,"outside road-edge bus stop admitted")
			if not placed.ok:continue
			var lot: Dictionary=city.public_facilities.lots[0]
			verify(lot.front_road_id==road.parcel_id and lot.road_direction==1 and lot.front_direction==Vector2(0,-heading),"stop binds the exact branch, travel direction and curb")
			var net := Buses.new()
			verify(net.build_city(city) and net.stops.has(lot.id),"actual scheduled network resolves branch berth")
			if not net.stops.has(lot.id):continue
			var lane: Dictionary=net.lanes[net.stops[lot.id].lane]
			var ok_berth: bool = lane.direction==1 and lane.index==variant and lane.get("bus_pocket",false)==(variant==0) and net.lanes.all(func(l):return l.direction==1)
			if variant==0:
				var entry: Dictionary=net.lanes[0]
				var through: int=entry.next[0]; var tail: int=lane.next[0]
				ok_berth=ok_berth and net.route(0,lane.id)==[0,lane.id] and through!=lane.id and net.lanes[through].next==[tail] and net.route(tail,0).is_empty()
			else:
				ok_berth=ok_berth and net.lanes.size()==2 and net.lanes[0].index==0 and net.route(0,lane.id).is_empty() and net.lanes[0].length>200
			verify(ok_berth,"6m pocket bypass or 8m independent inner through lane, no wrong-way edge")
			var other := path(Vector2(20,70),Vector2(80,70))
			verify(normal(city,other,2,0).ok,"unrelated demolition control road")
			var saved: Dictionary=city.roads[1].duplicate(true)
			var cut := city.road_demolition_selection(road.parcel_id,Vector2(40,40),Vector2(40+heading*2,40))
			verify(cut.ok and city.demolish_road_selection(cut).ok,"branch drag demolishes one selected 8m interval")
			var survivors := city.roads.filter(func(r):return r.has("road_variant"))
			verify(saved in city.roads and survivors.size()==2 and survivors[0].parcel_id==road.parcel_id and survivors.all(func(r):return r.road_variant==road.road_variant and r.travel_dir==1 and r.width==road.width),"both survivors preserve profile, heading and non-target ID")
			verify(not stripe_at(city.road_branch_edge_marks,Vector2(40+heading,outer_curb.y-.04*heading)) and lot.front_road_id>=0 and lot.road_direction==1 and lot.position==outer_curb,"paint respects cut and surviving stop remains fixed")

func private_lot(id: int,x: int,y: int) -> Dictionary:
	return {"id":id,"x":x,"y":y,"size":2,"level":3,"zone":"residential","asset_id":"","score":0.0}

func warning_b() -> void:
	for variant in [0,1]:
		var city := City.new(100,100)
		city.buildings.assign([private_lot(91,31,39),private_lot(92,45,40),private_lot(93,37,42)])
		city.next_id=94
		var points := path(Vector2(20,40),Vector2(60,40))
		var before := var_to_bytes([city.roads,city.buildings,city.next_road_id,city.road_topology_revision])
		var preview := city.add_branch_one_way(points,variant,false)
		verify(preview.ok and preview.warning and preview.demolish_ids==[91,92],"Warning B names only intersecting private building IDs")
		verify(not city.add_branch_one_way(points,variant).ok and not city.add_branch_one_way(points,variant,true,true,[91]).ok and before==var_to_bytes([city.roads,city.buildings,city.next_road_id,city.road_topology_revision]),"cancel or stale approval cannot mutate branch transaction")
		verify(city.add_branch_one_way(points,variant,true,true,preview.get("demolish_ids",[])).ok and city.buildings.size()==1 and city.buildings[0].id==93 and city.roads.size()==1,"approval removes exactly the two named lots")

func worker_checkpoint() -> void:
	var city := City.new(100,100)
	city.population_enabled=false
	city.happiness_enabled=false
	var legacy := path(Vector2(20,20),Vector2(60,20))
	verify(city.add_road(legacy).ok,"legacy road before real worker boot")
	var legacy_roads := road_record_bytes(city.roads)
	var legacy_graph := road_graph(city.roads)
	city.enable_simulation_worker()
	city.simulation.worker.Suspend()
	var legacy_checkpoint: Dictionary = bytes_to_var(var_to_bytes(city.simulation.worker.ExportCheckpoint()))
	city.simulation.worker.SetValidationGate(true)
	city.advance_society(2)
	var corner := PackedVector2Array([Vector2(20,50),Vector2(50,50),Vector2(50,34)])
	verify(city.add_branch_one_way(corner,Profile.BranchVariant.SIX_METRE).get("queued",false),"real worker queues authored 6m corner")
	verify(city.add_branch_one_way(path(Vector2(20,70),Vector2(60,70)),Profile.BranchVariant.EIGHT_METRE).get("queued",false),"real worker queues 8m branch")
	verify(city.roads.size()==1,"no branch record before worker publication")
	var first: bool = city.simulation.validation_publish()
	city.simulation.resume();city.advance_society(2)
	verify(first and city.simulation.validation_publish() and city.simulation.get_published_tick()==2,"both real worker boundaries publish")
	var state: Dictionary = city.simulation.export_validation_state()
	city.simulation.shutdown()
	verify_legacy_checkpoint(legacy_checkpoint,legacy_roads,legacy_graph)
	var checkpoint: Dictionary=bytes_to_var(var_to_bytes(state.get("checkpoint",{})))
	var values: Dictionary = checkpoint.get("model",{}).get("values",{})
	var ids_match: bool = not values.is_empty() and city.roads.size()==3 and road_record_bytes(values.roads)==road_record_bytes(city.roads) and values.next_road_id==city.next_road_id
	verify(ids_match,"native FIFO export preserves exact serialized primitive roads and ID watermark")
	if not ids_match:return
	var paint := city.road_branch_edge_marks
	verify(values.road_branch_edge_marks==paint and not paint.is_empty() and stripe_at(paint,Vector2(34,50.5225)) and stripe_at(paint,Vector2(34,70.71)),"native checkpoint initially contains real retained paint for both variants")
	# A cache copy in the checkpoint must not be able to satisfy reconstruction.
	values.erase("road_branch_edge_marks")
	values.road_asphalt=[]
	var replay := Mailbox.new()
	replay.Initialize(Adapter.new(),checkpoint)
	replay.Suspend()
	var boot: Dictionary = replay.ExportCheckpoint().get("model",{}).get("values",{})
	verify(not boot.is_empty() and boot.road_branch_edge_marks.is_empty() and boot.road_asphalt.is_empty(),"native boot starts without either retained cache")
	var submitted := replay.Submit({"base_tick":0,"base_revision":0,"revision":1,"world":{"roads":values.roads.duplicate(true)}},city.config.development_interval_seconds)
	replay.Suspend()
	var published := replay.PublishBoundary()
	var rebuilt: Dictionary = replay.ExportCheckpoint().get("model",{}).get("values",{})
	var fault := replay.GetFault()
	replay.Shutdown()
	verify(submitted and fault.is_empty() and int(published.get("logical_tick",0))==1 and int(published.get("revision",0))==1,"restored worker accepts and publishes a real road-dirty boundary")
	verify(not rebuilt.is_empty() and road_record_bytes(rebuilt.roads)==road_record_bytes(city.roads) and rebuilt.next_road_id==city.next_road_id and rebuilt.road_asphalt==city.road_asphalt and rebuilt.road_branch_edge_marks==paint and not paint.is_empty(),"road-dirty reconstruction reproduces exact nonempty asphalt and stripe caches from primitive variants")
	var ordinary := city.roads.duplicate(true)
	ordinary[1].erase("road_variant")
	verify(Transit.bus_topology_key_for(ordinary,[])==Transit.bus_topology_key(city),"6m paint and parking metadata do not invalidate an identical bus graph")

func road_graph(roads: Array) -> Array:
	var graph := Net.new()
	if not graph.build(roads):return []
	return graph.lanes.map(func(lane):return [lane.road,lane.direction,lane.index,lane.next,lane.curve.get_baked_points()])

func road_record_bytes(roads: Array) -> Array:
	# The adapter transports an untyped outer Array. Compare each record exactly.
	return roads.map(func(road):return var_to_bytes(road))

func verify_legacy_checkpoint(checkpoint: Dictionary,roads: Array,graph: Array) -> void:
	verify(not checkpoint.is_empty() and not graph.is_empty(),"real pre-branch export has a nonempty ordinary graph")
	if checkpoint.is_empty():return
	var values: Dictionary = checkpoint.model.values
	values.erase("road_branch_edge_marks") # Model what a pre-E4b writer actually omits.
	var replay := Mailbox.new()
	replay.Initialize(Adapter.new(),checkpoint)
	var restored: Dictionary = replay.ExportCheckpoint().get("model",{}).get("values",{})
	var fault := replay.GetFault()
	replay.Shutdown()
	var same_roads: bool = fault.is_empty() and not restored.is_empty() and road_record_bytes(restored.roads)==roads and restored.next_road_id==values.next_road_id
	verify(same_roads and not restored.roads[0].has("road_variant") and not restored.roads[0].has("travel_dir") and restored.roads[0].major_side==1,"pre-E4b native boot preserves exact legacy keys, types and IDs")
	verify(same_roads and restored.road_branch_edge_marks.is_empty() and restored.road_asphalt==values.road_asphalt and road_graph(restored.roads)==graph,"pre-E4b native boot keeps ordinary asphalt and directed graph unchanged")
