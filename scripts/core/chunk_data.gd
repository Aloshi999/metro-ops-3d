class_name ChunkData
extends RefCounted
## Aggregate stats for one 16×16 lot chunk. No per-citizen agents.

var cx: int = 0
var cy: int = 0
var active: bool = false
var damaged: bool = false
var damage_timer: int = 0

var res_tiles: int = 0
var com_tiles: int = 0
var ind_tiles: int = 0
var res_occ: float = 0.0
var com_occ: float = 0.0
var ind_occ: float = 0.0

var powered_zone_tiles: int = 0
var watered_zone_tiles: int = 0
var serviced_zone_tiles: int = 0


func reset_counts() -> void:
	res_tiles = 0
	com_tiles = 0
	ind_tiles = 0
	powered_zone_tiles = 0
	watered_zone_tiles = 0
	serviced_zone_tiles = 0


func tax_yield(tax_per: float, demand_mult: float) -> float:
	if damaged:
		return 0.0
	var occ_sum := res_occ * res_tiles + com_occ * com_tiles + ind_occ * ind_tiles
	return occ_sum * tax_per * demand_mult


func tax_yield_weighted(event_mult: float) -> float:
	if damaged:
		return 0.0
	var income := 0.0
	income += res_occ * float(res_tiles) * GameConstants.TAX_RES
	income += com_occ * float(com_tiles) * GameConstants.TAX_COM
	income += ind_occ * float(ind_tiles) * GameConstants.TAX_IND
	return income * event_mult
