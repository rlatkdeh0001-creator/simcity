extends RefCounted
## Worker-owned hidden daily statistics. No Node, clock, RNG, traffic or utility mutation.
var _config: Dictionary
var _day := -1
var _neighbors := {}

func _init(config: Dictionary = {}):
	_config = config.duplicate(true) if not config.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://core/neighbor_commuting_config.json"))

func refresh_day(day: int, local_population: int, exchange: Dictionary) -> bool:
	if day < 0 or day <= _day: return false
	var elapsed := day - _day if _day >= 0 else 0
	for spec in exchange.get("neighbors", []):
		var id := str(spec.id)
		var level: Dictionary = _config.levels.get(spec.get("development", "peer"), _config.levels.peer)
		var target := maxf(float(level.minimum_population), maxf(0, local_population) * float(level.population_multiplier) + float(level.population_base))
		var population: float = target
		if _neighbors.has(id):
			population = target + (float(_neighbors[id].population_exact) - target) * pow(1.0 - clampf(float(_config.daily_growth_fraction), 0, 1), elapsed)
		var count := maxi(0, int(floor(population)))
		var labor := clampi(int(floor(count * float(_config.labor_fraction))), 0, count)
		var unemployed := clampi(int(floor(labor * float(_config.unemployment_fraction))), 0, labor)
		var employed := labor - unemployed
		var jobs := maxi(employed, int(floor(labor * float(_config.jobs_per_labor))))
		var stats := {"id":id, "edge":str(spec.edge), "population":count, "population_exact":population,
			"labor":labor, "unemployed":unemployed, "employed":employed, "jobs":jobs,
			"vacancies":jobs - employed, "utilities":{}}
		for utility in _config.utilities:
			var rule: Dictionary = _config.utilities[utility]
			var consumed := count * float(rule.consumed_per_person)
			stats.utilities[utility] = {"produced":consumed * float(rule.production_to_consumption), "consumed":consumed, "unit":str(rule.unit)}
		_neighbors[id] = stats
	_day = day
	return true

func snapshot() -> Dictionary:
	return {"day":_day, "neighbors":_neighbors.duplicate(true)}

## Pure whole replacement; never consumes daily stats or frees LOCAL incumbent slots.
## Current inbound is added back to context free slots; existing outbound jobs get priority.
func plan(exchange: Dictionary, local: Dictionary, routes: Array = []) -> Dictionary:
	var result := {"day":_day, "inbound":0, "outbound":0, "residential_vacancy_reduction":0,
		"local_vacancies_remaining":0, "local_unemployed_remaining":0, "flows":[], "neighbors":{},
		"inbound_reservations":[], "outbound_assignments":[]}
	var towns := {}
	for town in exchange.get("neighbors", []):
		if not town is Dictionary: continue
		var id := str(town.get("id", ""))
		if not _neighbors.has(id) or towns.has(id): continue
		towns[id] = town
		var weights = town.get("education_distribution", _config.get("education_distribution", [1,1,1,1,1]))
		var workers := _distribute(int(_neighbors[id].unemployed), town.get("unemployed_education_distribution", _config.get("unemployed_education_distribution", weights)))
		var jobs := _distribute(int(_neighbors[id].vacancies), town.get("vacancy_education_distribution", _config.get("vacancy_education_distribution", weights)))
		result.neighbors[id] = {"inbound":0, "outbound":0, "unemployed_remaining":int(_neighbors[id].unemployed), "vacancies_remaining":int(_neighbors[id].vacancies), "unemployed_by_education":workers, "vacancies_by_stage":jobs}
	var workplaces := _rows(local.get("workplaces", []), "workplace_id")
	var remaining := {}
	for row in workplaces:
		var slots = row.get("free_slots", [])
		if not slots is Array or slots.size() != 5: continue
		var valid := true
		for n in slots:
			if not _integer(n, 0): valid = false
		if valid: remaining[_key(row.id)] = slots.duplicate()
	var previous := {}
	for row in local.get("inbound", []):
		if not row is Dictionary or not _id_valid(row.get("workplace_id")) or not _integer(row.get("stage"),0,4) or not _integer(row.get("count"),0): continue
		var key := _key(row.workplace_id)
		if not remaining.has(key): continue
		var token := key + ":" + str(int(row.stage))
		previous[token] = maxi(int(previous.get(token, 0)), int(row.count))
	for row in workplaces:
		var key := _key(row.id)
		if not remaining.has(key): continue
		for stage in range(5): remaining[key][stage] += int(previous.get(key + ":" + str(stage), 0))
	var candidates := []
	for row in workplaces:
		if not remaining.has(_key(row.id)): continue
		for id in towns:
			var access := _best_route(towns[id], str(row.id), "inbound", routes)
			if not access.is_empty(): candidates.append({"row":row, "town":towns[id], "access":access})
	candidates.sort_custom(_candidate_before)
	var reservations := {}
	for candidate in candidates:
		var row: Dictionary = candidate.row
		var id := str(candidate.town.id)
		var quota: Dictionary = result.neighbors[id]
		var slots: Array = remaining[_key(row.id)]
		for education in range(5):
			for stage in range(maxi(0, education-1), mini(4, education+1)+1):
				var amount := mini(int(slots[stage]), int(quota.unemployed_by_education[education]))
				if amount <= 0: continue
				slots[stage] -= amount
				quota.unemployed_by_education[education] -= amount
				quota.unemployed_remaining -= amount
				quota.inbound += amount
				result.inbound += amount
				var token := _key(row.id) + ":" + str(stage)
				if not reservations.has(token): reservations[token] = {"workplace_id":row.id, "stage":stage, "count":0}
				reservations[token].count += amount
				result.flows.append(_flow(candidate, "inbound", amount, education, stage))
	for row in workplaces:
		var key := _key(row.id)
		if not remaining.has(key): continue
		for stage in range(5):
			result.local_vacancies_remaining += int(remaining[key][stage])
			var token := key + ":" + str(stage)
			if reservations.has(token): result.inbound_reservations.append(reservations[token])
	var people := _rows(local.get("outbound", []), "person_id")
	var known := {}
	for person in people:
		known[_key(person.id)] = true
		person["incumbent"] = true
	for person in _rows(local.get("unemployed", []), "person_id"):
		if known.has(_key(person.id)): continue
		known[_key(person.id)] = true
		person["incumbent"] = false
		people.append(person)
	people.sort_custom(func(a,b):
		if a.incumbent != b.incumbent: return a.incumbent
		if int(a.get("education",-1)) != int(b.get("education",-1)): return int(a.get("education",-1)) < int(b.get("education",-1))
		return _id_before(a.id,b.id))
	var assigned := {}
	# Reserve EVERY still-valid external incumbent before any lost-job rematching.
	for person in people:
		if not person.incumbent or not _integer(person.get("education"),0,4) or not _integer(person.get("stage"),0,4): continue
		if not _id_valid(person.get("home_id")) or (person.home_id is int and person.home_id == -1): continue
		if absi(int(person.education)-int(person.stage)) > 1: continue
		var id := str(person.get("neighbor_id",""))
		if not towns.has(id) or int(result.neighbors[id].vacancies_by_stage[int(person.stage)]) <= 0: continue
		var access := _best_route(towns[id], str(person.home_id), "outbound", routes)
		if access.is_empty(): continue
		result.neighbors[id].vacancies_by_stage[int(person.stage)] -= 1
		result.neighbors[id].vacancies_remaining -= 1
		result.neighbors[id].outbound += 1
		result.outbound += 1
		assigned[_key(person.id)] = true
		result.outbound_assignments.append({"person_id":person.id,"neighbor_id":id,"stage":int(person.stage)})
		result.flows.append(_flow({"row":person,"town":towns[id],"access":access},"outbound",1,int(person.education),int(person.stage)))
	for person in people:
		if assigned.has(_key(person.id)): continue
		if not _integer(person.get("education"),0,4) or not _id_valid(person.get("home_id")) or (person.home_id is int and person.home_id == -1): continue
		var options := []
		for id in towns:
			var access := _best_route(towns[id], str(person.home_id), "outbound", routes)
			if not access.is_empty(): options.append({"row":person, "town":towns[id], "access":access})
		options.sort_custom(_candidate_before)
		var choice := {}
		var selected_stage := -1
		for option in options:
			var id := str(option.town.id)
			for stage in range(maxi(0,int(person.education)-1),mini(4,int(person.education)+1)+1):
				if int(result.neighbors[id].vacancies_by_stage[stage]) > 0:
					choice = option
					selected_stage = stage
					break
			if not choice.is_empty(): break
		if choice.is_empty(): continue
		var id := str(choice.town.id)
		result.neighbors[id].vacancies_by_stage[selected_stage] -= 1
		result.neighbors[id].vacancies_remaining -= 1
		result.neighbors[id].outbound += 1
		result.outbound += 1
		assigned[_key(person.id)] = true
		result.outbound_assignments.append({"person_id":person.id, "neighbor_id":id, "stage":selected_stage})
		result.flows.append(_flow(choice, "outbound", 1, int(person.education), selected_stage))
	result.outbound_assignments.sort_custom(func(a,b):return _id_before(a.person_id,b.person_id))
	result.local_unemployed_remaining = people.size() - assigned.size()
	result.residential_vacancy_reduction = result.inbound
	return result

func _flow(candidate: Dictionary, direction: String, count: int, education: int, stage: int) -> Dictionary:
	var row: Dictionary = candidate.row
	var town: Dictionary = candidate.town
	var id := str(town.id)
	var flow := {"id":JSON.stringify([_day,direction,id,_key(row.id),education,stage]).sha256_text(), "day":_day, "direction":direction, "neighbor_id":id,
		"neighbor_edge":str(town.edge), "local_group_id":row.id, "count":count, "education":education, "stage":stage,
		"home_id":("neighbor:"+id+":homes") if direction == "inbound" else row.home_id,
		"workplace_id":row.id if direction == "inbound" else ("neighbor:"+id+":jobs"),
		"neighbor_endpoint_is_pool":true, "mode":str(candidate.access.mode), "route":candidate.access.duplicate(true)}
	if direction == "outbound": flow["person_id"] = row.id
	return flow

func _rows(rows, id_field: String) -> Array:
	var unique := {}
	if not rows is Array: return []
	for source in rows:
		if not source is Dictionary: continue
		var id = source.get(id_field,source.get("id"))
		if not _id_valid(id): continue
		var row: Dictionary = source.duplicate(true)
		row["id"] = id
		var key := _key(id)
		if unique.has(key) and unique[key] != row: unique[key] = {}
		elif not unique.has(key): unique[key] = row
	var result := []
	for row in unique.values():
		if not row.is_empty(): result.append(row)
	result.sort_custom(func(a,b):return _id_before(a.id,b.id))
	return result

func _id_valid(value) -> bool:
	return (value is String and not value.is_empty()) or value is int

func _key(value) -> String:
	return ("i:" if value is int else "s:") + str(value)

func _id_before(a,b) -> bool:
	if a is int and b is int: return a < b
	return _key(a) < _key(b)

func _distribute(total: int, weights) -> Array:
	if not _weights_valid(weights): weights = [1,1,1,1,1]
	var sum := 0.0
	for weight in weights: sum += float(weight)
	var result := []
	var fractions := []
	var used := 0
	for stage in range(5):
		var exact := float(total)*float(weights[stage])/sum
		var count := int(floor(exact))
		result.append(count)
		used += count
		fractions.append({"stage":stage,"fraction":exact-count})
	fractions.sort_custom(func(a,b):return a.fraction > b.fraction if a.fraction != b.fraction else a.stage < b.stage)
	for i in range(total-used): result[int(fractions[i % 5].stage)] += 1
	return result

func _best_route(town: Dictionary, endpoint: String, direction: String, routes: Array) -> Dictionary:
	var best := {}
	if endpoint.is_empty(): return best
	for route in routes:
		if str(route.get("neighbor_id", "")) != str(town.id) or str(route.get("local_id", "")) != endpoint or str(route.get("direction", "")) != direction: continue
		var mode := str(route.get("mode", ""))
		if not mode in ["rail", "metro", "road"] or not route.get("reachable", false): continue
		if not town.get("channels", {}).get(mode, {}).get("connected", false): continue
		if str(route.get("route_id", "")).is_empty(): continue
		if mode != "road" and (not route.get("station_access", false) or str(route.get("station_id", "")).is_empty()): continue
		if best.is_empty() or _route_before(route, best): best = route.duplicate(true)
	return best

func _route_before(a: Dictionary, b: Dictionary) -> bool:
	var modes := ["rail", "metro", "road"]
	if modes.find(str(a.mode)) != modes.find(str(b.mode)): return modes.find(str(a.mode)) < modes.find(str(b.mode))
	var da := maxf(0, float(a.get("distance_m", 0)))
	var db := maxf(0, float(b.get("distance_m", 0)))
	if da != db: return da < db
	return str(a.route_id) < str(b.route_id)

func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	if _route_before(a.access, b.access): return true
	if _route_before(b.access, a.access): return false
	if str(a.town.id) != str(b.town.id): return str(a.town.id) < str(b.town.id)
	return _id_before(a.row.id,b.row.id)

## Lazy logical records, not sampled physical cars; limit=-1 means all remaining.
func trips_for_flow(flow: Dictionary, offset: int = 0, limit: int = -1) -> Array:
	var records := []
	if offset < 0 or limit < -1 or not _integer(flow.get("count"),0) or not _integer(flow.get("day"),0): return records
	var stop := int(flow.count) if limit == -1 else mini(int(flow.count), offset+limit)
	for ordinal in range(offset,stop):
		var identity := str(flow.get("id","")) + ":" + str(ordinal)
		var trip: Dictionary = flow.duplicate(true)
		trip.erase("count")
		trip["flow_id"] = flow.id
		trip["id"] = identity.sha256_text()
		trip["ordinal"] = ordinal
		trip["person_id"] = flow.get("person_id", "neighbor:"+str(flow.neighbor_id)+":"+str(trip.id))
		trip["departure_hour"] = int(flow.day)*24 + 5 + (identity.sha256_text().substr(0,7).hex_to_int() % 5)
		trip["late_after_hour"] = int(trip.departure_hour) + 4
		records.append(trip)
	return records

## A pure presentation instruction only. Ordinal is GLOBAL 1-based (0 for previews).
func presentation_record(trip: Dictionary, population_ordinal: int, returning: bool = false, tracked: bool = false) -> Dictionary:
	var display := tracked or population_ordinal <= 1000 or (population_ordinal <= 10000 and population_ordinal % 10 == 0) or (population_ordinal > 10000 and population_ordinal % 100 == 0)
	var origin = "neighbor_boundary" if trip.direction == "inbound" else trip.home_id
	var destination = trip.workplace_id if trip.direction == "inbound" else "neighbor_boundary"
	return {"id":trip.id, "person_id":trip.person_id, "display":display, "tracked":tracked,
		"kind":"boundary_car" if trip.mode == "road" else "boundary_transit", "mode":trip.mode,
		"origin":destination if returning else origin, "destination":origin if returning else destination,
		"neighbor_id":trip.neighbor_id, "neighbor_edge":trip.neighbor_edge, "returning":returning,
		"route":trip.route.duplicate(true), "departure_hour":trip.departure_hour, "late_after_hour":trip.late_after_hour}

func export_state() -> Dictionary:
	return {"version":1,"day":_day,"neighbors":_neighbors.duplicate(true),"config":_config.duplicate(true)}

## Validate a detached candidate completely before committing anything.
func import_state(state: Dictionary) -> bool:
	if not _integer(state.get("version"),1,1) or not _integer(state.get("day"),-1): return false
	if not state.get("neighbors") is Dictionary or not state.get("config") is Dictionary: return false
	var config: Dictionary = state.config.duplicate(true)
	if not _config_valid(config): return false
	var neighbors: Dictionary = state.neighbors.duplicate(true)
	if int(state.day) == -1 and not neighbors.is_empty(): return false
	for id in neighbors:
		if not id is String or id.is_empty() or not neighbors[id] is Dictionary: return false
		var row: Dictionary = neighbors[id]
		if not row.get("id") is String or not row.get("edge") is String: return false
		if row.id != id or not row.edge in ["x_min","x_max","y_min","y_max"]: return false
		for key in ["population","labor","unemployed","employed","jobs","vacancies"]:
			if not _integer(row.get(key),0): return false
		if not _number(row.get("population_exact"),0) or int(floor(float(row.population_exact))) != int(row.population): return false
		if int(row.labor) > int(row.population) or int(row.unemployed)+int(row.employed) != int(row.labor) or int(row.jobs)-int(row.employed) != int(row.vacancies): return false
		var labor := clampi(int(floor(int(row.population)*float(config.labor_fraction))),0,int(row.population))
		if int(row.labor) != labor or int(row.unemployed) != clampi(int(floor(labor*float(config.unemployment_fraction))),0,labor): return false
		if int(row.jobs) != maxi(int(row.employed),int(floor(labor*float(config.jobs_per_labor)))): return false
		if not row.get("utilities") is Dictionary or row.utilities.size() != config.utilities.size(): return false
		for utility in config.utilities:
			if not row.utilities.get(utility) is Dictionary: return false
			var rule: Dictionary = config.utilities[utility]
			var data: Dictionary = row.utilities[utility]
			if not data.get("unit") is String: return false
			if not _number(data.get("consumed"),0) or not _number(data.get("produced"),0) or data.unit != rule.unit: return false
			var consumed := int(row.population)*float(rule.consumed_per_person)
			if not is_equal_approx(float(data.consumed),consumed) or not is_equal_approx(float(data.produced),consumed*float(rule.production_to_consumption)): return false
		for key in ["population","labor","unemployed","employed","jobs","vacancies"]: row[key] = int(row[key])
	_config = config
	_neighbors = neighbors
	_day = int(state.day)
	return true

func _number(value, minimum: float = 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum

func _integer(value, minimum: int, maximum: int = 9007199254740991) -> bool:
	return _number(value,float(minimum)) and float(value) <= float(maximum) and floor(float(value)) == float(value)

func _weights_valid(weights) -> bool:
	if not weights is Array or weights.size() != 5: return false
	var total := 0.0
	for value in weights:
		if not _number(value,0): return false
		total += float(value)
	return is_finite(total) and total > 0

func _config_valid(config: Dictionary) -> bool:
	if not _integer(config.get("version"),1,1): return false
	for key in ["daily_growth_fraction","labor_fraction","unemployment_fraction"]:
		if not _number(config.get(key),0) or float(config[key]) > 1: return false
	if not _number(config.get("jobs_per_labor"),0): return false
	if config.has("wages_by_stage"):
		if not config.wages_by_stage is Array or config.wages_by_stage.size() != 5: return false
		for wage in config.wages_by_stage:
			if not _number(wage,0): return false
	for key in ["education_distribution","unemployed_education_distribution","vacancy_education_distribution"]:
		if config.has(key) and not _weights_valid(config[key]): return false
	if not config.get("levels") is Dictionary or not config.levels.has("peer"): return false
	for level in config.levels.values():
		if not level is Dictionary: return false
		for key in ["minimum_population","population_multiplier","population_base"]:
			if not _number(level.get(key),0): return false
	if not config.get("utilities") is Dictionary: return false
	for rule in config.utilities.values():
		if not rule is Dictionary or not rule.get("unit") is String: return false
		if not _number(rule.get("consumed_per_person"),0) or not _number(rule.get("production_to_consumption"),0): return false
	return true

