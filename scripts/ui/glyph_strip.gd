class_name GlyphStrip
extends RefCounted
## Neutral action glyphs + verbs. No A/B/X/Y/LB/RB/View/L3/Start/Select text.
## Lookup is by InputMap / IGA action name. Paths: res://assets/ui/glyphs/deck/<action>.png
## GodotSteam is not in the tree — these are Deck-default fallbacks until Steamworks.

const DIR := "res://assets/ui/glyphs/deck/"

const FILES: Dictionary = {
	"pause": "pause.png",
	"confirm": "confirm.png",
	"cancel": "cancel.png",
	"paint": "paint.png",
	"radial": "radial.png",
	"brush": "brush.png",
	"orbit": "orbit.png",
	"zoom": "zoom.png",
	"pan": "pan.png",
	"heatmap": "heatmap.png",
}

const VERBS: Dictionary = {
	"pause": "Pause",
	"resume": "Resume",
	"confirm": "Bench",
	"cancel": "Back",
	"abort": "Abort",
	"paint": "Paint",
	"radial": "Tools",
	"brush": "Brush",
	"orbit": "Orbit",
	"zoom": "Zoom",
	"pan": "Pan",
	"heatmap": "Heatmap",
}

static var _tex: Dictionary = {}


static func texture(action: String) -> Texture2D:
	var key := action.strip_edges().to_lower()
	if key == "resume":
		key = "pause"
	if key == "abort" or key == "back" or key == "close":
		key = "cancel"
	if key == "tools":
		key = "radial"
	if _tex.has(key) and _tex[key] is Texture2D:
		return _tex[key]
	var file: String = str(FILES.get(key, ""))
	if file == "":
		return null
	var path := DIR + file
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				tex = ImageTexture.create_from_image(img)
	if tex:
		_tex[key] = tex
	return tex


static func path_of(action: String) -> String:
	var key := action.strip_edges().to_lower()
	if key == "resume":
		key = "pause"
	if key == "abort" or key == "back" or key == "close":
		key = "cancel"
	if key == "tools":
		key = "radial"
	var file: String = str(FILES.get(key, ""))
	if file == "":
		return ""
	return DIR + file


static func required_paths() -> PackedStringArray:
	return PackedStringArray([
		DIR + "pause.png",
		DIR + "confirm.png",
		DIR + "cancel.png",
		DIR + "paint.png",
		DIR + "radial.png",
		DIR + "brush.png",
		DIR + "orbit.png",
		DIR + "zoom.png",
		DIR + "pan.png",
		DIR + "heatmap.png",
	])


static func pair(action: String, verb: String, font_size: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.focus_mode = Control.FOCUS_NONE
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture(action)
	row.add_child(icon)
	var lab := Label.new()
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.focus_mode = Control.FOCUS_NONE
	lab.add_theme_font_size_override("font_size", font_size)
	lab.text = verb
	row.add_child(lab)
	_ignore_tree(row)
	return row


static func strip(pairs: Array, font_size: int = 18, sep: int = 14) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", sep)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in pairs:
		if typeof(p) != TYPE_ARRAY or p.size() < 2:
			continue
		box.add_child(pair(str(p[0]), str(p[1]), font_size))
	_ignore_tree(box)
	return box


static func fill(box: HBoxContainer, pairs: Array, font_size: int = 18) -> void:
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in pairs:
		if typeof(p) != TYPE_ARRAY or p.size() < 2:
			continue
		box.add_child(pair(str(p[0]), str(p[1]), font_size))
	_ignore_tree(box)


static func _ignore_tree(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_ignore_tree(c)
