extends RefCounted
## Finish actual upstream meshes: one surface owner at same-height merges.
const Geometry=preload("res://core/road_geometry.gd")
const Palette=preload("res://shaders/road_palette.gdshader")
var report:Dictionary={"trimmed_triangles":0,"removed_area_m2":0.0,"openings":0}
var parent_polygons:Dictionary={}
func xz(v:Vector3)->Vector2:return Vector2(v.x,v.z)
func world_polygon(adapter,road:Dictionary)->PackedVector2Array:
	var points:=PackedVector2Array()
	for p in road.points:points.append(xz(adapter.point3(p,0)))
	return Geometry2D.offset_polyline(points,road.width*2,Geometry2D.JOIN_ROUND,Geometry2D.END_SQUARE)[0]
func polygon_area(poly:PackedVector2Array)->float:
	var area:=0.0
	for i in range(poly.size()):area+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(area)*.5
func barycentric(p:Vector2,triangle:Array)->Vector3:
	var a:=xz(triangle[0]);var b:=xz(triangle[1]);var c:=xz(triangle[2])
	var denominator:float=(b-a).cross(c-a)
	var v:float=(p-a).cross(c-a)/denominator
	var w:float=(b-a).cross(p-a)/denominator
	return Vector3(1-v-w,v,w)
func trim(instance:MeshInstance3D,parents:Array,adapter,road:Dictionary)->void:
	var old:Mesh=instance.mesh;var output:=ArrayMesh.new()
	for surface in range(old.get_surface_count()):
		var arrays:Array=old.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()):indices.append(i)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count:=0
		for i in range(0,indices.size(),3):
			var ids:Array=[indices[i],indices[i+1],indices[i+2]]
			var triangle:Array=[];var poly:=PackedVector2Array()
			for id in ids:
				var p:Vector3=instance.to_global(vertices[id])
				if road.get("smooth_join",false):
					var cell:=Vector2(p.x/4+50,p.z/4+50)
					var adjusted:=preload("res://core/ramp_geometry.gd").weld(cell,road)
					p.x=(adjusted.x-50)*4;p.z=(adjusted.y-50)*4
				triangle.append(p);poly.append(xz(p))
			var pieces:Array[PackedVector2Array]=[poly]
			var center:Vector3=(triangle[0]+triangle[1]+triangle[2])/3
			var area:=polygon_area(poly)
			var applicable:Array=[]
			for parent in parents:
				if absf(center.y-parent.height)<=.6:applicable.append(parent.polygon)
			if area<.000001:
				var hidden:=false
				for parent in applicable:
					if Geometry2D.is_point_in_polygon(xz(center),parent):hidden=true;break
				if hidden:report.trimmed_triangles+=1;continue
				for k in range(3):
					st.set_uv(uvs[ids[k]] if not uvs.is_empty() else Vector2.ZERO);st.add_vertex(instance.to_local(triangle[k]));count+=1
				continue
			for parent in applicable:
				var remaining:Array[PackedVector2Array]=[]
				for piece in pieces:remaining.append_array(Geometry2D.clip_polygons(piece,parent))
				pieces=remaining
			var remaining_area:=0.0
			for piece in pieces:remaining_area+=polygon_area(piece)
			if area-remaining_area>.00001:
				report.trimmed_triangles+=1;report.removed_area_m2+=area-remaining_area
			for piece in pieces:
				var triangulation:=Geometry2D.triangulate_polygon(piece)
				# Preserve the upstream face winding after planar clipping.
				for t in range(0,triangulation.size(),3):
					var i0:int=triangulation[t];var i1:int=triangulation[t+1];var i2:int=triangulation[t+2]
					if (piece[i1]-piece[i0]).cross(piece[i2]-piece[i0])*(poly[1]-poly[0]).cross(poly[2]-poly[0])<0:
						triangulation[t+1]=i2;triangulation[t+2]=i1
				for index in triangulation:
					var weights:=barycentric(piece[index],triangle)
					var p:Vector3=triangle[0]*weights.x+triangle[1]*weights.y+triangle[2]*weights.z
					var uv:=Vector2.ZERO
					if not uvs.is_empty():uv=uvs[ids[0]]*weights.x+uvs[ids[1]]*weights.y+uvs[ids[2]]*weights.z
					st.set_uv(uv);st.add_vertex(instance.to_local(p));count+=1
		if count>0:
			st.index();st.generate_normals();st.set_material(old.surface_get_material(surface));st.commit(output)
	instance.mesh=output
func make_material(adapter,ri:int)->ShaderMaterial:
	var road:Dictionary=adapter.source_city.roads[ri]
	var material:=ShaderMaterial.new();material.shader=Palette
	var original:StandardMaterial3D=load("res://addons/road-generator/resources/road_texture.material")
	material.set_shader_parameter("road_texture",original.albedo_texture)
	material.set_shader_parameter("allow_white_paint",road.kind!="ramp")
	material.set_shader_parameter("allow_yellow_paint",road.kind!="ramp")
	material.set_shader_parameter("curb",Color("c8cbc3") if road.kind=="local" else Color("a8b4b6"))
	var axes:=PackedVector4Array();var openings:=PackedVector4Array()
	if road.kind!="ramp":
		for i in range(mini(64,road.points.size()-1)):
			var a:Vector3=adapter.point3(road.points[i],0);var b:Vector3=adapter.point3(road.points[i+1],0)
			axes.append(Vector4(a.x,a.z,b.x,b.z))
		for merge in adapter.merge_points:
			var port:Dictionary=merge.port
			if port.road!=ri:continue
			var center:Vector3=adapter.point3(port.anchor,port.layer*8)
			var edge:Vector3=center+Vector3(port.normal.x,0,port.normal.y)*Geometry.carriageway_width(road)*2
			var a:Vector3=edge+merge.heading*(-2 if merge.start else -30)
			var b:Vector3=edge+merge.heading*(30 if merge.start else 2)
			openings.append(Vector4(a.x,a.z,b.x,b.z))
		report.openings+=openings.size()
	material.set_shader_parameter("axis_count",axes.size());axes.resize(64);material.set_shader_parameter("road_axes",axes)
	material.set_shader_parameter("half_carriageway",Geometry.carriageway_width(road)*2)
	material.set_shader_parameter("opening_count",openings.size());openings.resize(8);material.set_shader_parameter("openings",openings)
	return material
func apply(adapter)->void:
	for ri in range(adapter.source_city.roads.size()):
		var road:Dictionary=adapter.source_city.roads[ri]
		if road.kind!="ramp":parent_polygons[ri]=world_polygon(adapter,road)
	for ri in range(adapter.containers.size()):
		var road:Dictionary=adapter.source_city.roads[ri]
		var material:=make_material(adapter,ri)
		var parents:Array=[]
		if road.kind=="ramp":
			for port in [road.start_attachment,road.end_attachment]:parents.append({"height":port.layer*8,"polygon":parent_polygons[port.road]})
		for segment in adapter.containers[ri].get_segments():
			if road.kind=="ramp":trim(segment.road_mesh,parents,adapter,road)
			if segment.road_mesh.mesh.get_surface_count()>0:segment.road_mesh.set_surface_override_material(0,material)
