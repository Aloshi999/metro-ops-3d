class_name NightMarketKit
extends RefCounted
## Curated night-market stall props. Shared PackedScenes / shared colormap.
## Plaza benches/lanterns/cabin walls/trees + a few large food props.
## Tiny food GLBs (apple, taco) are NOT lot buildings and are not cached.

const GameConstants = preload("res://scripts/core/game_constants.gd")

const BASE := "res://assets/city/district_night_market/"
const PLAZA := BASE + "plaza/"
const FOOD := BASE + "food/"
const MANIFEST_PATH := BASE + "instance_manifest.json"

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var skipped: int = 0
var piece_scale: float = GameConstants.BUILDING_SCALE

var _scenes: Dictionary = {}
## Stall-scale plaza pieces only — not gingerbread / socks / toy trains.
var _plaza: Array[String] = [
	PLAZA + "bench.glb",
	PLAZA + "bench-short.glb",
	PLAZA + "lantern.glb",
	PLAZA + "lantern-hanging.glb",
	PLAZA + "cabin-wall.glb",
	PLAZA + "cabin-wall-low.glb",
	PLAZA + "cabin-window-a.glb",
	PLAZA + "cabin-doorway.glb",
	PLAZA + "cabin-corner.glb",
	PLAZA + "cabin-fence.glb",
	PLAZA + "tree.glb",
	PLAZA + "tree-decorated.glb",
	PLAZA + "lights-colored.glb",
]
## Larger food props only (barrel / pot / crate-like). Skip produce.
var _food: Array[String] = [
	FOOD + "barrel.glb",
	FOOD + "pot.glb",
	FOOD + "pot-stew.glb",
	FOOD + "pizza-box.glb",
	FOOD + "carton.glb",
	FOOD + "bag.glb",
	FOOD + "frying-pan.glb",
	FOOD + "can.glb",
]


func load_kit() -> void:
	var manifest_slots := 0
	if FileAccess.file_exists(MANIFEST_PATH):
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				if bool(data.get("unique_per_lot", false)):
					push_warning("[NightMarketKit] unique_per_lot is true; instancing anyway shared")
				var counts = data.get("counts", {})
				if typeof(counts) == TYPE_DICTIONARY:
					manifest_slots = int(counts.get("slots", 0))
				var slots = data.get("slots", [])
				if typeof(slots) == TYPE_ARRAY and slots.size() > manifest_slots:
					manifest_slots = slots.size()
	for arr in [_plaza, _food]:
		for p in arr:
			_cache(p)
	if manifest_slots > 0:
		skipped = maxi(0, manifest_slots - loaded_count)
	else:
		skipped = 299 - loaded_count
	ready = loaded_count >= 4
	print("[NightMarketKit] loaded=", loaded_count, " failed=", failed.size(), " skipped=", skipped, " ready=", ready, " scale=", piece_scale)


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


func pick_prop(index: int) -> Node3D:
	if not ready:
		return null
	var live: Array[String] = []
	for p in _plaza:
		if _scenes.has(p):
			live.append(p)
	for p in _food:
		if _scenes.has(p):
			live.append(p)
	if live.is_empty():
		return null
	var path: String = live[posmod(index, live.size())]
	var n := instantiate_shared(path, piece_scale)
	if n:
		n.rotate_y(float((index * 17) % 4) * PI * 0.5)
	return n
