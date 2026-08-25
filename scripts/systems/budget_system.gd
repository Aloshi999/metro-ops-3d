class_name BudgetSystem
extends RefCounted
## Cash ledger: per-zone tax from aggregate occupancy, upkeep for services.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const MapData = preload("res://scripts/systems/map_data.gd")

signal cash_changed(cash: int, income: int, upkeep: int)

var cash: int = GameConstants.STARTING_CASH
var last_income: int = 0
var last_upkeep: int = 0
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


func tick(map: MapData) -> void:
	var income_f := _tax_income(map)
	var upkeep := 0
	if grace_ticks > 0:
		grace_ticks -= 1
	else:
		# Starter HQ power/water are civic — only player-placed services bill upkeep.
		var extra_power: int = maxi(0, map.power_plants.size() - map.starter_power_count)
		var extra_water: int = maxi(0, map.water_towers.size() - map.starter_water_count)
		upkeep += extra_power * GameConstants.POWER_UPKEEP
		upkeep += extra_water * GameConstants.WATER_UPKEEP

	last_income = int(income_f)
	last_upkeep = upkeep
	cash += last_income - last_upkeep
	_emit()


func _tax_income(map: MapData) -> float:
	var event_mult: float = demand_mult * tax_mult
	var income_f := 0.0
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		income_f += chunk.tax_yield_weighted(event_mult)
	if income_f > 0.01:
		return income_f
	# Fallback if sim has not aggregated yet: tax occupied lots on active chunks.
	for c2 in map.chunks:
		var chunk2: ChunkData = c2
		if not chunk2.active:
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
						income_f += occ * GameConstants.TAX_RES
					TileTypes.Zone.COMMERCIAL:
						income_f += occ * GameConstants.TAX_COM
					TileTypes.Zone.INDUSTRIAL:
						income_f += occ * GameConstants.TAX_IND
	return income_f * event_mult


func _emit() -> void:
	cash_changed.emit(cash, last_income, last_upkeep)
