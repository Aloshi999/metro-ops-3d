extends Node3D
## Orbit/pan rig: L-stick pans on XZ, R-stick orbits + zooms, RMB drag orbits, wheel zooms.

const GameConstants = preload("res://scripts/core/game_constants.gd")

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

var yaw: float = deg_to_rad(GameConstants.CAM_YAW_DEFAULT)
var pitch: float = deg_to_rad(GameConstants.CAM_PITCH_DEFAULT)
var distance: float = GameConstants.CAM_DIST_DEFAULT
var map_extent: float = 2048.0
var _mouse_orbiting: bool = false


func _ready() -> void:
	_apply_transform()
	if camera:
		camera.current = true
		camera.fov = 50.0
		camera.near = 0.25
		camera.far = 900.0


func setup(look_at_pos: Vector3, extent: float) -> void:
	map_extent = extent
	global_position = look_at_pos
	_apply_transform()


func apply_input(pan: Vector2, orbit: Vector2, zoom: float, dt: float) -> void:
	var basis_yaw := Basis(Vector3.UP, yaw)
	var right := basis_yaw.x
	var forward := -basis_yaw.z
	forward.y = 0.0
	forward = forward.normalized()
	var speed := GameConstants.CAM_PAN_SPEED * lerpf(0.55, 1.55, clampf(distance / GameConstants.CAM_DIST_MAX, 0.0, 1.0))
	global_position += (right * pan.x + forward * pan.y) * speed * dt
	var pad := 48.0
	global_position.x = clampf(global_position.x, pad, map_extent - pad)
	global_position.z = clampf(global_position.z, pad, map_extent - pad)
	global_position.y = 0.0

	yaw += orbit.x * GameConstants.CAM_YAW_SPEED * dt
	pitch = clampf(
		pitch - orbit.y * 1.15 * dt,
		deg_to_rad(GameConstants.CAM_PITCH_MIN),
		deg_to_rad(GameConstants.CAM_PITCH_MAX)
	)
	distance = clampf(distance + zoom * GameConstants.CAM_ZOOM_SPEED * dt, GameConstants.CAM_DIST_MIN, GameConstants.CAM_DIST_MAX)
	_apply_transform()


func apply_mouse_orbit(relative: Vector2) -> void:
	yaw -= relative.x * 0.0045
	pitch = clampf(pitch - relative.y * 0.0038, deg_to_rad(GameConstants.CAM_PITCH_MIN), deg_to_rad(GameConstants.CAM_PITCH_MAX))
	_apply_transform()


func apply_wheel(dir: float) -> void:
	distance = clampf(distance + dir * GameConstants.CAM_WHEEL_STEP, GameConstants.CAM_DIST_MIN, GameConstants.CAM_DIST_MAX)
	_apply_transform()


func look_point() -> Vector3:
	return global_position


func _apply_transform() -> void:
	rotation.y = yaw
	if pitch_pivot:
		pitch_pivot.rotation.x = pitch
	if camera:
		camera.position = Vector3(0.0, 0.0, distance)
