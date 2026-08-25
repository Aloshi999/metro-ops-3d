class_name Glyphs
extends Object
## Action-named Deck glyphs in assets/ui/glyphs/deck/. Fallback: face/shoulder icons.
## Player-facing help = glyph + verb only. Never A / B / X / Y / LB / RB / View / L3.

const DECK_DIR := "res://assets/ui/glyphs/deck/"
const DIR := "res://assets/ui/glyphs/"

const ALIASES := {
	"south": ["face_south", "south"],
	"east": ["face_east", "east"],
	"west": ["face_west", "west"],
	"north": ["face_north", "north"],
	"lb": ["shoulder_l", "lb"],
	"rb": ["shoulder_r", "rb"],
	"view": ["menu", "view"],
	"menu": ["menu", "view"],
	"stick_l": ["stick_l"],
	"stick_r": ["stick_r"],
	"stick_click": ["stick_click"],
	"dpad": ["dpad"],
	"confirm": ["confirm", "face_south", "south"],
	"cancel": ["cancel", "face_east", "east"],
	"paint": ["paint", "face_south", "south"],
	"radial": ["radial", "face_north", "north"],
	"brush": ["brush", "face_west", "west"],
	"orbit": ["orbit", "stick_r"],
	"zoom": ["zoom", "stick_r"],
	"pan": ["pan", "stick_l"],
	"heatmap": ["heatmap", "stick_click"],
	"tools": ["radial", "face_north", "north"],
	"pause": ["pause", "menu", "view"],
}

const SOUTH := Color(0.30, 0.78, 0.40, 1.0)
const EAST := Color(0.90, 0.32, 0.30, 1.0)
const WEST := Color(0.30, 0.52, 0.95, 1.0)
const NORTH := Color(0.95, 0.84, 0.22, 1.0)
const METAL := Color(0.62, 0.66, 0.72, 1.0)
const INK := Color(0.10, 0.12, 0.16, 1.0)

static var _cache: Dictionary = {}


static func required_paths() -> PackedStringArray:
	return PackedStringArray([
		DIR + "face_south.png",
		DIR + "face_east.png",
		DIR + "face_west.png",
		DIR + "face_north.png",
		DIR + "shoulder_l.png",
		DIR + "shoulder_r.png",
		DIR + "menu.png",
		DIR + "stick_l.png",
		DIR + "stick_r.png",
		DECK_DIR + "pause.png",
		DECK_DIR + "confirm.png",
		DECK_DIR + "cancel.png",
		DECK_DIR + "paint.png",
		DECK_DIR + "radial.png",
		DECK_DIR + "brush.png",
		DECK_DIR + "orbit.png",
		DECK_DIR + "zoom.png",
		DECK_DIR + "pan.png",
		DECK_DIR + "heatmap.png",
	])


static func tex(kind: String) -> Texture2D:
	var key := kind.strip_edges().to_lower()
	if _cache.has(key) and _cache[key] is Texture2D:
		return _cache[key]
	var keys: Array = ALIASES.get(key, [key])
	for k in keys:
		var p := ""
		if ResourceLoader.exists(DECK_DIR + str(k) + ".png") or FileAccess.file_exists(ProjectSettings.globalize_path(DECK_DIR + str(k) + ".png")):
			p = DECK_DIR + str(k) + ".png"
		else:
			p = DIR + str(k) + ".png"
		var t: Texture2D = null
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is Texture2D:
				t = res
		if t == null:
			var abs_path := ProjectSettings.globalize_path(p)
			if FileAccess.file_exists(abs_path):
				var img := Image.load_from_file(abs_path)
				if img:
					t = ImageTexture.create_from_image(img)
		if t:
			_cache[key] = t
			return t
	return null


static func make_chip(kind: String, caption: String, font_size: int = 18) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := tex(kind)
	if t:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.focus_mode = Control.FOCUS_NONE
		box.add_child(tr)
	var lab := Label.new()
	lab.text = caption
	lab.add_theme_font_size_override("font_size", font_size)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.focus_mode = Control.FOCUS_NONE
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lab)
	return box


static func fill_bar(bar: Control, chips: Array) -> void:
	if bar == null:
		return
	for c in bar.get_children():
		bar.remove_child(c)
		c.queue_free()
	for pair in chips:
		if typeof(pair) != TYPE_ARRAY or pair.size() < 2:
			continue
		bar.add_child(make_chip(str(pair[0]), str(pair[1]), 18))
	_ignore(bar)


static func _ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_ignore(c)


static func face(color: Color = SOUTH, size: int = 22) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size * 0.5
	var r := size * 0.42
	var r2 := r * r
	for y in size:
		for x in size:
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func confirm_tex(size: int = 22) -> Texture2D:
	return face(SOUTH, size)


static func back_tex(size: int = 22) -> Texture2D:
	return face(EAST, size)


static func tool_tex(size: int = 22) -> Texture2D:
	return face(NORTH, size)


static func help_title() -> String:
	return "Play · Exit"


static func help_play() -> String:
	return "Paint · Tools · Pause"


static func help_pause() -> String:
	return "Resume · Graphics · Pause"


static func help_graphics() -> String:
	return "Graphics · Abort · Pause"


static func help_bench() -> String:
	return "Abort"
