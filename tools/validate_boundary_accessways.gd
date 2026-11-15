extends "res://tests/test_entrance_accessways.gd"
const Links=preload("res://core/boundary_links.gd")
const Access=preload("res://core/entrance_accessways.gd")
func motion(p:Vector2):
 var event:=InputEventMouseMotion.new();event.position=p;event.global_position=p;root.push_input(event,true)
func click(p:Vector2):
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.position=p;event.global_position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await process_frame
func settle():
 for i in range(8):await process_frame
func frame_pose(game,zoom:float,center:Vector2):
 game.map_zoom=zoom;game.origin=Vector2.ZERO;game.origin=Vector2(960,440)-game.screen(center);game.queue_redraw()
func colour_near(image:Image,point:Vector2,colour:Color)->bool:
 for y in range(int(point.y)-2,int(point.y)+3):
  for x in range(int(point.x)-2,int(point.x)+3):
   if x<0 or y<0 or x>=image.get_width() or y>=image.get_height():continue
   var c:=image.get_pixel(x,y)
   if maxf(absf(c.r-colour.r),maxf(absf(c.g-colour.g),absf(c.b-colour.b)))<.04:return true
 return false
func run():
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var city=town(0);city.funds=maxi(city.funds,int(city.public_facilities.price("parking-large-4x8"))+1000)
 var placed:Dictionary=city.public_facilities.place("parking-large-4x8",Vector2(60,54),0,false);assert(placed.ok)
 var record:Dictionary=placed.record;var geometry:=var_to_bytes([record.polygon,record.position])
 var game=load("res://main.tscn").instantiate();game.city=city;game.paused=true;root.add_child(game);await settle()
 frame_pose(game,1.5,Vector2(80,60));game.drawer.hide();game.road_grid_enabled=true;game.road_lanes=4;game.road_drawer.set_kind("straight");await settle()
 motion(game.screen(Vector2(70.5,60.75)));await click(game.screen(Vector2(70.5,60.75)))
 motion(game.screen(Vector2(99.8,60.75)));await settle()
 var preview:Dictionary=game.road_drawer.preview();assert(preview.ok and preview.points[-1].x==100)
 await click(game.screen(Vector2(99.8,60.75)));await settle();assert(not Links.road_links(city).is_empty())
 game.road_drawer.cancel();game.mode="select";game.drawer.hide();await settle();await RenderingServer.frame_post_draw
 var arrow_image:=root.get_texture().get_image();var arrow_pixels:=0
 for link in Links.road_links(city):
  for polygon in Links.arrow_shapes(link):
   var center:=Vector2.ZERO
   for p in polygon:center+=p
   center/=polygon.size()
   if colour_near(arrow_image,game.screen(center),Color(.84,.85,.86)):arrow_pixels+=1
 assert(arrow_pixels>0)
 frame_pose(game,3.2,Vector2(60,57));game.refresh()
 for i in range(120):
  await RenderingServer.frame_post_draw
  if i>5 and not game.building_views.busy and game.building_views.queue.is_empty():break
 var polygons:=Access.build(city);assert(polygons.size()==2)
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));var visible:=0
 for polygon in polygons:
  var center:=Vector2.ZERO
  for p in polygon:center+=p
  center/=polygon.size()
  if colour_near(image,game.screen(center),Access.COLOR):visible+=1
 assert(visible==2 and geometry==var_to_bytes([record.polygon,record.position]))
 var folder:="D:/project/simcity/docs/boundary-accessway-validation";assert(image.save_png(folder.path_join("parking-accessways-1920.png"))==OK)
 var file:=FileAccess.open(folder.path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"input":"real viewport mouse press/release; grid on, same-road overdraw to map edge","endpoint":var_to_str(city.roads[-1].points[-1]),"boundary_arrow_samples":arrow_pixels,"visible_entry_paving":visible,"lot_geometry_preserved":true,"entry_polygons":var_to_str(polygons)},"  "));file.close()
 game.queue_free();await process_frame;print("NATIVE_ACCESSWAY_PASS boundary_arrows=",arrow_pixels," paved_entries=",visible);quit()
