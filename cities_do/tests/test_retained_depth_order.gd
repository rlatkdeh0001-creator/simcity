extends SceneTree
const City=preload("res://core/city_model.gd")
const Order=preload("res://core/isometric_order.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
static func record(id:int,origin:Vector2,size:int,front:Vector2,asset:String="")->Dictionary:
 return {"id":id,"x":origin.x,"y":origin.y,"size":size,"level":5 if size==8 else 1,"zone":"industrial","score":0.0,"asset_id":asset,"front_direction":front,"front_road_id":-1}
static func engine_order(renderer)->Array:
 # Godot 4.6.3 ItemYSort: approximate Y equality falls back to ysort_index.
 var nodes:Array=renderer.buildings.values()
 nodes.sort_custom(func(a,b):return a.get_index()<b.get_index() if is_equal_approx(a.position.y,b.position.y) else a.position.y<b.position.y)
 return nodes.map(func(n):return n.record.id)
static func insert_record(city,value:Dictionary):
 if value.has("public_asset_id"):city.public_facilities.lots.append(value)
 else:city.buildings.append(value)
func run():
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 for sizes in [[2,4],[2,8],[4,8]]:
  for turns in range(4):
   var city=City.new(150,150);var raw:Array=[]
   for spec in [[1,Vector2(40+sizes[1]+1,43-sizes[0]),sizes[0]],[2,Vector2(40,40),sizes[1]]]:
    var shape:=city.footprint(record(spec[0],spec[1],spec[2],Vector2.DOWN));var minimum:=Vector2(INF,INF)
    for p in shape:minimum=minimum.min((p-Vector2(50,50)).rotated(turns*PI/2)+Vector2(50,50))
    raw.append(record(spec[0],minimum.round(),spec[2],Vector2.DOWN.rotated(turns*PI/2)))
   var painter:Array=Order.new().sorted(raw,[city.footprint(raw[0]),city.footprint(raw[1])]);var front:Dictionary=painter[-1];var rear:Dictionary=painter[0]
   # Reproduce ordinary play: front sprite exists before a newly built rear warehouse.
   city.buildings.append(front);game.city=city;game.refresh();await process_frame;await process_frame
   city.buildings.append(rear);city.society_changed.emit();await process_frame
   var wanted:Array=game.building_draw_order().map(func(b):return b.id)
   verify(engine_order(game.world_renderer)==wanted,"retained engine order equals painter after late rear creation sizes=%s direction=%s"%[sizes,turns])
   var nodes:Array=game.building_draw_order().map(func(b):return game.world_renderer.buildings[b.id])
   verify(nodes[0].get_index()<nodes[1].get_index(),"cached painter ranks determine the sibling order used for approximate-Y ties")
 for turns in range(4):
  var city=City.new(150,150)
  var public:Dictionary=city.public_facilities.preview("parking-large-4x8",Vector2(42,44)).record;public.id=2
  var warehouse:=record(1,Vector2(45,39),4,Vector2.DOWN)
  var raw:Array=[warehouse,public]
  for value:Dictionary in raw:
   var rotated:=PackedVector2Array();var minimum:=Vector2(INF,INF)
   for p in city.footprint(value):
    var q:Vector2=(p-Vector2(50,50)).rotated(turns*PI/2)+Vector2(50,50);rotated.append(q);minimum=minimum.min(q)
   if value.has("public_asset_id"):
    value.polygon=rotated;value.position=(value.position-Vector2(50,50)).rotated(turns*PI/2)+Vector2(50,50)
   else:value.x=minimum.round().x;value.y=minimum.round().y
   value.front_direction=Vector2.DOWN.rotated(turns*PI/2)
  var painter:Array=Order.new().sorted(raw,raw.map(func(b):return city.footprint(b)))
  insert_record(city,painter[-1]);game.city=city;game.refresh();await process_frame;await process_frame
  insert_record(city,painter[0]);city.society_changed.emit();await process_frame
  verify(engine_order(game.world_renderer)==painter.map(func(b):return b.id),"flat public parking and warehouse follow painter order direction="+str(turns))
  var snapshot:=var_to_bytes([city.buildings,city.public_facilities.lots]);game.world_renderer.synchronize()
  verify(snapshot==var_to_bytes([city.buildings,city.public_facilities.lots]),"ordering preserves public/warehouse placement records direction="+str(turns))
 game.queue_free();await process_frame
 print("RESULT %d/%d retained depth checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
