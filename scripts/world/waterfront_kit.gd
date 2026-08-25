class_name WaterfrontKit
extends RefCounted
## PH pier/props at 1.0 m. Kenney shore trees / lilies at 14.5. Shared PackedScenes.

const BASE := "res://assets/city/district_waterfront/"
const PH_SCALE: float = 1.0
const KENNEY_SCALE: float = 14.5

var ready: bool = false
var loaded_count: int = 0
var failed: PackedStringArray = []
var _scenes: Dictionary = {}
var _scales: Dictionary = {}

var pier: String = BASE + "models/modular_wooden_pier/modular_wooden_pier_2k.gltf"
var crane: String = BASE + "models/overhead_crane/overhead_crane_2k.gltf"
var crane_ok: bool = false
var props: PackedStringArray = PackedStringArray()
var palms: PackedStringArray = PackedStringArray()
var lilies: PackedStringArray = PackedStringArray()


func load_kit() -> void:
	_cache(pier, PH_SCALE)
	for p in [
		"models/Barrel_01/Barrel_01_2k.gltf",
		"models/barrel_03/barrel_03_2k.gltf",
		"models/wooden_crate_01/wooden_crate_01_2k.gltf",
		"models/lifebuoy/lifebuoy_2k.gltf",
		"models/ocean_buoy/ocean_buoy_2k.gltf",
	]:
		var path: String = BASE + p
		if _cache(path, PH_SCALE):
			props.append(path)
	for p in ["nature_water/tree_palm.glb", "nature_water/tree_palmBend.glb", "nature_water/tree_oak.glb"]:
		var path: String = BASE + p
		if _cache(path, KENNEY_SCALE):
			palms.append(path)
	for p in ["nature_water/lily_large.glb", "nature_water/lily_small.glb"]:
		var path: String = BASE + p
		if _cache(path, KENNEY_SCALE):
			lilies.append(path)
	_try_crane()
	ready = _scenes.has(pier) or palms.size() >= 1
	print("[WaterfrontKit] loaded=", loaded_count, " failed=", failed.size(), " ready=", ready, " ph=", PH_SCALE, " kn=", KENNEY_SCALE, " crane=", crane_ok)


func _try_crane() -> void:
	if not _cache(crane, PH_SCALE):
		return
	var packed: PackedScene = _scenes.get(crane, null)
	if packed == null:
		return
	var n: Node = packed.instantiate()
	var aabb := _aabb_of(n)
	n.free()
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest > 80.0:
		_scenes.erase(crane)
		_scales.erase(crane)
		loaded_count = maxi(0, loaded_count - 1)
		print("[WaterfrontKit] skip crane aabb=", aabb.size)
		return
	if longest > 28.0:
		_scales[crane] = 20.0 / maxf(longest, 0.01)
	else:
		_scales[crane] = PH_SCALE
	crane_ok = true


func _aabb_of(n: Node) -> AABB:
	var box := AABB()
	var started := false
	if n is VisualInstance3D:
		box = (n as VisualInstance3D).get_aabb()
		started = true
	for c in n.get_children():
		var child_box := _aabb_of(c)
		if child_box.size == Vector3.ZERO and child_box.position == Vector3.ZERO:
			continue
		if n is Node3D:
			var xf := (c as Node3D).transform if c is Node3D else Transform3D.IDENTITY
			child_box = xf * child_box
		if started:
			box = box.merge(child_box)
		else:
			box = child_box
			started = true
	return box


func _cache(path: String, scale: float) -> bool:
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
		_scales[path] = scale
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
	var sc: float = float(_scales.get(path, PH_SCALE))
	wrap.scale = Vector3(sc, sc, sc)
	_strip_giant(wrap)
	return wrap


func _strip_giant(n: Node) -> void:
	if n is VisualInstance3D:
		var sz: Vector3 = (n as VisualInstance3D).get_aabb().size
		var sc: float = 1.0
		if n is Node3D:
			var ls: Vector3 = (n as Node3D).scale
			sc = maxf(ls.x, maxf(ls.y, ls.z))
		if maxf(sz.x, maxf(sz.y, sz.z)) * sc > 64.0:
			(n as VisualInstance3D).visible = false
			print("[WaterfrontKit] hide giant ", n.name, " aabb=", sz)
	for c in n.get_children():
		_strip_giant(c)


func instantiate_pier() -> Node3D:
	return instantiate_shared(pier)


func instantiate_crane() -> Node3D:
	if not crane_ok:
		return null
	return instantiate_shared(crane)


func pick_prop(i: int) -> Node3D:
	if props.is_empty():
		return null
	return instantiate_shared(props[i % props.size()])


func pick_palm(i: int) -> Node3D:
	if palms.is_empty():
		return null
	return instantiate_shared(palms[i % palms.size()])


func pick_lily(i: int) -> Node3D:
	if lilies.is_empty():
		return null
	return instantiate_shared(lilies[i % lilies.size()])


func pick_piece(lot_index: int, on_water: bool = false) -> Node3D:
	if on_water:
		if lot_index % 17 == 0:
			return instantiate_pier()
		return pick_lily(lot_index)
	if lot_index % 19 == 0:
		return instantiate_pier()
	if lot_index % 4 == 1:
		return pick_prop(lot_index)
	return pick_palm(lot_index)
