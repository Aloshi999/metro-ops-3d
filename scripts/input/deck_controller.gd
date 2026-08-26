extends Node
## Gamepad-first Deck controls for the 3D city. Mouse only wins after real pointer motion.
## Gamepad-first. HUD uses action glyphs + verbs, never console button names.

signal paint_pressed
signal paint_released
signal cycle_next
signal cycle_prev
signal toggle_pause
signal open_menu
signal toggle_fps
signal war_pressed
signal disaster_pressed
signal radial_toggled(open: bool)
signal radial_select(index: int)
signal brush_cycled(size: int)
signal gfx_cycle(dir: int)
signal menu_row_shift(dir: int)
signal gfx_row(dir: int)
signal cancel_pressed
signal heatmap_toggled

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
var menu_focus: bool = false
var bench_blocking: bool = false

const BRUSH_STEPS: Array[int] = [1, 3, 5]
const RADIAL_SLICES: int = 6


func is_menu_exclusive() -> bool:
	## Single source of truth: title, pause, or graphics is up. City input is dead.
	return menu_focus or graphics_focus


func set_menu_exclusive(on: bool) -> void:
	menu_focus = on
	graphics_focus = on
	if on:
		_clear_city_vectors()
		if radial_open:
			_set_radial(false)
	else:
		painting = false


func _clear_city_vectors() -> void:
	pan_smooth = Vector2.ZERO
	pan_vector = Vector2.ZERO
	orbit_vector = Vector2.ZERO
	zoom_delta = 0.0
	radial_aim = Vector2.ZERO
	painting = false
	rmb_orbit = false


func _process(dt: float) -> void:
	if is_menu_exclusive():
		_clear_city_vectors()
		if mouse_active_until > 0.0:
			mouse_active_until = maxf(0.0, mouse_active_until - dt)
		return
	_update_pan()
	_update_look()
	_update_radial_aim()
	if mouse_active_until > 0.0:
		mouse_active_until = maxf(0.0, mouse_active_until - dt)


func _physics_process(_dt: float) -> void:
	if is_menu_exclusive():
		_clear_city_vectors()


func _update_pan() -> void:
	if is_menu_exclusive():
		_clear_city_vectors()
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
	if is_menu_exclusive():
		return
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
	if is_menu_exclusive():
		return
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


func _eat(_event: InputEvent = null) -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _is_keyboard_b(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_B or k.keycode == KEY_B
	return false


func _is_blockable_device(event: InputEvent) -> bool:
	return event is InputEventJoypadButton \
		or event is InputEventJoypadMotion \
		or event is InputEventKey \
		or event is InputEventMouseButton \
		or event is InputEventMouseMotion


func _is_menu_nav(event: InputEvent) -> bool:
	## Events that still drive title / pause / graphics while exclusive.
	if event is InputEventJoypadMotion:
		return false
	if event.is_action("paint") or event.is_action("cancel"):
		return true
	if InputMap.has_action("ui_accept") and event.is_action("ui_accept"):
		return true
	if InputMap.has_action("confirm") and event.is_action("confirm"):
		return true
	if event.is_action("pause_advisor") or event.is_action("view_resume"):
		return true
	if event.is_action("pan_up") or event.is_action("pan_down") \
			or event.is_action("pan_left") or event.is_action("pan_right"):
		return true
	if event.is_action("cycle_tool_next") or event.is_action("cycle_tool_prev"):
		return true
	if event is InputEventJoypadButton:
		var b: int = (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_A or b == JOY_BUTTON_B:
			return true
		if b == JOY_BUTTON_START or b == JOY_BUTTON_GUIDE or b == JOY_BUTTON_BACK:
			return true
		if b == JOY_BUTTON_DPAD_UP or b == JOY_BUTTON_DPAD_DOWN \
				or b == JOY_BUTTON_DPAD_LEFT or b == JOY_BUTTON_DPAD_RIGHT:
			return true
		if b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER:
			return true
	return false


func _is_menu_confirm_pressed(event: InputEvent) -> bool:
	## A / ui_accept / confirm / paint — Deck A is not always mapped as "paint".
	if event == null:
		return false
	if event.is_action_pressed("paint"):
		return true
	if InputMap.has_action("ui_accept") and event.is_action_pressed("ui_accept"):
		return true
	if InputMap.has_action("confirm") and event.is_action_pressed("confirm"):
		return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed and jb.button_index == JOY_BUTTON_A:
			return true
	return false


func _is_menu_confirm_released(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_released("paint"):
		return true
	if InputMap.has_action("ui_accept") and event.is_action_released("ui_accept"):
		return true
	if InputMap.has_action("confirm") and event.is_action_released("confirm"):
		return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if (not jb.pressed) and jb.button_index == JOY_BUTTON_A:
			return true
	return false


func _route_menu_event(event: InputEvent) -> bool:
	## Drive the overlay. Returns true if this event was a menu action.
	if _is_menu_confirm_pressed(event):
		painting = false
		paint_pressed.emit()
		return true
	if _is_menu_confirm_released(event):
		painting = false
		return true
	if event.is_action_pressed("pan_up"):
		menu_row_shift.emit(-1)
		if has_signal("gfx_row"):
			gfx_row.emit(-1)
		return true
	if event.is_action_pressed("pan_down"):
		menu_row_shift.emit(1)
		if has_signal("gfx_row"):
			gfx_row.emit(1)
		return true
	if event.is_action_pressed("pan_left") or event.is_action_pressed("cycle_tool_prev"):
		gfx_cycle.emit(-1)
		return true
	if event.is_action_pressed("pan_right") or event.is_action_pressed("cycle_tool_next"):
		gfx_cycle.emit(1)
		return true
	return false


func _input(event: InputEvent) -> void:
	## High-priority: radial cancel and pause so GUI focus can never trap Start/Esc/B.
	## Keyboard B is also brush_size — while bench is active it MUST abort, not cycle brush.
	if (bench_blocking or is_menu_exclusive()) and _is_keyboard_b(event):
		if radial_open:
			_set_radial(false)
		else:
			cancel_pressed.emit()
		_eat(event)
		return
	var cancel_hit := false
	if InputMap.has_action("cancel") and event.is_action_pressed("cancel"):
		cancel_hit = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		cancel_hit = true
	if cancel_hit:
		if radial_open:
			_set_radial(false)
			_eat(event)
			return
		cancel_pressed.emit()
		_eat(event)
		return
	if event.is_action_pressed("pause_advisor") or (
			event is InputEventJoypadButton and event.pressed
			and (event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_GUIDE)):
		if radial_open:
			_set_radial(false)
			_eat(event)
			return
		# Start / Menu / Esc — toggle pause (opens from play, closes from pause).
		toggle_pause.emit()
		open_menu.emit()
		_eat(event)
		return
	if event.is_action_pressed("view_resume"):
		if radial_open:
			_set_radial(false)
			_eat(event)
			return
		# View resumes (toggle). Steam overlay / QAM still work via FOCUS_OUT.
		toggle_pause.emit()
		_eat(event)
		return
	if is_menu_exclusive():
		if radial_open:
			_set_radial(false)
		if _route_menu_event(event):
			_eat(event)
			return
		if _is_blockable_device(event):
			## Sticks (JoypadMotion), Y/X, heatmap, war, mouse orbit — consumed.
			_eat(event)
		return
	if event.is_action_pressed("radial"):
		if bench_blocking:
			_eat(event)
			return
		if radial_open:
			_set_radial(false)
		else:
			_set_radial(true)
		_eat(event)
		return


func _unhandled_input(event: InputEvent) -> void:
	if is_menu_exclusive():
		if _route_menu_event(event):
			_eat(event)
			return
		if _is_blockable_device(event):
			_eat(event)
		return
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
			_eat(event)
		elif event.is_action_pressed("pan_left"):
			radial_index = posmod(radial_index - 1, RADIAL_SLICES)
			_eat(event)
		elif event.is_action_pressed("pan_right"):
			radial_index = posmod(radial_index + 1, RADIAL_SLICES)
			_eat(event)
		elif event.is_action_pressed("pan_up"):
			radial_index = posmod(radial_index - 1, RADIAL_SLICES)
			_eat(event)
		elif event.is_action_pressed("pan_down"):
			radial_index = posmod(radial_index + 1, RADIAL_SLICES)
			_eat(event)
		return

	if event.is_action_pressed("paint"):
		painting = true
		paint_pressed.emit()
		_eat(event)
	elif event.is_action_released("paint"):
		painting = false
		paint_released.emit()
		_eat(event)
	elif event.is_action_pressed("cycle_tool_next"):
		if bench_blocking:
			_eat(event)
			return
		gfx_cycle.emit(1)
		_eat(event)
	elif event.is_action_pressed("cycle_tool_prev"):
		if bench_blocking:
			_eat(event)
			return
		gfx_cycle.emit(-1)
		_eat(event)
	elif graphics_focus and event.is_action_pressed("pan_up"):
		menu_row_shift.emit(-1)
		if has_signal("gfx_row"):
			gfx_row.emit(-1)
		_eat(event)
	elif graphics_focus and event.is_action_pressed("pan_down"):
		menu_row_shift.emit(1)
		if has_signal("gfx_row"):
			gfx_row.emit(1)
		_eat(event)
	elif graphics_focus and event.is_action_pressed("pan_left"):
		gfx_cycle.emit(-1)
		_eat(event)
	elif graphics_focus and event.is_action_pressed("pan_right"):
		gfx_cycle.emit(1)
		_eat(event)
	elif event.is_action_pressed("brush_size"):
		if bench_blocking or is_menu_exclusive():
			cancel_pressed.emit()
			_eat(event)
			return
		_cycle_brush()
		_eat(event)
	elif event.is_action_pressed("toggle_fps"):
		toggle_fps.emit()
		_eat(event)
	elif event.is_action_pressed("toggle_heatmap"):
		heatmap_toggled.emit()
		_eat(event)
	elif event.is_action_pressed("trigger_war"):
		war_pressed.emit()
		_eat(event)
	elif event.is_action_pressed("trigger_disaster"):
		disaster_pressed.emit()
		_eat(event)


func using_mouse() -> bool:
	return (not prefer_gamepad) and mouse_active_until > 0.0


func _mark_gamepad() -> void:
	prefer_gamepad = true
	mouse_active_until = 0.0


func _mark_mouse() -> void:
	prefer_gamepad = false
	mouse_active_until = mouse_grab_seconds


func _cycle_brush() -> void:
	if bench_blocking or is_menu_exclusive():
		return
	var idx := BRUSH_STEPS.find(brush_size)
	if idx < 0:
		idx = 0
	brush_size = BRUSH_STEPS[(idx + 1) % BRUSH_STEPS.size()]
	brush_cycled.emit(brush_size)


func _set_radial(open: bool) -> void:
	if radial_open == open:
		return
	if open and (is_menu_exclusive() or bench_blocking):
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


func handle_brush_action() -> void:
	## Keyboard B is brush_size in play. Bench: abort (do not cycle 1→3). Pause: Back.
	if bench_blocking or is_menu_exclusive():
		cancel_pressed.emit()
		return
	_cycle_brush()


func handle_gamepad_b() -> void:
	if radial_open:
		_set_radial(false)
		return
	cancel_pressed.emit()
