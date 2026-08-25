extends Control
## Cheap gamepad radial for tools — no mouse hits required.
## Drawn at viewport CENTER so the full pie is on-screen at 1280×800.

signal tool_hovered(index: int)

@export var radius: float = 140.0
@export var slice_count: int = 6

var open: bool = false
var aim: Vector2 = Vector2.ZERO
var labels: PackedStringArray = PackedStringArray([
	"Road", "R Zone", "C Zone", "I Zone", "Power", "Water"
])
var colors: Array[Color] = [
	Color(0.75, 0.75, 0.78),
	Color(0.35, 0.85, 0.45),
	Color(0.35, 0.55, 1.0),
	Color(0.95, 0.75, 0.25),
	Color(1.0, 0.9, 0.35),
	Color(0.35, 0.75, 1.0),
]
var sticky_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	open = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40


func set_open(v: bool) -> void:
	open = v
	visible = v
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if v:
		sticky_index = clampi(sticky_index, 0, slice_count - 1)
		var vp := get_viewport()
		if vp:
			vp.gui_release_focus()
	else:
		aim = Vector2.ZERO
	queue_redraw()


func set_aim(v: Vector2) -> void:
	aim = v
	var idx := _aim_index()
	if idx >= 0 and idx != sticky_index:
		sticky_index = idx
		tool_hovered.emit(idx)
	queue_redraw()


func set_index(idx: int) -> void:
	if slice_count <= 0:
		return
	sticky_index = posmod(idx, slice_count)
	tool_hovered.emit(sticky_index)
	queue_redraw()


func hovered_index() -> int:
	if not open:
		return -1
	return sticky_index


func _aim_index() -> int:
	if aim.length() < 0.35:
		return -1
	var ang := atan2(aim.y, aim.x) + PI * 0.5
	if ang < 0.0:
		ang += TAU
	return int(floor(ang / TAU * float(slice_count))) % slice_count


func _center() -> Vector2:
	## Never trust size==(0,0) (CanvasLayer child before layout) — that clips to top-left.
	var vp := get_viewport_rect().size
	if size.x >= 64.0 and size.y >= 64.0:
		vp = size
	# Slightly above geometric center so the pie sits above the help bar.
	return Vector2(vp.x * 0.5, vp.y * 0.46)


func _draw() -> void:
	if not open:
		return
	var c := _center()
	draw_circle(c, radius + 18.0, Color(0.05, 0.06, 0.08, 0.72))
	draw_arc(c, radius + 18.0, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 2.0, true)
	for i in slice_count:
		var a0 := -PI * 0.5 + TAU * float(i) / float(slice_count)
		var a1 := -PI * 0.5 + TAU * float(i + 1) / float(slice_count)
		var mid := (a0 + a1) * 0.5
		var selected := i == sticky_index
		var col: Color = colors[i % colors.size()]
		col.a = 0.95 if selected else 0.55
		var r0 := 36.0
		var r1 := radius + (10.0 if selected else 0.0)
		var pts := PackedVector2Array()
		pts.append(c + Vector2(cos(a0), sin(a0)) * r0)
		var steps := 8
		for s in range(steps + 1):
			var a := lerpf(a0, a1, float(s) / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * r1)
		pts.append(c + Vector2(cos(a1), sin(a1)) * r0)
		draw_colored_polygon(pts, col)
		var label_pos := c + Vector2(cos(mid), sin(mid)) * (radius * 0.68)
		var text: String = labels[i] if i < labels.size() else str(i)
		var font := ThemeDB.fallback_font
		var fs := 20 if selected else 18
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, label_pos - sz * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1 if selected else 0.85))
	if aim.length() > 0.2:
		draw_circle(c + aim.normalized() * (radius * 0.42), 7.0, Color(1, 1, 1, 0.95))
	draw_circle(c, 28.0, Color(0.08, 0.09, 0.11, 0.9))
	var caption := "TOOL"
	var cfs := 18
	var csz := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs)
	draw_string(ThemeDB.fallback_font, c - csz * 0.5, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(1, 1, 1, 0.9))
	var hint := "A confirm  ·  B / View close"
	var hsz := ThemeDB.fallback_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(ThemeDB.fallback_font, c + Vector2(-hsz.x * 0.5, radius + 44.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.85))
