extends SceneTree
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, detail: String):
 checks+=1
 if value: print("PASS "+detail)
 else:
  failed+=1
  push_error("FAIL "+detail)
func run():
 root.gui_embed_subwindows=true
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 current_scene=game
 await process_frame
 game.paused=true
 var slots: Array=game.service_slots()
 verify(slots.size()==7,"seven emergency slots")
 var sizes := {"fire.small":16,"fire.standard":24,"fire.regional":32,"police.small":16,"police.standard":24,"police.headquarters":32,"police.prison":32}
 var funds: int=game.city.funds
 var count: int=game.city.buildings.size()
 for slot: Dictionary in slots:
  verify(slot.status=="ready" and not str(slot.asset).is_empty(),str(slot.id)+" ready spec path")
  if slot.status!="ready" or str(slot.asset).is_empty(): continue
  var entry: Dictionary=game.slot_asset(slot)
  verify(not entry.is_empty(),str(slot.id)+" valid real service spec")
  if entry.is_empty(): continue
  verify(entry.name==slot.name and int(entry.width)*4==sizes[slot.id] and int(entry.depth)*4==sizes[slot.id],str(slot.id)+" approved name and lot")
  verify(not entry.simulation_enabled and entry.front_axis==[0.0,1.0],str(slot.id)+" preview only and +Z frontage")
  var model: Node3D=load(entry.model).instantiate()
  root.add_child(model)
  var bounds := AABB()
  var first := true
  for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb()
   bounds=box if first else bounds.merge(box)
   first=false
  verify(not first and absf(bounds.size.x-sizes[slot.id])<.05 and absf(bounds.size.z-sizes[slot.id])<.05,str(slot.id)+" GLB footprint is metres")
  verify(absf(bounds.position.y)<.01 and absf(bounds.size.y-float(entry.height_m))<.05,str(slot.id)+" GLB ground and height")
  var frontage=model.find_child("ServiceFrontage",true,false)
  verify(frontage!=null and frontage.global_position.z>sizes[slot.id]*.4,str(slot.id)+" exported front marker faces +Z")
  var actual_front=model.find_child(str(entry.front_feature_node),true,false)
  verify(actual_front is MeshInstance3D and (actual_front.global_transform*actual_front.get_aabb()).get_center().z>0,str(slot.id)+" actual original entrance/door geometry faces +Z")
  model.queue_free()
  game.select_category(slot.category)
  var buttons: Array=game.drawer_box.get_children().filter(func(b):return b is Button and b.get_meta("slot_id","")==slot.id)
  verify(buttons.size()==1 and not buttons[0].disabled,str(slot.id)+" enabled actual button")
  if buttons.size()==1: buttons[0].pressed.emit()
  await process_frame
  var windows=game.find_children("ServiceAssetPreview","Window",true,false)
  verify(windows.size()==1 and windows[0].title==slot.name+" · 애셋",str(slot.id)+" opens matching inspector")
  if not windows.is_empty():
   verify(not windows[0].find_children("*","MeshInstance3D",true,false).is_empty(),str(slot.id)+" inspector contains real meshes")
   windows[0].close_requested.emit()
  await process_frame
 verify(game.city.funds==funds and game.city.buildings.size()==count,"inspection never constructs or charges")
 game.queue_free()
 await process_frame
 print("RESULT %d/%d emergency asset checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
