class_name CityCamera
extends Node3D
## Orbit/pan 3D camera. Gamepad-first; mouse look only after the pointer actually moves.
## Locked boot: 190m / pitch -56 / 6 lots south of HQ. Dist 155–215, pitch -62° to -44°.

const GameConstants = preload("res://scripts/core/game_constants.gd")

const DIST_MIN: float = 155.0
const DIST_MAX: float = 215.0
const BOOT_DIST: float = 190.0
const PITCH_MIN_DEG: float = -62.0
const PITCH_MAX_DEG: float = -44.0
const BOOT_PITCH: float = -56.0
const SOUTH_LOTS: float = 6.0
const WHEEL_STEP: float = 12.0

@onready var cam: Camera3D = $Camera3D
@onready var camera: Camera3D = $Camera3D

var target: Vector3 = Vector3.ZERO
var yaw: float = deg_to_rad(GameConstants.CAM_YAW_DEFAULT)
var pitch: float = deg_to_rad(BOOT_PITCH)
var distance: float = BOOT_DIST
var _zoom_goal: float = BOOT_DIST
var _smooth_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	_reset_rig()
	_smooth_target = target
	_apply()


func setup(world_target: Vector3, _extent: float = 0.0) -> void:
	target = world_target
	target.y = 0.0
	## lot_to_world maps lot y → +Z; south is +Z.
	target.z += SOUTH_LOTS * GameConstants.LOT_METERS
	_smooth_target = target
	_reset_rig()
	_apply()


func _reset_rig() -> void:
	yaw = deg_to_rad(GameConstants.CAM_YAW_DEFAULT)
	pitch = deg_to_rad(BOOT_PITCH)
	distance = BOOT_DIST
	_zoom_goal = distance
	_clamp_rig()


func apply_input(pan_vec: Vector2, orbit_vec: Vector2, zoom: float, dt: float) -> void:
	pan(pan_vec, dt)
	orbit(orbit_vec.x, zoom + orbit_vec.y, 0.0, dt)


func apply_mouse_orbit(relative: Vector2) -> void:
	yaw += relative.x * 0.005
	pitch = clampf(
		pitch - relative.y * 0.004,
		deg_to_rad(PITCH_MIN_DEG),
		deg_to_rad(PITCH_MAX_DEG)
	)
	_clamp_rig()


func apply_wheel(sign: float) -> void:
	## One discrete notch per tick. Sign clamped to ±1 so a fat event cannot yeet the 60m range.
	if absf(sign) < 0.0001:
		return
	var notch := clampf(sign, -1.0, 1.0)
	_zoom_goal = clampf(_zoom_goal + notch * WHEEL_STEP, _min_distance(), DIST_MAX)


func look_point() -> Vector3:
	return ground_point_center()


func pan(delta_xz: Vector2, dt: float) -> void:
	## delta_xz in camera-relative ground plane (x = right, y = forward).
	if delta_xz == Vector2.ZERO:
		return
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var speed := GameConstants.CAM_PAN_SPEED * (distance / BOOT_DIST)
	target += (right * delta_xz.x + forward * -delta_xz.y) * speed * dt
	_clamp_target()


func orbit(yaw_delta: float, zoom_delta: float, pitch_delta: float, dt: float) -> void:
	yaw += yaw_delta * GameConstants.CAM_YAW_SPEED * dt
	pitch = clampf(
		pitch + pitch_delta * dt,
		deg_to_rad(PITCH_MIN_DEG),
		deg_to_rad(PITCH_MAX_DEG)
	)
	_zoom_goal = clampf(
		_zoom_goal + zoom_delta * GameConstants.CAM_ZOOM_SPEED * dt,
		_min_distance(),
		DIST_MAX
	)


func _process(dt: float) -> void:
	var z := clampf(GameConstants.CAM_ZOOM_SMOOTH * dt, 0.0, 1.0)
	distance = lerpf(distance, _zoom_goal, z)
	_smooth_target = _smooth_target.lerp(target, clampf(8.0 * dt, 0.0, 1.0))
	_clamp_rig()
	_apply()


func _min_distance() -> float:
	## Keep camera Y above Kenney roofs at the current pitch (never dive into AABBs).
	var s := absf(sin(pitch))
	s = maxf(s, 0.38)
	return maxf(DIST_MIN, GameConstants.CAM_ROOF_CLEARANCE / s)


func _clamp_rig() -> void:
	pitch = clampf(
		pitch,
		deg_to_rad(PITCH_MIN_DEG),
		deg_to_rad(PITCH_MAX_DEG)
	)
	var dmin := _min_distance()
	distance = clampf(distance, dmin, DIST_MAX)
	_zoom_goal = clampf(_zoom_goal, dmin, DIST_MAX)
	_clamp_target()


func _apply() -> void:
	var cp := cos(pitch)
	var offset := Vector3(
		sin(yaw) * cp * distance,
		-sin(pitch) * distance,
		cos(yaw) * cp * distance
	)
	if cam:
		var pos := _smooth_target + offset
		if pos.y < GameConstants.CAM_ROOF_CLEARANCE:
			pos.y = GameConstants.CAM_ROOF_CLEARANCE
		cam.global_position = pos
		cam.look_at(_smooth_target + Vector3(0, 2.0, 0), Vector3.UP)


func _clamp_target() -> void:
	var w := float(GameConstants.MAP_SIZE) * GameConstants.LOT_METERS
	var m := GameConstants.LOT_METERS * 2.0
	target.x = clampf(target.x, m, w - m)
	target.z = clampf(target.z, m, w - m)
	target.y = 0.0


func ground_point_at_screen(screen: Vector2) -> Vector3:
	if cam == null:
		return target
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return target
	var t := -from.y / dir.y
	if t < 0.0:
		return target
	return from + dir * t


func ground_point_center() -> Vector3:
	return ground_point_at_screen(get_viewport().get_visible_rect().size * 0.5)
