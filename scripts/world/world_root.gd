class_name WorldRoot
extends Node3D
## Standalone 3D city: Kenney GLBs, orbit cam, late-afternoon sun.
## Self-bootstraps so world.tscn looks like a city even without main.tscn.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BuildingCatalog = preload("res://scripts/world/building_catalog.gd")
const CityView = preload("res://scripts/world/city_view.gd")
const CityCamera = preload("res://scripts/world/city_camera.gd")
const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")

var map: MapData
var catalog: BuildingCatalog

@onready var city_view: CityView = $CityView
@onready var city_camera: CityCamera = $CityCamera
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D

var graphics_preset: int = GraphicsPresets.Id.LOW
var _capture_armed: bool = false
var _stats_printed: bool = false
var _boot_frames: int = 0


func _ready() -> void:
	graphics_preset = GraphicsPresets.from_env(GraphicsPresets.Id.LOW)
	_setup_environment()
	if map == null:
		map = MapData.new()
		catalog = BuildingCatalog.new()
		catalog.load_all()
		print("BuildingCatalog loaded_count=", catalog.loaded_count, " failed=", catalog.failed)
		setup(map, catalog)
	if OS.get_environment("CITY_MESH_CAPTURE") == "1":
		_capture_armed = true
		# Store-page still: 800p + cheap SSAO on the 0.58/0.78 film. Do not lift to High 1080p.
		if world_env and world_env.environment:
			var env := world_env.environment
			env.ssao_enabled = true
			env.ssao_intensity = 0.40
			env.ssao_radius = 1.0


func setup(p_map: MapData, p_catalog: BuildingCatalog) -> void:
	map = p_map
	catalog = p_catalog
	if city_view:
		city_view.setup(map, catalog)
	if city_camera and map:
		city_camera.setup(map.lot_to_world(map.hq.x, map.hq.y), map.world_size())


func _process(_dt: float) -> void:
	_boot_frames += 1
	if not _stats_printed and _boot_frames >= 3:
		_stats_printed = true
		_print_instance_counts()
	if _capture_armed and _boot_frames >= 22:
		_capture_armed = false
		_save_capture()


func _print_instance_counts() -> void:
	if city_view == null:
		return
	var bld_n := city_view.buildings_root.get_child_count() if city_view.buildings_root else 0
	var rd_n := city_view.roads_root.get_child_count() if city_view.roads_root else 0
	var lot_n := city_view.lots_root.get_child_count() if city_view.lots_root else 0
	var svc_n := city_view.services_root.get_child_count() if city_view.services_root else 0
	var prop_n := city_view.props_root.get_child_count() if city_view.props_root else 0
	print("CITY_MESH instances buildings=", bld_n, " roads=", rd_n, " lots=", lot_n, " services=", svc_n, " props=", prop_n)
	print("CITY_MESH park=", city_view.park_count, " waterfront=", city_view.waterfront_count, " cards=", city_view.card_count)
	if catalog:
		print("CITY_MESH caches albedo=", catalog._albedo_cache.size(), " emissive=", catalog._emissive_cache.size())


func apply_graphics_preset(preset: int) -> void:
	## Controls/Builder: world.apply_graphics_preset(GraphicsPresets.Id.HIGH)
	## or GraphicsPresets.apply(world, viewport, id). Stores + switches look.
	graphics_preset = clampi(preset, GraphicsPresets.Id.LOW, GraphicsPresets.Id.ULTRA)
	GraphicsPresets.apply(self, get_viewport(), graphics_preset)


func apply_preset(name: String = "low") -> void:
	## String alias for older Controls wiring.
	apply_graphics_preset(GraphicsPresets.id_from_name(name))


func _setup_environment() -> void:
	## Boot default LOW (Deck floor). METRO_GRAPHICS honored in _ready.
	apply_graphics_preset(graphics_preset)


func _ensure_fill_light() -> void:
	## One unshadowed cool fill, opposite-ish the sun. Not a second shadow caster.
	var fill := get_node_or_null("FillLight") as DirectionalLight3D
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.name = "FillLight"
		add_child(fill)
	fill.rotation_degrees = Vector3(-28.0, -140.0, 0.0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.55, 0.68, 0.90)
	fill.shadow_enabled = false


func _save_capture() -> void:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("CITY_MESH capture: no viewport texture")
		get_tree().quit(1)
		return
	var img := tex.get_image()
	if img == null:
		push_error("CITY_MESH capture: get_image failed")
		get_tree().quit(1)
		return
	var dest_b := "/workspace/metro-ops-3d/builds/city_looks_3d.png"
	var dest_c := "/workspace/city_looks_3d.png"
	var err := img.save_png(dest_b)
	print("CITY_MESH capture save ", dest_b, " err=", err, " size=", img.get_width(), "x", img.get_height())
	img.save_png(dest_c)
	get_tree().quit(0)
