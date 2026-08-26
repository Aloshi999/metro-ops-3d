class_name MidriseKit
extends RefCounted
## Midrise district loader. Shared PackedScenes / shared materials.
## Instances all exteriors from instance_manifest buildings[] at scale 1.0 (1u=1m).
## Runtime GLTFDocument fallback — editor import of the whole district hangs.
## Do not stamp Kenney 14.5 on these exteriors. Furniture stays Kenney 14.5.

const BASE := "res://assets/city/district_midrise/"
const MANIFEST_PATH := "res://assets/city/district_midrise/instance_manifest.json"
const BUILDINGS := "res://assets/city/district_midrise/buildings/"

var ready: bool = false
var building_scale: float = 1.0
var loaded_count: int = 0
var failed: PackedStringArray = []
var skip_reason: String = ""
var lots2_count: int = 0

var _scenes: Dictionary = {}
var _lots: Dictionary = {}  # path -> lots
var _pool_low: Array[String] = []
var _pool_mid: Array[String] = []
var _pool_high: Array[String] = []


func load_kit() -> void:
	_scenes.clear()
	_lots.clear()
	_pool_low.clear()
	_pool_mid.clear()
	_pool_high.clear()
	loaded_count = 0
	failed.clear()
	lots2_count = 0
	var buildings: Array = []
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[MidriseKit] unique_per_lot is true; would instance shared anyway")
				if data.has("building_scale"):
					building_scale = float(data.get("building_scale", 1.0))
				elif data.has("scale"):
					building_scale = float(data.get("scale", 1.0))
				if data.has("buildings") and typeof(data["buildings"]) == TYPE_ARRAY:
					buildings = data["buildings"]
	for entry in buildings:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		if path.is_empty():
			continue
		var lots := int(entry.get("lots", 1))
		var bid := str(entry.get("id", path.get_file().get_basename()))
		_lots[path] = lots
		_cache(path)
		if not _scenes.has(path):
			continue
		if lots >= 2:
			lots2_count += 1
		_bucket(path, bid, lots)
	ready = _scenes.size() >= 1
	if not ready:
		skip_reason = "no exterior building glTF cached"
	print("[MidriseKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " scale=", building_scale, " lots2=", lots2_count)


func _bucket(path: String, bid: String, lots: int) -> void:
	## occ < 0.42 low · < 0.52 mid · else high (6Story / Large / lots=2 wides).
	if lots >= 2 or _is_high_id(bid):
		_pool_high.append(path)
	elif _is_low_id(bid):
		_pool_low.append(path)
	else:
		_pool_mid.append(path)


func _is_low_id(bid: String) -> bool:
	if bid.begins_with("2Story"):
		return true
	if bid.begins_with("Building_Small"):
		return true
	if bid == "Shop" or bid == "Flat" or bid == "Flat2":
		return true
	return false


func _is_high_id(bid: String) -> bool:
	if bid.begins_with("6Story"):
		return true
	if bid.contains("Large") or bid.contains("Big"):
		return true
	return false


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
	## PackedScene.instantiate only — materials stay shared. No material.duplicate.
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
	return wrap


func pick_building(occupancy: float, lot_index: int) -> Node3D:
	if not ready:
		return null
	var pool: Array[String] = _pool_low
	if occupancy < 0.42:
		pool = _pool_low
	elif occupancy < 0.52:
		pool = _pool_mid
	else:
		pool = _pool_high
	if pool.is_empty():
		if occupancy < 0.52:
			pool = _pool_mid if not _pool_mid.is_empty() else _pool_high
		else:
			pool = _pool_mid if not _pool_mid.is_empty() else _pool_low
	if pool.is_empty():
		return null
	var path: String = pool[posmod(lot_index, pool.size())]
	if not _scenes.has(path):
		return null
	var n := instantiate_shared(path, building_scale)
	if n:
		n.rotate_y(float(lot_index) * PI * 0.5)
		n.set_meta("midrise_lots", int(_lots.get(path, 1)))
	return n
