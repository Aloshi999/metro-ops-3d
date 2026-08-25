class_name BudgetSystem
extends RefCounted
## Cash ledger: per-zone tax from aggregate occupancy, upkeep for services.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")

signal cash_changed(cash: int, income: int, upkeep: int)

var cash: int = GameConstants.STARTING_CASH
var last_income: int = 0
var last_upkeep: int = 0
var tax_mult: float = 1.0
var demand_mult: float = 1.0


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
	var income_f := 0.0
	var upkeep := 0
	upkeep += map.power_plants.size() * GameConstants.POWER_UPKEEP
	upkeep += map.water_towers.size() * GameConstants.WATER_UPKEEP

	var event_mult: float = demand_mult * tax_mult
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		income_f += chunk.tax_yield_weighted(event_mult)

	last_income = int(income_f)
	last_upkeep = upkeep
	cash += last_income - last_upkeep
	_emit()


func _emit() -> void:
	cash_changed.emit(cash, last_income, last_upkeep)
