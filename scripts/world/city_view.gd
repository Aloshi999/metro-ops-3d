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

@onready var terrain_mi: MeshInstance3D = $Terrain
@onready var water_mi: MeshInstance3D = $Water
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


func setup(p_map: MapData, p_catalog: BuildingCatalog, _env: WorldEnvironment = null) -> void:
	map = p_map
	catalog = p_catalog
	grass_tex = load("res://assets/env/grass_diff.jpg")
	dirt_tex = load("res://assets/env/dirt_diff.jpg")
	asphalt_tex = load("res://assets/env/asphalt_diff.jpg")
	_densify_downtown()
	_build_terrain()
	_build_cursor()
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


func _process(_dt: float) -> void:
	if map == null:
		return
	if _dirty_full:
		_dirty_full = false
		_rebuild_roads()
		_rebuild_services()
		_rebuild_lots_and_buildings()
		_dirty_occ = false
	elif _dirty_occ:
		_dirty_occ = false
		_rebuild_lots_and_buildings()
	_update_cursor()


func rebuild_all() -> void:
	_dirty_full = true
	_dirty_occ = true
	_scatter_trees()


func _build_terrain() -> void:
	var s := GameConstants.LOT_METERS
	var n: int = map.size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_texture = grass_tex
	grass_mat.vertex_color_use_as_albedo = true
	grass_mat.roughness = 0.92
	grass_mat.metallic = 0.0
	grass_mat.uv1_scale = Vector3(float(n) * 0.35, float(n) * 0.35, 1.0)

	for y in n:
		for x in n:
			var i := map.idx(x, y)
			var t: int = map.terrain[i]
			if t == TileTypes.Terrain.WATER:
				continue
			var revealed: bool = map.revealed[i] == 1
			var col := TileTypes.terrain_color(t, revealed)
			var x0 := float(x) * s
			var z0 := float(y) * s
			var x1 := x0 + s
			var z1 := z0 + s
			var yb := 0.0
			_quad(st, Vector3(x0, yb, z0), Vector3(x1, yb, z0), Vector3(x1, yb, z1), Vector3(x0, yb, z1), col)

	terrain_mi.mesh = st.commit()
	terrain_mi.material_override = grass_mat
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Water as a slightly lower plane covering water lots + a world-surrounding rim
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wcol := Color(0.12, 0.42, 0.72)
	for y in n:
		for x in n:
			if map.terrain[map.idx(x, y)] != TileTypes.Terrain.WATER:
				continue
			var x0 := float(x) * s
			var z0 := float(y) * s
			_quad(wst, Vector3(x0, -0.6, z0), Vector3(x0 + s, -0.6, z0), Vector3(x0 + s, -0.6, z0 + s), Vector3(x0, -0.6, z0 + s), wcol)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.15, 0.42, 0.72)
	wmat.roughness = 0.18
	wmat.metallic = 0.15
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color.a = 0.92
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


func _build_cursor() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(GameConstants.LOT_METERS * 0.96, 0.55, GameConstants.LOT_METERS * 0.96)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.18, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 1.4
	cursor_mi.mesh = box
	cursor_mi.material_override = mat
	cursor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor_mi.visible = true
	_flash_mi = MeshInstance3D.new()
	_flash_mi.name = "PaintFlash"
	var fbox := BoxMesh.new()
	fbox.size = Vector3(GameConstants.LOT_METERS * 0.98, 1.2, GameConstants.LOT_METERS * 0.98)
	_flash_mi.mesh = fbox
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.9, 0.2, 0.0)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.85, 0.2)
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
	if not map.in_bounds(cursor_lot.x, cursor_lot.y):
		cursor_mi.visible = false
		return
	cursor_mi.visible = true
	var p := map.lot_to_world(cursor_lot.x, cursor_lot.y)
	cursor_mi.global_position = Vector3(p.x, 0.35, p.z)
	var sc := float(maxi(1, cursor_brush))
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	cursor_mi.scale = Vector3(sc * pulse, 1.15, sc * pulse)
	var cmat := cursor_mi.material_override as StandardMaterial3D
	if cmat:
		cmat.albedo_color = Color(1.0, 0.92, 0.18, 0.72)
	if _flash_mi:
		if _paint_flash_t > 0.0:
			_paint_flash_t = maxf(0.0, _paint_flash_t - get_process_delta_time())
			var fp := map.lot_to_world(_paint_flash_lot.x, _paint_flash_lot.y)
			_flash_mi.global_position = Vector3(fp.x, 0.7, fp.z)
			_flash_mi.scale = Vector3(sc, 1.0, sc)
			var fm := _flash_mi.material_override as StandardMaterial3D
			if fm:
				var a := clampf(_paint_flash_t / 0.45, 0.0, 1.0) * 0.55
				if _paint_flash_ok:
					fm.albedo_color = Color(1.0, 0.92, 0.2, a)
					fm.emission = Color(1.0, 0.85, 0.15)
				else:
					fm.albedo_color = Color(1.0, 0.2, 0.12, a)
					fm.emission = Color(1.0, 0.15, 0.08)
			_flash_mi.visible = _paint_flash_t > 0.0
		else:
			_flash_mi.visible = false


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


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
			var node := catalog.instantiate_road(map.road_mask(x, y))
			if node == null:
				continue
			node.position = map.lot_to_world(x, y)
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


func _rebuild_lots_and_buildings() -> void:
	if _lot_mesh == null:
		_lot_mesh = PlaneMesh.new()
		_lot_mesh.size = Vector2(GameConstants.LOT_METERS * 0.92, GameConstants.LOT_METERS * 0.92)
		_lot_mesh.orientation = PlaneMesh.FACE_Y

	var keep: Dictionary = {}
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
				var z: int = map.zone[i]
				if z == TileTypes.Zone.NONE:
					continue
				keep[i] = true
				var occ: float = map.occupancy[i]
				var damaged: bool = map.damaged_tile[i] == 1 or chunk.damaged
				_ensure_lot_decal(x, y, z, occ, damaged)
				var tier := _occ_tier(occ, damaged)
				var key := "%d:%d:%d" % [z, tier, 1 if damaged else 0]
				if _building_key.get(i, "") == key:
					continue
				_building_key[i] = key
				if _building_nodes.has(i) and is_instance_valid(_building_nodes[i]):
					(_building_nodes[i] as Node).queue_free()
					_building_nodes.erase(i)
				if tier <= 0:
					continue
				if catalog == null or not catalog.has_meshes():
					continue
				var b := catalog.pick_zone_building(z, occ, i)
				if b:
					b.position = map.lot_to_world(x, y)
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
	pass


func pulse_disaster() -> void:
	notify_occupancy()
