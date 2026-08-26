class_name DowntownKit
extends RefCounted
## Instances Quaternius downtown GLTFs. Shared PackedScenes / shared materials.
## Never unique per lot. Never stamp Kenney 14.5. Scale is Look-measured from Large_2.

const BASE := "res://assets/city/district_downtown/buildings/"
const MANIFEST_PATH := "res://assets/city/district_downtown/instance_manifest.json"
const LOT_M: float = 16.0
## Measured AABB is already meters (1 unit = 1 m). Do NOT squash 20.64→16 (0.775).
## Large sits on a 2-lot / 32 m pad. Kenney HQ 14.5 spike stays the tall tower.

var ready: bool = false
var building_scale: float = 1.0
var street_scale: float = 1.0
var loaded_count: int = 0
var failed: PackedStringArray = []

var _scenes: Dictionary = {}
var _small: String = BASE + "Building_Small_1.gltf"
var _medium: String = BASE + "Building_Medium_2_001.gltf"
var _large: String = BASE + "Building_Large_2.gltf"
var _street_straight: String = BASE + "Street_2Lane.gltf"
var _street_t: String = BASE + "Street_TIntersection.gltf"
var _street_cross: String = BASE + "Street_4WayIntersection.gltf"
var _street_curve: String = BASE + "Street_Curve_2Lane.gltf"
var _street_end: String = BASE + "Street_2Lane_noSidewalk.gltf"
const PROPS := "res://assets/city/district_downtown/props/"
## Quaternius / MegaKit / PH street dressing. Scale 1.0. Parked/static only.
var _cars: Array[String] = [
	PROPS + "car_Cop.glb",
	PROPS + "car_NormalCar1.glb",
	PROPS + "car_NormalCar2.glb",
	PROPS + "car_SUV.glb",
	PROPS + "car_SportsCar.glb",
	PROPS + "car_SportsCar2.glb",
	PROPS + "car_Taxi.glb",
	PROPS + "transit_Taxi.glb",
	PROPS + "transit_Bus.glb",
	PROPS + "transit_Ambulance.glb",
	PROPS + "transit_SchoolBus.glb",
]
var _street_props: Array[String] = [
	PROPS + "Prop_Bollard.gltf",
	PROPS + "Prop_Planter_Single.gltf",
	PROPS + "Prop_ManholeCover.gltf",
	PROPS + "Prop_Drain.gltf",
	PROPS + "Prop_ACUnit.gltf",
	PROPS + "transit_TrafficCone.glb",
	PROPS + "transit_TrafficLight.glb",
	PROPS + "transit_TrafficSign1.glb",
	PROPS + "polyhaven_street_lamp_01/street_lamp_01_2k.gltf",
	PROPS + "polyhaven_painted_wooden_bench/painted_wooden_bench_2k.gltf",
	PROPS + "polyhaven/fire_hydrant/fire_hydrant_2k.gltf",
	PROPS + "polyhaven/concrete_road_barrier/concrete_road_barrier_2k.gltf",
]


func load_kit() -> void:
	# Manifest is the contract (unique_per_lot / shared_materials). Pieces live on disk
	# under buildings/ even when the JSON still lists Kenney prop slots.
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[DowntownKit] unique_per_lot is true; instancing anyway shared")
	for p in [_small, _medium, _large, _street_straight, _street_t, _street_cross, _street_curve, _street_end]:
		_cache(p)
	for p in _cars:
		_cache(p)
	for p in _street_props:
		_cache(p)
	ready = _scenes.has(_small) and _scenes.has(_medium) and _scenes.has(_large)
	print("[DowntownKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " bscale=", building_scale, " sscale=", street_scale)


func _cache(path: String) -> void:
	if path.is_empty() or _scenes.has(path):
		return
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is PackedScene:
			packed = res
	if packed == null:
		packed = _pack_gltf_runtime(path)
	if packed:
		_scenes[path] = packed
		loaded_count += 1
	else:
		failed.append(path)


func _pack_gltf_runtime(path: String) -> PackedScene:
	## Headless/OpenGL box often has no .gltf.import sidecar. Pack from disk.
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(abs_path, state, 0, abs_path.get_base_dir())
	if err != OK:
		return null
	var node := doc.generate_scene(state)
	if node == null:
		return null
	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		return null
	return packed


func instantiate_shared(path: String, scale: float) -> Node3D:
	## PackedScene.instantiate only — materials stay shared on the imported resource.
	var packed: PackedScene = _scenes.get(path, null)
	if packed == null:
		_cache(path)
		packed = _scenes.get(path, null)
	if packed == null:
		return null
	var n: Node = packed.instantiate()
	var wrap := Node3D.new()
	wrap.name = path.get_file().get_basename()
	wrap.add_child(n)
	wrap.scale = Vector3(scale, scale, scale)
	_strip_giant(wrap)
	return wrap


func _strip_giant(n: Node) -> void:
	## Hide imported backdrop / cubemap spheres that fill the boot frustum.
	if n is VisualInstance3D:
		var sz: Vector3 = (n as VisualInstance3D).get_aabb().size
		if maxf(sz.x, maxf(sz.y, sz.z)) > 64.0:
			(n as VisualInstance3D).visible = false
			print("[DowntownKit] hide giant ", n.name, " aabb=", sz)
	for c in n.get_children():
		_strip_giant(c)


func pick_building(occupancy: float, lot_index: int) -> Node3D:
	if not ready:
		return null
	var path := _small
	var lot_x: int = lot_index % 128
	if occupancy >= 0.85 and (lot_x & 1) == 0:
		path = _large
	elif occupancy >= 0.58:
		path = _medium
	var n := instantiate_shared(path, building_scale)
	if n:
		n.rotate_y(float((lot_index * 17) % 4) * PI * 0.5)
		if path == _large:
			n.set_meta("downtown_lots", 2)
		else:
			n.set_meta("downtown_lots", 1)
	return n


func instantiate_hq() -> Node3D:
	if _large.is_empty():
		return null
	return instantiate_shared(_large, building_scale * 1.08)


func instantiate_street(mask: int) -> Node3D:
	if loaded_count < 3:
		return null
	var bits := 0
	if mask & 1:
		bits += 1
	if mask & 2:
		bits += 1
	if mask & 4:
		bits += 1
	if mask & 8:
		bits += 1
	var path := _street_straight
	var yaw := 0.0
	match bits:
		0, 1:
			path = _street_end if _scenes.has(_street_end) else _street_straight
			if mask & 2:
				yaw = -PI * 0.5
			elif mask & 4:
				yaw = PI
			elif mask & 8:
				yaw = PI * 0.5
		2:
			if (mask & 5) == 5:
				path = _street_straight
				yaw = 0.0
			elif (mask & 10) == 10:
				path = _street_straight
				yaw = PI * 0.5
			else:
				path = _street_curve if _scenes.has(_street_curve) else _street_straight
				if mask == (1 | 2):
					yaw = 0.0
				elif mask == (2 | 4):
					yaw = -PI * 0.5
				elif mask == (4 | 8):
					yaw = PI
				else:
					yaw = PI * 0.5
		3:
			path = _street_t if _scenes.has(_street_t) else _street_straight
			if (mask & 1) == 0:
				yaw = PI
			elif (mask & 2) == 0:
				yaw = PI * 0.5
			elif (mask & 4) == 0:
				yaw = 0.0
			else:
				yaw = -PI * 0.5
		_:
			path = _street_cross if _scenes.has(_street_cross) else _street_straight
	if path.is_empty():
		return null
	var n := instantiate_shared(path, street_scale)
	if n:
		n.rotate_y(yaw)
	return n


func pick_car(index: int) -> Node3D:
	var live: Array[String] = []
	for p in _cars:
		if _scenes.has(p):
			live.append(p)
	if live.is_empty():
		return null
	return instantiate_shared(live[posmod(index, live.size())], building_scale)


func pick_street_prop(index: int) -> Node3D:
	var live: Array[String] = []
	for p in _street_props:
		if _scenes.has(p):
			live.append(p)
	if live.is_empty():
		return null
	return instantiate_shared(live[posmod(index, live.size())], building_scale)
