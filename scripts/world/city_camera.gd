class_name CityCamera
extends Node3D
## Orbit/pan 3D camera. Gamepad-first; mouse look only after the pointer actually moves.

const GameConstants = preload("res://scripts/core/game_constants.gd")

@onready var cam: Camera3D = $Camera3D
@onready var camera: Camera3D = $Camera3D

var target: Vector3 = Vector3.ZERO
var yaw: float = deg_to_rad(42.0)
var pitch: float = deg_to_rad(-52.0)
var distance: float = 148.0
var _smooth_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	_smooth_target = target
	_apply()


func setup(world_target: Vector3, _extent: float = 0.0) -> void:
	target = world_target
	_smooth_target = world_target
	_apply()


func apply_input(pan_vec: Vector2, orbit_vec: Vector2, zoom: float, dt: float) -> void:
	pan(pan_vec, dt)
	orbit(orbit_vec.x, zoom + orbit_vec.y, 0.0, dt)


func apply_mouse_orbit(relative: Vector2) -> void:
	yaw += relative.x * 0.005
	pitch = clampf(pitch - relative.y * 0.004, deg_to_rad(GameConstants.CAM_PITCH_MIN), deg_to_rad(GameConstants.CAM_PITCH_MAX))


func apply_wheel(sign: float) -> void:
	distance = clampf(distance + sign * 8.0, GameConstants.CAM_DIST_MIN, GameConstants.CAM_DIST_MAX)


func look_point() -> Vector3:
	return ground_point_center()


func pan(delta_xz: Vector2, dt: float) -> void:
	## delta_xz in camera-relative ground plane (x = right, y = forward).
	if delta_xz == Vector2.ZERO:
		return
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var speed := GameConstants.CAM_PAN_SPEED * (distance / 80.0)
	target += (right * delta_xz.x + forward * -delta_xz.y) * speed * dt
	_clamp_target()


func orbit(yaw_delta: float, zoom_delta: float, pitch_delta: float, dt: float) -> void:
	yaw += yaw_delta * GameConstants.CAM_YAW_SPEED * dt
	pitch = clampf(pitch + pitch_delta * dt, deg_to_rad(GameConstants.CAM_PITCH_MIN), deg_to_rad(GameConstants.CAM_PITCH_MAX))
	distance = clampf(distance + zoom_delta * GameConstants.CAM_ZOOM_SPEED * dt, GameConstants.CAM_DIST_MIN, GameConstants.CAM_DIST_MAX)


func _process(dt: float) -> void:
	_smooth_target = _smooth_target.lerp(target, clampf(8.0 * dt, 0.0, 1.0))
	_apply()


func _apply() -> void:
	var cp := cos(pitch)
	var offset := Vector3(
		sin(yaw) * cp * distance,
		-sin(pitch) * distance,
		cos(yaw) * cp * distance
	)
	if cam:
		cam.global_position = _smooth_target + offset
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
