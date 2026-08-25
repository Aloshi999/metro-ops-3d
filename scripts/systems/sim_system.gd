class_name SimSystem
extends RefCounted
## Active-chunk aggregate sim only. No per-citizen agents, no traffic pathfinding.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const LotRecord = preload("res://scripts/core/lot_record.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")

signal tick_done
signal demand_changed(res_d: float, com_d: float, ind_d: float)

var tick_count: int = 0
var war_timer: int = 0
var disaster_timer: int = 0
var event_cooldown: int = 0
## Main sets true in _ready. Smoke never sets it, so start_war still applies at tick 0.
var tutor_active: bool = false

var demand_r: float = GameConstants.RCI_DEMAND_BASE
var demand_c: float = GameConstants.RCI_DEMAND_BASE
var demand_i: float = GameConstants.RCI_DEMAND_BASE

var mass_r: float = 0.0
var mass_c: float = 0.0
var mass_i: float = 0.0

## City-wide 0..1 factors, recomputed once per tick from active chunks.
var factor_land: float = 0.5
var land_value: float = 0.5
var factor_rci: float = 0.5
var factor_tax: float = 1.0
var factor_services: float = 0.5
var factor_roads: float = 0.5
var factor_pollution: float = 0.5
var factor_trade: float = 1.0
var factor_recovery: float = 1.0
var happiness: float = 0.5
## Mass-weighted city opinions (last tick). Feed R/C/I demand; HUD mood.
var city_opinion_r: float = 1.0
var city_opinion_c: float = 1.0
var city_opinion_i: float = 1.0

const _W_LAND: float = 0.18
const _W_RCI: float = 0.14
const _W_TAX: float = 0.10
const _W_SVC: float = 0.16
const _W_ROAD: float = 0.12
const _W_POLL: float = 0.10
const _W_TRADE: float = 0.10
const _W_REC: float = 0.10


func tick(map: MapData, budget: BudgetSystem) -> void:
	tick_count += 1
	if tutor_active and float(tick_count) * GameConstants.SIM_TICK_SEC >= 600.0:
		tutor_active = false
	_tick_events(budget)
	_recompute_city_demand(map, budget)
	_sim_active_chunks(map)
	_recompute_city_factors(map, budget)
	budget.tick(map, land_value)
	tick_done.emit()
	demand_changed.emit(demand_r, demand_c, demand_i)


func _tick_events(budget: BudgetSystem) -> void:
	if event_cooldown > 0:
		event_cooldown -= 1
	if war_timer > 0:
		war_timer -= 1
		if war_timer <= 0:
			budget.tax_mult = 1.0
			event_cooldown = GameConstants.WAR_DURATION_TICKS * 2
		else:
			var t := 1.0 - float(war_timer) / float(GameConstants.WAR_DURATION_TICKS)
			budget.tax_mult = lerpf(GameConstants.WAR_EMBARGO_TAX_START, GameConstants.WAR_EMBARGO_TAX_MULT, t)
	if disaster_timer > 0:
		disaster_timer -= 1
		if disaster_timer <= 0:
			budget.demand_mult = 1.0
			event_cooldown = GameConstants.DISASTER_DURATION_TICKS * 2


func _recompute_city_demand(map: MapData, budget: BudgetSystem) -> void:
	var r_m := 0.0
	var c_m := 0.0
	var i_m := 0.0
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		r_m += chunk.res_occ * float(chunk.res_tiles)
		c_m += chunk.com_occ * float(chunk.com_tiles)
		i_m += chunk.ind_occ * float(chunk.ind_tiles)
	mass_r = r_m
	mass_c = c_m
	mass_i = i_m

	var jobs := c_m + i_m * 1.15
	var homes := r_m
	var shops := c_m
	var g := GameConstants.RCI_BALANCE_GAIN
	var base := GameConstants.RCI_DEMAND_BASE

	var dr := base + (jobs - homes) * g * 0.04
	var dc := base + (homes - shops) * g * 0.045
	var di := base + (shops * 0.75 + homes * 0.25 - i_m) * g * 0.04

	if homes + jobs < 0.5:
		dr = base + 0.25
		dc = base + 0.15
		di = base + 0.10

	if war_timer > 0:
		dr *= GameConstants.WAR_DEMAND_R
		dc *= GameConstants.WAR_DEMAND_C
		di *= GameConstants.WAR_DEMAND_I
	if disaster_timer > 0:
		dr *= GameConstants.DISASTER_DEMAND_R
		dc *= GameConstants.DISASTER_DEMAND_C
		di *= GameConstants.DISASTER_DEMAND_I
		dr *= budget.demand_mult
		dc *= lerpf(1.0, budget.demand_mult, 0.5)
		di *= lerpf(1.0, budget.demand_mult, 0.35)

	_refresh_city_opinions(map)
	## Mild city-wide demand nudge from last-tick opinions (occupancy still uses per-chunk).
	var t_r := inverse_lerp(GameConstants.OPINION_MIN, GameConstants.OPINION_MAX, city_opinion_r)
	var t_c := inverse_lerp(GameConstants.OPINION_MIN, GameConstants.OPINION_MAX, city_opinion_c)
	var t_i := inverse_lerp(GameConstants.OPINION_MIN, GameConstants.OPINION_MAX, city_opinion_i)
	dr *= lerpf(0.88, 1.08, clampf(t_r, 0.0, 1.0))
	dc *= lerpf(0.88, 1.08, clampf(t_c, 0.0, 1.0))
	di *= lerpf(0.88, 1.08, clampf(t_i, 0.0, 1.0))

	demand_r = clampf(dr, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)
	demand_c = clampf(dc, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)
	demand_i = clampf(di, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)
	## First-10 tutor window: keep demand hot so minute 3–6 zone-paint fills (>0.4 gate).
	if _in_tutor_window():
		demand_r = maxf(demand_r, 0.45)
		demand_c = maxf(demand_c, 0.45)
		demand_i = maxf(demand_i, 0.45)


func _sim_active_chunks(map: MapData) -> void:
	for c in map.chunks:
		var chunk: ChunkData = c
		if chunk.damaged:
			chunk.damage_timer -= 1
			if chunk.damage_timer <= 0:
				map.clear_chunk_damage(chunk)
		if not chunk.active:
			continue
		_sim_chunk(map, chunk)


func _sim_chunk(map: MapData, chunk: ChunkData) -> void:
	var nearby := _nearby_industry(map, chunk)
	chunk.refresh_opinions(war_timer, disaster_timer, nearby, _nearby_park(map, chunk))
	_apply_city_opinion_feed(chunk)
	var rec_lot := _first_occupied_r_lot(map, chunk)
	if rec_lot.x >= 0:
		_nudge_chunk_from_tags(chunk, LotRecord.from_lot(rec_lot.x, rec_lot.y).tags)
	chunk.reset_counts()
	var x0 := chunk.cx * map.chunk_size
	var y0 := chunk.cy * map.chunk_size
	var res_sum := 0.0
	var com_sum := 0.0
	var ind_sum := 0.0

	for y in range(y0, y0 + map.chunk_size):
		for x in range(x0, x0 + map.chunk_size):
			var i := map.idx(x, y)
			var ter: int = map.terrain[i]
			var dcode: int = map.district[i] if map.district.size() > i else 0
			if dcode == 3 or dcode == 4:  ## District.PARK / WATERFRONT (ints — headless class_name)
				chunk.park_tiles += 1
			elif ter == TileTypes.Terrain.WATER:
				chunk.park_tiles += 1
			elif ter == TileTypes.Terrain.GRASS and map.zone[i] == TileTypes.Zone.NONE and map.road[i] == 0 and map.service[i] == TileTypes.Service.NONE:
				chunk.park_tiles += 1
			var z: int = map.zone[i]
			if z == TileTypes.Zone.NONE:
				continue
			var has_power: bool = map.powered[i] == 1
			var has_water: bool = map.watered[i] == 1
			var has_road: bool = map.has_road_neighbor(x, y)
			if has_power:
				chunk.powered_zone_tiles += 1
			if has_water:
				chunk.watered_zone_tiles += 1
			if has_road:
				chunk.roaded_zone_tiles += 1

			var service_target := 0.0
			if has_power and has_water and has_road and map.damaged_tile[i] == 0 and not chunk.damaged:
				chunk.serviced_zone_tiles += 1
				service_target = 1.0
			elif has_power or has_water:
				service_target = 0.15
			else:
				service_target = 0.0

			var zone_demand := 1.0
			match z:
				TileTypes.Zone.RESIDENTIAL:
					zone_demand = demand_r
				TileTypes.Zone.COMMERCIAL:
					zone_demand = demand_c
				TileTypes.Zone.INDUSTRIAL:
					zone_demand = demand_i

			## Fill only when demand is hot and the lot is powered+watered+roaded.
			var target := 0.0
			if zone_demand > 0.4 and service_target >= 1.0:
				target = service_target * clampf(zone_demand, 0.0, 1.0)
				match z:
					TileTypes.Zone.RESIDENTIAL:
						target *= chunk.opinion_r
					TileTypes.Zone.COMMERCIAL:
						target *= chunk.opinion_c
					TileTypes.Zone.INDUSTRIAL:
						target *= chunk.opinion_i
				if zone_demand > 1.0:
					target = 1.0
				else:
					target = clampf(target, 0.0, 1.0)
			# else: leak down (cold demand or not fully serviced)

			var occ: float = map.occupancy[i]
			var rate: float = 0.08 if target > occ else 0.12
			if target > occ:
				rate *= lerpf(0.7, 1.35, clampf(zone_demand / GameConstants.RCI_DEMAND_MAX, 0.0, 1.0))
			else:
				rate *= lerpf(1.25, 0.75, clampf(zone_demand, 0.0, 1.0))
			occ = lerpf(occ, target, rate)
			map.occupancy[i] = occ

			match z:
				TileTypes.Zone.RESIDENTIAL:
					chunk.res_tiles += 1
					res_sum += occ
				TileTypes.Zone.COMMERCIAL:
					chunk.com_tiles += 1
					com_sum += occ
				TileTypes.Zone.INDUSTRIAL:
					chunk.ind_tiles += 1
					ind_sum += occ

	chunk.res_occ = (res_sum / float(chunk.res_tiles)) if chunk.res_tiles > 0 else 0.0
	chunk.com_occ = (com_sum / float(chunk.com_tiles)) if chunk.com_tiles > 0 else 0.0
	chunk.ind_occ = (ind_sum / float(chunk.ind_tiles)) if chunk.ind_tiles > 0 else 0.0
	## Catch opinions up to this tick's counts so budget / next demand stay honest.
	chunk.refresh_opinions(war_timer, disaster_timer, _nearby_industry(map, chunk), _nearby_park(map, chunk))
	_apply_city_opinion_feed(chunk)


func _apply_city_opinion_feed(chunk: ChunkData) -> void:
	## Tiny extra multipliers from last tick's city mood. Stay inside OPINION_MIN/MAX.
	var hm := lerpf(0.97, 1.03, clampf(happiness, 0.0, 1.0))
	var lm := lerpf(0.97, 1.03, clampf(factor_land, 0.0, 1.0))
	var pm := lerpf(1.03, 0.97, clampf(factor_pollution, 0.0, 1.0))
	var extra := hm * lm * pm
	chunk.opinion_r = clampf(chunk.opinion_r * extra, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	chunk.opinion_c = clampf(chunk.opinion_c * extra, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	chunk.opinion_i = clampf(chunk.opinion_i * extra, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)


func _nudge_chunk_from_tags(chunk: ChunkData, tags: PackedStringArray) -> void:
	for t in tags:
		match str(t):
			"jobs":
				chunk.want_jobs *= 0.96
			"services":
				chunk.want_services *= 0.96
			"quiet":
				chunk.hate_pollution += 0.02
			"trade":
				chunk.want_jobs *= 1.02
			"safety":
				chunk.event_fear *= 0.97
			"rent":
				chunk.want_services *= 0.98


func _recompute_city_factors(map: MapData, budget: BudgetSystem) -> void:
	var zone_n := 0
	var occ_sum := 0.0
	var svc_n := 0
	var road_n := 0
	var poll_acc := 0.0
	var amenity_acc := 0.0
	var n_active := 0
	var any_damaged := false
	for c in map.chunks:
		var chunk: ChunkData = c
		if chunk.damaged:
			any_damaged = true
		if not chunk.active:
			continue
		n_active += 1
		var zt: int = chunk.res_tiles + chunk.com_tiles + chunk.ind_tiles
		zone_n += zt
		occ_sum += chunk.res_occ * float(chunk.res_tiles)
		occ_sum += chunk.com_occ * float(chunk.com_tiles)
		occ_sum += chunk.ind_occ * float(chunk.ind_tiles)
		svc_n += chunk.serviced_zone_tiles
		road_n += chunk.roaded_zone_tiles
		poll_acc += (chunk.ind_occ * float(chunk.ind_tiles)) / 256.0
		amenity_acc += chunk.amenity

	var denom := maxf(1.0, float(zone_n))
	var occ_avg := clampf(occ_sum / denom, 0.0, 1.0)
	factor_services = clampf(float(svc_n) / denom, 0.0, 1.0)
	factor_roads = clampf(float(road_n) / denom, 0.0, 1.0)
	factor_pollution = clampf(poll_acc / maxf(1.0, float(n_active)), 0.0, 1.0)
	var amenity_avg := clampf(amenity_acc / maxf(1.0, float(n_active)), 0.0, 1.0)
	factor_land = clampf(factor_services * factor_roads * occ_avg - factor_pollution + amenity_avg * 0.20, 0.0, 1.0)
	land_value = factor_land
	factor_rci = (
		clampf(demand_r, 0.0, 1.0) +
		clampf(demand_c, 0.0, 1.0) +
		clampf(demand_i, 0.0, 1.0)
	) / 3.0
	factor_tax = clampf(budget.tax_mult, 0.0, 1.0)
	## War embargo is tax_mult; shops' mood (opinion_c) is the second real trade factor.
	factor_trade = clampf(budget.tax_mult * clampf(city_opinion_c, 0.0, 1.25), 0.0, 1.0)
	if any_damaged or disaster_timer > 0:
		var t := 0.0
		if disaster_timer > 0:
			t = 1.0 - float(disaster_timer) / float(GameConstants.DISASTER_DURATION_TICKS)
		factor_recovery = lerpf(0.55, 1.0, t)
	else:
		factor_recovery = 1.0
	happiness = clampf(
		_W_LAND * factor_land
		+ _W_RCI * factor_rci
		+ _W_TAX * factor_tax
		+ _W_SVC * factor_services
		+ _W_ROAD * factor_roads
		+ _W_POLL * (1.0 - factor_pollution)
		+ _W_TRADE * factor_trade
		+ _W_REC * factor_recovery,
		0.0, 1.0)


func inspect_lot(map: MapData, x: int, y: int) -> Dictionary:
	if not map.in_bounds(x, y):
		return {}
	var i := map.idx(x, y)
	if map.terrain[i] == TileTypes.Terrain.WATER:
		return {}
	if map.zone[i] != TileTypes.Zone.RESIDENTIAL:
		return {}
	if map.occupancy[i] <= 0.2:
		return {}
	var rec: LotRecord = LotRecord.from_lot(x, y)
	return {
		"name": rec.name,
		"job_class": rec.job_class,
		"faction": rec.faction,
		"tags": rec.tags,
		"lot": rec.lot,
	}


func sampled_voices(map: MapData, max_n: int = 6) -> Array:
	var out: Array = []
	var cap: int = maxi(0, max_n)
	for c in map.chunks:
		if out.size() >= cap:
			break
		var chunk: ChunkData = c
		if not chunk.active or chunk.res_tiles <= 0:
			continue
		var lot := _first_occupied_r_lot(map, chunk)
		if lot.x < 0:
			continue
		out.append(LotRecord.from_lot(lot.x, lot.y))
	return out


func _first_occupied_r_lot(map: MapData, chunk: ChunkData) -> Vector2i:
	## Hash-select one occupied R lot in the chunk (min-hash). Not a personality scan.
	var x0 := chunk.cx * map.chunk_size
	var y0 := chunk.cy * map.chunk_size
	var best := Vector2i(-1, -1)
	var best_h := 0x7fffffff
	for y in range(y0, y0 + map.chunk_size):
		for x in range(x0, x0 + map.chunk_size):
			var i := map.idx(x, y)
			if map.zone[i] == TileTypes.Zone.RESIDENTIAL and map.occupancy[i] > 0.2:
				var h: int = absi(x * 73856093 ^ y * 19349663)
				if h < best_h:
					best_h = h
					best = Vector2i(x, y)
	return best


func factor_summary() -> String:
	return "land %.0f%% · rci %.0f%% · tax %.0f%% · svc %.0f%% · roads %.0f%% · pollution %.0f%% · trade %.0f%% · recovery %.0f%%" % [
		factor_land * 100.0, factor_rci * 100.0, factor_tax * 100.0,
		factor_services * 100.0, factor_roads * 100.0, factor_pollution * 100.0,
		factor_trade * 100.0, factor_recovery * 100.0
	]


func dominant_factor_name(want_best: bool) -> String:
	var items: Array = [
		["land", factor_land],
		["rci", factor_rci],
		["tax", factor_tax],
		["services", factor_services],
		["roads", factor_roads],
		["pollution", 1.0 - factor_pollution],
		["trade", factor_trade],
		["recovery", factor_recovery],
	]
	var pick: String = str(items[0][0])
	var score: float = float(items[0][1])
	for it in items:
		var s: float = float(it[1])
		if want_best:
			if s > score:
				score = s
				pick = str(it[0])
		else:
			if s < score:
				score = s
				pick = str(it[0])
	return pick


func worst_factor_name() -> String:
	return dominant_factor_name(false)


func best_factor_name() -> String:
	return dominant_factor_name(true)


func first_ten_complete() -> bool:
	return float(tick_count) * GameConstants.SIM_TICK_SEC >= 600.0


func _in_tutor_window() -> bool:
	return tutor_active and not first_ten_complete()


func _tutor_hold_card() -> Dictionary:
	return {
		"title": "Advisor",
		"body": "Finish the first lesson — View/L3 recap first."
	}


func _event_busy() -> bool:
	return war_timer > 0 or disaster_timer > 0 or event_cooldown > 0


func _event_busy_card() -> Dictionary:
	return {
		"title": "Event Already Active",
		"body": "One event at a time — war/disaster still running or cooling down."
	}


func density_unlock_tier() -> int:
	## City-wide occ mass → house / midrise / sky unlock. Catalog stays Mesh's.
	var mass := mass_r + mass_c + mass_i
	if mass >= 26000.0:
		return 2
	if mass >= 1100.0:
		return 1
	return 0


func start_war(budget: BudgetSystem) -> Dictionary:
	if _in_tutor_window():
		return _tutor_hold_card()
	if _event_busy():
		return _event_busy_card()
	war_timer = GameConstants.WAR_DURATION_TICKS
	budget.tax_mult = GameConstants.WAR_EMBARGO_TAX_START
	budget.apply_levy(GameConstants.WAR_LEVY_HIT)
	return {
		"title": "Trade Embargo + Military Levy",
		"body": "War: tax income starts at %d%% and tightens toward %d%%, levy −$%d. Commercial/industrial demand crushed; residential holds better." % [
			int(GameConstants.WAR_EMBARGO_TAX_START * 100.0),
			int(GameConstants.WAR_EMBARGO_TAX_MULT * 100.0),
			GameConstants.WAR_LEVY_HIT
		]
	}


func start_disaster(map: MapData, budget: BudgetSystem) -> Dictionary:
	if _in_tutor_window():
		return _tutor_hold_card()
	if _event_busy():
		return _event_busy_card()
	disaster_timer = GameConstants.DISASTER_DURATION_TICKS
	budget.demand_mult = GameConstants.DISASTER_DEMAND_MULT
	var active: Array = []
	for c in map.chunks:
		var chunk: ChunkData = c
		if chunk.active and not chunk.damaged:
			active.append(chunk)
	var target: ChunkData
	if active.is_empty():
		target = map.chunk_at(map.hq.x, map.hq.y)
	else:
		target = active[randi() % active.size()]
	map.damage_chunk(target.cx, target.cy)
	return {
		"title": "Disaster Strikes",
		"body": "Chunk (%d,%d) damaged — buildings offline. Residential demand collapsed; rebuild power/water/roads to recover." % [
			target.cx, target.cy
		]
	}


func demand_label() -> String:
	return "RCI demand  R %.0f%% · C %.0f%% · I %.0f%%" % [
		demand_r * 100.0, demand_c * 100.0, demand_i * 100.0
	]


func mood_label() -> String:
	return "Mood %.0f%%" % (clampf(happiness, 0.0, 1.0) * 100.0)


func city_opinion_mean() -> float:
	return clampf((city_opinion_r + city_opinion_c + city_opinion_i) / 3.0, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)


func _refresh_city_opinions(map: MapData) -> void:
	var wr := 0.0
	var wc := 0.0
	var wi := 0.0
	var sr := 0.0
	var sc := 0.0
	var si := 0.0
	var n := 0
	var ur := 0.0
	var uc := 0.0
	var ui := 0.0
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		n += 1
		ur += chunk.opinion_r
		uc += chunk.opinion_c
		ui += chunk.opinion_i
		var rt := float(chunk.res_tiles)
		var ct := float(chunk.com_tiles)
		var it := float(chunk.ind_tiles)
		if rt > 0.0:
			wr += rt
			sr += chunk.opinion_r * rt
		if ct > 0.0:
			wc += ct
			sc += chunk.opinion_c * ct
		if it > 0.0:
			wi += it
			si += chunk.opinion_i * it
	if n <= 0:
		city_opinion_r = 1.0
		city_opinion_c = 1.0
		city_opinion_i = 1.0
		return
	var nf := float(n)
	city_opinion_r = clampf((sr / wr) if wr > 0.0 else (ur / nf), GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	city_opinion_c = clampf((sc / wc) if wc > 0.0 else (uc / nf), GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	city_opinion_i = clampf((si / wi) if wi > 0.0 else (ui / nf), GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)


func _nearby_industry(map: MapData, chunk: ChunkData) -> float:
	## Adjacent-chunk occupied industry mass, normalized. O(4), no lot walk.
	var acc := 0.0
	var seen := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = chunk.cx + d.x
		var ny: int = chunk.cy + d.y
		if nx < 0 or ny < 0 or nx >= map.chunks_side or ny >= map.chunks_side:
			continue
		var nb: ChunkData = map.chunks[ny * map.chunks_side + nx]
		acc += nb.ind_occ * float(nb.ind_tiles)
		seen += 1
	if seen <= 0:
		return 0.0
	return clampf(acc / (float(seen) * 64.0), 0.0, 1.0)


func _nearby_park(map: MapData, chunk: ChunkData) -> float:
	## Adjacent-chunk park / waterfront lots. O(4).
	var acc := 0.0
	var seen := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = chunk.cx + d.x
		var ny: int = chunk.cy + d.y
		if nx < 0 or ny < 0 or nx >= map.chunks_side or ny >= map.chunks_side:
			continue
		var nb: ChunkData = map.chunks[ny * map.chunks_side + nx]
		acc += float(nb.park_tiles)
		seen += 1
	if seen <= 0:
		return 0.0
	return clampf(acc / (float(seen) * 256.0), 0.0, 1.0)
