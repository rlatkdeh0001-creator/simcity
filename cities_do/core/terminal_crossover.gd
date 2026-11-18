extends RefCounted
## Canonical terminal switch geometry: world metres, from station port outward.
const Routes = preload("res://core/transit_routes.gd")
const Height = preload("res://core/road_height.gd")
const LENGTH := 32.0
const EPS := 0.002 # Same 2 mm world tolerance as the operating-line graph.
const ERROR_TEXT := "종점 역 앞에 곧은 복선 8칸이 필요합니다"

static func failure() -> Dictionary:
 return Routes.failure("terminal_crossover", ERROR_TEXT)

static func owned(city) -> Dictionary:
 # The line rows are the sole authoritative ownership journal. Reconstruct in
 # canonical order; the same FIFO delta also covers create/delete in one batch.
 var result: Dictionary = {}
 var lots: Dictionary = {}
 for lot: Dictionary in city.public_facilities.lots:lots[lot.id] = lot
 var lines: Array = city.transit_lines.duplicate()
 lines.sort_custom(func(a,b):return a.id<b.id)
 for line: Dictionary in lines:
  for pair: Array in line.get("terminal_ports", []):
   if not lots.has(pair[0]):continue
   var key := "%d:%d" % [pair[0],pair[1]]
   if not result.has(key):
    var x := geometry(lots[pair[0]], pair[1])
    if not available(city,x):continue
    x.line_ids = []
    result[key] = x
   result[key].line_ids.append(line.id)
 return result

static func geometry(lot: Dictionary, port_index: int) -> Dictionary:
 var port: Dictionary = lot.station_ports[port_index]
 var start: Vector2 = port.point * 4.0
 var axis: Vector2 = port.outward.normalized()
 var side := Vector2(-axis.y, axis.x)
 var kind: String = port.kind
 var offsets: PackedFloat64Array = Routes.profile(kind).track_offsets_m
 var half: float = offsets[1]
 var shift := half * 2.0
 # Chord constraints at both ends determine the exact radius. The metro's
 # nominal 32.9 m is rounded; forcing it would miss the fixed 32 m host.
 var radius := (LENGTH * LENGTH + shift * shift) / (4.0 * shift)
 var turn := 2.0 * atan(shift / LENGTH)
 var pieces := ceili(radius * turn / 0.5)
 var paths: Array[PackedVector2Array] = []
 for sign_value: float in [-1.0, 1.0]:
  var path := PackedVector2Array()
  for i in range(2 * pieces + 1):
   var mirrored := i > pieces
   var angle := turn * float(2 * pieces - i if mirrored else i) / pieces
   var x := radius * sin(angle)
   var y := -half + radius * (1.0 - cos(angle))
   path.append(start + axis * (LENGTH - x if mirrored else x) + side * sign_value * (-y if mirrored else y))
  paths.append(path)
 return {"key": "%d:%d" % [lot.id, port_index], "station_id": lot.id, "port": port_index,
  "kind": kind, "start": start, "end": start + axis * LENGTH, "axis": axis,
  "paths": paths, "radius_m": radius, "lateral_m": shift}

static func available(city, x: Dictionary) -> bool:
 var start: Vector2 = x.start / 4.0
 var end: Vector2 = x.end / 4.0
 var axis: Vector2 = x.axis
 var side := Vector2(-axis.y, axis.x)
 var profile := Routes.profile(x.kind)
 var padding: float = float(profile.width) / 2.0
 var strip := PackedVector2Array([start-side*padding, end-side*padding, end+side*padding, start+side*padding])
 var intervals: Array[Vector2] = []
 for route: Dictionary in city.transit_routes:
  if route.kind != x.kind or route.get("station_id", -1) == x.station_id:
   continue
  for i in range(1, route.points.size()):
   var a: Vector2 = route.points[i-1] - start
   var b: Vector2 = route.points[i] - start
   var lo := minf(a.dot(axis), b.dot(axis))
   var hi := maxf(a.dot(axis), b.dot(axis))
   if absf(a.cross(axis))*4.0 <= EPS and absf(b.cross(axis))*4.0 <= EPS and not route.has("station_id"):
    # E3a: an X crossover only sits on ground track, never on a ramp or deck.
    if hi > 0.0 and lo < LENGTH / 4.0 and maxf(Height.height_at(route, route.points[i-1]), Height.height_at(route, route.points[i])) > Height.EPS:
     return false
    if hi > 0.0 and lo < LENGTH / 4.0:
     intervals.append(Vector2(maxf(0.0, lo), minf(LENGTH/4.0, hi)))
   elif _obstructs(a, b, axis, padding):
    return false
 intervals.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
 var covered := 0.0
 for interval in intervals:
  if interval.x > covered + EPS/4.0:
   return false
  covered = maxf(covered, interval.y)
 if covered < (LENGTH-EPS)/4.0:
  return false
 if x.kind == "rail":
  for pavement: PackedVector2Array in city.road_pavement + city.junction_pavement:
   if not Geometry2D.intersect_polygons(strip, pavement).is_empty():
    return false
 return true

static func conflict_zone(x: Dictionary) -> Dictionary:
 var center: Vector2 = (x.start+x.end)/2.0
 var along: Vector2 = x.axis*4.0
 var across: Vector2 = along.orthogonal().normalized()*(x.lateral_m/2.0+2.0)
 return {"kind":x.kind,"center":center,"polygon":PackedVector2Array([
  center-along-across,center+along-across,center+along+across,center-along+across])}

static func _obstructs(a: Vector2, b: Vector2, axis: Vector2, padding: float) -> bool:
 # Clip the obstruction segment to the host's axial interval, then test lateral
 # distance. At the far boundary a tangent continuation is not a branch.
 var ax := a.dot(axis)
 var bx := b.dot(axis)
 var limit := LENGTH / 4.0
 if maxf(ax, bx) < -EPS/4.0 or minf(ax, bx) > limit + EPS/4.0:
  return false
 var t0 := 0.0
 var t1 := 1.0
 if absf(bx-ax) > 0.000001:
  t0 = clampf(minf(-ax/(bx-ax), (limit-ax)/(bx-ax)), 0.0, 1.0)
  t1 = clampf(maxf(-ax/(bx-ax), (limit-ax)/(bx-ax)), 0.0, 1.0)
 if is_equal_approx(t0,t1) and minf(ax,bx) >= limit-EPS/4.0:
  return absf((b-a).normalized().cross(axis)) > 0.025 and absf(a.lerp(b,t0).cross(axis)) < padding*2.0
 var y0 := a.lerp(b,t0).cross(axis)
 var y1 := a.lerp(b,t1).cross(axis)
 return minf(y0,y1) < padding*2.0 and maxf(y0,y1) > -padding*2.0
