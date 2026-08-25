class_name MidriseCards
extends RefCounted
## Shared window/cutaway cards for the 190m camera. Not first-person rooms.
## interiors_dropin tonemapped JPGs + MegaKit T_lit. unique_per_lot: false.

const DROP := "res://assets/city/interiors_dropin/window_cards/"
const MID := "res://assets/city/district_midrise/interiors/window_cards/"
const T_LIT1 := "res://assets/city/district_downtown/textures/T_lit_interior_1.png"
const T_LIT2 := "res://assets/city/district_downtown/textures/T_lit_interior_2.png"

## Night-market / lounge warmth (amber).
const WARM_CARDS: Array[String] = [
	DROP + "fireplace_tonemapped.jpg",
	DROP + "anniversary_lounge_tonemapped.jpg",
	DROP + "hotel_room_tonemapped.jpg",
	MID + "shop_comfy_cafe/comfy_cafe_tonemapped.jpg",
	T_LIT1,
]
## Cool apartments / studios.
const COOL_CARDS: Array[String] = [
	DROP + "studio_small_03_tonemapped.jpg",
	DROP + "photo_studio_01_tonemapped.jpg",
	MID + "apartment_kiara_interior/kiara_interior_tonemapped.jpg",
	T_LIT2,
]

const WARM_EMISSION := Color(1.0, 0.56, 0.20)
const COOL_EMISSION := Color(0.48, 0.64, 0.95)
const WARM_ENERGY := 0.46
const COOL_ENERGY := 0.32

var ready: bool = false
var _warm: Array[StandardMaterial3D] = []
var _cool: Array[StandardMaterial3D] = []


func load_kit() -> void:
	_warm.clear()
	_cool.clear()
	for p in WARM_CARDS:
		var m := _make_card_mat(p, WARM_EMISSION, WARM_ENERGY)
		if m:
			_warm.append(m)
	for p in COOL_CARDS:
		var m := _make_card_mat(p, COOL_EMISSION, COOL_ENERGY)
		if m:
			_cool.append(m)
	ready = not _warm.is_empty() or not _cool.is_empty()
	print("[MidriseCards] loaded=", _warm.size() + _cool.size(), " warm=", _warm.size(), " cool=", _cool.size(), " ready=", ready)


func _make_card_mat(path: String, emission: Color, energy: float) -> StandardMaterial3D:
	var tex := _load_tex(path)
	if tex == null:
		return null
	var mat := StandardMaterial3D.new()
	mat.resource_name = "midrise_card_" + path.get_file().get_basename()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.92, 0.90, 0.86)
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_texture = tex
	mat.emission_energy_multiplier = energy
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			return res
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _pick_mat(lot_index: int) -> StandardMaterial3D:
	## Most midrise lots get night-market warmth; every 5th is a cool apartment.
	var use_warm := (lot_index % 5) != 0
	var pool: Array[StandardMaterial3D] = _warm if use_warm and not _warm.is_empty() else _cool
	if pool.is_empty():
		pool = _warm if not _warm.is_empty() else _cool
	if pool.is_empty():
		return null
	return pool[lot_index % pool.size()]


func attach(building: Node3D, lot_index: int) -> bool:
	if not ready or building == null:
		return false
	var mat := _pick_mat(lot_index)
	if mat == null:
		return false
	## One south-facing card. Shared mat — never duplicated per lot.
	## Kenney wrap is 14.5; undo so the card stays ~7×5 m world.
	_place_card(building, mat, Vector3(0.0, 7.0, 6.6), Vector2(6.8, 5.2), "midrise_card")
	return true


func _place_card(building: Node3D, mat: StandardMaterial3D, world_off: Vector3, size: Vector2, name: String) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s := maxf(absf(building.scale.x), 0.01)
	mi.scale = Vector3(1.0 / s, 1.0 / s, 1.0 / s)
	mi.rotation.y = -building.rotation.y
	mi.position = world_off.rotated(Vector3.UP, -building.rotation.y) / s
	building.add_child(mi)
