extends RefCounted
## Docs CSV is the only editable source; packaged fallback is a generated exact copy.
var values: Dictionary={}
var units: Dictionary={}
var valid:=false
func _init():reload()
func reload(path: String="") -> bool:
 values.clear();units.clear();valid=false
 if path.is_empty():
  path=ProjectSettings.globalize_path("res://../docs/economy-balance/ECONOMY_BALANCE.csv")
  if not FileAccess.file_exists(path):path="res://assets/economy/ECONOMY_BALANCE.csv.txt"
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return false
 var header:=file.get_csv_line()
 var key_column:=header.find("항목ID");var value_column:=header.find("값");var unit_column:=header.find("단위")
 if mini(key_column,mini(value_column,unit_column))<0:return false
 while not file.eof_reached():
  var row:=file.get_csv_line()
  if row.size()!=header.size():continue
  var key: String=row[key_column]
  if values.has(key):return false
  values[key]=row[value_column];units[key]=row[unit_column]
 valid=true
 return true
func number(key: String) -> float:
 var value: String=str(values.get(key,""))
 return float(value) if valid and value.is_valid_float() else NAN
func capacities(id: String) -> Dictionary:
 var result: Dictionary={};var prefix: String="public."+id+".capacity."
 for key: String in values:
  if key.begins_with(prefix):result[key.trim_prefix(prefix)]=number(key)
 return result
