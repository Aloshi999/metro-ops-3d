class_name BudgetSystem
extends RefCounted
## Cash ledger: rent + jobs + trade from aggregate occupancy, upkeep for services.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const MapData = preload("res://scripts/systems/map_data.gd")

signal cash_changed(cash: int, income: int, upkeep: int)

var cash: int = GameConstants.STARTING_CASH
var last_income: int = 0
var last_upkeep: int = 0
var last_rent: int = 0
var last_jobs: int = 0
var last_trade: int = 0
var last_land: int = 0
var tax_mult: float = 1.0
var demand_mult: float = 1.0
var grace_ticks: int = GameConstants.UPKEEP_GRACE_TICKS


func can_afford(cost: int) -> bool:
	return cash >= cost


func spend(cost: int) -> bool:
	if cash < cost:
		return false
	cash -= cost
	_emit()
	return true


func apply_levy(amount: int) -> void:
	cash = maxi(0, cash - amount)
	_emit()


func tick(map: MapData, land_value: float = 0.70) -> void:
	_tax_income(map, land_value)
	var upkeep := 0
	if grace_ticks > 0:
		grace_ticks -= 1
	else:
		# Starter HQ power/water are civic — only player-placed services bill upkeep.
		var extra_power: int = maxi(0, map.power_plants.size() - map.starter_power_count)
		var extra_water: int = maxi(0, map.water_towers.size() - map.starter_water_count)
		upkeep += extra_power * GameConstants.POWER_UPKEEP
		upkeep += extra_water * GameConstants.WATER_UPKEEP

	last_income = last_rent + last_jobs + last_trade + last_land
	last_upkeep = upkeep
	cash += last_income - last_upkeep
	_emit()


func _tax_income(map: MapData, land_value: float = 0.70) -> float:
	var event_mult: float = demand_mult * tax_mult
	var rent := 0.0
	var jobs := 0.0
	var trade := 0.0
	var land := 0.0
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active or chunk.damaged:
			continue
		var r_mass: float = chunk.res_occ * float(chunk.res_tiles)
		var op_r: float = clampf(chunk.opinion_r, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
		var op_c: float = clampf(chunk.opinion_c, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
		## Opinion-weighted rent: sour neighborhoods collect less, happy ones more.
		rent += r_mass * GameConstants.TAX_RES * event_mult * op_r
		land += r_mass * GameConstants.LAND_VALUE_TAX * land_value * event_mult
		var ci_mass: float = chunk.com_occ * float(chunk.com_tiles) + chunk.ind_occ * float(chunk.ind_tiles)
		jobs += ci_mass * GameConstants.JOB_TAX * event_mult
		## Trade: war embargo is tax_mult; shops' mood is the second real factor.
		trade += chunk.com_occ * float(chunk.com_tiles) * GameConstants.TRADE_BONUS * tax_mult * op_c
	if rent + jobs + trade <= 0.01:
		# Fallback if sim has not aggregated yet: tax occupied lots on active chunks.
		for c2 in map.chunks:
			var chunk2: ChunkData = c2
			if not chunk2.active or chunk2.damaged:
				continue
			var x0 := chunk2.cx * map.chunk_size
			var y0 := chunk2.cy * map.chunk_size
			for y in range(y0, y0 + map.chunk_size):
				for x in range(x0, x0 + map.chunk_size):
					var i := map.idx(x, y)
					var z: int = map.zone[i]
					if z == TileTypes.Zone.NONE:
						continue
					var occ: float = map.occupancy[i]
					if occ <= 0.0:
						continue
					match z:
						TileTypes.Zone.RESIDENTIAL:
							rent += occ * GameConstants.TAX_RES * event_mult * clampf(chunk2.opinion_r, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
							land += occ * GameConstants.LAND_VALUE_TAX * land_value * event_mult
						TileTypes.Zone.COMMERCIAL:
							jobs += occ * GameConstants.JOB_TAX * event_mult
							trade += occ * GameConstants.TRADE_BONUS * tax_mult * clampf(chunk2.opinion_c, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
						TileTypes.Zone.INDUSTRIAL:
							jobs += occ * GameConstants.JOB_TAX * event_mult
	last_rent = int(rent)
	last_jobs = int(jobs)
	last_trade = int(trade)
	last_land = int(land)
	return rent + jobs + trade + land


func _emit() -> void:
	cash_changed.emit(cash, last_income, last_upkeep)
