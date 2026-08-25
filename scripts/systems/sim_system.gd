class_name SimSystem
extends RefCounted
## Active-chunk aggregate sim only. No per-citizen agents, no traffic pathfinding.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")

signal tick_done
signal demand_changed(res_d: float, com_d: float, ind_d: float)

var tick_count: int = 0
var war_timer: int = 0
var disaster_timer: int = 0

var demand_r: float = GameConstants.RCI_DEMAND_BASE
var demand_c: float = GameConstants.RCI_DEMAND_BASE
var demand_i: float = GameConstants.RCI_DEMAND_BASE

var mass_r: float = 0.0
var mass_c: float = 0.0
var mass_i: float = 0.0


func tick(map: MapData, budget: BudgetSystem) -> void:
	tick_count += 1
	_tick_events(budget)
	_recompute_city_demand(map, budget)
	_sim_active_chunks(map)
	budget.tick(map)
	tick_done.emit()
	demand_changed.emit(demand_r, demand_c, demand_i)


func _tick_events(budget: BudgetSystem) -> void:
	if war_timer > 0:
		war_timer -= 1
		if war_timer <= 0:
			budget.tax_mult = 1.0
	if disaster_timer > 0:
		disaster_timer -= 1
		if disaster_timer <= 0:
			budget.demand_mult = 1.0


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

	demand_r = clampf(dr, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)
	demand_c = clampf(dc, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)
	demand_i = clampf(di, GameConstants.RCI_DEMAND_MIN, GameConstants.RCI_DEMAND_MAX)


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
	chunk.reset_counts()
	var x0 := chunk.cx * map.chunk_size
	var y0 := chunk.cy * map.chunk_size
	var res_sum := 0.0
	var com_sum := 0.0
	var ind_sum := 0.0

	for y in range(y0, y0 + map.chunk_size):
		for x in range(x0, x0 + map.chunk_size):
			var i := map.idx(x, y)
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

			var target := service_target * clampf(zone_demand, 0.0, 1.0)
			if zone_demand > 1.0 and service_target >= 1.0:
				target = 1.0

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


func start_war(budget: BudgetSystem) -> Dictionary:
	war_timer = GameConstants.WAR_DURATION_TICKS
	budget.tax_mult = GameConstants.WAR_EMBARGO_TAX_MULT
	budget.apply_levy(GameConstants.WAR_LEVY_HIT)
	return {
		"title": "Trade Embargo + Military Levy",
		"body": "War: tax income cut to %d%%, levy −$%d. Commercial/industrial demand crushed; residential holds better." % [
			int(GameConstants.WAR_EMBARGO_TAX_MULT * 100.0),
			GameConstants.WAR_LEVY_HIT
		]
	}


func start_disaster(map: MapData, budget: BudgetSystem) -> Dictionary:
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
