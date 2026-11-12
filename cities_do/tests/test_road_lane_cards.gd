extends SceneTree
const City=preload("res://core/city_model.gd")
const Network=preload("res://core/traffic_network.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 for count in [2,3,4,5,8]:
  var city:=City.new(100,100)
  var added: Dictionary=city.add_road(PackedVector2Array([Vector2(20,40),Vector2(40,40)]),"local",true,count)
  verify(added.ok,"normal road accepts approved total lane count %d"%count)
  if not added.ok:continue
  var road: Dictionary=city.roads[0];var network:=Network.new()
  verify(network.build(city.roads) and network.lanes.size()==count,"actual traffic graph has exactly %d lanes"%count)
  verify(network.lanes.filter(func(l):return l.direction==1).size()==ceili(count/2.0) and network.lanes.filter(func(l):return l.direction==-1).size()==floori(count/2.0),"default major side follows drawing direction")
  if count%2==1:
   road.major_side=-1;network.build(city.roads)
   verify(network.lanes.filter(func(l):return l.direction==-1).size()==ceili(count/2.0),"stored major_side reverses odd allocation without a new UI")
  var offsets:={}
  for dash in Geometry.lane_marks(road):offsets[roundi(dash[0].y*10000)]=true
  verify(offsets.size()==count-2,"real road renderer includes every non-median lane separator")
 var city:=City.new(100,100)
 verify(not city.add_road(PackedVector2Array([Vector2(10,10),Vector2(30,10)]),"highway",false,3).ok,"highway lane policy stays unchanged")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 verify(game.has_method("select_road_lanes"),"approved lane cards replace the old selector")
 if game.has_method("select_road_lanes"):
  game.select_category("road");await process_frame;await process_frame
  verify(game.road_lane_cards.size()==5 and game.find_child("RoadLanes",true,false)==null,"five C-cards and no old OptionButton")
  verify(game.road_grid_enabled and game.road_grid_button.button_pressed,"grid icon defaults on")
  for card in game.road_lane_cards:
   card.pressed.emit()
   verify(game.road_lanes==int(card.get_meta("lanes")) and card.button_pressed and game.mode=="road","one card activation selects and arms its exact lane count")
   verify(card.picture.texture!=null and card.caption.get_theme_font_size("font_size")>=18,"lane card uses a real rendered PNG and readable name band")
  game.road_grid_button.pressed.emit();verify(not game.road_grid_enabled,"grid toggle turns off without changing modes")
  game.select_category("build");game.select_category("road");await process_frame
  verify(not game.road_grid_enabled and not game.road_grid_button.button_pressed,"grid choice survives category changes")
  for size in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
   root.size=size;await process_frame;await process_frame
   var good:=true
   for i in range(4):good=good and game.road_lane_cards[i].get_global_rect().end.x<=game.road_lane_cards[i+1].get_global_rect().position.x
   verify(good and game.road_grid_button.get_global_rect().end.x<=size.x,"lane row remains ordered and grid button is inside viewport "+str(size))
 game.queue_free();await process_frame
 print("RESULT %d/%d road lane card checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
