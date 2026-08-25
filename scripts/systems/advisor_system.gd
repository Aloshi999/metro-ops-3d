class_name AdvisorSystem
extends RefCounted
## Blocks / warns bad first moves + RCI imbalance / event feedback.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")
const SimSystem = preload("res://scripts/systems/sim_system.gd")

signal advice_changed(messages: Array)

enum Severity { INFO, WARN, BLOCK }

var messages: Array = []


func evaluate(map: MapData, budget: BudgetSystem, tool_name: String, sim: SimSystem = null, campaign = null) -> Array:
	messages.clear()
	if campaign != null and campaign.has_method("advisor_line"):
		var line: String = str(campaign.advisor_line())
		if line != "":
			_add(Severity.INFO, line)
	var has_power: bool = map.power_plants.size() > 0
	var has_water: bool = map.water_towers.size() > 0
	var zone_count := _count_zones(map)

	if budget.cash < 500:
		_add(Severity.WARN, "Treasury low. Cut upkeep or grow taxed occupancy.")

	if not has_power:
		_add(Severity.WARN, "No power plant. Zones will not grow occupancy.")
		if tool_name.begins_with("zone_"):
			_add(Severity.BLOCK, "Advisor: place a Power Plant before zoning (or expect empty lots).")

	if not has_water:
		_add(Severity.WARN, "No water tower. Zones need water + power to fill.")
		if tool_name.begins_with("zone_") and has_power:
			_add(Severity.BLOCK, "Advisor: place a Water Tower before heavy zoning.")

	if has_power and has_water and zone_count == 0:
		_add(Severity.INFO, "Services online. Paint roads, then R/C/I beside them.")

	if zone_count > 0 and not has_power:
		_add(Severity.BLOCK, "Zoned lots lack city power — build a plant near roads.")

	if budget.tax_mult < 1.0:
		_add(Severity.WARN, "War embargo active — tax income reduced; C/I demand crushed.")
	if budget.demand_mult < 1.0:
		_add(Severity.WARN, "Disaster demand crash — residential growth stalled.")

	if sim != null:
		_add(Severity.INFO, sim.demand_label())
		_advise_rci(sim, tool_name)
		_advise_voices(map, sim)
		_advise_happiness(sim)

	if messages.is_empty():
		_add(Severity.INFO, "City stable. Expand roads to reveal fog-of-build.")

	## First 10 minutes: one card only. Cheap slice, HUD unchanged.
	if sim != null and not sim.first_ten_complete() and messages.size() > 1:
		messages.resize(1)

	advice_changed.emit(messages)
	return messages


func _advise_rci(sim: SimSystem, tool_name: String) -> void:
	var total := sim.mass_r + sim.mass_c + sim.mass_i
	if total < 1.0:
		return
	if sim.demand_r >= 1.15 and not tool_name.begins_with("zone_r"):
		_add(Severity.INFO, "Housing demand hot — paint Residential beside roads.")
	if sim.demand_c >= 1.15 and not tool_name.begins_with("zone_c"):
		_add(Severity.INFO, "Shop demand hot — Commercial wants customers (more R nearby).")
	if sim.demand_i >= 1.15 and not tool_name.begins_with("zone_i"):
		_add(Severity.INFO, "Industry demand hot — Industrial feeds shops; keep roads clear.")
	if sim.demand_r <= 0.25 and sim.mass_r > 2.0:
		_add(Severity.WARN, "Residential demand cold — add jobs (C/I) or wait out disaster.")
	if sim.demand_c <= 0.25 and sim.mass_c > 1.0:
		_add(Severity.WARN, "Commercial demand cold — more residents, or war embargo still on.")
	if sim.war_timer > 0:
		_add(Severity.INFO, "War timer %d ticks — embargo lifts when it hits 0." % sim.war_timer)
	elif sim.disaster_timer > 0:
		_add(Severity.INFO, "Disaster timer %d ticks — repair damaged chunk services." % sim.disaster_timer)


func _advise_voices(map: MapData, sim: SimSystem) -> void:
	## At most 1-2 INFO lines from extreme chunks OR sampled lot records. No bodies.
	var added := 0
	var poll_chunk: ChunkData = null
	var poll_best: float = 0.05
	var jobs_chunk: ChunkData = null
	var jobs_worst: float = 0.30
	var fear_chunk: ChunkData = null
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active or chunk.res_tiles <= 0:
			continue
		if chunk.hate_pollution > poll_best:
			poll_best = chunk.hate_pollution
			poll_chunk = chunk
		if chunk.want_jobs < jobs_worst:
			jobs_worst = chunk.want_jobs
			jobs_chunk = chunk
		if chunk.event_fear < 0.8 and fear_chunk == null:
			fear_chunk = chunk
	if poll_chunk != null:
		if poll_chunk.amenity < 0.08:
			_add(Severity.INFO, "Renters at chunk (%d,%d) hate the factories — no park buffer." % [poll_chunk.cx, poll_chunk.cy])
		else:
			_add(Severity.INFO, "Renters at chunk (%d,%d) hate the factories." % [poll_chunk.cx, poll_chunk.cy])
		added += 1
	if added < 2 and jobs_chunk != null:
		_add(Severity.INFO, "Households at (%d,%d) want jobs — C/I too thin." % [jobs_chunk.cx, jobs_chunk.cy])
		added += 1
	if added < 2 and fear_chunk != null:
		_add(Severity.INFO, "Neighbors fear the disaster / embargo.")
		added += 1
	var voices: Array = sim.sampled_voices(map, 1)
	if not voices.is_empty():
		var rec = voices[0]
		var tag := "jobs"
		if rec.tags.size() > 0:
			tag = str(rec.tags[0])
		_add(Severity.INFO, "%s (%s) wants %s." % [rec.name, rec.job_class, tag])


func _advise_happiness(sim: SimSystem) -> void:
	var mood_pct: int = int(round(clampf(sim.happiness, 0.0, 1.0) * 100.0))
	if sim.happiness < 0.4:
		_add(Severity.INFO, "City mood %d%% — %s." % [mood_pct, sim.worst_factor_name()])
	elif sim.happiness > 0.75:
		_add(Severity.INFO, "City mood %d%% — %s." % [mood_pct, sim.best_factor_name()])
	else:
		_add(Severity.INFO, "City mood %d%%." % mood_pct)
	if sim.city_opinion_r <= GameConstants.OPINION_MIN + 0.08:
		_add(Severity.WARN, "Renters are sour — cover power/water or pull industry off the parks.")


func should_block_paint(tool_name: String, map: MapData) -> bool:
	if not tool_name.begins_with("zone_"):
		return false
	if map.power_plants.is_empty() and _count_zones(map) >= 8:
		return true
	return false


func _count_zones(map: MapData) -> int:
	var n := 0
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		n += chunk.res_tiles + chunk.com_tiles + chunk.ind_tiles
	if n == 0:
		var r := 20
		for y in range(map.hq.y - r, map.hq.y + r):
			for x in range(map.hq.x - r, map.hq.x + r):
				if map.in_bounds(x, y) and map.zone[map.idx(x, y)] != TileTypes.Zone.NONE:
					n += 1
	return n


func _add(sev: int, text: String) -> void:
	messages.append({"sev": sev, "text": text})
