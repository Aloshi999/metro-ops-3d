class_name BenchmarkMode
extends Node
## Scripted 60–90s camera path over existing downtown / midrise / park / waterfront lots.
## Measures real frame times. Never invents FPS. Default preset is Deck Low.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")

const RESULT_PATH := "user://benchmark_last.txt"
const DURATION_PLAY: float = 75.0
const DURATION_SMOKE: float = 3.0
const DEFAULT_PRESET := "low"

signal live_fps(fps: float, elapsed: float, duration: float)
signal finished(results: Dictionary)
signal aborted

enum State { IDLE, RUNNING, RESULTS, ABORTED }

var camera
var map
var city_view

var state: int = State.IDLE
var duration: float = DURATION_PLAY
var elapsed: float = 0.0
var preset_name: String = DEFAULT_PRESET
var smoke: bool = false

var _samples: PackedFloat32Array = PackedFloat32Array()
var _sum_dt: float = 0.0
var _waypoints: Array = []
var _results: Dictionary = {}
var _skip_first: bool = true


func setup(p_camera, p_map, p_city_view = null) -> void:
	camera = p_camera
	map = p_map
	city_view = p_city_view


func default_preset() -> String:
	return DEFAULT_PRESET


func is_running() -> bool:
	return state == State.RUNNING


func is_results() -> bool:
	return state == State.RESULTS


func is_blocking() -> bool:
	return state == State.RUNNING or state == State.RESULTS


func is_aborted() -> bool:
	return state == State.ABORTED


func start(p_preset: String = DEFAULT_PRESET) -> void:
	_begin(p_preset, false)


func start_smoke(p_preset: String = DEFAULT_PRESET) -> void:
	_begin(p_preset, true)


func _begin(p_preset: String, p_smoke: bool) -> void:
	smoke = p_smoke
	duration = DURATION_SMOKE if p_smoke else DURATION_PLAY
	var n := p_preset.strip_edges().to_lower()
	if n.is_empty():
		n = DEFAULT_PRESET
	preset_name = GraphicsPresets.name_of(GraphicsPresets.id_from_name(n))
	elapsed = 0.0
	_samples = PackedFloat32Array()
	_sum_dt = 0.0
	_results = {}
	_skip_first = true
	_waypoints = _build_waypoints()
	state = State.RUNNING
	if camera != null and camera.has_method("begin_scripted"):
		camera.begin_scripted()
	_apply_path(0.0)


func tick(dt: float) -> void:
	if state != State.RUNNING:
		return
	if _skip_first:
		_skip_first = false
		_apply_path(0.0)
		live_fps.emit(0.0, 0.0, duration)
		return
	if dt > 0.0:
		_samples.append(dt)
		_sum_dt += dt
	elapsed += maxf(dt, 0.0)
	var u := 1.0 if duration <= 0.0 else clampf(elapsed / duration, 0.0, 1.0)
	_apply_path(u)
	var fps_now := 0.0
	if dt > 0.0:
		fps_now = 1.0 / dt
	live_fps.emit(fps_now, elapsed, duration)
	if elapsed >= duration:
		_finish()


func force_finish() -> void:
	if state == State.RUNNING:
		_finish()


func abort() -> void:
	if state != State.RUNNING and state != State.RESULTS:
		return
	state = State.ABORTED
	if camera != null and camera.has_method("end_scripted"):
		camera.end_scripted(true)
	aborted.emit()


func dismiss() -> void:
	if state == State.RESULTS or state == State.ABORTED:
		state = State.IDLE
		_results = {}


func results() -> Dictionary:
	return _results.duplicate()


func _finish() -> void:
	var avg := 0.0
	var low := 0.0
	var n := _samples.size()
	if n > 0 and _sum_dt > 0.0:
		avg = float(n) / _sum_dt
	var p99 := _percentile_99(_samples)
	if p99 > 0.0:
		low = 1.0 / p99
	var ts := Time.get_datetime_string_from_system(true)
	if not ts.ends_with("Z"):
		ts += "Z"
	_results = {
		"avg": avg,
		"1pct_low": low,
		"duration": elapsed,
		"preset": preset_name,
		"timestamp": ts,
		"frames": n,
	}
	_write_file(_results)
	state = State.RESULTS
	if camera != null and camera.has_method("end_scripted"):
		camera.end_scripted(true)
	finished.emit(_results)


func _write_file(r: Dictionary) -> void:
	var body := "avg=%.2f\n1pct_low=%.2f\nduration=%.2f\npreset=%s\ntimestamp=%s\n" % [
		float(r["avg"]),
		float(r["1pct_low"]),
		float(r["duration"]),
		str(r["preset"]),
		str(r["timestamp"]),
	]
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Benchmark: could not write %s (%s)" % [RESULT_PATH, FileAccess.get_open_error()])
		return
	f.store_string(body)
	f.close()


func _percentile_99(samples: PackedFloat32Array) -> float:
	var n := samples.size()
	if n <= 0:
		return 0.0
	var arr := samples.duplicate()
	arr.sort()
	var idx := int(ceili(0.99 * float(n))) - 1
	idx = clampi(idx, 0, n - 1)
	return arr[idx]


func _build_waypoints() -> Array:
	## 5 poses, 75s play / 3s smoke. Dist 172–198, pitch -56..-50 — inside camera clamps.
	var pts: Array = []
	pts.append(_wp("downtown", _landmark("downtown", 0, 0), 42.0, -56.0, 190.0))
	pts.append(_wp("midrise", _landmark("midrise", 8, -8), 98.0, -52.0, 185.0))
	pts.append(_wp("park", _landmark("park", -8, 4), 205.0, -50.0, 172.0))
	pts.append(_wp("waterfront", _landmark("waterfront", 8, 4), 318.0, -54.0, 198.0))
	pts.append(_wp("downtown_close", _landmark("downtown", 0, 2), 42.0, -56.0, 190.0))
	return pts


func _wp(label: String, target: Vector3, yaw_deg: float, pitch_deg: float, dist: float) -> Dictionary:
	return {
		"label": label,
		"target": target,
		"yaw": deg_to_rad(yaw_deg),
		"pitch": deg_to_rad(pitch_deg),
		"dist": dist,
	}


func _landmark(kind: String, ox: int, oy: int) -> Vector3:
	if city_view != null and city_view.has_method("landmark_world"):
		var w: Vector3 = city_view.landmark_world(kind)
		if w != Vector3.ZERO:
			return w
	var hq := Vector2i(64, 64)
	if map != null and map.get("hq") != null:
		hq = map.hq
	var lot := Vector2i(hq.x + ox, hq.y + oy)
	if map != null and map.has_method("lot_to_world"):
		return map.lot_to_world(lot.x, lot.y)
	var s := GameConstants.LOT_METERS
	return Vector3((float(lot.x) + 0.5) * s, 0.0, (float(lot.y) + 0.5) * s)


func _apply_path(u: float) -> void:
	if camera == null or _waypoints.is_empty():
		return
	var n := _waypoints.size()
	if n == 1:
		_pose(_waypoints[0], _waypoints[0], 0.0)
		return
	var t := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := clampi(int(floor(t)), 0, n - 2)
	var local := clampf(t - float(i), 0.0, 1.0)
	local = local * local * (3.0 - 2.0 * local)
	_pose(_waypoints[i], _waypoints[i + 1], local)


func _pose(a: Dictionary, b: Dictionary, t: float) -> void:
	var target: Vector3 = (a["target"] as Vector3).lerp(b["target"] as Vector3, t)
	var yaw := _lerp_angle(float(a["yaw"]), float(b["yaw"]), t)
	var pitch := lerpf(float(a["pitch"]), float(b["pitch"]), t)
	var dist := lerpf(float(a["dist"]), float(b["dist"]), t)
	if camera.has_method("set_scripted_pose"):
		camera.set_scripted_pose(target, yaw, pitch, dist)
	else:
		camera.set("target", target)
		camera.set("yaw", yaw)
		camera.set("pitch", pitch)
		camera.set("distance", dist)
		if camera.get("_zoom_goal") != null:
			camera.set("_zoom_goal", dist)
		if camera.has_method("_clamp_rig"):
			camera._clamp_rig()
		if camera.has_method("_apply"):
			camera._apply()


func _lerp_angle(a: float, b: float, t: float) -> float:
	return lerp_angle(a, b, t)
