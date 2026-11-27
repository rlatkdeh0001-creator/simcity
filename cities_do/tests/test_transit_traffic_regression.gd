extends "res://tests/test_traffic.gd"
## Functional ACC/lane regression entry point. Deliberately excludes legacy timed fleet
## and the unrelated scene round-trip fixture; P3 native UI is tested separately.
func run():
 for method:String in ["test_network","test_following","test_loop","test_timing"]:
  if call(method)!=true:verify(false,method+" completed")
 print("TRANSIT_TRAFFIC_REGRESSION checks=%d failed=%d"%[checks,failed])
 quit(1 if failed else 0)
