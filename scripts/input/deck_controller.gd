extends Node
## Gamepad-first Deck controls for the 3D city. Mouse only wins after real pointer motion.
## L-stick / WASD pan · R-stick orbit+zoom · A paint · L1/R1 cycle tools.

signal paint_pressed
signal paint_released
signal cycle_next
signal cycle_prev
signal toggle_pause
signal toggle_fps
signal war_pressed
signal disaster_pressed
signal radial_toggled(open: bool)
signal radial_select(index: int)
signal brush_cycled(size: int)
signal gfx_cycle(dir: int)

@export var pan_lerp: float = 0.22
@export var stick_deadzone: float = 0.22
@export var look_deadzone: float = 0.28
@export var mouse_grab_seconds: float = 0.45

var pan_vector: Vector2 = Vector2.ZERO
var pan_smooth: Vector2 = Vector2.ZERO
var orbit_vector: Vector2 = Vector2.ZERO
var zoom_delta: float = 0.0
var painting: bool = false
var radial_open: bool = false
var radial_aim: Vector2 = Vector2.ZERO
var radial_index: int = 0
var brush_size: int = 1
var prefer_gamepad: bool = true
var mouse_active_until: float = 0.0
var rmb_orbit: bool = false
var graphics_focus: bool = false

const BRUSH_STEPS: Array[int] = [1, 3, 5]
const RADIAL_SLICES: int = 6


func _process(dt: float) -> void:
	_update_pan()
	_update_look()
	_update_radial_aim()
	if mouse_active_until > 0.0:
		mouse_active_until = maxf(0.0, mouse_active_until - dt)


func _update_pan() -> void:
	if graphics_focus:
		pan_smooth = Vector2.ZERO
		pan_vector = Vector2.ZERO
		return
	var raw := Vector2.ZERO
	if not radial_open:
		if Input.is_action_pressed("pan_up"):
			raw.y -= 1
		if Input.is_action_pressed("pan_down"):
			raw.y += 1
		if Input.is_action_pressed("pan_left"):
			raw.x -= 1
		if Input.is_action_pressed("pan_right"):
			raw.x += 1
		var stick := Vector2(
			Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > stick_deadzone:
			var t := (stick.length() - stick_deadzone) / (1.0 - stick_deadzone)
			raw += stick.normalized() * clampf(t * t, 0.0, 1.0)
			_mark_gamepad()
	if raw.length() > 1.0:
		raw = raw.normalized()
	pan_smooth = pan_smooth.lerp(raw, pan_lerp)
	if pan_smooth.length() < 0.02 and raw == Vector2.ZERO:
		pan_smooth = Vector2.ZERO
	pan_vector = pan_smooth


func _update_look() -> void:
	orbit_vector = Vector2.ZERO
	zoom_delta = 0.0
	if radial_open:
		return
	if Input.is_action_pressed("zoom_in"):
		zoom_delta -= 1.0
	if Input.is_action_pressed("zoom_out"):
		zoom_delta += 1.0
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var look := Vector2(rx, ry)
	if look.length() > look_deadzone:
		_mark_gamepad()
		var t := (look.length() - look_deadzone) / (1.0 - look_deadzone)
		t = clampf(t, 0.0, 1.0)
		var shaped := look.normalized() * (t * t)
		orbit_vector = Vector2(-shaped.x, shaped.y * 0.55)
		zoom_delta += shaped.y * 1.05
	zoom_delta = clampf(zoom_delta, -1.85, 1.85)


func _update_radial_aim() -> void:
	radial_aim = Vector2.ZERO
	if not radial_open:
		return
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if stick.length() < stick_deadzone:
		stick = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
	if stick.length() > stick_deadzone:
		radial_aim = stick.normalized()
		_mark_gamepad()
		var idx := aim_to_index(radial_aim, RADIAL_SLICES)
		if idx >= 0:
			radial_index = idx
	# D-pad / WASD cycle the sticky index in _unhandled_input (no analog fight).


func _input(event: InputEvent) -> void:
	## High-priority: radial cancel and pause so GUI focus can never trap Start/Esc/B.
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		if radial_open:
			_set_radial(false)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause_advisor"):
		if radial_open:
			_set_radial(false)
			get_viewport().set_input_as_handled()
			return
		toggle_pause.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("radial"):
		if radial_open:
			_set_radial(false)
		else:
			_set_radial(true)
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 1.5:
			_mark_mouse()
		return
	if event is InputEventMouseButton and event.pressed:
		_mark_mouse()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rmb_orbit = true
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		rmb_orbit = false

	if radial_open:
		if event.is_action_pressed("paint"):
			_confirm_radial()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pan_left"):
			radial_index = posmod(radial_index - 1, RADIAL_SLICES)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pan_right"):
			radial_index = posmod(radial_index + 1, RADIAL_SLICES)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pan_up"):
			radial_index = posmod(radial_index - 1, RADIAL_SLICES)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pan_down"):
			radial_index = posmod(radial_index + 1, RADIAL_SLICES)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("paint"):
		painting = true
		paint_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("paint"):
		painting = false
		paint_released.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_tool_next"):
		# LB/RB: graphics cycle (tools stay on Y radial)
		gfx_cycle.emit(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_tool_prev"):
		gfx_cycle.emit(-1)
		get_viewport().set_input_as_handled()
	elif graphics_focus and event.is_action_pressed("pan_left"):
		gfx_cycle.emit(-1)
		get_viewport().set_input_as_handled()
	elif graphics_focus and event.is_action_pressed("pan_right"):
		gfx_cycle.emit(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("brush_size"):
		_cycle_brush()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fps"):
		toggle_fps.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("trigger_war"):
		war_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("trigger_disaster"):
		disaster_pressed.emit()
		get_viewport().set_input_as_handled()


func using_mouse() -> bool:
	return (not prefer_gamepad) and mouse_active_until > 0.0


func _mark_gamepad() -> void:
	prefer_gamepad = true
	mouse_active_until = 0.0


func _mark_mouse() -> void:
	prefer_gamepad = false
	mouse_active_until = mouse_grab_seconds


func _cycle_brush() -> void:
	var idx := BRUSH_STEPS.find(brush_size)
	if idx < 0:
		idx = 0
	brush_size = BRUSH_STEPS[(idx + 1) % BRUSH_STEPS.size()]
	brush_cycled.emit(brush_size)


func _set_radial(open: bool) -> void:
	if radial_open == open:
		return
	radial_open = open
	if open:
		painting = false
		radial_aim = Vector2.ZERO
		var vp := get_viewport()
		if vp:
			vp.gui_release_focus()
	radial_toggled.emit(open)


func _confirm_radial() -> void:
	if not radial_open:
		return
	var idx := radial_index
	if radial_aim.length() >= 0.35:
		var aimed := aim_to_index(radial_aim, RADIAL_SLICES)
		if aimed >= 0:
			idx = aimed
	_set_radial(false)
	if idx >= 0:
		radial_select.emit(idx)


static func aim_to_index(aim: Vector2, count: int) -> int:
	if aim.length() < 0.35 or count <= 0:
		return -1
	var ang := atan2(aim.y, aim.x)
	ang += PI * 0.5
	if ang < 0.0:
		ang += TAU
	return int(floor(ang / TAU * float(count))) % count
