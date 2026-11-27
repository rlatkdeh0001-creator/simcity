extends Node
## Independent real-time pan: simulation pause/speed never changes camera movement.
const SPEED:=600.0 # screen pixels/sec at zoom 1
const MOVE_KEYS:=[KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT]
var owner_reference: WeakRef
var held:={}
var view:
 get:return owner_reference.get_ref()
func _init(owner):
 owner_reference=weakref(owner)
 name="KeyboardCamera"
 process_mode=Node.PROCESS_MODE_ALWAYS
func _ready():get_window().focus_exited.connect(clear)
func clear():held.clear()
func text_input_active() -> bool:
 var focus: Control=get_viewport().gui_get_focus_owner()
 while focus!=null:
  if focus is LineEdit or focus is TextEdit:return true
  focus=focus.get_parent_control()
 return false
func handle_input(event: InputEvent) -> bool:
 if not event is InputEventKey:return false
 var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if not event.pressed:held.erase(code)
 if text_input_active() or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
  clear();return false
 if code!=KEY_SHIFT and event.shift_pressed:held[KEY_SHIFT]=true
 if code==KEY_SHIFT:
  if event.pressed:held[code]=true
  return false # Shift itself remains available to other shortcuts.
 if not code in MOVE_KEYS:return false
 if event.pressed:held[code]=true
 return true # Outside editors, arrow keys pan instead of navigating HUD focus.
func constrained_origin(candidate: Vector2) -> Vector2:
 var center: Vector2=view.get_viewport_rect().size/2
 var delta: Vector2=(center-candidate)/view.map_zoom
 var world_center:=Vector2((delta.x/view.tile.x+delta.y/view.tile.y)/2,(delta.y/view.tile.y-delta.x/view.tile.x)/2)
 world_center=world_center.clamp(Vector2.ZERO,Vector2(view.city.width,view.city.height))
 return center-Vector2((world_center.x-world_center.y)*view.tile.x,(world_center.x+world_center.y)*view.tile.y)*view.map_zoom
func step(delta: float):
 if text_input_active():clear();return
 if delta<=0 or view.panning:return
 var direction:=Vector2(float(held.has(KEY_D) or held.has(KEY_RIGHT))-float(held.has(KEY_A) or held.has(KEY_LEFT)),float(held.has(KEY_S) or held.has(KEY_DOWN))-float(held.has(KEY_W) or held.has(KEY_UP)))
 if direction==Vector2.ZERO:return
 # User requirement: travel faster when zoomed out (inverse zoom).
 var speed: float=SPEED/maxf(view.map_zoom,.15)*(2.0 if held.has(KEY_SHIFT) else 1.0)
 view.origin=constrained_origin(view.origin-direction.normalized()*speed*delta)
 view.pointer=view.world(get_viewport().get_mouse_position())
 view.queue_redraw()
func _process(delta: float):step(delta)
