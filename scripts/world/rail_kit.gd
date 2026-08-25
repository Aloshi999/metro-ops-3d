class_name RailKit
extends RefCounted
## Kenney Train Kit tracks + rolling stock. Shared PackedScenes / shared colormap.
## Never unique per lot. Scale 14.5. No station building this pass.

const GameConstants = preload("res://scripts/core/game_constants.gd")

const BASE := "res://assets/city/district_rail/"
const MODELS := BASE + "models/"
const MANIFEST_PATH := BASE + "instance_manifest.json"

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var skipped: PackedStringArray = []
var piece_scale: float = GameConstants.BUILDING_SCALE

var _scenes: Dictionary = {}
var _tracks: Array[String] = [
	MODELS + "railroad-straight.glb",
	MODELS + "railroad-curve.glb",
	MODELS + "railroad-corner-small.glb",
	MODELS + "railroad-corner-large.glb",
	MODELS + "railroad-rail-straight.glb",
	MODELS + "railroad-rail-curve.glb",
	MODELS + "railroad-straight-bend.glb",
	MODELS + "track.glb",
	MODELS + "track-detailed.glb",
	MODELS + "track-single.glb",
	MODELS + "spline-track.glb",
]
var _trains: Array[String] = [
	MODELS + "train-locomotive-a.glb",
	MODELS + "train-locomotive-passenger-a.glb",
	MODELS + "train-diesel-a.glb",
	MODELS + "train-electric-subway-a.glb",
	MODELS + "train-electric-city-a.glb",
	MODELS + "train-tram-modern.glb",
	MODELS + "train-carriage-box.glb",
	MODELS + "train-carriage-container-red.glb",
	MODELS + "train-carriage-flatbed.glb",
	MODELS + "train-carriage-tank.glb",
]


func load_kit() -> void:
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[RailKit] unique_per_lot is true; instancing anyway shared")
				var want: Dictionary = {}
				for p in _tracks:
					want[p] = true
				for p in _trains:
					want[p] = true
				var slots = data.get("slots", [])
				if typeof(slots) == TYPE_ARRAY:
					for slot in slots:
						if typeof(slot) != TYPE_DICTIONARY:
							continue
						var rel := str(slot.get("path", ""))
						if rel.is_empty():
							continue
						var full := BASE + rel
						if not want.has(full):
							skipped.append(full)
	for arr in [_tracks, _trains]:
		for p in arr:
			_cache(p)
	var track_ok := 0
	var train_ok := 0
	for p in _tracks:
		if _scenes.has(p):
			track_ok += 1
	for p in _trains:
		if _scenes.has(p):
			train_ok += 1
	ready = track_ok >= 1 and train_ok >= 1
	print("[RailKit] loaded=", loaded_count, " failed=", failed.size(), " skipped=", skipped.size(), " ready=", ready, " scale=", piece_scale, " tracks=", track_ok, " trains=", train_ok)


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


func pick_piece(kind: String, index: int) -> Node3D:
	if not ready:
		return null
	var k := kind.to_lower()
	var arr: Array[String] = []
	if k == "train" or k == "locomotive" or k == "carriage" or k == "tram":
		arr = _live(_trains)
	elif k == "track" or k == "rail" or k == "railroad":
		arr = _live(_tracks)
	else:
		arr = _live(_tracks)
		arr.append_array(_live(_trains))
	if arr.is_empty():
		return null
	var path: String = arr[posmod(index, arr.size())]
	var n := instantiate_shared(path, piece_scale)
	if n:
		n.rotate_y(float((index * 17) % 4) * PI * 0.5)
	return n


func _live(arr: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p in arr:
		if _scenes.has(p):
			out.append(p)
	return out
