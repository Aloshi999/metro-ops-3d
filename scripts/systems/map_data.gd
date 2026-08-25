class_name MapData
extends RefCounted
## Flat 128×128 lot map + 16×16 chunk grid. Fog-of-build + aggregate fields.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")

signal map_changed
signal fog_changed
signal services_changed

var size: int = GameConstants.MAP_SIZE
var chunk_size: int = GameConstants.CHUNK_SIZE
var chunks_side: int = GameConstants.CHUNKS_PER_SIDE

var terrain: PackedByteArray
var zone: PackedByteArray
var road: PackedByteArray
var service: PackedByteArray
var revealed: PackedByteArray
var powered: PackedByteArray
var watered: PackedByteArray
var occupancy: PackedFloat32Array
var damaged_tile: PackedByteArray

var chunks: Array = []
var hq: Vector2i = Vector2i(64, 64)

var power_plants: Array[Vector2i] = []
var water_towers: Array[Vector2i] = []
var starter_power_count: int = 0
var starter_water_count: int = 0

var district: PackedByteArray
var seed_downtown_lots: int = 0
var seed_midrise_lots: int = 0
var seed_park_lots: int = 0
var seed_waterfront_lots: int = 0


func _init() -> void:
	_alloc()
	_gen_terrain()
	_init_chunks()
	_place_hq()
	_seed_downtown()
	_seed_district_lots()


func _alloc() -> void:
	var n := size * size
	terrain = PackedByteArray(); terrain.resize(n)
	zone = PackedByteArray(); zone.resize(n)
	road = PackedByteArray(); road.resize(n)
	service = PackedByteArray(); service.resize(n)
	revealed = PackedByteArray(); revealed.resize(n)
	powered = PackedByteArray(); powered.resize(n)
	watered = PackedByteArray(); watered.resize(n)
	damaged_tile = PackedByteArray(); damaged_tile.resize(n)
	occupancy = PackedFloat32Array(); occupancy.resize(n)
	district = PackedByteArray(); district.resize(n)
	for i in n:
		occupancy[i] = 0.0


func idx(x: int, y: int) -> int:
	return y * size + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func lot_to_world(x: int, y: int) -> Vector3:
	var s := GameConstants.LOT_METERS
	return Vector3((float(x) + 0.5) * s, 0.0, (float(y) + 0.5) * s)


func world_to_lot(p: Vector3) -> Vector2i:
	var s := GameConstants.LOT_METERS
	return Vector2i(int(floor(p.x / s)), int(floor(p.z / s)))


func world_size() -> float:
	return float(size) * GameConstants.LOT_METERS


func _gen_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in size:
		for x in size:
			var i := idx(x, y)
			var n := rng.randf()
			var h := fposmod(sin(x * 0.07 + y * 0.11) * 0.5 + cos(x * 0.03 - y * 0.05) * 0.5, 1.0)
			if h < 0.07:
				terrain[i] = TileTypes.Terrain.WATER
			elif n > 0.48:
				terrain[i] = TileTypes.Terrain.GRASS
			else:
				terrain[i] = TileTypes.Terrain.DIRT


func _init_chunks() -> void:
	chunks.clear()
	for cy in chunks_side:
		for cx in chunks_side:
			var c := ChunkData.new()
			c.cx = cx
			c.cy = cy
			chunks.append(c)


func chunk_at(x: int, y: int) -> ChunkData:
	var cx := x / chunk_size
	var cy := y / chunk_size
	return chunks[cy * chunks_side + cx]


func _place_hq() -> void:
	hq = Vector2i(size / 2, size / 2)
	var i := idx(hq.x, hq.y)
	terrain[i] = TileTypes.Terrain.DIRT
	service[i] = TileTypes.Service.HQ
	road[i] = 1
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var p: Vector2i = hq + d
		if in_bounds(p.x, p.y):
			var j := idx(p.x, p.y)
			if terrain[j] != TileTypes.Terrain.WATER:
				road[j] = 1
	_reveal_around(hq.x, hq.y, GameConstants.FOG_REVEAL_RADIUS + 6)
	_mark_chunk_active(hq.x, hq.y)


func _seed_downtown() -> void:
	## Visible 3D starter city around HQ so the product opens as a city, not empty dirt.
	var rng := RandomNumberGenerator.new()
	rng.seed = 777001
	# Road grid every 3 lots in a 17×17 neighborhood
	for y in range(hq.y - 8, hq.y + 9):
		for x in range(hq.x - 8, hq.x + 9):
			if not in_bounds(x, y):
				continue
			var i := idx(x, y)
			if terrain[i] == TileTypes.Terrain.WATER:
				continue
			if (x - hq.x) % 3 == 0 or (y - hq.y) % 3 == 0:
				if service[i] == TileTypes.Service.NONE:
					road[i] = 1
					zone[i] = TileTypes.Zone.NONE
	# Power + water so occupancy can grow immediately
	_force_service(hq.x + 3, hq.y + 3, TileTypes.Service.POWER_PLANT)
	_force_service(hq.x - 3, hq.y + 3, TileTypes.Service.WATER_TOWER)
	starter_power_count = power_plants.size()
	starter_water_count = water_towers.size()
	# Fill interior lots with mixed RCI + occupancy
	for y in range(hq.y - 7, hq.y + 8):
		for x in range(hq.x - 7, hq.x + 8):
			if not in_bounds(x, y):
				continue
			var i := idx(x, y)
			if road[i] == 1 or service[i] != TileTypes.Service.NONE:
				continue
			if terrain[i] == TileTypes.Terrain.WATER:
				continue
			var roll := rng.randf()
			if roll < 0.42:
				zone[i] = TileTypes.Zone.RESIDENTIAL
				occupancy[i] = rng.randf_range(0.35, 0.95)
			elif roll < 0.70:
				zone[i] = TileTypes.Zone.COMMERCIAL
				occupancy[i] = rng.randf_range(0.40, 0.98)
			elif roll < 0.88:
				zone[i] = TileTypes.Zone.INDUSTRIAL
				occupancy[i] = rng.randf_range(0.30, 0.85)
			_mark_chunk_active(x, y)
	_reveal_around(hq.x, hq.y, 14)
	recompute_services()
	for y in range(hq.y - 7, hq.y + 8):
		for x in range(hq.x - 7, hq.x + 8):
			if not in_bounds(x, y):
				continue
			var i := idx(x, y)
			if zone[i] != TileTypes.Zone.NONE:
				district[i] = TileTypes.District.DOWNTOWN
				seed_downtown_lots += 1


func _force_service(x: int, y: int, s: int) -> void:
	if not in_bounds(x, y):
		return
	var i := idx(x, y)
	if terrain[i] == TileTypes.Terrain.WATER:
		return
	service[i] = s
	road[i] = 0
	zone[i] = TileTypes.Zone.NONE
	occupancy[i] = 0.0
	match s:
		TileTypes.Service.POWER_PLANT:
			power_plants.append(Vector2i(x, y))
		TileTypes.Service.WATER_TOWER:
			water_towers.append(Vector2i(x, y))
	_mark_chunk_active(x, y)


func _reveal_around(cx: int, cy: int, radius: int) -> void:
	var r2 := radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not in_bounds(x, y):
				continue
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				revealed[idx(x, y)] = 1
	fog_changed.emit()


func _mark_chunk_active(x: int, y: int) -> void:
	chunk_at(x, y).active = true


func can_build_at(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var i := idx(x, y)
	return revealed[i] == 1 and terrain[i] != TileTypes.Terrain.WATER


func paint_road(x: int, y: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if road[i] == 1 or service[i] != TileTypes.Service.NONE:
		return false
	road[i] = 1
	zone[i] = TileTypes.Zone.NONE
	occupancy[i] = 0.0
	_reveal_around(x, y, GameConstants.FOG_REVEAL_RADIUS)
	_mark_chunk_active(x, y)
	recompute_services()
	map_changed.emit()
	return true


func paint_zone(x: int, y: int, z: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if road[i] == 1 or service[i] != TileTypes.Service.NONE:
		return false
	if zone[i] == z:
		return false
	zone[i] = z
	occupancy[i] = GameConstants.PAINT_ZONE_OCCUPANCY
	damaged_tile[i] = 0
	_mark_chunk_active(x, y)
	map_changed.emit()
	return true


func place_service(x: int, y: int, s: int) -> bool:
	if not can_build_at(x, y):
		return false
	var i := idx(x, y)
	if service[i] != TileTypes.Service.NONE:
		return false
	service[i] = s
	road[i] = 0
	zone[i] = TileTypes.Zone.NONE
	occupancy[i] = 0.0
	match s:
		TileTypes.Service.POWER_PLANT:
			power_plants.append(Vector2i(x, y))
		TileTypes.Service.WATER_TOWER:
			water_towers.append(Vector2i(x, y))
	_reveal_around(x, y, GameConstants.FOG_REVEAL_RADIUS)
	_mark_chunk_active(x, y)
	recompute_services()
	map_changed.emit()
	services_changed.emit()
	return true


func recompute_services() -> void:
	var n := size * size
	for i in n:
		powered[i] = 0
		watered[i] = 0
	_stamp_radius(power_plants, GameConstants.POWER_RADIUS, powered)
	_stamp_radius(water_towers, GameConstants.WATER_RADIUS, watered)
	_stamp_one(hq, GameConstants.HQ_SERVICE_RADIUS, powered)
	_stamp_one(hq, GameConstants.HQ_SERVICE_RADIUS, watered)
	services_changed.emit()


func _stamp_radius(points: Array[Vector2i], radius: int, field: PackedByteArray) -> void:
	var r2 := radius * radius
	for p in points:
		_stamp_one(p, radius, field, r2)


func _stamp_one(p: Vector2i, radius: int, field: PackedByteArray, r2: int = -1) -> void:
	if r2 < 0:
		r2 = radius * radius
	for y in range(p.y - radius, p.y + radius + 1):
		for x in range(p.x - radius, p.x + radius + 1):
			if not in_bounds(x, y):
				continue
			var dx := x - p.x
			var dy := y - p.y
			if dx * dx + dy * dy <= r2:
				field[idx(x, y)] = 1


func has_road_neighbor(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if in_bounds(nx, ny) and road[idx(nx, ny)] == 1:
			return true
	return false


func road_mask(x: int, y: int) -> int:
	## bit0 N, bit1 E, bit2 S, bit3 W
	var m := 0
	if in_bounds(x, y - 1) and road[idx(x, y - 1)] == 1:
		m |= 1
	if in_bounds(x + 1, y) and road[idx(x + 1, y)] == 1:
		m |= 2
	if in_bounds(x, y + 1) and road[idx(x, y + 1)] == 1:
		m |= 4
	if in_bounds(x - 1, y) and road[idx(x - 1, y)] == 1:
		m |= 8
	return m


func damage_chunk(cx: int, cy: int) -> void:
	if cx < 0 or cy < 0 or cx >= chunks_side or cy >= chunks_side:
		return
	var c: ChunkData = chunks[cy * chunks_side + cx]
	c.damaged = true
	c.damage_timer = GameConstants.DISASTER_DURATION_TICKS
	var x0 := cx * chunk_size
	var y0 := cy * chunk_size
	for y in range(y0, y0 + chunk_size):
		for x in range(x0, x0 + chunk_size):
			var i := idx(x, y)
			if zone[i] != TileTypes.Zone.NONE:
				damaged_tile[i] = 1
				occupancy[i] *= 0.15
	map_changed.emit()


func clear_chunk_damage(c: ChunkData) -> void:
	c.damaged = false
	c.damage_timer = 0
	var x0 := c.cx * chunk_size
	var y0 := c.cy * chunk_size
	for y in range(y0, y0 + chunk_size):
		for x in range(x0, x0 + chunk_size):
			damaged_tile[idx(x, y)] = 0
	map_changed.emit()



func _seed_district_lots() -> void:
	## Stamp park / waterfront / midrise lots so smoke + sim see district counts
	## without requiring CityView. CityView overlays the same ranges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	seed_park_lots = 0
	seed_waterfront_lots = 0
	seed_midrise_lots = 0
	# Park block west of HQ (CityView._seed_park).
	for y in range(hq.y + 1, hq.y + 8):
		for x in range(hq.x - 10, hq.x - 5):
			if not in_bounds(x, y):
				continue
			var i := idx(x, y)
			if terrain[i] == TileTypes.Terrain.WATER:
				continue
			if service[i] != TileTypes.Service.NONE:
				continue
			terrain[i] = TileTypes.Terrain.GRASS
			if y != hq.y:
				road[i] = 0
			zone[i] = TileTypes.Zone.NONE
			occupancy[i] = 0.0
			district[i] = TileTypes.District.PARK
			revealed[i] = 1
			_mark_chunk_active(x, y)
			seed_park_lots += 1
	# Waterfront inlet east of HQ (CityView._seed_waterfront).
	for y in range(hq.y + 1, hq.y + 8):
		for x in range(hq.x + 6, hq.x + 11):
			if not in_bounds(x, y):
				continue
			var i := idx(x, y)
			if service[i] != TileTypes.Service.NONE:
				continue
			if district[i] == TileTypes.District.PARK:
				continue
			if x >= hq.x + 8:
				terrain[i] = TileTypes.Terrain.WATER
				road[i] = 0
				zone[i] = TileTypes.Zone.NONE
				occupancy[i] = 0.0
			district[i] = TileTypes.District.WATERFRONT
			revealed[i] = 1
			_mark_chunk_active(x, y)
			seed_waterfront_lots += 1
	# Midrise Kenney ring: cheb 6–11, R/C lots (CityView._seed_midrise_ring).
	for y in range(hq.y - 11, hq.y + 12):
		for x in range(hq.x - 11, hq.x + 12):
			if not in_bounds(x, y):
				continue
			var dx := absi(x - hq.x)
			var dy := absi(y - hq.y)
			var cheb := dx if dx > dy else dy
			if cheb <= 5 or cheb > 11:
				continue
			var i := idx(x, y)
			if terrain[i] == TileTypes.Terrain.WATER:
				continue
			if road[i] == 1 or service[i] != TileTypes.Service.NONE:
				continue
			if district[i] == TileTypes.District.PARK or district[i] == TileTypes.District.WATERFRONT:
				continue
			if zone[i] != TileTypes.Zone.RESIDENTIAL and zone[i] != TileTypes.Zone.COMMERCIAL:
				if zone[i] == TileTypes.Zone.NONE and (x + y) % 2 == 0:
					zone[i] = TileTypes.Zone.RESIDENTIAL if (x + y) % 4 == 0 else TileTypes.Zone.COMMERCIAL
					occupancy[i] = rng.randf_range(0.40, 0.56)
					revealed[i] = 1
					_mark_chunk_active(x, y)
				else:
					continue
			district[i] = TileTypes.District.MIDRISE
			seed_midrise_lots += 1
	if seed_downtown_lots < 20:
		seed_downtown_lots = 0
		for y in range(hq.y - 7, hq.y + 8):
			for x in range(hq.x - 7, hq.x + 8):
				if not in_bounds(x, y):
					continue
				if zone[idx(x, y)] != TileTypes.Zone.NONE:
					seed_downtown_lots += 1


func occupancy_percent() -> float:
	var n := 0
	var s := 0.0
	for c in chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		n += chunk.res_tiles + chunk.com_tiles + chunk.ind_tiles
		s += chunk.res_occ * float(chunk.res_tiles)
		s += chunk.com_occ * float(chunk.com_tiles)
		s += chunk.ind_occ * float(chunk.ind_tiles)
	if n <= 0:
		return 0.0
	return (s / float(n)) * 100.0
