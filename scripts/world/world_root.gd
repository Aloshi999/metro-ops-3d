class_name WorldRoot
extends Node3D
## Standalone 3D city: Kenney GLBs, orbit cam, late-afternoon sun.
## Self-bootstraps so world.tscn looks like a city even without main.tscn.

var map: MapData
var catalog: BuildingCatalog

@onready var city_view: CityView = $CityView
@onready var city_camera: CityCamera = $CityCamera
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D

var _capture_armed: bool = false
var _stats_printed: bool = false
var _boot_frames: int = 0


func _ready() -> void:
	Engine.max_fps = GameConstants.TARGET_FPS
	_setup_environment()
	if map == null:
		map = MapData.new()
		catalog = BuildingCatalog.new()
		catalog.load_all()
		print("BuildingCatalog loaded_count=", catalog.loaded_count, " failed=", catalog.failed)
		setup(map, catalog)
	if OS.get_environment("CITY_MESH_CAPTURE") == "1":
		_capture_armed = true


func setup(p_map: MapData, p_catalog: BuildingCatalog) -> void:
	map = p_map
	catalog = p_catalog
	if city_view:
		city_view.setup(map, catalog)
	if city_camera and map:
		city_camera.setup(map.lot_to_world(map.hq.x, map.hq.y))


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


func _setup_environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	var hdr = load("res://assets/env/sky.hdr")
	if hdr:
		sky_mat.panorama = hdr
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.62
	env.ambient_light_color = Color(0.78, 0.82, 0.92)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	env.fog_enabled = true
	env.fog_density = 0.0007
	env.fog_light_color = Color(0.68, 0.76, 0.90)
	env.fog_aerial_perspective = 0.35
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	if world_env:
		world_env.environment = env
	if sun:
		sun.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
		sun.light_energy = 1.2
		sun.light_color = Color(1.0, 0.91, 0.76)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 320.0


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
