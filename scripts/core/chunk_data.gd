class_name ChunkData
extends RefCounted
## Aggregate stats for one 16×16 lot chunk. No per-citizen agents.

const GameConstants = preload("res://scripts/core/game_constants.gd")

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
var roaded_zone_tiles: int = 0
## Unzoned grass + water in the chunk — cheap park / waterfront amenity (no Mesh hook).
var park_tiles: int = 0

## Demand-modifier opinions (recomputed from previous-tick aggregates).
var want_jobs: float = 1.0
var want_services: float = 1.0
var hate_pollution: float = 1.0
var event_fear: float = 1.0
var amenity: float = 0.0
var nearby_industry: float = 0.0
var power_cover: float = 0.0
var water_cover: float = 0.0
var opinion_r: float = 1.0
var opinion_c: float = 1.0
var opinion_i: float = 1.0


func reset_counts() -> void:
	res_tiles = 0
	com_tiles = 0
	ind_tiles = 0
	powered_zone_tiles = 0
	watered_zone_tiles = 0
	serviced_zone_tiles = 0
	roaded_zone_tiles = 0
	park_tiles = 0


func refresh_opinions(war_timer: int, disaster_timer: int, nearby_ind: float = 0.0, nearby_park: float = 0.0) -> void:
	## Cheap arithmetic from last tick's counts. Does not walk lots.
	var jobs_ratio: float = (com_occ * float(com_tiles) + ind_occ * float(ind_tiles)) / maxf(1.0, float(res_tiles))
	var zone_tiles: int = res_tiles + com_tiles + ind_tiles
	var zone_n: float = maxf(1.0, float(zone_tiles))
	var svc_ratio: float = float(serviced_zone_tiles) / zone_n
	power_cover = clampf(float(powered_zone_tiles) / zone_n, 0.0, 1.0)
	water_cover = clampf(float(watered_zone_tiles) / zone_n, 0.0, 1.0)
	## Coverage is the service-radius proxy: tiles already stamped inside POWER/WATER/HQ radius.
	var svc_q: float = clampf(svc_ratio * 0.50 + power_cover * 0.25 + water_cover * 0.25, 0.0, 1.0)
	var pollution: float = (ind_occ * float(ind_tiles)) / 256.0
	var homes_ratio: float = (res_occ * float(res_tiles)) / maxf(1.0, float(com_tiles))
	var occ_mass: float = res_occ * float(res_tiles) + com_occ * float(com_tiles) + ind_occ * float(ind_tiles)
	var occ_avg: float = clampf(occ_mass / zone_n, 0.0, 1.0)
	amenity = clampf(float(park_tiles) / 256.0 + clampf(nearby_park, 0.0, 1.0) * 0.50, 0.0, 1.0)
	nearby_industry = clampf(nearby_ind, 0.0, 1.0)
	## R likes parks and hates factories next door; I is the inverse.
	var green: float = clampf(amenity - pollution * 0.50 - nearby_industry * 0.35, 0.0, 1.0)
	var fear: float = 1.0
	if damaged:
		fear = 0.55
	elif disaster_timer > 0:
		fear = 0.78
	elif war_timer > 0:
		fear = 0.90
	want_jobs = jobs_ratio
	want_services = svc_q
	hate_pollution = pollution
	event_fear = fear
	opinion_r = clampf(
		lerpf(0.78, 1.16, jobs_ratio)
		* lerpf(0.72, 1.08, svc_q)
		* lerpf(0.88, 1.10, green)
		* lerpf(0.90, 1.05, occ_avg)
		* fear,
		GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	opinion_c = clampf(
		lerpf(0.80, 1.12, homes_ratio)
		* lerpf(0.78, 1.06, svc_q)
		* lerpf(0.94, 1.06, amenity)
		* lerpf(0.92, 1.04, occ_avg)
		* fear,
		GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)
	opinion_i = clampf(
		lerpf(0.90, 1.10, 1.0 - pollution)
		* lerpf(0.80, 1.06, svc_q)
		* lerpf(0.88, 1.08, power_cover)
		* lerpf(0.96, 1.06, nearby_industry)
		* lerpf(1.02, 0.92, amenity)
		* lerpf(1.0, 0.85, fear),
		GameConstants.OPINION_MIN, GameConstants.OPINION_MAX)


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
