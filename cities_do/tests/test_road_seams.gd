extends SceneTree
const Topology=preload("res://core/road_junctions.gd")
const Network=preload("res://core/traffic_network.gd")
const Simulation=preload("res://core/traffic_simulation.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func road(points: Array,lanes: int=4) -> Dictionary:
 return {"points":PackedVector2Array(points),"width":float(lanes),"lanes":lanes,"kind":"local"}
func route(network,first: int,last: int) -> Array:
 for a in network.lanes:
  if a.road!=first:continue
  for b in network.lanes:
   if b.road!=last:continue
   var path: Array=network.route(a.id,b.id)
   if not path.is_empty():return path
 return []
func run():
 for end in [Vector2(65,40),Vector2(65,42),Vector2(65,53),Vector2(40,70)]:
  var roads:=[road([Vector2(10,40),Vector2(40,40)]),road([Vector2(40,40),end])]
  var original:=var_to_str(roads)
  var topology: Dictionary=Topology.analyze(roads)
  verify(topology.junctions.is_empty(),"two-arm seam is never a controlled intersection "+str(end))
  var network:=Network.new()
  verify(network.build(roads) and network.junctions.is_empty(),"lane connection builds with no traffic-control junction")
  var forward:=route(network,0,1);var reverse:=route(network,1,0)
  verify(not forward.is_empty() and not reverse.is_empty(),"both carriageways stay routed through seam")
  if forward.is_empty() or reverse.is_empty():continue
  var continuous:=true
  for path in [forward,reverse]:
   for i in range(1,path.size()):continuous=continuous and network.sample(path[i-1],network.lanes[path[i-1]].length).distance_to(network.sample(path[i],0))<.1
  verify(continuous,"lane connector endpoints meet without teleportation")
  var sim:=Simulation.new(network)
  sim.spawn({"id":"car-hatch-01","length_m":4.0,"max_speed":14.0},forward,network.lanes[forward[0]].length-10)
  for i in range(1800):sim.update(1.0/30)
  verify(sim.reservations.is_empty() and sim.vehicles.size()==1 and sim.vehicles[0].arrived,"traffic completes seam without intersection reservation or signal stop")
  verify(var_to_str(roads)==original,"derived seam preserves authored road records")
 # These assertions are reached after the topology failure in the RED run.
 if failures>0:print("RESULT %d/%d seam checks passed" % [checks-failures,checks]);quit(1);return
 var chain:=[road([Vector2(10,40),Vector2(40,40)]),road([Vector2(40,40),Vector2(65,53)]),road([Vector2(80,70),Vector2(65,53)])]
 var visual: Array=Geometry.continuous_roads(chain)
 verify(visual.size()==1,"three separately drawn matching roads form one visual stroke")
 verify(visual[0].points[0]==Vector2(10,40) and visual[0].points[-1]==Vector2(80,70),"reverse-authored continuation retains chain endpoints")
 verify(visual[0].points.size()>chain.size()+1,"bent joins are sampled as smooth tangent curves")
 var straight: Array=Geometry.continuous_roads([road([Vector2(10,40),Vector2(40,40)]),road([Vector2(40,40),Vector2(65,40)])])
 var whole: Dictionary=road([Vector2(10,40),Vector2(40,40),Vector2(65,40)])
 verify(Geometry.lane_marks(straight[0])==Geometry.lane_marks(whole),"dash phase continues across separately drawn collinear seam")
 var tee:=[chain[0],road([Vector2(40,40),Vector2(70,40)]),road([Vector2(40,40),Vector2(40,70)])]
 verify(Topology.analyze(tee).junctions.size()==1 and Geometry.continuous_roads(tee).size()==3,"three-arm branch remains a true intersection")
 var mixed:=[road([Vector2(10,40),Vector2(40,40)],2),road([Vector2(40,40),Vector2(70,40)],4)]
 var net:=Network.new();net.build(mixed)
 verify(net.junctions.is_empty() and not route(net,0,1).is_empty() and not route(net,1,0).is_empty(),"lane-width transition stays bidirectional without intersection control")
 print("RESULT %d/%d seam checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
