extends Control
## Cheap gamepad radial for tools — no mouse hits required.

signal tool_hovered(index: int)

@export var radius: float = 118.0
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
var _hover: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 20


func set_open(v: bool) -> void:
	open = v
	visible = v
	if not v:
		_hover = -1
	queue_redraw()


func set_aim(v: Vector2) -> void:
	aim = v
	var idx := _aim_index()
	if idx != _hover:
		_hover = idx
		if idx >= 0:
			tool_hovered.emit(idx)
	queue_redraw()


func hovered_index() -> int:
	return _hover


func _aim_index() -> int:
	if aim.length() < 0.35:
		return -1
	var ang := atan2(aim.y, aim.x) + PI * 0.5
	if ang < 0.0:
		ang += TAU
	return int(floor(ang / TAU * float(slice_count))) % slice_count


func _draw() -> void:
	if not open:
		return
	var c := size * 0.5
	draw_circle(c, radius + 18.0, Color(0.05, 0.06, 0.08, 0.72))
	draw_arc(c, radius + 18.0, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 2.0, true)
	for i in slice_count:
		var a0 := -PI * 0.5 + TAU * float(i) / float(slice_count)
		var a1 := -PI * 0.5 + TAU * float(i + 1) / float(slice_count)
		var mid := (a0 + a1) * 0.5
		var selected := i == _hover
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
		var fs := 16 if selected else 14
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, label_pos - sz * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1 if selected else 0.85))
	if aim.length() > 0.2:
		draw_circle(c + aim.normalized() * (radius * 0.42), 7.0, Color(1, 1, 1, 0.95))
	draw_circle(c, 22.0, Color(0.08, 0.09, 0.11, 0.9))
	draw_string(ThemeDB.fallback_font, c + Vector2(-18, 5), "TOOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
