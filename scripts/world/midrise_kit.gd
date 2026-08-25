class_name MidriseKit
extends RefCounted
## Midrise district loader. Shared PackedScenes / shared materials.
## Honest: this pack has no exterior building glTF this pass (furniture + window cards only).
## ready stays false — do not stub fake towers from sofas.

const BASE := "res://assets/city/district_midrise/"
const MANIFEST_PATH := "res://assets/city/district_midrise/instance_manifest.json"
const BUILDINGS := "res://assets/city/district_midrise/buildings/"

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var skip_reason: String = "no exterior building glTF on disk"

var _scenes: Dictionary = {}


func load_kit() -> void:
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[MidriseKit] unique_per_lot is true; would instance shared anyway")
	# Only exterior building meshes count. Furniture / HDR window cards are not lot buildings.
	var found: PackedStringArray = []
	for p in [
		BUILDINGS + "Building_Small.gltf",
		BUILDINGS + "Building_Medium.gltf",
		BUILDINGS + "Building_Large.gltf",
		BUILDINGS + "building.glb",
	]:
		if ResourceLoader.exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			found.append(p)
			_cache(p)
	ready = found.size() >= 1 and _scenes.size() >= 1
	if not ready:
		skip_reason = "no exterior building glTF (PACK: furniture + window cards only)"
	print("[MidriseKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " skip=", skip_reason)


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


func pick_building(_occupancy: float, _lot_index: int) -> Node3D:
	## No usable exterior mesh — fail soft.
	return null
