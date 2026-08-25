class_name ToolSystem
extends RefCounted

const GameConstants = preload("res://scripts/core/game_constants.gd")

signal tool_changed(tool_id: String, label: String)

enum Tool {
	ROAD,
	ZONE_R,
	ZONE_C,
	ZONE_I,
	POWER,
	WATER,
	BULLDOZE
}

var current: int = Tool.ROAD
var brush: int = 1

const ORDER: Array[int] = [
	Tool.ROAD, Tool.ZONE_R, Tool.ZONE_C, Tool.ZONE_I, Tool.POWER, Tool.WATER
]


func cycle(dir: int = 1) -> void:
	var idx := ORDER.find(current)
	if idx < 0:
		idx = 0
	idx = (idx + dir + ORDER.size()) % ORDER.size()
	current = ORDER[idx]
	_emit()


func set_tool(t: int) -> void:
	current = t
	_emit()


func id_name() -> String:
	match current:
		Tool.ROAD:
			return "road"
		Tool.ZONE_R:
			return "zone_r"
		Tool.ZONE_C:
			return "zone_c"
		Tool.ZONE_I:
			return "zone_i"
		Tool.POWER:
			return "power"
		Tool.WATER:
			return "water"
		_:
			return "unknown"


func label() -> String:
	match current:
		Tool.ROAD:
			return "Road ($%d)" % GameConstants.ROAD_COST
		Tool.ZONE_R:
			return "Residential ($%d)" % GameConstants.ZONE_COST
		Tool.ZONE_C:
			return "Commercial ($%d)" % GameConstants.ZONE_COST
		Tool.ZONE_I:
			return "Industrial ($%d)" % GameConstants.ZONE_COST
		Tool.POWER:
			return "Power Plant ($%d)" % GameConstants.POWER_PLANT_COST
		Tool.WATER:
			return "Water Tower ($%d)" % GameConstants.WATER_TOWER_COST
		_:
			return "?"


func cost() -> int:
	match current:
		Tool.ROAD:
			return GameConstants.ROAD_COST
		Tool.ZONE_R, Tool.ZONE_C, Tool.ZONE_I:
			return GameConstants.ZONE_COST
		Tool.POWER:
			return GameConstants.POWER_PLANT_COST
		Tool.WATER:
			return GameConstants.WATER_TOWER_COST
		_:
			return 0


func _emit() -> void:
	tool_changed.emit(id_name(), label())
