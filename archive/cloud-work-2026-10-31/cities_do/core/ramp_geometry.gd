extends RefCounted
## Shared C2 ramp centreline, taper, height and edge weld for gameplay and 3D.
static func smooth(t:float)->float:
	t=clampf(t,0,1)
	return t*t*t*(10+t*(-15+6*t))
static func smooth_derivative(t:float)->float:
	t=clampf(t,0,1)
	return 30*t*t*(1-t)*(1-t)
static func evaluate(control:PackedVector2Array,t:float)->Vector2:
	var work:=control.duplicate()
	for count in range(work.size()-1,0,-1):
		for i in range(count):work[i]=work[i].lerp(work[i+1],t)
	return work[0]
static func derivative(road:Dictionary,t:float)->Vector2:
	var control:PackedVector2Array=road.curve_controls
	var result:=PackedVector2Array()
	for i in range(5):result.append((control[i+1]-control[i])*5)
	return evaluate(result,t)
static func width_factor(road:Dictionary,t:float)->float:
	var fraction:float=road.get("taper_fraction",.28)
	return smooth(t/fraction)*smooth((1-t)/fraction)
static func height(road:Dictionary,t:float)->float:
	return lerpf(road.start_layer,road.end_layer,smooth(t))
static func configure(road:Dictionary,start_heading:Vector2,end_heading:Vector2,samples:int=48,taper:float=.28,fillet:float=.75):
	var a:Vector2=road.start_attachment.position;var b:Vector2=road.end_attachment.position
	var handle:float=a.distance_to(b)*.20
	road.curve_controls=PackedVector2Array([a,a+start_heading*handle,a+start_heading*handle*2,b-end_heading*handle*2,b-end_heading*handle,b])
	road.taper_fraction=taper;road.fillet_width=fillet;road.smooth_join=true
	road.start_attachment.heading=start_heading;road.end_attachment.heading=end_heading
	road.points=PackedVector2Array();road.tangents=PackedVector2Array();road.width_factors=PackedFloat32Array()
	for i in range(samples+1):
		var t:=float(i)/samples
		road.points.append(evaluate(road.curve_controls,t));road.tangents.append(derivative(road,t).normalized());road.width_factors.append(width_factor(road,t))
static func weld(point:Vector2,road:Dictionary)->Vector2:
	var blend:float=road.get("fillet_width",.75)
	for port in [road.start_attachment,road.end_attachment]:
		var distance:float=(point-port.position).dot(port.normal)
		if distance>0 and distance<blend:
			var s:float=distance/blend
			# Positive-part fillet: value, tangent and curvature match the straight edge.
			var softened:float=blend*s*s*s*(6+s*(-8+3*s))
			point+=port.normal*(softened-distance)
	return point
static func edge(road:Dictionary,side:float,fraction:float=1.0)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(road.points.size()):
		var tangent:Vector2=road.tangents[i];var normal:=Vector2(-tangent.y,tangent.x)
		result.append(weld(road.points[i]+normal*side*road.width*road.width_factors[i]*fraction/2,road))
	return result
static func ribbon(road:Dictionary,fraction:float=1.0)->PackedVector2Array:
	var left:=edge(road,-1,fraction);var right:=edge(road,1,fraction);right.reverse()
	var polygon:=PackedVector2Array()
	for p in left+right:
		if polygon.is_empty() or p.distance_to(polygon[-1])>.000001:polygon.append(p)
	if polygon.size()>1 and polygon[0].distance_to(polygon[-1])<.000001:polygon.resize(polygon.size()-1)
	return polygon
static func mouth(road:Dictionary,port:Dictionary,parent:Dictionary)->PackedVector2Array:
	var geometry=preload("res://core/road_geometry.gd")
	var start:bool=port.road==road.start_attachment.road and port.position.distance_to(road.start_attachment.position)<.0001
	var inner:float=geometry.carriageway_width(parent)/2-.015
	var gap:float=parent.width/2-inner
	var inside:=PackedVector2Array();var outside:=PackedVector2Array()
	for i in range(25):
		var t:=float(i)/24
		var center:Vector2=port.anchor+port.heading*(5*t if start else -5*t)
		var extent:float=smooth(t*4)*smooth((1-t)*4)
		inside.append(center+port.normal*inner)
		outside.append(center+port.normal*(inner+gap*extent))
	outside.reverse()
	var polygon:=PackedVector2Array()
	for p in inside+outside:
		if polygon.is_empty() or p.distance_to(polygon[-1])>.000001:polygon.append(p)
	if polygon[0].distance_to(polygon[-1])<.000001:polygon.resize(polygon.size()-1)
	return polygon
