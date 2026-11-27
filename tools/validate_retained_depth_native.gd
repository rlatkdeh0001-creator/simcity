extends "res://tests/test_retained_depth_order.gd"
var stage:="before"
func settle_images(game):
 for i in range(120):
  await RenderingServer.frame_post_draw
  if i>5 and not game.building_views.busy and game.building_views.queue.is_empty():break
func error(a:Color,b:Color)->float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func texel(node:Sprite2D,image:Image,p:Vector2)->Color:
 var q:Vector2=node.to_local(p)-node.offset-Vector2(.5,.5)
 var x:=floori(q.x);var y:=floori(q.y)
 if x<0 or y<0 or x+1>=image.get_width() or y+1>=image.get_height():return Color.TRANSPARENT
 return image.get_pixel(x,y).lerp(image.get_pixel(x+1,y),q.x-x).lerp(image.get_pixel(x,y+1).lerp(image.get_pixel(x+1,y+1),q.x-x),q.y-y)
func compare(game,front,rear)->Dictionary:
 var a:Image=front.texture.get_image();var b:Image=rear.texture.get_image()
 if a.is_compressed():a.decompress()
 if b.is_compressed():b.decompress()
 var output:Image=root.get_texture().get_image()
 var first:=Rect2(game.origin+front.world_bounds.position*game.map_zoom,front.world_bounds.size*game.map_zoom)
 var last:=Rect2(game.origin+rear.world_bounds.position*game.map_zoom,rear.world_bounds.size*game.map_zoom)
 var box:=first.intersection(last).intersection(Rect2(0,80,1920,800));var samples:=0;var front_hits:=0;var rear_hits:=0
 for y in range(ceili(box.position.y),floori(box.end.y),2):
  for x in range(ceili(box.position.x),floori(box.end.x),2):
   var p:=Vector2(x+.5,y+.5);var ca:=texel(front,a,p);var cb:=texel(rear,b,p)
   if ca.a<.995 or cb.a<.995 or error(ca,cb)<.14:continue
   samples+=1;var actual:=output.get_pixel(x,y)
   if error(actual,ca)<.08:front_hits+=1
   if error(actual,cb)<.08:rear_hits+=1
 return {"samples":samples,"front_hits":front_hits,"rear_hits":rear_hits,"front_fraction":float(front_hits)/maxi(1,samples)}
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
 assert(stage in ["before","after"])
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var folder:="D:/project/simcity/docs/retained-depth-validation";DirAccess.make_dir_recursive_absolute(folder)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var rows:Array=[]
 for kind in ["industrial","parking"]:
  var city=City.new(150,150);var front:Dictionary;var rear:Dictionary
  if kind=="industrial":
   front=record(1,Vector2(49,41),2,Vector2.DOWN,"small-2x2-foodworks-02")
   rear=record(2,Vector2(40,40),8,Vector2.DOWN,"large-8x8-auto-assembly-07")
  else:
   front=record(1,Vector2(45,39),4,Vector2.DOWN,"small-4x4-logistics-01")
   rear=city.public_facilities.preview("parking-large-4x8",Vector2(42,44)).record;rear.id=2
  city.buildings.append(front);game.city=city;game.mode="select";game.drawer.hide();game.map_zoom=2;game.origin=Vector2.ZERO;game.origin=Vector2(960,540)-game.screen(Vector2(46,44));game.refresh();await settle_images(game)
  if kind=="parking":city.public_facilities.lots.append(rear)
  else:city.buildings.append(rear)
  city.society_changed.emit();await settle_images(game)
  var ordered:Array=game.building_draw_order();assert(ordered[0].id==2 and ordered[1].id==1)
  var front_node=game.world_renderer.buildings[1];var rear_node=game.world_renderer.buildings[2];assert(front_node.texture!=null and rear_node.texture!=null)
  await RenderingServer.frame_post_draw
  var result:=compare(game,front_node,rear_node);result.kind=kind;result.painter_ids=ordered.map(func(b):return b.id);rows.append(result)
  assert(result.samples>0)
  if stage=="after":assert(result.front_fraction>.95)
  assert(root.get_texture().get_image().save_png(folder.path_join(stage+"-"+kind+".png"))==OK)
  print("NATIVE_DEPTH ",stage," ",JSON.stringify(result))
 var file:=FileAccess.open(folder.path_join(stage+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
 game.queue_free();await process_frame;print("NATIVE_DEPTH_PASS "+stage);quit()
