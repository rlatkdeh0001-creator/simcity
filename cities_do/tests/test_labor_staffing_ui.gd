extends SceneTree
func _initialize():
 var panel=load("res://labor_rings.gd").new()
 var checks:=1;var failed:=0
 if not panel.has_method("occupied"):
  failed=1;printerr("FAIL foreign reservations must count in staffing UI")
 else:
  panel.work={"slots":[5,5,5,5,5],"filled":[1,0,0,0,0],"inbound_reserved":[2,0,0,0,0]}
  checks+=1
  if panel.occupied(0)!=3:failed+=1
  panel.work={"filled":[1,0,0,0,0]};checks+=1
  if panel.occupied(0)!=1:failed+=1
 panel.free()
 print("LABOR_STAFFING_UI checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
