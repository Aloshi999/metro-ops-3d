class_name WorksKit
extends RefCounted
## Kenney Factory Kit hero cache. Shared PackedScenes / shared colormap.
## Never unique per lot. Scale 14.5. Curated subset only — skip arrows/details.

const GameConstants = preload("res://scripts/core/game_constants.gd")

const BASE := "res://assets/city/district_works/"
const KIT := "res://assets/city/kits/kenney_factory-kit/"
const MANIFEST_PATH := BASE + "instance_manifest.json"

## Factory buildings / hoppers (tanks) / machines / cranes / conveyors. Not arrows/buttons/cogs.
const HERO_IDS: Array[String] = [
	"structure-high",
	"structure-tall",
	"structure-medium",
	"structure-yellow-high",
	"structure-yellow-tall",
	"structure-yellow-medium",
	"hopper-high-round",
	"hopper-high-square",
	"hopper-round",
	"machine-fortified",
	"machine",
	"machine-window",
	"crane",
	"crane-lift",
	"conveyor-long",
	"conveyor-long-sides",
	"box-large",
	"scanner-high",
]

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var skipped: PackedStringArray = []
var piece_scale: float = GameConstants.BUILDING_SCALE

var _scenes: Dictionary = {}
var _heroes: Array[String] = []


func load_kit() -> void:
	_heroes.clear()
	var want: Dictionary = {}
	for id in HERO_IDS:
		want[id] = true
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[WorksKit] unique_per_lot is true; instancing anyway shared")
				var slots = data.get("meshes", data.get("slots", []))
				if typeof(slots) == TYPE_ARRAY:
					for slot in slots:
						if typeof(slot) != TYPE_DICTIONARY:
							continue
						var sid := str(slot.get("id", "")).get_file().get_basename()
						if sid.is_empty():
							var rel := str(slot.get("path", ""))
							sid = rel.get_file().get_basename()
						if sid.is_empty() or want.has(sid):
							continue
						skipped.append(sid)
	for id in HERO_IDS:
		var p := _cache_id(id)
		if not p.is_empty():
			_heroes.append(p)
	ready = _heroes.size() >= 4
	print("[WorksKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " scale=", piece_scale)


func _path_usable(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	return FileAccess.file_exists(abs_path) or FileAccess.file_exists(path)


func _resolve(id: String) -> String:
	var kit_path := KIT + id + ".glb"
	if _path_usable(kit_path):
		return kit_path
	return kit_path


func _cache_id(id: String) -> String:
	var primary := _resolve(id)
	_cache(primary)
	if _scenes.has(primary):
		return primary
	return ""


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


func pick_piece(index: int) -> Node3D:
	if not ready:
		return null
	var arr := _live(_heroes)
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
