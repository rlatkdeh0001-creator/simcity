extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func finish():
 for failure in failures:printerr("FAIL "+failure)
 print("TRANSIT_PORTS checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
func run():
 var routes=load("res://core/transit_routes.gd")
 check(routes.has_method("station_ports"),"spec-driven station port adapter exists")
 if not routes.has_method("station_ports"):finish();return
 var spec:Dictionary={"version":"v2","track_count":2,"track_included":false,"trackway_width_m":7.6,"track_midline_blender_y_m":10.0,"track_centres_blender_y_m":[8.0,12.0],"track_end_points_blender":[[-16.0,10.0,0.0],[16.0,10.0,0.0]],"platform_length_m":32.0,"max_consist_length_m":32.0}
 var result:Dictionary=routes.station_ports(spec,Vector2(30,40),Vector2.DOWN)
 check(result.ok,"valid v2 spec")
 check(result.points==PackedVector2Array([Vector2(26,37.5),Vector2(34,37.5)]),"Blender metres to city cells and front transform")
 check(result.ports[0].outward==Vector2.LEFT and result.ports[1].outward==Vector2.RIGHT,"ports carry perpendicular outward direction")
 check(result.track_offsets_m==PackedFloat64Array([-2.0,2.0]) and result.width_m==7.6,"spec-driven cross section")
 var rotated:Dictionary=routes.station_ports(spec,Vector2(30,40),Vector2.RIGHT)
 check(rotated.points==PackedVector2Array([Vector2(27.5,44),Vector2(27.5,36)]),"rotated station ports")
 var changed:=spec.duplicate(true)
 changed.track_midline_blender_y_m=11.0;changed.track_centres_blender_y_m=[9.0,13.0]
 changed.track_end_points_blender=[[-20.0,11.0,0.0],[20.0,11.0,0.0]]
 var adapted:Dictionary=routes.station_ports(changed,Vector2.ZERO,Vector2.DOWN)
 check(adapted.points==PackedVector2Array([Vector2(-5,-2.75),Vector2(5,-2.75)]),"port coordinates are read rather than hardcoded")
 changed.version="v1"
 check(not routes.station_ports(changed,Vector2.ZERO,Vector2.DOWN).ok,"v1 does not silently use v2 ports")
 check(not routes.station_ports({},Vector2.ZERO,Vector2.DOWN).ok,"missing spec rejected")
 changed=spec.duplicate(true);changed.track_end_points_blender=[[0,0],[1,2,3]]
 check(not routes.station_ports(changed,Vector2.ZERO,Vector2.DOWN).ok,"malformed ports rejected without runtime error")
 changed=spec.duplicate(true);changed.track_count="two"
 check(not routes.station_ports(changed,Vector2.ZERO,Vector2.DOWN).ok,"typed malformed count rejected")
 changed=spec.duplicate(true);changed.track_included="false"
 check(not routes.station_ports(changed,Vector2.ZERO,Vector2.DOWN).ok,"typed malformed inclusion rejected")
 check(not routes.station_ports(spec,Vector2.ZERO,Vector2.ZERO).ok,"zero front rejected")
 finish()
