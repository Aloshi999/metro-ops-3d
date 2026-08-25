class_name GraphicsPresets
extends Object
## Look-owned WorldEnvironment / lights / SSAO / GI / scaling per quality preset.
## Controls/Builder call WorldRoot.apply_graphics_preset(id) or GraphicsPresets.apply(world, vp, id).
## Never SDFGI+VoxelGI. Never MSAA, TAA, glow, SSR, SSIL.

enum Id { LOW = 0, MEDIUM = 1, HIGH = 2, ULTRA = 3 }

const FILM_SUN: float = 0.58
const FILM_EXPOSURE: float = 0.78
const FILM_HDRI: float = 0.55
const FILM_AMBIENT: float = 0.30
const FILM_FILL: float = 0.22

const _NAMES: PackedStringArray = ["low", "medium", "high", "ultra"]


static func name_of(preset: int) -> String:
	var i := clampi(preset, Id.LOW, Id.ULTRA)
	return _NAMES[i]


static func id_from_name(s: String) -> int:
	var n := s.strip_edges().to_lower()
	match n:
		"low", "0", "deck":
			return Id.LOW
		"medium", "med", "1":
			return Id.MEDIUM
		"high", "2":
			return Id.HIGH
		"ultra", "3":
			return Id.ULTRA
		_:
			return Id.LOW


static func from_env(default_id: int = Id.LOW) -> int:
	var g := OS.get_environment("METRO_GRAPHICS").strip_edges()
	if g.is_empty():
		return default_id
	return id_from_name(g)


static func apply(world: Node, viewport: Viewport, preset: int) -> void:
	preset = clampi(preset, Id.LOW, Id.ULTRA)
	if world != null and world.has_method("_ensure_fill_light"):
		world.call("_ensure_fill_light")
	var env := _make_film_env()
	match preset:
		Id.LOW:
			_apply_low(env, world)
		Id.MEDIUM:
			_apply_medium(env, world)
		Id.HIGH:
			_apply_high(env, world)
		Id.ULTRA:
			_apply_ultra(env, world)
	_assign_env(world, env)
	_apply_sun(world)
	_apply_fill(world)
	_apply_camera_far(world, preset)
	_apply_viewport(viewport, preset)
	_apply_window(preset)
	_apply_fps(preset)
	_disable_voxel_gi(world)
	if world != null and world.get("graphics_preset") != null:
		world.set("graphics_preset", preset)
	print("GRAPHICS_PRESET=", name_of(preset))


static func _make_film_env() -> Environment:
	var sky_mat := PanoramaSkyMaterial.new()
	var hdr = load("res://assets/env/sky.hdr")
	if hdr:
		sky_mat.panorama = hdr
	if "energy_multiplier" in sky_mat:
		sky_mat.energy_multiplier = FILM_HDRI
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	if not ("energy_multiplier" in sky_mat) and "background_energy_multiplier" in env:
		env.background_energy_multiplier = FILM_HDRI
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = FILM_AMBIENT
	env.ambient_light_color = Color(0.55, 0.56, 0.70)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = FILM_EXPOSURE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.20
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.54, 0.66)
	env.fog_aerial_perspective = 0.58
	if "fog_sky_affect" in env:
		env.fog_sky_affect = 0.68
	if "fog_light_energy" in env:
		env.fog_light_energy = 0.82
	env.glow_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	return env


static func _apply_low(env: Environment, world: Node) -> void:
	env.ssao_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.45
	if "fog_sky_affect" in env:
		env.fog_sky_affect = 0.55
	_shadow(world, 180.0, 1024, 0)
	_ssao_quality(0)


static func _apply_medium(env: Environment, world: Node) -> void:
	env.ssao_enabled = true
	env.ssao_intensity = 0.32
	env.ssao_radius = 1.0
	if "ssao_quality" in env:
		env.ssao_quality = 0
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_density = 0.0017
	env.fog_aerial_perspective = 0.55
	if "fog_sky_affect" in env:
		env.fog_sky_affect = 0.62
	_shadow(world, 280.0, 1024, 0)
	_ssao_quality(0)


static func _apply_high(env: Environment, world: Node) -> void:
	env.ssao_enabled = true
	env.ssao_intensity = 0.48
	env.ssao_radius = 1.0
	if "ssao_quality" in env:
		env.ssao_quality = 1
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.fog_density = 0.00155
	env.fog_aerial_perspective = 0.58
	if "fog_sky_affect" in env:
		env.fog_sky_affect = 0.68
	_shadow(world, 420.0, 2048, 1)
	_ssao_quality(1)


static func _apply_ultra(env: Environment, world: Node) -> void:
	## SDFGI only — never VoxelGI, never both GI.
	env.ssao_enabled = true
	env.ssao_intensity = 0.52
	env.ssao_radius = 1.2
	if "ssao_quality" in env:
		env.ssao_quality = 1
	env.sdfgi_enabled = true
	if "sdfgi_energy" in env:
		env.sdfgi_energy = 0.70
	if "sdfgi_bounce_feedback" in env:
		env.sdfgi_bounce_feedback = 0.35
	env.volumetric_fog_enabled = true
	if "volumetric_fog_density" in env:
		env.volumetric_fog_density = 0.008
	if "volumetric_fog_albedo" in env:
		env.volumetric_fog_albedo = Color(0.70, 0.55, 0.45)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.62
	if "fog_sky_affect" in env:
		env.fog_sky_affect = 0.72
	_shadow(world, 520.0, 2048, 1)
	_ssao_quality(1)


static func _assign_env(world: Node, env: Environment) -> void:
	if world == null:
		return
	var world_env = world.get("world_env")
	if not (world_env is WorldEnvironment):
		world_env = world.get_node_or_null("WorldEnvironment")
	if world_env is WorldEnvironment:
		(world_env as WorldEnvironment).environment = env


static func _sun_of(world: Node) -> DirectionalLight3D:
	if world == null:
		return null
	var sun = world.get("sun")
	if sun is DirectionalLight3D:
		return sun
	return world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D


static func _apply_sun(world: Node) -> void:
	var s := _sun_of(world)
	if s == null:
		return
	s.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	s.light_energy = FILM_SUN
	s.light_color = Color(1.0, 0.84, 0.68)
	s.shadow_enabled = true


static func _apply_fill(world: Node) -> void:
	if world == null:
		return
	var fill := world.get_node_or_null("FillLight") as DirectionalLight3D
	if fill == null:
		return
	fill.rotation_degrees = Vector3(-28.0, -140.0, 0.0)
	fill.light_energy = FILM_FILL
	fill.light_color = Color(0.55, 0.68, 0.90)
	fill.shadow_enabled = false


static func _apply_camera_far(world: Node, preset: int) -> void:
	## Far plane only — do not touch yaw/pitch/dist clamps.
	if world == null:
		return
	var rig = world.get("city_camera")
	if rig == null:
		rig = world.get_node_or_null("CityCamera")
	if rig == null:
		return
	var cam: Camera3D = null
	if rig.get("cam") is Camera3D:
		cam = rig.get("cam")
	elif rig.get("camera") is Camera3D:
		cam = rig.get("camera")
	if cam == null:
		cam = rig.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	match preset:
		Id.LOW:
			cam.far = 320.0
		Id.MEDIUM:
			cam.far = 480.0
		Id.HIGH:
			cam.far = 640.0
		Id.ULTRA:
			cam.far = 820.0


static func _apply_viewport(viewport: Viewport, preset: int) -> void:
	if viewport == null:
		return
	# Never MSAA / TAA / MSAA+FSR2.
	if "msaa_3d" in viewport:
		viewport.msaa_3d = Viewport.MSAA_DISABLED
	if "msaa_2d" in viewport:
		viewport.msaa_2d = Viewport.MSAA_DISABLED
	if "use_taa" in viewport:
		viewport.use_taa = false
	match preset:
		Id.LOW:
			viewport.scaling_3d_mode = 2  # FSR2
			viewport.scaling_3d_scale = 0.67
			viewport.fsr_sharpness = 0.2
		Id.MEDIUM:
			viewport.scaling_3d_mode = 2
			viewport.scaling_3d_scale = 0.77
			viewport.fsr_sharpness = 0.2
		Id.HIGH:
			viewport.scaling_3d_mode = 0  # native bilinear
			viewport.scaling_3d_scale = 1.0
			viewport.fsr_sharpness = 0.2
		Id.ULTRA:
			viewport.scaling_3d_mode = 0
			viewport.scaling_3d_scale = 1.0
			viewport.fsr_sharpness = 0.2


static func _apply_window(preset: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var size := Vector2i(1280, 800)
	match preset:
		Id.LOW:
			size = Vector2i(1280, 800)
		Id.MEDIUM, Id.HIGH:
			size = Vector2i(1920, 1080)
		Id.ULTRA:
			size = Vector2i(2560, 1440)
	DisplayServer.window_set_size(size)


static func _apply_fps(preset: int) -> void:
	if preset == Id.LOW:
		Engine.max_fps = 40
	else:
		Engine.max_fps = 60


static func _shadow(world: Node, dist: float, size: int, quality: int) -> void:
	var s := _sun_of(world)
	if s:
		s.directional_shadow_max_distance = dist
	if ProjectSettings.has_setting("rendering/lights_and_shadows/directional_shadow/size"):
		ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", size)
	if ProjectSettings.has_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"):
		ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", quality)


static func _ssao_quality(q: int) -> void:
	if ProjectSettings.has_setting("rendering/environment/ssao/quality"):
		ProjectSettings.set_setting("rendering/environment/ssao/quality", q)


static func _disable_voxel_gi(world: Node) -> void:
	## Never add VoxelGI. If one is already a direct child, keep it off so it cannot pair with SDFGI.
	if world == null:
		return
	for c in world.get_children():
		if c is VoxelGI:
			(c as VoxelGI).visible = false
