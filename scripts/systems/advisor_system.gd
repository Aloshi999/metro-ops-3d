class_name AdvisorSystem
extends RefCounted
## Blocks / warns bad first moves + RCI imbalance / event feedback.

const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")
const SimSystem = preload("res://scripts/systems/sim_system.gd")

signal advice_changed(messages: Array)

enum Severity { INFO, WARN, BLOCK }

var messages: Array = []


func evaluate(map: MapData, budget: BudgetSystem, tool_name: String, sim: SimSystem = null) -> Array:
	messages.clear()
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

	if messages.is_empty():
		_add(Severity.INFO, "City stable. Expand roads to reveal fog-of-build.")

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
