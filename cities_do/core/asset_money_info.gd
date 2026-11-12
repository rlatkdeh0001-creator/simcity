extends RefCounted
## Display only: approved values come from the same CSV reader as construction.
const CAPACITY_LABELS=[
 ["average_output_kw","평균 발전량"],["rated_output_kw","정격 발전량"],
 ["supply_m3_day","급수량"],["sewage_m3_day","하수 처리량"],["storage_m3","저장 용량"],
 ["students","정원"],["beds","병상"],["outpatient_day","외래 정원"],["inmates","수용 정원"],
 ["vehicles","차량 정원"],["vehicle_bays","차고"],["simultaneous_incidents","동시 대응"],
 ["population_capacity","수용 정원"],["visitors","이용 정원"],
 ["average_throughput","평균 처리량"],["rated_throughput","정격 처리량"],["storage","보관 용량"],
 ["throughput_t_day","처리량"],["recovery_percent","회수율"],["residue_percent","잔재율"]]
static func rows(city,id: String) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 if not city.public_facilities.entries.has(id):return result
 var public=city.public_facilities
 var cost: float=public.price(id);var upkeep: float=public.upkeep(id)
 if is_finite(cost):result.append({"id":"construction","label":"건설비","value":cost,"number":city.Economy.format_number(int(cost)),"unit":city.Economy.CURRENCY_SYMBOL,"text":city.Economy.format_amount(int(cost))})
 if is_finite(upkeep):result.append({"id":"upkeep","label":"유지비","value":upkeep,"number":"−"+city.Economy.format_number(int(upkeep)),"unit":city.Economy.CURRENCY_SYMBOL+"/월","text":"−"+city.Economy.format_amount(int(upkeep))+"/월"})
 var values: Dictionary=public.balance.capacities(id);var count:=0
 for pair in CAPACITY_LABELS:
  if not values.has(pair[0]) or not is_finite(float(values[pair[0]])):continue
  var value: float=values[pair[0]]
  var number: String=city.Economy.format_number(int(value)) if is_equal_approx(value,roundf(value)) else str(value)
  var unit: String=public.balance.units.get("public."+id+".capacity."+pair[0],"")
  result.append({"id":pair[0],"label":pair[1],"value":value,"number":number,"unit":unit,"text":number+(" "+unit if not unit.is_empty() else "")})
  count+=1
  if count>=3:break
 return result
