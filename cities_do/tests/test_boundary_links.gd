extends SceneTree
const Links=preload("res://core/boundary_links.gd")
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 for pair in [[Vector2(0,50),Vector2(25,50)],[Vector2(100,50),Vector2(75,50)],[Vector2(50,0),Vector2(50,25)],[Vector2(50,100),Vector2(50,75)],[Vector2(100,62),Vector2(70,48)],[Vector2(25,0),Vector2(45,45)]]:
  var city:=City.new(100,100)
  city.add_road(PackedVector2Array(pair),"local",true,4)
  var before:=var_to_str(city.roads)
  var links: Array=Links.road_links(city)
  verify(links.size()==1,"one genuine edge terminal receives a neighbor marking")
  if links.is_empty():continue
  verify(links[0].direction.dot((pair[0]-pair[1]).normalized())>.9999,"glyph follows road progress rather than screen vertical")
  var glyph: Array=Links.arrow_shapes(links[0])
  verify(glyph.size()==2 and glyph.all(func(p):return p.size()==7),"white bidirectional marking consists of two opposed filled arrows")
  var safe:=true
  for polygon in glyph:
   for p in polygon:safe=safe and p.x>=0 and p.y>=0 and p.x<=100 and p.y<=100
  verify(safe and var_to_str(city.roads)==before,"inset glyph stays inside map without changing road data")
  var flat:=true;var edge_vertices:=0
  for polygon in Geometry.clipped_ribbons(city.roads[0].points,4,Vector2(100,100)):
   for p in polygon:
    flat=flat and p.x>=0 and p.y>=0 and p.x<=100 and p.y<=100
    if p.distance_to(pair[0])>0 and (is_zero_approx(p.x-pair[0].x) if str(links[0].edge).begins_with("x") else is_zero_approx(p.y-pair[0].y)):edge_vertices+=1
  verify(flat and edge_vertices>=2,"road ribbon terminates flat at exact boundary with no round cap outside map")
 verify(Geometry.clipped_segment(Vector2(95,49),Vector2(102,50),Vector2(100,100))[-1].x==100,"oblique lane dash stops at boundary rather than floating outside clipped asphalt")
 verify(Geometry.clipped_segment(Vector2(102,49),Vector2(102,50),Vector2(100,100)).is_empty(),"fully exterior lane dash is not drawn")
 var city:=City.new(100,100)
 for points in [[Vector2(5,5),Vector2(40,30)],[Vector2(0,10),Vector2(0,40)],[Vector2(0,0),Vector2(20,20)]]:
  city.roads=[{"points":PackedVector2Array(points),"width":2.0,"lanes":2,"kind":"local"}]
  verify(Links.road_links(city).is_empty(),"interior road, edge-parallel touch or ambiguous corner never claims external connection")
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(50,70),Vector2(50,100)]))
 var port: Dictionary=city.power.ports.filter(func(p):return p.edge=="y_max")[0]
 var end: Vector2=port.position+Vector2.UP*80
 verify(Links.utility_links(city.power,true).is_empty(),"unused neighbor utility ports have no connection arrow")
 verify(city.power.add_wire(PackedVector2Array([port.position,end])).ok and city.water.add_pipe(PackedVector2Array([port.position,end])).ok,"real power and paired water/sewage connections build")
 var power:=city.power_state();var water:=city.water_state()
 for tab in [false,true,false]:
  verify(Links.utility_links(city.power,tab).size()==(1 if tab else 0),"power connection arrow follows its tab gate")
  verify(Links.utility_links(city.water.geometry,tab).size()==(1 if tab else 0),"water/sewage pair shares one tab-gated bidirectional icon")
 verify(city.power_state()==power and city.water_state()==water,"arrow queries never change real utility supply or metering")
 city.power.remove_wire(city.power.wires[0].id);city.water.remove_pipe(city.water.geometry.wires[0].id)
 verify(Links.utility_links(city.power,true).is_empty() and Links.utility_links(city.water.geometry,true).is_empty(),"demolishing final connection removes utility markers")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);await process_frame
 var p: Dictionary=game.city.power.ports.filter(func(v):return v.edge=="y_max")[0]
 game.city.power.add_wire(PackedVector2Array([p.position,p.position+Vector2.UP*80]));game.city.water.add_pipe(PackedVector2Array([p.position,p.position+Vector2.UP*80]))
 for tab in ["power","water","road"]:
  game.select_category(tab)
  verify(Links.utility_links(game.city.power,game.power_overlay.tab_open).size()==(1 if tab=="power" else 0) and Links.utility_links(game.city.water.geometry,game.water_overlay.tab_open).size()==(1 if tab=="water" else 0),"actual category switches gate connected arrows: "+tab)
 game.drawer.hide()
 verify(Links.utility_links(game.city.power,game.power_overlay.tab_open).is_empty() and Links.utility_links(game.city.water.geometry,game.water_overlay.tab_open).is_empty(),"closing actual tray hides both utility arrow layers")
 game.queue_free();await process_frame
 print("RESULT %d/%d boundary link checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
