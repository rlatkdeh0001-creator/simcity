extends SceneTree
const City = preload("res://core/city_model.gd")
var checks := 0
var failed := 0
func _initialize():
 run.call_deferred()
func verify(value: bool, label: String):
 checks += 1
 if value: print("PASS "+label)
 else:
  failed += 1
  push_error("FAIL "+label)
func run():
 var city := City.new(100,80,42)
 var towns: Array = city.regional_exchange().neighbors
 verify(towns.size()==4,"four neighbors exist on new map")
 var expected: Array=[['y_min','neighbor_advanced','Brightvale'],['x_max','neighbor_developed','Kindbrook'],['y_max','neighbor_peer_a','Ironfield'],['x_min','neighbor_peer_b','Fairwater']]
 for i in range(expected.size()):
  var spec: Array=expected[i]
  verify(towns[i].edge==spec[0] and towns[i].id==spec[1] and towns[i].development_name==spec[2],"approved town name matches its fixed map edge without changing identity: "+str(spec[0]))
  var power: Dictionary=city.power.ports.filter(func(p):return p.edge==spec[0])[0]
  var water: Dictionary=city.water.geometry.ports.filter(func(p):return p.edge==spec[0])[0]
  verify(power.name==spec[2] and water.name==spec[2],"power and water port data share the approved town name: "+str(spec[0]))
 verify(towns[0].development=="highly_developed" and towns[1].development=="developed" and towns[2].development=="peer" and towns[3].development=="peer","one very advanced, one developed and two distinct peers")
 for town in towns:
  verify(not town.exchange_available and town.channels.size()==6,"all six channels initially disconnected: "+town.edge)
 var road := PackedVector2Array([Vector2(50,20),Vector2(50,0)])
 verify(city.add_road(road,"local",false).ok and not city.regional_exchange().neighbors[0].exchange_available,"road preview cannot open exchange")
 city.add_road(road)
 towns=city.regional_exchange().neighbors
 verify(towns[0].exchange_available and towns[0].channels.road.connected,"boundary road automatically opens its neighbor road channel")
 verify(not towns[0].channels.power.connected and not towns[1].exchange_available,"road does not enable utilities or other town")
 city.add_road(road)
 city.roads.pop_back()
 verify(city.regional_exchange().neighbors[0].channels.road.connected,"one remaining road preserves connection")
 city.roads.clear()
 verify(not city.regional_exchange().neighbors[0].exchange_available,"removing last road closes exchange")
 for kind in ["rail","power","metro","water","sewage"]:
  var before: int = city.external_infrastructure.size()
  verify(city.add_external_link(kind,road,false).ok and city.external_infrastructure.size()==before,"utility preview nonmutating: "+kind)
  var added: Dictionary = city.add_external_link(kind,road)
  verify(added.ok and city.regional_exchange().neighbors[0].channels[kind].connected,"independent infrastructure terminal: "+kind)
  verify(city.remove_external_link(added.link.id) and not city.regional_exchange().neighbors[0].channels[kind].connected,"removal closes infrastructure channel: "+kind)
 verify(not city.add_external_link("internet",road).ok,"unknown infrastructure rejected")
 verify(not city.add_external_link("power",PackedVector2Array([Vector2(0,10),Vector2(-1,10)])).ok,"outside path rejected")
 verify(not city.add_external_link("water",PackedVector2Array([Vector2(NAN,1),Vector2(0,1)])).ok,"non-finite coordinate rejected")
 verify(not city.add_external_link("metro",PackedVector2Array([Vector2(1,1),Vector2(1,1)])).ok,"degenerate connection rejected")
 city.add_road(PackedVector2Array([Vector2(1,1),Vector2(0,0)]))
 verify(not city.regional_exchange().neighbors.any(func(t):return t.exchange_available),"corner does not silently connect two neighbors")
 city.roads.clear()
 city.add_road(PackedVector2Array([Vector2(10,0),Vector2(30,0)]))
 verify(not city.regional_exchange().neighbors[0].exchange_available,"road along boundary is not an outward terminal")
 city.roads.clear()
 city.add_road(PackedVector2Array([Vector2(10,.02),Vector2(30,.02)]))
 verify(not city.regional_exchange().neighbors[0].exchange_available,"near-boundary road cannot open exchange by visual width alone")
 city.roads.clear()
 city.add_road(PackedVector2Array([Vector2(10,10),Vector2(20,0),Vector2(30,10)]))
 verify(not city.regional_exchange().neighbors[0].exchange_available,"intermediate boundary touch is not a terminal")
 city.roads.clear()
 city.add_road(PackedVector2Array([Vector2(0,40),Vector2(50,40),Vector2(100,40)]),"highway")
 towns=city.regional_exchange().neighbors
 verify(towns[1].channels.road.connected and towns[3].channels.road.connected,"opposite endpoints connect both appropriate sides; highway counts as road")
 city.add_external_link("water",PackedVector2Array([Vector2(50,40),Vector2(50,80)]))
 towns=city.regional_exchange().neighbors
 verify(towns[2].channels.water.connected and not towns[2].channels.sewage.connected,"water and sewage stay independent")
 verify(towns[2].id!=towns[3].id,"peer towns remain separate identities")
 verify(not city.regional_exchange().economy_simulated,"connection flags do not claim an economy or free utility supply")
 print("RESULT %d/%d regional checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
