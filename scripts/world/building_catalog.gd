class_name BuildingCatalog
extends RefCounted
## Loads Kenney City Kit GLBs (real meshes) and MegaKit downtown prebuilts.
## Occupancy tiers swap house → midrise → skyscraper / factory.
## Downtown core COM uses MegaKit at DISTRICT_DOWNTOWN_SCALE 1.0 (not 14.5).

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const MidriseKitGD = preload("res://scripts/world/midrise_kit.gd")
const ParkKitGD = preload("res://scripts/world/park_kit.gd")
const WaterfrontKitGD = preload("res://scripts/world/waterfront_kit.gd")
const MidriseCardsGD = preload("res://scripts/world/midrise_cards.gd")
const RailKitGD = preload("res://scripts/world/rail_kit.gd")
const NightMarketKitGD = preload("res://scripts/world/night_market_kit.gd")

const SUB := "res://assets/city/kenney_suburban/"
const COM := "res://assets/city/kenney_commercial/"
const IND := "res://assets/city/kenney_industrial/"
const ROAD := "res://assets/city/kenney_roads/"

var _scenes: Dictionary = {}  # path -> PackedScene
var downtown: DowntownKit
var midrise
var park
var waterfront
var rail
var market
var midrise_cards
var loaded_count: int = 0
var _window_card_tex: Dictionary = {}  # path -> Texture2D, shared
var failed: PackedStringArray = []
var _emissive_cache: Dictionary = {}  # path -> Array of StandardMaterial3D (walk order)
var _albedo_cache: Dictionary = {}  # path -> Array of StandardMaterial3D (walk order)

## Path-cached roughness/metal (never uniqued per lot).
const RES_ROUGHNESS: float = 0.88
const RES_METALLIC: float = 0.0
const IND_ROUGHNESS: float = 0.70
const IND_METALLIC: float = 0.10
const COM_ROUGHNESS: float = 0.45
const COM_METALLIC: float = 0.16

const RES_LOW: Array[String] = [
	SUB + "building-type-a.glb",
	SUB + "building-type-c.glb",
	SUB + "building-type-g.glb",
	SUB + "building-type-h.glb",
	SUB + "building-type-j.glb",
]
const RES_MID: Array[String] = [
	SUB + "building-type-b.glb",
	SUB + "building-type-d.glb",
	SUB + "building-type-e.glb",
	SUB + "building-type-f.glb",
	SUB + "building-type-i.glb",
	SUB + "building-type-k.glb",
	SUB + "building-type-l.glb",
]
const RES_HIGH: Array[String] = [
	SUB + "building-type-m.glb",
	SUB + "building-type-n.glb",
	SUB + "building-type-o.glb",
	SUB + "building-type-p.glb",
	SUB + "building-type-q.glb",
	SUB + "building-type-r.glb",
	SUB + "building-type-s.glb",
	SUB + "building-type-t.glb",
	SUB + "building-type-u.glb",
	COM + "low-detail-building-a.glb",
	COM + "low-detail-building-wide-a.glb",
	COM + "building-k.glb",
	COM + "building-l.glb",
	COM + "building-skyscraper-a.glb",
]

const COM_LOW: Array[String] = [
	COM + "building-a.glb",
	COM + "building-b.glb",
	COM + "low-detail-building-c.glb",
	COM + "low-detail-building-d.glb",
]
const COM_MID: Array[String] = [
	COM + "building-c.glb",
	COM + "building-d.glb",
	COM + "building-e.glb",
	COM + "building-f.glb",
	COM + "building-g.glb",
	COM + "building-h.glb",
	COM + "building-i.glb",
	COM + "building-j.glb",
	COM + "building-k.glb",
	COM + "building-skyscraper-a.glb",
	COM + "building-skyscraper-e.glb",
]
const COM_HIGH: Array[String] = [
	COM + "building-skyscraper-a.glb",
	COM + "building-skyscraper-b.glb",
	COM + "building-skyscraper-c.glb",
	COM + "building-skyscraper-d.glb",
	COM + "building-skyscraper-e.glb",
	COM + "building-m.glb",
	COM + "building-n.glb",
]

const IND_LOW: Array[String] = [
	IND + "building-a.glb",
	IND + "building-b.glb",
	IND + "building-c.glb",
	IND + "detail-tank.glb",
]
const IND_MID: Array[String] = [
	IND + "building-d.glb",
	IND + "building-e.glb",
	IND + "building-f.glb",
	IND + "building-g.glb",
	IND + "building-h.glb",
	IND + "building-i.glb",
]
const IND_HIGH: Array[String] = [
	IND + "building-j.glb",
	IND + "building-k.glb",
	IND + "building-l.glb",
	IND + "building-m.glb",
	IND + "building-n.glb",
	IND + "building-o.glb",
	IND + "building-p.glb",
	IND + "building-q.glb",
	IND + "building-r.glb",
	IND + "building-s.glb",
	IND + "building-t.glb",
]

const HQ_PATH: String = COM + "building-skyscraper-d.glb"
const POWER_PATH: String = IND + "building-s.glb"
const POWER_CHIMNEY: String = IND + "chimney-large.glb"
const WATER_PATH: String = IND + "detail-tank.glb"
const TREE_LARGE: String = SUB + "tree-large.glb"
const TREE_SMALL: String = SUB + "tree-small.glb"

const ROAD_STRAIGHT: String = ROAD + "road-straight.glb"
const ROAD_CROSS: String = ROAD + "road-crossroad.glb"
const ROAD_T: String = ROAD + "road-intersection.glb"
const ROAD_BEND: String = ROAD + "road-bend.glb"
const ROAD_END: String = ROAD + "road-end.glb"
const ROAD_SQUARE: String = ROAD + "road-square.glb"
const LAMP: String = ROAD + "light-curved.glb"

const DOWNTOWN := "res://assets/city/district_downtown/buildings/"
const DOWNTOWN_LARGE: String = DOWNTOWN + "Building_Large_2.gltf"
const DOWNTOWN_MEDIUM: String = DOWNTOWN + "Building_Medium_2_001.gltf"
const DOWNTOWN_SMALL: String = DOWNTOWN + "Building_Small_1.gltf"
const DOWNTOWN_LIT: String = "res://assets/city/district_downtown/textures/T_lit_interior_1.png"
const DOWNTOWN_LIT_2: String = "res://assets/city/district_downtown/textures/T_lit_interior_2.png"
const INTERIORS_DROPIN := "res://assets/city/interiors_dropin/"
## Tonemapped JPGs + T_lit only. Skip 2K HDRIs (hitch) and do not spawn rooms.
const WINDOW_CARD_PATHS: Array[String] = [
	DOWNTOWN_LIT,
	DOWNTOWN_LIT_2,
	INTERIORS_DROPIN + "window_cards/hotel_room_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/anniversary_lounge_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/fireplace_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/photo_studio_01_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/studio_small_03_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/apartment_kiara_interior/kiara_interior_tonemapped.jpg",
	INTERIORS_DROPIN + "window_cards/shop_comfy_cafe/comfy_cafe_tonemapped.jpg",
]

var _downtown_lit_tex: Texture2D = null


func load_all() -> void:
	var paths: Array[String] = []
	for arr in [RES_LOW, RES_MID, RES_HIGH, COM_LOW, COM_MID, COM_HIGH, IND_LOW, IND_MID, IND_HIGH]:
		for p in arr:
			if p not in paths:
				paths.append(p)
	for p in [HQ_PATH, POWER_PATH, POWER_CHIMNEY, WATER_PATH, TREE_LARGE, TREE_SMALL,
			ROAD_STRAIGHT, ROAD_CROSS, ROAD_T, ROAD_BEND, ROAD_END, ROAD_SQUARE, LAMP]:
		if p not in paths:
			paths.append(p)
	for p in paths:
		_load(p)
	downtown = DowntownKit.new()
	downtown.load_kit()
	midrise = MidriseKitGD.new()
	midrise.load_kit()
	park = ParkKitGD.new()
	park.load_kit()
	midrise_cards = MidriseCardsGD.new()
	midrise_cards.load_kit()
	rail = RailKitGD.new()
	rail.load_kit()
	market = NightMarketKitGD.new()
	market.load_kit()
	waterfront = WaterfrontKitGD.new()
	if waterfront:
		waterfront.load_kit()


func _load(path: String) -> void:
	if _scenes.has(path):
		return
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is PackedScene:
			_scenes[path] = res
			loaded_count += 1
			return
	# MegaKit glTF may not have editor .import sidecars — pack at runtime (no recook).
	if path.ends_with(".gltf") or path.ends_with(".glb"):
		var packed := _pack_gltf_runtime(path)
		if packed:
			_scenes[path] = packed
			loaded_count += 1
			return
	if not FileAccess.file_exists(path):
		failed.append(path)
		return
	failed.append(path)


func _pack_gltf_runtime(path: String) -> PackedScene:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path) and not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		err = doc.append_from_file(abs_path, state)
	if err != OK:
		return null
	var node := doc.generate_scene(state)
	if node == null:
		return null
	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		return null
	return packed


func has_meshes() -> bool:
	return loaded_count >= 8


func instantiate_path(path: String, scale: float = GameConstants.BUILDING_SCALE) -> Node3D:
	var packed: PackedScene = _scenes.get(path, null)
	if packed == null:
		_load(path)
		packed = _scenes.get(path, null)
	if packed == null:
		return null
	var n: Node = packed.instantiate()
	var wrap := Node3D.new()
	wrap.name = path.get_file().get_basename()
	if n is Node3D:
		(n as Node3D).scale = Vector3.ONE
		wrap.add_child(n)
	else:
		wrap.add_child(n)
	wrap.scale = Vector3(scale, scale, scale)
	return wrap


func pick_downtown_building(occupancy: float, lot_index: int) -> Node3D:
	## Quaternius downtown via shared DowntownKit PackedScenes (look-measured scale).
	if downtown == null or not downtown.ready:
		return null
	var n := downtown.pick_building(occupancy, lot_index)
	if n:
		var key := "downtown_small"
		if occupancy >= 0.85 and ((lot_index % 128) & 1) == 0:
			key = "downtown_large"
		elif occupancy >= 0.58:
			key = "downtown_medium"
		_apply_downtown_window_glow(n, key)
	return n


func pick_midrise_building(occupancy: float, lot_index: int) -> Node3D:
	## Fail soft — midrise pack has no exterior buildings this pass.
	if midrise == null or not midrise.ready:
		return null
	return midrise.pick_building(occupancy, lot_index)


func pick_park_piece(lot_index: int) -> Node3D:
	if park == null or not park.ready:
		return null
	return park.pick_piece(lot_index)


func pick_waterfront_piece(lot_index: int, on_water: bool = false) -> Node3D:
	if waterfront == null or not waterfront.ready:
		return null
	return waterfront.pick_piece(lot_index, on_water)


func pick_rail_piece(kind: String, index: int) -> Node3D:
	## Mesh-callable. Fail soft if the rail pack did not cache.
	if rail == null or not rail.ready:
		return null
	return rail.pick_piece(kind, index)


func pick_market_prop(index: int) -> Node3D:
	## Mesh-callable curated stall/prop. Fail soft. Not a lot building.
	if market == null or not market.ready:
		return null
	return market.pick_prop(index)


func pick_window_card_texture(index: int) -> Texture2D:
	## Shared interiors_dropin / T_lit cards for 190m window glow. Not rooms.
	var live: Array[String] = []
	for p in WINDOW_CARD_PATHS:
		if _window_card_exists(p):
			live.append(p)
	if live.is_empty():
		return null
	return _load_window_card(live[posmod(index, live.size())])


func pick_zone_building(z: int, occupancy: float, lot_index: int) -> Node3D:
	var tier: Array[String]
	if occupancy < 0.08:
		return null
	elif occupancy < 0.32:
		tier = _low(z)
	elif occupancy < 0.58:
		tier = _mid(z)
	else:
		tier = _high(z)
	if tier.is_empty():
		return null
	var path: String = tier[lot_index % tier.size()]
	var n := instantiate_path(path, GameConstants.BUILDING_SCALE)
	if n:
		n.rotate_y(float((lot_index * 17) % 4) * PI * 0.5)
		# Look pass: tower step vs houses at the 190 m camera. Does not change BUILDING_SCALE.
		if z == TileTypes.Zone.COMMERCIAL and occupancy >= 0.58:
			n.scale.y *= 1.12 + occupancy * 0.18
			# Albedo mul first so white Kenney walls have headroom, then window sheen.
			_apply_albedo_tint(n, path, Color(0.68, 0.70, 0.74), COM_ROUGHNESS, COM_METALLIC)
			_apply_window_emission(n, path)
		elif z == TileTypes.Zone.RESIDENTIAL:
			# Umber multiply kills mint roofs and greys Kenney sidewalk pads.
			_apply_albedo_tint(n, path, Color(0.42, 0.30, 0.22), RES_ROUGHNESS, RES_METALLIC)
		elif z == TileTypes.Zone.INDUSTRIAL:
			_apply_albedo_tint(n, path, Color(0.60, 0.55, 0.48), IND_ROUGHNESS, IND_METALLIC)
			if occupancy >= 0.58:
				n.scale.y *= 1.06
	return n


func instantiate_hq() -> Node3D:
	if downtown and downtown.ready:
		var dt := downtown.instantiate_hq()
		if dt:
			_apply_downtown_window_glow(dt, "downtown_hq")
			return dt
	var n := instantiate_path(HQ_PATH, GameConstants.BUILDING_SCALE * 1.15)
	if n:
		_apply_albedo_tint(n, HQ_PATH, Color(0.68, 0.70, 0.74), COM_ROUGHNESS, COM_METALLIC)
		_apply_window_emission(n, HQ_PATH)
	return n


func instantiate_power() -> Node3D:
	var root := instantiate_path(POWER_PATH, GameConstants.BUILDING_SCALE)
	if root == null:
		return null
	var chim := instantiate_path(POWER_CHIMNEY, GameConstants.BUILDING_SCALE * 0.55)
	if chim:
		chim.position = Vector3(3.5, 0.0, 3.5)
		root.add_child(chim)
	return root


func instantiate_water() -> Node3D:
	var n := instantiate_path(WATER_PATH, GameConstants.BUILDING_SCALE * 1.35)
	if n:
		n.scale.y *= 1.6
	return n


func instantiate_road(mask: int, use_downtown: bool = false) -> Node3D:
	## mask: bit0 N, bit1 E, bit2 S, bit3 W. Returns yaw in radians via meta.
	if use_downtown and downtown:
		var dt := downtown.instantiate_street(mask)
		if dt:
			return dt
	var bits := 0
	if mask & 1:
		bits += 1
	if mask & 2:
		bits += 1
	if mask & 4:
		bits += 1
	if mask & 8:
		bits += 1
	var path := ROAD_SQUARE
	var yaw := 0.0
	match bits:
		0:
			path = ROAD_SQUARE
		1:
			path = ROAD_END
			if mask & 1:
				yaw = 0.0
			elif mask & 2:
				yaw = -PI * 0.5
			elif mask & 4:
				yaw = PI
			else:
				yaw = PI * 0.5
		2:
			if (mask & 5) == 5:
				path = ROAD_STRAIGHT
				yaw = 0.0
			elif (mask & 10) == 10:
				path = ROAD_STRAIGHT
				yaw = PI * 0.5
			else:
				path = ROAD_BEND
				if mask == (1 | 2):
					yaw = 0.0
				elif mask == (2 | 4):
					yaw = -PI * 0.5
				elif mask == (4 | 8):
					yaw = PI
				else:
					yaw = PI * 0.5
		3:
			path = ROAD_T
			if (mask & 1) == 0:
				yaw = PI
			elif (mask & 2) == 0:
				yaw = PI * 0.5
			elif (mask & 4) == 0:
				yaw = 0.0
			else:
				yaw = -PI * 0.5
		_:
			path = ROAD_CROSS
	var n := instantiate_path(path, GameConstants.ROAD_SCALE)
	if n:
		n.rotate_y(yaw)
	return n


func instantiate_tree(large: bool) -> Node3D:
	return instantiate_path(TREE_LARGE if large else TREE_SMALL, GameConstants.PROP_SCALE)


func instantiate_lamp() -> Node3D:
	return instantiate_path(LAMP, GameConstants.PROP_SCALE)


func _downtown_lit_texture() -> Texture2D:
	if _downtown_lit_tex != null:
		return _downtown_lit_tex
	# T_lit first, then interiors_dropin tonemapped JPGs. Shared, not per-lot.
	_downtown_lit_tex = pick_window_card_texture(0)
	return _downtown_lit_tex


func _window_card_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	return FileAccess.file_exists(abs_path) or FileAccess.file_exists(path)


func _load_window_card(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _window_card_tex.has(path):
		return _window_card_tex[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	if tex == null:
		var abs_path := path
		if path.begins_with("res://"):
			abs_path = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.new()
			if img.load(abs_path) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex:
		_window_card_tex[path] = tex
	return tex


func _mat_name_is_window_lit(src: Material) -> bool:
	if src == null:
		return false
	var nm := src.resource_name
	if nm.is_empty():
		nm = str(src.resource_path.get_file())
	var low := nm.to_lower()
	return low.contains("window") or low.contains("interior") or low.contains("lit")


func _downtown_glow_or_null(src: Material) -> Variant:
	## Cool COM-like sheen on Window / Interior / Lit only — not whole-building albedo emission.
	if src == null or not (src is StandardMaterial3D):
		return null
	if not _mat_name_is_window_lit(src):
		return null
	var dupe := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	dupe.emission_enabled = true
	dupe.emission = Color(0.45, 0.62, 0.95)
	dupe.emission_energy_multiplier = 0.35
	var tex := _downtown_lit_texture()
	if tex:
		dupe.emission_texture = tex
	return dupe


func _apply_downtown_window_glow(root: Node3D, path: String) -> void:
	## Path-cached surface mats (shared _emissive_cache). Not uniqued per lot.
	if root == null:
		return
	if not _emissive_cache.has(path):
		_emissive_cache[path] = _build_downtown_glow_mats(root)
	var idx := [0]
	_walk_assign_downtown_glow(root, _emissive_cache[path], idx)


func _build_downtown_glow_mats(n: Node) -> Array:
	var mats: Array = []
	_walk_dupe_downtown_glow(n, mats)
	return mats


func _walk_dupe_downtown_glow(n: Node, mats: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		var scount := mesh.get_surface_count() if mesh else 0
		if scount <= 0:
			var src: Material = mi.material_override
			if src == null:
				src = mi.get_active_material(0)
			mats.append(_downtown_glow_or_null(src))
		else:
			for s in scount:
				var src: Material = mi.get_surface_override_material(s)
				if src == null and mesh:
					src = mesh.surface_get_material(s)
				if src == null:
					src = mi.get_active_material(s)
				mats.append(_downtown_glow_or_null(src))
	for c in n.get_children():
		_walk_dupe_downtown_glow(c, mats)


func _walk_assign_downtown_glow(n: Node, mats: Array, idx: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		var scount := mesh.get_surface_count() if mesh else 0
		if scount <= 0:
			var i: int = idx[0]
			if i < mats.size() and mats[i] != null:
				mi.material_override = mats[i]
			idx[0] = i + 1
		else:
			for s in scount:
				var i: int = idx[0]
				if i < mats.size() and mats[i] != null:
					mi.set_surface_override_material(s, mats[i])
				idx[0] = i + 1
	for c in n.get_children():
		_walk_assign_downtown_glow(c, mats, idx)


func _apply_albedo_tint(root: Node3D, path: String, mul: Color, roughness: float = RES_ROUGHNESS, metallic: float = RES_METALLIC) -> void:
	## Path-cached albedo multiply (houses warmer/darker, industry sooty). Not uniqued per instance.
	if root == null:
		return
	if not _albedo_cache.has(path):
		_albedo_cache[path] = _build_albedo_mats(root, mul, roughness, metallic)
	var idx := [0]
	_walk_assign_emissive(root, _albedo_cache[path], idx)


func _build_albedo_mats(n: Node, mul: Color, roughness: float, metallic: float) -> Array:
	var mats: Array = []
	_walk_dupe_albedo(n, mats, mul, roughness, metallic)
	return mats


func _walk_dupe_albedo(n: Node, mats: Array, mul: Color, roughness: float, metallic: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var src: Material = mi.material_override
		if src == null:
			src = mi.get_active_material(0)
		if src is StandardMaterial3D:
			var dupe := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			dupe.albedo_color = dupe.albedo_color * mul
			dupe.roughness = roughness
			dupe.metallic = metallic
			mats.append(dupe)
		else:
			mats.append(null)
	for c in n.get_children():
		_walk_dupe_albedo(c, mats, mul, roughness, metallic)


func _apply_window_emission(root: Node3D, path: String) -> void:
	## Small cool albedo emission so COM_HIGH / HQ silhouettes hold at 190 m.
	## Duplicated materials are cached by GLB path — not uniqued per instance.
	if root == null:
		return
	if not _emissive_cache.has(path):
		_emissive_cache[path] = _build_emissive_mats(root, path)
	var idx := [0]
	_walk_assign_emissive(root, _emissive_cache[path], idx)


func _build_emissive_mats(n: Node, path: String) -> Array:
	var mats: Array = []
	_walk_dupe_emissive(n, mats, path)
	return mats


func _walk_dupe_emissive(n: Node, mats: Array, path: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var src: Material = mi.material_override
		if src == null:
			src = mi.get_active_material(0)
		if src is StandardMaterial3D:
			var dupe := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			dupe.emission_enabled = true
			# Cool sheen only — do not bind albedo as emission_texture (clips sunlit whites).
			dupe.emission = Color(0.45, 0.62, 0.95)
			dupe.emission_energy_multiplier = 0.23
			dupe.emission_texture = null
			# Specular towers so COM/HQ still read when the left HUD card covers the horizon.
			dupe.roughness = COM_ROUGHNESS
			dupe.metallic = COM_METALLIC
			mats.append(dupe)
		else:
			mats.append(null)
	for c in n.get_children():
		_walk_dupe_emissive(c, mats, path)


func _walk_assign_emissive(n: Node, mats: Array, idx: Array) -> void:
	if n is MeshInstance3D:
		var i: int = idx[0]
		if i < mats.size() and mats[i] != null:
			(n as MeshInstance3D).material_override = mats[i]
		idx[0] = i + 1
	for c in n.get_children():
		_walk_assign_emissive(c, mats, idx)


func _low(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_LOW
		TileTypes.Zone.COMMERCIAL:
			return COM_LOW
		_:
			return IND_LOW


func _mid(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_MID
		TileTypes.Zone.COMMERCIAL:
			return COM_MID
		_:
			return IND_MID


func _high(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_HIGH
		TileTypes.Zone.COMMERCIAL:
			return COM_HIGH
		_:
			return IND_HIGH
