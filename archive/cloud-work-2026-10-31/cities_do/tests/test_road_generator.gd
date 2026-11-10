extends SceneTree
const Model=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Adapter=preload("res://core/road_generator_adapter.gd")
var failed:=false
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	if value:print("PASS ",label)
	else:failed=true;push_error(label)
func run():
	var city=Model.new(100,100)
	city.add_road(PackedVector2Array([Vector2(50,24),Vector2(50,76)]),"local",true,4)
	city.add_road(PackedVector2Array([Vector2(24,50),Vector2(76,50)]),"highway",true,4)
	city.add_interchange_at(Vector2(50,50))
	var road_count:int=city.roads.size();var edge_count:int=city.road_network.edges.size()
	var adapter=Adapter.new();root.add_child(adapter);adapter.build(city)
	for i in range(5):await process_frame
	var stats:Dictionary=adapter.stats();print("UPSTREAM STATS ",stats)
	check(stats.containers==6 and stats.meshes==stats.segments and stats.vertices>500,"real upstream runtime creates all motorway, local and ramp meshes")
	check(stats.merge_points==8 and stats.lanes>0,"upstream lane paths and eight side taper points generated")
	check(city.roads.size()==road_count and city.road_network.edges.size()==edge_count,"3D comparison preserves construction model")
	var good:=true
	for point in adapter.merge_points:
		var port:Dictionary=point.port
		var offset:Vector3=point.position-adapter.point3(port.anchor,port.layer*8)
		var lateral:float=offset.dot(Vector3(port.normal.x,0,port.normal.y))
		good=good and lateral>0 and lateral<=city.roads[port.road].width*2+.001
	check(good,"every taper ends in the outside lane, never at the road median")
	var finite_vertices:=true
	for container in adapter.containers:
		for segment in container.get_segments():
			var mesh=segment.road_mesh.mesh
			for surface in range(mesh.get_surface_count()):
				for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:finite_vertices=finite_vertices and vertex.is_finite()
	check(finite_vertices,"upstream mesh vertices are finite")
	check(adapter.surface_finisher.report.trimmed_triangles>0 and adapter.surface_finisher.report.removed_area_m2>0,"same-height overlapping ramp triangles are physically trimmed")
	check(adapter.surface_finisher.report.openings==8,"all eight ramp mouths open the white edge stripe")
	var overlap_free:=true;var open_at_ports:=true;var median_closed:=true
	for ri in range(adapter.containers.size()):
		var road:Dictionary=city.roads[ri]
		for segment in adapter.containers[ri].get_segments():
			var instance=segment.road_mesh
			if road.kind!="ramp":
				var mat=instance.get_surface_override_material(0)
				var openings:PackedVector4Array=mat.get_shader_parameter("openings")
				var count:int=mat.get_shader_parameter("opening_count")
				for merge in adapter.merge_points:
					if merge.port.road!=ri:continue
					var port:Dictionary=merge.port
					var anchor:Vector3=adapter.point3(port.anchor,port.layer*8)
					var edge:Vector3=anchor+Vector3(port.normal.x,0,port.normal.y)*Geometry.carriageway_width(road)*2
					var opened:=false
					for o in range(count):
						var a:=Vector2(openings[o].x,openings[o].y);var b:=Vector2(openings[o].z,openings[o].w)
						if Geometry2D.get_closest_point_to_segment(Vector2(edge.x,edge.z),a,b).distance_to(Vector2(edge.x,edge.z))<2.5:opened=true
						if Geometry2D.get_closest_point_to_segment(Vector2(anchor.x,anchor.z),a,b).distance_to(Vector2(anchor.x,anchor.z))<2.5:median_closed=false
					open_at_ports=open_at_ports and opened
				continue
			var arrays:Array=instance.mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for t in range(0,indices.size(),3):
				var triangle:Array=[];var poly:=PackedVector2Array()
				for k in range(3):
					var vertex:Vector3=instance.to_global(vertices[indices[t+k]])
					triangle.append(vertex);poly.append(Vector2(vertex.x,vertex.z))
				var center:Vector3=(triangle[0]+triangle[1]+triangle[2])/3
				for port in [road.start_attachment,road.end_attachment]:
					if absf(center.y-port.layer*8)>.6:continue
					for intersection in Geometry2D.intersect_polygons(poly,adapter.surface_finisher.parent_polygons[port.road]):
						if adapter.surface_finisher.polygon_area(intersection)>.001:overlap_free=false
	check(overlap_free,"finished ramp top surfaces have no positive-area same-height overlap with parent roads")
	check(open_at_ports and median_closed,"white edge stripe is open at ramp mouths while centre median stays intact")
	var right_hand_paths:=true;var ramps_follow_flow:=true;var ramps_unpainted:=true
	for ri in range(adapter.containers.size()):
		var road:Dictionary=city.roads[ri]
		for segment in adapter.containers[ri].get_segments():
			if road.kind=="ramp":
				var mat=segment.road_mesh.get_surface_override_material(0)
				ramps_unpainted=ramps_unpainted and mat.get_shader_parameter("allow_white_paint")==false
			for lane in segment.get_lanes():
				if lane.curve.point_count<2:continue
				var a:Vector3=lane.to_global(lane.curve.get_point_position(0))
				var b:Vector3=lane.to_global(lane.curve.get_point_position(lane.curve.point_count-1))
				if road.kind=="ramp":
					ramps_follow_flow=ramps_follow_flow and (b-a).dot(segment.end_point.global_position-segment.start_point.global_position)>0
				else:
					var start:Vector3=adapter.point3(road.points[0],0);var end:Vector3=adapter.point3(road.points[-1],0)
					var middle:=Vector2((a.x+b.x)/2,(a.z+b.z)/2)
					var center:=Geometry2D.get_closest_point_to_segment(middle,Vector2(start.x,start.z),Vector2(end.x,end.z))
					right_hand_paths=right_hand_paths and Vector2(b.x-a.x,b.z-a.z).cross(middle-center)>0
	check(right_hand_paths,"actual upstream lane curves use right-hand traffic")
	check(ramps_follow_flow,"actual upstream ramp curves follow entry and exit flow")
	check(ramps_unpainted,"all ramp surface materials suppress white paint for their entire length")
	for reversed in [false,true]:
		var odd_city=Model.new(100,100)
		odd_city.add_road(PackedVector2Array([Vector2(5,50),Vector2(95,50)]),"highway",true,5,reversed)
		var odd=Adapter.new();root.add_child(odd);odd.build(odd_city)
		var forward:=0;var backward:=0;var right_sides:=true
		var profile:=Geometry.lane_profile(odd_city.roads[0])
		for segment in odd.containers[0].get_segments():
			for lane in segment.get_lanes():
				var a:Vector3=lane.to_global(lane.curve.get_point_position(0));var b:Vector3=lane.to_global(lane.curve.get_point_position(lane.curve.point_count-1))
				if b.x>a.x:forward+=1
				else:backward+=1
				right_sides=right_sides and (b.x-a.x)*((a.z+b.z)/2-profile.median_offset*4)>0
		check(forward==profile.forward and backward==profile.backward and right_sides,"actual odd-lane path allocation preserves right-hand traffic when reversed")
		odd.queue_free();await process_frame
	var comparison=load("res://road_generator_comparison.tscn").instantiate();root.add_child(comparison)
	for i in range(3):await process_frame
	check(comparison.adapter.stats().meshes==comparison.adapter.stats().segments and comparison.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"before-after scene instantiates the real plugin and matched plan camera")
	comparison.set_camera(true)
	check(comparison.perspective and comparison.camera.position.y>0,"comparison switches to an elevated 3D view")
	comparison.queue_free();await process_frame
	adapter.queue_free();await process_frame
	print("RESULT upstream integration ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
