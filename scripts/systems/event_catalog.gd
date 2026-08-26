class_name EventCatalog
extends RefCounted
## Six 1.0 event cards on the aggregate ledger. No walkers. Builder integrates HUD.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")

const WAR_IDS: PackedStringArray = ["trade_embargo", "corridor_interdiction"]
const DISASTER_IDS: PackedStringArray = ["flood_surge", "quake_grid", "grid_blackout", "dock_walkout"]


static func apply(sim, map, budget, id: String) -> Dictionary:
	match id:
		"trade_embargo":
			return _embargo(sim, budget)
		"corridor_interdiction":
			return _corridor(sim, map, budget)
		"flood_surge":
			return _flood(sim, map, budget)
		"quake_grid":
			return _quake(sim, map, budget)
		"grid_blackout":
			return _blackout(sim, map, budget)
		"dock_walkout":
			return _walkout(sim, budget)
		_:
			return {"title": "Unknown Event", "body": id}


static func clear(sim, budget, map) -> void:
	sim.active_card = ""
	sim.card_demand_r = 1.0
	sim.card_demand_c = 1.0
	sim.card_demand_i = 1.0
	sim.card_land_mult = 1.0
	sim.war_timer = 0
	sim.disaster_timer = 0
	if budget != null:
		budget.tax_mult = 1.0
		budget.demand_mult = 1.0
		budget.trade_mult = 1.0
	if map != null and map.blackout_plant.x >= 0:
		map.blackout_plant = Vector2i(-1, -1)
		map.recompute_services()


static func _begin_war(sim, budget, duration: int, tax: float, trade: float, dr: float, dc: float, di: float, land: float) -> void:
	sim.war_timer = duration
	sim.disaster_timer = 0
	sim.card_demand_r = dr
	sim.card_demand_c = dc
	sim.card_demand_i = di
	sim.card_land_mult = land
	budget.tax_mult = tax
	budget.trade_mult = trade


static func _begin_disaster(sim, budget, duration: int, tax: float, trade: float, demand_mult: float, dr: float, dc: float, di: float, land: float) -> void:
	sim.disaster_timer = duration
	sim.war_timer = 0
	sim.card_demand_r = dr
	sim.card_demand_c = dc
	sim.card_demand_i = di
	sim.card_land_mult = land
	budget.tax_mult = tax
	budget.trade_mult = trade
	budget.demand_mult = demand_mult


static func _embargo(sim, budget) -> Dictionary:
	sim.active_card = "trade_embargo"
	_begin_war(
		sim, budget,
		GameConstants.WAR_DURATION_TICKS,
		GameConstants.WAR_EMBARGO_TAX_START,
		GameConstants.EMBARGO_TRADE_MULT,
		GameConstants.WAR_DEMAND_R, GameConstants.WAR_DEMAND_C, GameConstants.WAR_DEMAND_I,
		1.0
	)
	budget.apply_levy(GameConstants.WAR_LEVY_HIT)
	return {
		"title": "Trade Embargo",
		"body": "Docks locked. Commercial/industrial demand crushed; residential holds better. Levy −$%d. Tax starts at %d%% and tightens toward %d%%." % [
			GameConstants.WAR_LEVY_HIT,
			int(GameConstants.WAR_EMBARGO_TAX_START * 100.0),
			int(GameConstants.WAR_EMBARGO_TAX_MULT * 100.0)
		]
	}


static func _corridor(sim, map, budget) -> Dictionary:
	sim.active_card = "corridor_interdiction"
	_begin_war(
		sim, budget,
		GameConstants.CORRIDOR_DURATION_TICKS,
		GameConstants.CORRIDOR_TAX_MULT,
		GameConstants.CORRIDOR_TRADE_MULT,
		GameConstants.CORRIDOR_DEMAND_R, GameConstants.CORRIDOR_DEMAND_C, GameConstants.CORRIDOR_DEMAND_I,
		GameConstants.CORRIDOR_LAND_MULT
	)
	var n := _damage_adjacent(map, GameConstants.CORRIDOR_CHUNKS)
	return {
		"title": "Corridor Interdiction",
		"body": "Freight spine cut. %d chunks offline. Commercial trade dies on the road." % n
	}


static func _flood(sim, map, budget) -> Dictionary:
	sim.active_card = "flood_surge"
	_begin_disaster(
		sim, budget,
		GameConstants.DISASTER_DURATION_TICKS,
		0.93,
		GameConstants.FLOOD_TRADE_MULT,
		GameConstants.DISASTER_DEMAND_MULT,
		GameConstants.DISASTER_DEMAND_R, GameConstants.DISASTER_DEMAND_C, GameConstants.DISASTER_DEMAND_I,
		GameConstants.FLOOD_LAND_MULT
	)
	var n := _damage_water_edge(map, GameConstants.FLOOD_CHUNKS)
	return {
		"title": "Flood Surge",
		"body": "Water takes the lots. %d shoreline chunks damaged. Rebuild power/water/roads." % n
	}


static func _quake(sim, map, budget) -> Dictionary:
	sim.active_card = "quake_grid"
	var n_want := 2
	if _active_count(map) >= 6:
		n_want = 3
	_begin_disaster(
		sim, budget,
		GameConstants.QUAKE_DURATION_TICKS,
		GameConstants.QUAKE_TAX_MULT,
		GameConstants.QUAKE_TRADE_MULT,
		GameConstants.DISASTER_DEMAND_MULT,
		GameConstants.QUAKE_DEMAND_R, GameConstants.QUAKE_DEMAND_C, GameConstants.QUAKE_DEMAND_I,
		GameConstants.QUAKE_LAND_MULT
	)
	var n := _damage_random(map, n_want)
	return {
		"title": "Grid Quake",
		"body": "The grid cracks. %d chunks down. Rebuild demand spikes — paint I near the rubble." % n
	}


static func _blackout(sim, map, budget) -> Dictionary:
	sim.active_card = "grid_blackout"
	_begin_disaster(
		sim, budget,
		GameConstants.BLACKOUT_DURATION_TICKS,
		GameConstants.BLACKOUT_TAX_MULT,
		GameConstants.BLACKOUT_TRADE_MULT,
		0.90,
		GameConstants.BLACKOUT_DEMAND_R, GameConstants.BLACKOUT_DEMAND_C, GameConstants.BLACKOUT_DEMAND_I,
		1.0
	)
	var plant := Vector2i(-1, -1)
	if map != null and map.power_plants.size() > 0:
		plant = map.power_plants[0]
	if plant.x >= 0:
		map.blackout_plant = plant
		map.recompute_services()
	return {
		"title": "Grid Blackout",
		"body": "The plant goes dark. Shops and factories stop paying. Place another plant or wait it out."
	}


static func _walkout(sim, budget) -> Dictionary:
	sim.active_card = "dock_walkout"
	_begin_disaster(
		sim, budget,
		GameConstants.WALKOUT_DURATION_TICKS,
		GameConstants.WALKOUT_TAX_MULT,
		GameConstants.WALKOUT_TRADE_MULT,
		0.85,
		1.0, GameConstants.WALKOUT_DEMAND_C, GameConstants.WALKOUT_DEMAND_I,
		1.0
	)
	return {
		"title": "Dock Walkout",
		"body": "Docks go quiet. Freight piles up. Commercial demand starves until the shift ends."
	}


static func _active_count(map) -> int:
	var n := 0
	if map == null:
		return 0
	for c in map.chunks:
		if c.active:
			n += 1
	return n


static func _pick_active(map) -> Array:
	var out: Array = []
	if map == null:
		return out
	for c in map.chunks:
		if c.active and not c.damaged:
			out.append(c)
	return out


static func _damage_random(map, n: int) -> int:
	var pool := _pick_active(map)
	if pool.is_empty() and map != null:
		var hq = map.chunk_at(map.hq.x, map.hq.y)
		map.damage_chunk(hq.cx, hq.cy)
		return 1
	var hit := 0
	while hit < n and pool.size() > 0:
		var i := randi() % pool.size()
		var ch = pool[i]
		pool.remove_at(i)
		map.damage_chunk(ch.cx, ch.cy)
		hit += 1
	return hit


static func _damage_adjacent(map, n: int) -> int:
	var pool := _pick_active(map)
	if pool.is_empty():
		return _damage_random(map, n)
	var seed = pool[randi() % pool.size()]
	var chosen: Array = [seed]
	var guard := 0
	while chosen.size() < n and guard < 16:
		guard += 1
		var grew := false
		for ch in chosen.duplicate():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = ch.cx + d.x
				var ny: int = ch.cy + d.y
				if nx < 0 or ny < 0 or nx >= map.chunks_side or ny >= map.chunks_side:
					continue
				var nb = map.chunks[ny * map.chunks_side + nx]
				if nb in chosen:
					continue
				if nb.active or true:
					chosen.append(nb)
					grew = true
					if chosen.size() >= n:
						break
			if chosen.size() >= n:
				break
		if not grew:
			break
	var hit := 0
	for ch2 in chosen:
		map.damage_chunk(ch2.cx, ch2.cy)
		hit += 1
	return hit


static func _damage_water_edge(map, n: int) -> int:
	var wet: Array = []
	for c in _pick_active(map):
		if _touches_water(map, c):
			wet.append(c)
	if wet.is_empty():
		return _damage_random(map, n)
	var hit := 0
	while hit < n and wet.size() > 0:
		var i := randi() % wet.size()
		var ch = wet[i]
		wet.remove_at(i)
		map.damage_chunk(ch.cx, ch.cy)
		hit += 1
	return hit


static func _touches_water(map, chunk) -> bool:
	var x0: int = chunk.cx * map.chunk_size
	var y0: int = chunk.cy * map.chunk_size
	for y in range(y0, y0 + map.chunk_size):
		for x in range(x0, x0 + map.chunk_size):
			if map.terrain[map.idx(x, y)] == TileTypes.Terrain.WATER:
				return true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if map.in_bounds(nx, ny) and map.terrain[map.idx(nx, ny)] == TileTypes.Terrain.WATER:
					return true
	return false
