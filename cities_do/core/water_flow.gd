extends RefCounted
## Display-only fluid pulses. Volume and service never read these markers.
const Flow = preload("res://core/power_flow.gd")
static func markers(state: Dictionary, seconds: float, speed: float = 48.0, interval: float = 1.1) -> Array:
 var result := []
 for kind in ["water","sewage"]:
  var phase: float=0 if kind=="water" else .4
  for marker in Flow.markers({"routes":state.get(kind+"_routes",[])},maxf(0,seconds-phase),speed,interval):
   marker.kind=kind
   marker.pulse=seconds*7.0+marker.position.x*.03+marker.position.y*.02
   result.append(marker)
 return result

static func contour(center: Vector2, radius: float, phase: float) -> PackedVector2Array:
 var polygon := PackedVector2Array()
 var stretch := 1.0+.17*sin(phase)
 for i in range(24):
  var a := TAU*i/24.0
  var r := radius*(1.0+.09*sin(3*a-phase*1.2))
  polygon.append(center+Vector2(cos(a)*stretch,sin(a)/stretch)*r)
 return polygon
