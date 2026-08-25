class_name ParkKit
extends RefCounted
## Kenney nature / plaza hero cache. Scale 14.5 (Kenney lot contract). Shared PackedScenes.

const BASE := "res://assets/city/district_park/"
const SCALE: float = 14.5

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var _scenes: Dictionary = {}

var trees: PackedStringArray = PackedStringArray()
var benches: PackedStringArray = PackedStringArray()
var paths: PackedStringArray = PackedStringArray()
var statues: PackedStringArray = PackedStringArray()
var flowers: PackedStringArray = PackedStringArray()


func load_kit() -> void:
	var tree_ids := [
		"nature/tree_default.glb", "nature/tree_oak.glb", "nature/tree_detailed.glb",
		"nature/tree_cone.glb", "nature/tree_default_dark.glb",
	]
	var bench_ids := ["plaza/bench.glb", "plaza/bench-short.glb"]
	var path_ids := [
		"nature/ground_pathCross.glb", "nature/ground_pathBend.glb",
		"nature/ground_grass.glb", "nature/ground_pathStraight.glb",
	]
	var statue_ids := ["nature/statue_obelisk.glb", "nature/statue_column.glb"]
	var flower_ids := ["nature/flower_purpleA.glb", "nature/flower_yellowA.glb"]
	for p in tree_ids:
		if _cache(BASE + p):
			trees.append(BASE + p)
	for p in bench_ids:
		if _cache(BASE + p):
			benches.append(BASE + p)
	for p in path_ids:
		if _cache(BASE + p):
			paths.append(BASE + p)
	for p in statue_ids:
		if _cache(BASE + p):
			statues.append(BASE + p)
	for p in flower_ids:
		if _cache(BASE + p):
			flowers.append(BASE + p)
	ready = trees.size() >= 2
	print("[ParkKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " scale=", SCALE)


func _cache(path: String) -> bool:
	if _scenes.has(path):
		return true
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is PackedScene:
			packed = res
	if packed == null:
		packed = _pack_runtime(path)
	if packed:
		_scenes[path] = packed
		loaded_count += 1
		return true
	failed.append(path)
	return false


func _pack_runtime(path: String) -> PackedScene:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state, 0, abs_path.get_base_dir()) != OK:
		return null
	var node := doc.generate_scene(state)
	if node == null:
		return null
	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		return null
	return packed


func instantiate_shared(path: String) -> Node3D:
	var packed: PackedScene = _scenes.get(path, null)
	if packed == null:
		return null
	var n: Node = packed.instantiate()
	var wrap := Node3D.new()
	wrap.name = path.get_file().get_basename()
	wrap.add_child(n)
	wrap.scale = Vector3(SCALE, SCALE, SCALE)
	return wrap


func pick_tree(i: int) -> Node3D:
	if trees.is_empty():
		return null
	return instantiate_shared(trees[i % trees.size()])


func pick_bench(i: int) -> Node3D:
	if benches.is_empty():
		return null
	return instantiate_shared(benches[i % benches.size()])


func pick_path(i: int) -> Node3D:
	if paths.is_empty():
		return null
	return instantiate_shared(paths[i % paths.size()])


func pick_statue(i: int) -> Node3D:
	if statues.is_empty():
		return null
	return instantiate_shared(statues[i % statues.size()])


func pick_flower(i: int) -> Node3D:
	if flowers.is_empty():
		return null
	return instantiate_shared(flowers[i % flowers.size()])


func pick_piece(lot_index: int) -> Node3D:
	var r := lot_index % 10
	if r == 0:
		return pick_statue(lot_index)
	if r <= 2:
		return pick_bench(lot_index)
	if r <= 4:
		return pick_path(lot_index)
	if r == 5:
		return pick_flower(lot_index)
	return pick_tree(lot_index)
