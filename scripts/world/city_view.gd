class_name CityView
extends Node3D
## 3D city: terrain mesh + Kenney GLB roads/buildings. Occupancy swaps meshes.
const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BuildingCatalog = preload("res://scripts/world/building_catalog.gd")


var map: MapData
var catalog: BuildingCatalog
var cursor_lot: Vector2i = Vector2i.ZERO
var cursor_brush: int = 1
var cursor_tint: Color = Color(1.0, 0.92, 0.18, 0.72)
var park_count: int = 0
var waterfront_count: int = 0
var card_count: int = 0
var _park_lots: Dictionary = {}
var _wf_water: Dictionary = {}
var _wf_shore: Dictionary = {}
var park_root: Node3D
var waterfront_root: Node3D

@onready var terrain_mi: MeshInstance3D = $Terrain
@onready var water_mi: MeshInstance3D = $Water
var dirt_mi: MeshInstance3D
var road_bed_mi: MeshInstance3D
@onready var roads_root: Node3D = $Roads
@onready var buildings_root: Node3D = $Buildings
@onready var services_root: Node3D = $Services
@onready var lots_root: Node3D = $Lots
@onready var props_root: Node3D = $Props
@onready var cursor_mi: MeshInstance3D = $Cursor

var _building_nodes: Dictionary = {}  # int idx -> Node3D
var _lot_nodes: Dictionary = {}
var _road_nodes: Dictionary = {}
var _service_nodes: Dictionary = {}
var _dirty_full: bool = true
var _dirty_occ: bool = true
var grass_tex: Texture2D
var dirt_tex: Texture2D
var asphalt_tex: Texture2D
var _paint_flash_t: float = 0.0
var _paint_flash_ok: bool = true
var _paint_flash_lot: Vector2i = Vector2i.ZERO
var _flash_mi: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _cursor_rim: Node3D
var _fx_mi: MeshInstance3D
var _fx_mat: StandardMaterial3D
var _war_t: float = 0.0
var _disaster_t: float = 0.0


func setup(p_map: MapData, p_catalog: BuildingCatalog, _env: WorldEnvironment = null) -> void:
	map = p_map
	catalog = p_catalog
	grass_tex = load("res://assets/env/grass_diff.jpg")
	dirt_tex = load("res://assets/env/dirt_diff.jpg")
	asphalt_tex = load("res://assets/env/asphalt_diff.jpg")
	_densify_downtown()
	_seed_park()
	_seed_waterfront()
	_seed_midrise_ring()
	_build_terrain()
	_build_cursor()
	_ensure_event_fx()
	map.map_changed.connect(_on_map_changed)
	map.fog_changed.connect(_on_map_changed)
	rebuild_all()



func _densify_downtown() -> void:
	## World-layer seed overlay: more occupied lots + taller core. Does not edit systems/*.
	if map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 424201
	var hq: Vector2i = map.hq
	for y in range(hq.y - 12, hq.y + 13):
		for x in range(hq.x - 12, hq.x + 13):
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if map.terrain[i] == TileTypes.Terrain.WATER:
				continue
			if (x - hq.x) % 3 == 0 or (y - hq.y) % 3 == 0:
				if map.service[i] == TileTypes.Service.NONE:
					map.road[i] = 1
					map.zone[i] = TileTypes.Zone.NONE
			map.revealed[i] = 1
			map.chunk_at(x, y).active = true
	for y in range(hq.y - 11, hq.y + 12):
		for x in range(hq.x - 11, hq.x + 12):
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if map.terrain[i] == TileTypes.Terrain.WATER:
				continue
			if map.road[i] == 1 or map.service[i] != TileTypes.Service.NONE:
				continue
			var dx := absi(x - hq.x)
			var dy := absi(y - hq.y)
			var cheb := dx if dx > dy else dy
			if cheb <= 5:
				# Core is a Kenney tower cluster (skyline), even if it was houses.
				map.zone[i] = TileTypes.Zone.COMMERCIAL
				map.occupancy[i] = rng.randf_range(0.86, 0.99)
			elif map.zone[i] == TileTypes.Zone.NONE:
				if cheb <= 7:
					var roll := rng.randf()
					if roll < 0.48:
						map.zone[i] = TileTypes.Zone.COMMERCIAL
						map.occupancy[i] = rng.randf_range(0.62, 0.97)
					elif roll < 0.82:
						map.zone[i] = TileTypes.Zone.RESIDENTIAL
						map.occupancy[i] = rng.randf_range(0.55, 0.95)
					else:
						map.zone[i] = TileTypes.Zone.INDUSTRIAL
						map.occupancy[i] = rng.randf_range(0.50, 0.90)
				else:
					var roll2 := rng.randf()
					if roll2 < 0.58:
						map.zone[i] = TileTypes.Zone.RESIDENTIAL
						map.occupancy[i] = rng.randf_range(0.45, 0.92)
					elif roll2 < 0.82:
						map.zone[i] = TileTypes.Zone.COMMERCIAL
						map.occupancy[i] = rng.randf_range(0.50, 0.90)
					else:
						map.zone[i] = TileTypes.Zone.INDUSTRIAL
						map.occupancy[i] = rng.randf_range(0.40, 0.85)
			else:
				# Boost already-zoned lots so more hit mid/high Kenney tiers.
				if map.occupancy[i] < 0.50:
					map.occupancy[i] = rng.randf_range(0.55, 0.90)
	if map.has_method("recompute_services"):
		map.recompute_services()
	if map.has_method("_reveal_around"):
		map._reveal_around(hq.x, hq.y, 16)




func _on_map_changed() -> void:
	_dirty_full = true
	_dirty_occ = true


func notify_occupancy() -> void:
	_dirty_occ = true


func _process(dt: float) -> void:
	if map == null:
		return
	if _dirty_full:
		_dirty_full = false
		_build_terrain()
		_rebuild_roads()
		_rebuild_services()
		_rebuild_lots_and_buildings()
		_dirty_occ = false
	elif _dirty_occ:
		_dirty_occ = false
		_rebuild_lots_and_buildings()
	_update_cursor()
	_tick_event_fx(dt)


func rebuild_all() -> void:
	_dirty_full = true
	_dirty_occ = true
	_scatter_trees()
	_scatter_park()
	_scatter_waterfront()


func _ensure_ground_mesh(node_name: String) -> MeshInstance3D:
	var existing := get_node_or_null(node_name) as MeshInstance3D
	if existing:
		return existing
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _make_ground_mat(tex: Texture2D, n: int, albedo: Color = Color(1.0, 1.0, 1.0, 1.0)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = albedo
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(float(n) * 0.35, float(n) * 0.35, 1.0)
	return mat


func _build_terrain() -> void:
	## Three committed meshes (grass / dirt / asphalt road bed) — not per-lot instances.
	var s := GameConstants.LOT_METERS
	var n: int = map.size
	dirt_mi = _ensure_ground_mesh("Dirt")
	road_bed_mi = _ensure_ground_mesh("RoadBed")

	var grass_st := SurfaceTool.new()
	grass_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt_st := SurfaceTool.new()
	dirt_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grass_col := Color(0.18, 0.42, 0.16)
	var dirt_col := Color(0.78, 0.38, 0.10)
	var asphalt_col := Color(0.16, 0.16, 0.18)

	for y in n:
		for x in n:
			var i := map.idx(x, y)
			var t: int = map.terrain[i]
			if t == TileTypes.Terrain.WATER:
				continue
			var revealed: bool = map.revealed[i] == 1
			var x0 := float(x) * s
			var z0 := float(y) * s
			var x1 := x0 + s
			var z1 := z0 + s
			var is_road_bed := revealed and map.road[i] == 1 and map.service[i] == TileTypes.Service.NONE
			if is_road_bed:
				_quad(road_st, Vector3(x0, 0.03, z0), Vector3(x1, 0.03, z0), Vector3(x1, 0.03, z1), Vector3(x0, 0.03, z1), asphalt_col)
			elif t == TileTypes.Terrain.DIRT:
				var col := dirt_col
				if not revealed:
					col = col.darkened(0.72)
					col.s *= 0.70
				_quad(dirt_st, Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1), col)
			else:
				var col := grass_col
				if not revealed:
					col = col.darkened(0.72)
					col.s *= 0.70
				_quad(grass_st, Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1), col)

	terrain_mi.mesh = grass_st.commit()
	terrain_mi.material_override = _make_ground_mat(grass_tex, n)
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	dirt_mi.mesh = dirt_st.commit()
	dirt_mi.material_override = _make_ground_mat(dirt_tex, n, Color(1.0, 0.40, 0.08))
	dirt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	road_bed_mi.mesh = road_st.commit()
	# Dark charcoal bed — no albedo lift; Kenney roads sit on asphalt not sidewalk.
	road_bed_mi.material_override = _make_ground_mat(asphalt_tex, n, Color(0.28, 0.28, 0.32))
	road_bed_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Water as a slightly lower plane covering water lots + a world-surrounding rim
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wcol := Color(0.07, 0.24, 0.46)
	for y in n:
		for x in n:
			if map.terrain[map.idx(x, y)] != TileTypes.Terrain.WATER:
				continue
			var x0 := float(x) * s
			var z0 := float(y) * s
			_quad(wst, Vector3(x0, -0.6, z0), Vector3(x0 + s, -0.6, z0), Vector3(x0 + s, -0.6, z0 + s), Vector3(x0, -0.6, z0 + s), wcol)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.07, 0.24, 0.46)
	wmat.roughness = 0.22
	wmat.metallic = 0.18
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color.a = 0.94
	water_mi.mesh = wst.commit()
	water_mi.material_override = wmat
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var nrm := Vector3.UP
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(a.x, a.z) * 0.05); st.add_vertex(a)
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(b.x, b.z) * 0.05); st.add_vertex(b)
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(c.x, c.z) * 0.05); st.add_vertex(c)
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(a.x, a.z) * 0.05); st.add_vertex(a)
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(c.x, c.z) * 0.05); st.add_vertex(c)
	st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(d.x, d.z) * 0.05); st.add_vertex(d)


func _make_cursor_mat(col: Color, emission_mul: float = 2.4) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b)
	mat.emission_energy_multiplier = emission_mul
	mat.no_depth_test = true
	mat.render_priority = 16
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_cursor() -> void:
	## Obvious tinted lot quad under the paint cursor (no_depth so towers cannot hide it).
	var s := GameConstants.LOT_METERS
	var plane := PlaneMesh.new()
	plane.size = Vector2(s * 0.98, s * 0.98)
	plane.orientation = PlaneMesh.FACE_Y
	_cursor_mat = _make_cursor_mat(cursor_tint)
	cursor_mi.mesh = plane
	cursor_mi.material_override = _cursor_mat
	cursor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor_mi.visible = true

	_cursor_rim = Node3D.new()
	_cursor_rim.name = "CursorRim"
	cursor_mi.add_child(_cursor_rim)
	var thick := 0.55
	var tall := 2.8
	var rim_mat := _make_cursor_mat(Color(1.0, 0.95, 0.35, 0.95), 3.0)
	for i in 4:
		var edge := MeshInstance3D.new()
		var box := BoxMesh.new()
		if i < 2:
			box.size = Vector3(s * 0.99, tall, thick)
		else:
			box.size = Vector3(thick, tall, s * 0.99)
		edge.mesh = box
		edge.material_override = rim_mat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var half := s * 0.49
		match i:
			0:
				edge.position = Vector3(0.0, tall * 0.5, -half)
			1:
				edge.position = Vector3(0.0, tall * 0.5, half)
			2:
				edge.position = Vector3(-half, tall * 0.5, 0.0)
			3:
				edge.position = Vector3(half, tall * 0.5, 0.0)
		_cursor_rim.add_child(edge)

	_flash_mi = MeshInstance3D.new()
	_flash_mi.name = "PaintFlash"
	var fplane := PlaneMesh.new()
	fplane.size = Vector2(s * 1.05, s * 1.05)
	fplane.orientation = PlaneMesh.FACE_Y
	_flash_mi.mesh = fplane
	var fmat := _make_cursor_mat(Color(1.0, 0.9, 0.2, 0.0), 2.6)
	_flash_mi.material_override = fmat
	_flash_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mi.visible = false
	add_child(_flash_mi)


func flash_paint(lot: Vector2i, ok: bool) -> void:
	_paint_flash_t = 0.45
	_paint_flash_ok = ok
	_paint_flash_lot = lot
	if _flash_mi:
		_flash_mi.visible = true


func _update_cursor() -> void:
	if cursor_mi == null:
		return
	if map == null or not map.in_bounds(cursor_lot.x, cursor_lot.y):
		cursor_mi.visible = false
		return
	cursor_mi.visible = true
	var p := map.lot_to_world(cursor_lot.x, cursor_lot.y)
	cursor_mi.global_position = Vector3(p.x, 0.22, p.z)
	var sc := float(maxi(1, cursor_brush))
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008)
	cursor_mi.scale = Vector3(sc * pulse, 1.0, sc * pulse)
	if _cursor_mat:
		var a := 0.42 + 0.28 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009))
		var col := cursor_tint
		col.a = a
		_cursor_mat.albedo_color = col
		_cursor_mat.emission = Color(col.r, col.g, col.b)
	if _flash_mi:
		if _paint_flash_t > 0.0:
			_paint_flash_t = maxf(0.0, _paint_flash_t - get_process_delta_time())
			var fp := map.lot_to_world(_paint_flash_lot.x, _paint_flash_lot.y)
			_flash_mi.global_position = Vector3(fp.x, 0.28, fp.z)
			_flash_mi.scale = Vector3(sc * 1.08, 1.0, sc * 1.08)
			var fm := _flash_mi.material_override as StandardMaterial3D
			if fm:
				var fa := clampf(_paint_flash_t / 0.45, 0.0, 1.0) * 0.7
				if _paint_flash_ok:
					fm.albedo_color = Color(1.0, 0.92, 0.2, fa)
					fm.emission = Color(1.0, 0.85, 0.15)
				else:
					fm.albedo_color = Color(1.0, 0.2, 0.12, fa)
					fm.emission = Color(1.0, 0.15, 0.08)
			_flash_mi.visible = _paint_flash_t > 0.0
		else:
			_flash_mi.visible = false


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _downtown_cheb(x: int, y: int) -> int:
	var hq: Vector2i = map.hq
	var dx := absi(x - hq.x)
	var dy := absi(y - hq.y)
	return dx if dx > dy else dy


func _is_overlay_lot(i: int) -> bool:
	return _park_lots.has(i) or _wf_water.has(i) or _wf_shore.has(i)


func _rebuild_roads() -> void:
	_clear_children(roads_root)
	_road_nodes.clear()
	if catalog == null or not catalog.has_meshes():
		return
	for y in map.size:
		for x in map.size:
			var i := map.idx(x, y)
			if map.road[i] != 1 or map.revealed[i] != 1:
				continue
			if map.service[i] != TileTypes.Service.NONE:
				continue
			var node := catalog.instantiate_road(map.road_mask(x, y), _downtown_cheb(x, y) <= 8)
			if node == null:
				continue
			var pos := map.lot_to_world(x, y)
			pos.y += 0.06
			node.position = pos
			roads_root.add_child(node)
			_road_nodes[i] = node


func _rebuild_services() -> void:
	_clear_children(services_root)
	_service_nodes.clear()
	if catalog == null or not catalog.has_meshes():
		return
	for y in map.size:
		for x in map.size:
			var i := map.idx(x, y)
			var s: int = map.service[i]
			if s == TileTypes.Service.NONE or map.revealed[i] != 1:
				continue
			var node: Node3D
			match s:
				TileTypes.Service.HQ:
					node = catalog.instantiate_hq()
				TileTypes.Service.POWER_PLANT:
					node = catalog.instantiate_power()
				TileTypes.Service.WATER_TOWER:
					node = catalog.instantiate_water()
				_:
					continue
			if node == null:
				continue
			node.position = map.lot_to_world(x, y)
			services_root.add_child(node)
			_service_nodes[i] = node


var _lot_mesh: PlaneMesh
var _building_key: Dictionary = {}  # idx -> "z:tier:dmg"


func _occ_tier(occ: float, damaged: bool) -> int:
	if damaged or occ < 0.08:
		return 0
	if occ < 0.32:
		return 1
	if occ < 0.58:
		return 2
	return 3


func _downtown_core_com(x: int, y: int, z: int) -> bool:
	## cheb to HQ <= 5: replace Kenney COM_HIGH with MegaKit. Same lots, no densify.
	if z != TileTypes.Zone.COMMERCIAL or map == null:
		return false
	var hq: Vector2i = map.hq
	var dx := absi(x - hq.x)
	var dy := absi(y - hq.y)
	var cheb := dx if dx > dy else dy
	return cheb <= 5


func _mark_large_pad(pad_skip: Dictionary, x: int, y: int) -> bool:
	## Reserve the +X neighbor so a 20.64 m Large does not stack a second mesh.
	if map == null or not map.in_bounds(x + 1, y):
		return false
	var ni := map.idx(x + 1, y)
	if map.revealed[ni] != 1:
		return false
	if map.zone[ni] != TileTypes.Zone.COMMERCIAL:
		return false
	if map.road[ni] == 1 or map.service[ni] != TileTypes.Service.NONE:
		return false
	pad_skip[ni] = true
	return true


func _rebuild_lots_and_buildings() -> void:
	if _lot_mesh == null:
		_lot_mesh = PlaneMesh.new()
		_lot_mesh.size = Vector2(GameConstants.LOT_METERS * 0.92, GameConstants.LOT_METERS * 0.92)
		_lot_mesh.orientation = PlaneMesh.FACE_Y

	card_count = 0
	var keep: Dictionary = {}
	var pad_skip: Dictionary = {}  # 2-lot Large pad — neighbor gets decal, no second building
	for c in map.chunks:
		var chunk: ChunkData = c
		if not chunk.active:
			continue
		var x0 := chunk.cx * map.chunk_size
		var y0 := chunk.cy * map.chunk_size
		for y in range(y0, y0 + map.chunk_size):
			for x in range(x0, x0 + map.chunk_size):
				var i := map.idx(x, y)
				if map.revealed[i] != 1:
					continue
				if _is_overlay_lot(i):
					continue
				var z: int = map.zone[i]
				if z == TileTypes.Zone.NONE:
					continue
				keep[i] = true
				var occ: float = map.occupancy[i]
				var damaged: bool = map.damaged_tile[i] == 1 or chunk.damaged
				_ensure_lot_decal(x, y, z, occ, damaged)
				var downtown_com := _downtown_core_com(x, y, z)
				var tier := _occ_tier(occ, damaged)
				if downtown_com:
					if damaged or occ < 0.08:
						tier = 0
					elif occ >= 0.85:
						tier = 4 if (x & 1) == 0 else 3
					elif occ >= 0.58:
						tier = 3
					else:
						tier = 1
				var key := "%s%d:%d:%d" % ["dt" if downtown_com else "", z, tier, 1 if damaged else 0]
				if pad_skip.has(i):
					_building_key[i] = key
					if _building_nodes.has(i) and is_instance_valid(_building_nodes[i]):
						(_building_nodes[i] as Node).queue_free()
						_building_nodes.erase(i)
					continue
				if _building_key.get(i, "") == key:
					if downtown_com and occ >= 0.85 and (x & 1) == 0:
						_mark_large_pad(pad_skip, x, y)
					continue
				_building_key[i] = key
				if _building_nodes.has(i) and is_instance_valid(_building_nodes[i]):
					(_building_nodes[i] as Node).queue_free()
					_building_nodes.erase(i)
				if tier <= 0:
					continue
				if catalog == null or not catalog.has_meshes():
					continue
				var b: Node3D
				if downtown_com:
					b = catalog.pick_downtown_building(occ, i)
				else:
					b = catalog.pick_zone_building(z, occ, i)
				if b:
					var pos := map.lot_to_world(x, y)
					if downtown_com and b.has_meta("downtown_lots") and int(b.get_meta("downtown_lots")) >= 2:
						if _mark_large_pad(pad_skip, x, y):
							pos.x += GameConstants.LOT_METERS * 0.5
					b.position = pos
					if not downtown_com and z != TileTypes.Zone.INDUSTRIAL and occ >= 0.32 and occ < 0.62 and card_count < 40:
						if catalog.midrise_cards and catalog.midrise_cards.attach(b, i):
							card_count += 1
					buildings_root.add_child(b)
					_building_nodes[i] = b

	# Drop visuals for lots that are no longer zoned
	var drop: Array = []
	for i in _building_nodes.keys():
		if not keep.has(i):
			drop.append(i)
	for i in drop:
		if is_instance_valid(_building_nodes[i]):
			(_building_nodes[i] as Node).queue_free()
		_building_nodes.erase(i)
		_building_key.erase(i)
	drop.clear()
	for i in _lot_nodes.keys():
		if not keep.has(i):
			drop.append(i)
	for i in drop:
		if is_instance_valid(_lot_nodes[i]):
			(_lot_nodes[i] as Node).queue_free()
		_lot_nodes.erase(i)


func _ensure_lot_decal(x: int, y: int, z: int, occ: float, damaged: bool) -> void:
	var i := map.idx(x, y)
	var col := TileTypes.zone_color(z, occ, damaged)
	if _lot_nodes.has(i) and is_instance_valid(_lot_nodes[i]):
		var mi: MeshInstance3D = _lot_nodes[i]
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = col
		return
	var mi2 := MeshInstance3D.new()
	mi2.mesh = _lot_mesh
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = col
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi2.material_override = mat2
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := map.lot_to_world(x, y)
	mi2.position = Vector3(p.x, 0.08, p.z)
	lots_root.add_child(mi2)
	_lot_nodes[i] = mi2


func _scatter_trees() -> void:
	# wipe previous trees only (named)
	for c in props_root.get_children():
		if str(c.name).begins_with("tree") or str(c.name).begins_with("lamp"):
			c.queue_free()
	if catalog == null or not catalog.has_meshes():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90909
	var placed := 0
	for y in map.size:
		for x in map.size:
			if placed > 380:
				return
			var i := map.idx(x, y)
			if map.revealed[i] != 1:
				continue
			if map.road[i] == 1 or map.zone[i] != TileTypes.Zone.NONE or map.service[i] != TileTypes.Service.NONE:
				continue
			if _is_overlay_lot(i):
				continue
			if map.terrain[i] != TileTypes.Terrain.GRASS:
				continue
			if rng.randf() > 0.12:
				continue
			var t := catalog.instantiate_tree(rng.randf() > 0.45)
			if t == null:
				continue
			t.name = "tree_%d" % i
			t.position = map.lot_to_world(x, y)
			t.rotate_y(rng.randf() * TAU)
			props_root.add_child(t)
			placed += 1
	# lamps along starter roads near HQ
	var lamps := 0
	for y in range(map.hq.y - 12, map.hq.y + 13):
		for x in range(map.hq.x - 12, map.hq.x + 13):
			if lamps > 48:
				return
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if map.road[i] != 1:
				continue
			if (x + y) % 4 != 0:
				continue
			var lamp := catalog.instantiate_lamp()
			if lamp == null:
				continue
			lamp.name = "lamp_%d" % i
			lamp.position = map.lot_to_world(x, y) + Vector3(4.5, 0, 0)
			props_root.add_child(lamp)
			lamps += 1


func pulse_war() -> void:
	_ensure_event_fx()
	_war_t = 2.4


func pulse_disaster() -> void:
	_ensure_event_fx()
	_disaster_t = 2.0
	notify_occupancy()


func _ensure_event_fx() -> void:
	## One full-map wash plane — not a mesh per lot.
	if _fx_mi != null and is_instance_valid(_fx_mi):
		return
	var world := 2048.0
	if map:
		world = float(map.size) * GameConstants.LOT_METERS
	_fx_mi = MeshInstance3D.new()
	_fx_mi.name = "EventWash"
	var plane := PlaneMesh.new()
	plane.size = Vector2(world, world)
	plane.orientation = PlaneMesh.FACE_Y
	_fx_mi.mesh = plane
	_fx_mat = StandardMaterial3D.new()
	_fx_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fx_mat.no_depth_test = true
	_fx_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fx_mat.render_priority = 18
	_fx_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.0)
	_fx_mi.material_override = _fx_mat
	_fx_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_mi.position = Vector3(world * 0.5, 0.4, world * 0.5)
	_fx_mi.visible = false
	add_child(_fx_mi)


func _tick_event_fx(dt: float) -> void:
	if _war_t > 0.0:
		_war_t = maxf(0.0, _war_t - dt)
	if _disaster_t > 0.0:
		_disaster_t = maxf(0.0, _disaster_t - dt)
	if _fx_mat == null or _fx_mi == null:
		return
	var war_a := 0.0
	if _war_t > 0.0:
		war_a = (_war_t / 2.4) * 0.24
	var dis_a := 0.0
	if _disaster_t > 0.0:
		var flicker := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.017)
		dis_a = (_disaster_t / 2.0) * 0.22 * flicker
	var col := Color(0.0, 0.0, 0.0, 0.0)
	if war_a >= dis_a and war_a > 0.002:
		col = Color(0.82, 0.07, 0.10, war_a)
	elif dis_a > 0.002:
		col = Color(1.0, 0.62, 0.10, dis_a)
	_fx_mat.albedo_color = col
	_fx_mi.visible = col.a > 0.002


func _cheb_hq(x: int, y: int) -> int:
	var hq: Vector2i = map.hq
	var dx := absi(x - hq.x)
	var dy := absi(y - hq.y)
	return dx if dx > dy else dy


func _has_water_neighbor(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if map.in_bounds(nx, ny) and map.terrain[map.idx(nx, ny)] == TileTypes.Terrain.WATER:
			return true
	return false


func _water_face_yaw(x: int, y: int) -> float:
	## Yaw so +Z local aims at the first water neighbor (pier into water).
	if map.in_bounds(x + 1, y) and map.terrain[map.idx(x + 1, y)] == TileTypes.Terrain.WATER:
		return -PI * 0.5
	if map.in_bounds(x - 1, y) and map.terrain[map.idx(x - 1, y)] == TileTypes.Terrain.WATER:
		return PI * 0.5
	if map.in_bounds(x, y + 1) and map.terrain[map.idx(x, y + 1)] == TileTypes.Terrain.WATER:
		return 0.0
	if map.in_bounds(x, y - 1) and map.terrain[map.idx(x, y - 1)] == TileTypes.Terrain.WATER:
		return PI
	return 0.0


func _clear_lot_for_overlay(x: int, y: int, keep_road: bool) -> int:
	var i := map.idx(x, y)
	if map.service[i] != TileTypes.Service.NONE:
		return -1
	map.zone[i] = TileTypes.Zone.NONE
	map.occupancy[i] = 0.0
	if keep_road and map.road[i] == 1:
		pass
	else:
		map.road[i] = 0
	map.revealed[i] = 1
	map.chunk_at(x, y).active = true
	return i


func _seed_park() -> void:
	## Punch a park block west of HQ, visible from the south-looking 190m camera.
	if map == null:
		return
	_park_lots.clear()
	var hq: Vector2i = map.hq
	var kept_path_y := hq.y
	for y in range(hq.y + 1, hq.y + 8):
		for x in range(hq.x - 10, hq.x - 5):
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if map.terrain[i] == TileTypes.Terrain.WATER:
				continue
			if map.service[i] != TileTypes.Service.NONE:
				continue
			map.terrain[i] = TileTypes.Terrain.GRASS
			var keep_road := (y == kept_path_y and map.road[i] == 1)
			if _clear_lot_for_overlay(x, y, keep_road) >= 0:
				_park_lots[i] = Vector2i(x, y)
	if map.has_method("_reveal_around"):
		map._reveal_around(hq.x - 8, hq.y + 2, 8)
	print("[CityView] seed park lots=", _park_lots.size())


func _seed_waterfront() -> void:
	## Dress existing downtown water + a small east inlet. World-layer only.
	if map == null:
		return
	_wf_water.clear()
	_wf_shore.clear()
	var hq: Vector2i = map.hq
	# Small inlet east of HQ so the south camera sees pier/palms on the right.
	for y in range(hq.y + 1, hq.y + 8):
		for x in range(hq.x + 6, hq.x + 11):
			if not map.in_bounds(x, y):
				continue
			if _cheb_hq(x, y) <= 5:
				continue
			var i := map.idx(x, y)
			if map.service[i] != TileTypes.Service.NONE:
				continue
			if _park_lots.has(i):
				continue
			if x >= hq.x + 8:
				map.terrain[i] = TileTypes.Terrain.WATER
				map.road[i] = 0
				map.zone[i] = TileTypes.Zone.NONE
				map.occupancy[i] = 0.0
				map.revealed[i] = 1
				map.chunk_at(x, y).active = true
				_wf_water[i] = Vector2i(x, y)
			else:
				if map.terrain[i] == TileTypes.Terrain.WATER:
					_wf_water[i] = Vector2i(x, y)
				else:
					var keep_road := (y == hq.y + 3)
					if _clear_lot_for_overlay(x, y, keep_road) >= 0:
						if not keep_road:
							map.terrain[i] = TileTypes.Terrain.DIRT
						_wf_shore[i] = Vector2i(x, y)
	# Tag existing revealed water near HQ (already in the boot frame).
	for y in range(hq.y - 6, hq.y + 14):
		for x in range(hq.x - 4, hq.x + 14):
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if map.terrain[i] != TileTypes.Terrain.WATER:
				continue
			map.revealed[i] = 1
			map.chunk_at(x, y).active = true
			_wf_water[i] = Vector2i(x, y)
	# Shore: land adjacent to tagged water, outside Quaternius core.
	for y in range(hq.y - 6, hq.y + 14):
		for x in range(hq.x - 4, hq.x + 14):
			if not map.in_bounds(x, y):
				continue
			var i := map.idx(x, y)
			if _wf_water.has(i) or _park_lots.has(i):
				continue
			if map.terrain[i] == TileTypes.Terrain.WATER:
				continue
			if map.service[i] != TileTypes.Service.NONE:
				continue
			if _cheb_hq(x, y) <= 5:
				continue
			if not _has_water_neighbor(x, y):
				continue
			var keep_road := (y == hq.y and x > hq.x)
			if _clear_lot_for_overlay(x, y, keep_road) >= 0:
				_wf_shore[i] = Vector2i(x, y)
	if map.has_method("_reveal_around"):
		map._reveal_around(hq.x + 8, hq.y + 4, 10)
	print("[CityView] seed waterfront water=", _wf_water.size(), " shore=", _wf_shore.size())


func _seed_midrise_ring() -> void:
	## Pull some Kenney ring lots to mid occupancy so window cards attach.
	if map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	var hq: Vector2i = map.hq
	var n := 0
	for y in range(hq.y - 11, hq.y + 12):
		for x in range(hq.x - 11, hq.x + 12):
			if not map.in_bounds(x, y):
				continue
			var cheb := _cheb_hq(x, y)
			if cheb <= 5 or cheb > 11:
				continue
			var i := map.idx(x, y)
			if _is_overlay_lot(i):
				continue
			if map.terrain[i] == TileTypes.Terrain.WATER:
				continue
			if map.road[i] == 1 or map.service[i] != TileTypes.Service.NONE:
				continue
			var z: int = map.zone[i]
			if z != TileTypes.Zone.RESIDENTIAL and z != TileTypes.Zone.COMMERCIAL:
				continue
			if (x + y) % 2 != 0:
				continue
			if map.occupancy[i] >= 0.58:
				map.occupancy[i] = rng.randf_range(0.38, 0.56)
				n += 1
	print("[CityView] seed midrise-ring mid-occ=", n)


func _ensure_overlay_roots() -> void:
	if park_root == null or not is_instance_valid(park_root):
		park_root = get_node_or_null("Park") as Node3D
		if park_root == null:
			park_root = Node3D.new()
			park_root.name = "Park"
			add_child(park_root)
	if waterfront_root == null or not is_instance_valid(waterfront_root):
		waterfront_root = get_node_or_null("Waterfront") as Node3D
		if waterfront_root == null:
			waterfront_root = Node3D.new()
			waterfront_root.name = "Waterfront"
			add_child(waterfront_root)


func _scatter_park() -> void:
	_ensure_overlay_roots()
	_clear_children(park_root)
	park_count = 0
	if catalog == null or catalog.park == null or not catalog.park.ready:
		print("[CityView] park scatter skipped ready=", catalog != null and catalog.park != null and catalog.park.ready)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 70707
	var lots: Array = _park_lots.values()
	if lots.is_empty():
		return
	# Statue near the block center.
	var mid: Vector2i = lots[lots.size() / 2]
	var statue = catalog.park.pick_statue(0)
	if statue:
		statue.position = map.lot_to_world(mid.x, mid.y)
		park_root.add_child(statue)
		park_count += 1
	for lot in lots:
		if park_count >= 80:
			break
		var x: int = lot.x
		var y: int = lot.y
		var i := map.idx(x, y)
		var base := map.lot_to_world(x, y)
		if map.road[i] != 1:
			var path = catalog.park.pick_path(i)
			if path:
				path.position = base
				path.rotate_y(float((i * 3) % 4) * PI * 0.5)
				park_root.add_child(path)
				park_count += 1
		var trees_here := 1 + (i % 2)
		for t in trees_here:
			if park_count >= 80:
				break
			var tree = catalog.park.pick_tree(i + t)
			if tree == null:
				continue
			tree.position = base + Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-5.0, 5.0))
			tree.rotate_y(rng.randf() * TAU)
			park_root.add_child(tree)
			park_count += 1
		if (x + y) % 3 == 0 and park_count < 80:
			var bench = catalog.park.pick_bench(i)
			if bench:
				bench.position = base + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
				bench.rotate_y(rng.randf() * TAU)
				park_root.add_child(bench)
				park_count += 1
		if (x + y) % 4 == 1 and park_count < 80:
			var fl = catalog.park.pick_flower(i)
			if fl:
				fl.position = base + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
				park_root.add_child(fl)
				park_count += 1
	print("[CityView] park instances=", park_count)


func _scatter_waterfront() -> void:
	_ensure_overlay_roots()
	_clear_children(waterfront_root)
	waterfront_count = 0
	if catalog == null or catalog.waterfront == null or not catalog.waterfront.ready:
		print("[CityView] waterfront scatter skipped")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 19191
	var crane_placed := false
	for lot in _wf_shore.values():
		if waterfront_count >= 40:
			break
		var x: int = lot.x
		var y: int = lot.y
		var i := map.idx(x, y)
		var base := map.lot_to_world(x, y)
		var yaw := _water_face_yaw(x, y)
		if _has_water_neighbor(x, y) and (x + y) % 2 == 0:
			var pier = catalog.waterfront.instantiate_pier()
			if pier:
				var step := Vector3(0.0, 0.05, 6.0).rotated(Vector3.UP, yaw)
				pier.position = base + step
				pier.rotate_y(yaw)
				waterfront_root.add_child(pier)
				waterfront_count += 1
		if waterfront_count < 40:
			var palm = catalog.waterfront.pick_palm(i)
			if palm:
				palm.position = base + Vector3(rng.randf_range(-3.5, 3.5), 0.0, rng.randf_range(-3.5, 3.5))
				palm.rotate_y(rng.randf() * TAU)
				waterfront_root.add_child(palm)
				waterfront_count += 1
		if (i % 3) == 0 and waterfront_count < 40:
			var prop = catalog.waterfront.pick_prop(i)
			if prop:
				prop.position = base + Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
				prop.rotate_y(rng.randf() * TAU)
				waterfront_root.add_child(prop)
				waterfront_count += 1
		if not crane_placed and catalog.waterfront.crane_ok and waterfront_count < 40:
			var crane = catalog.waterfront.instantiate_crane()
			if crane:
				crane.position = base
				waterfront_root.add_child(crane)
				waterfront_count += 1
				crane_placed = true
	for lot in _wf_water.values():
		if waterfront_count >= 40:
			break
		var x2: int = lot.x
		var y2: int = lot.y
		var j := map.idx(x2, y2)
		if y2 >= map.hq.y + 2 and (x2 + y2) % 3 == 0 and waterfront_count < 40:
			var pier2 = catalog.waterfront.instantiate_pier()
			if pier2:
				var wp2 := map.lot_to_world(x2, y2)
				pier2.position = Vector3(wp2.x, 0.05, wp2.z)
				pier2.rotate_y(PI * 0.5)
				waterfront_root.add_child(pier2)
				waterfront_count += 1
		if (x2 + y2) % 2 != 0:
			continue
		var lily = catalog.waterfront.pick_lily(j)
		if lily == null:
			continue
		var wp := map.lot_to_world(x2, y2)
		lily.position = Vector3(wp.x + rng.randf_range(-4.0, 4.0), -0.35, wp.z + rng.randf_range(-4.0, 4.0))
		lily.rotate_y(rng.randf() * TAU)
		waterfront_root.add_child(lily)
		waterfront_count += 1
	print("[CityView] waterfront instances=", waterfront_count)
