class_name GraphicsSettings
extends RefCounted
## Gamepad graphics: preset + FPS cap + FSR. Look lives in GraphicsPresets.apply.
## Deck / first-run default is ALWAYS Low / 40 / FSR2 0.67. Ultra is a desktop menu pick.
## Saved FPS/FSR persist. Deck detect never promotes Ultra. No real DLSS (Godot 4.7).

const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")

const NAMES: PackedStringArray = ["low", "medium", "high", "ultra"]
const LABELS: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
const SAVE_PATH := "user://metro_ops_graphics.cfg"

const FPS_STEPS: Array[int] = [30, 40, 60, 0]
const FPS_LABELS: PackedStringArray = ["30", "40", "60", "Uncapped"]
const CAP_VALUES: Array[int] = [30, 40, 60, 0]
const CAP_LABELS: PackedStringArray = ["30", "40", "60", "Uncapped"]

const FSR_NAMES: PackedStringArray = ["off", "quality"]
const FSR_LABELS: PackedStringArray = ["Off", "On Quality"]
const FSR_SCALES: Array[float] = [1.0, 0.67]

var index: int = 0
var fps_cap: int = 40
var fsr_index: int = 1
var fsr_on: bool = true
var handheld: bool = false
var menu_row: int = 0
var cap_index: int = 1


func boot() -> void:
	handheld = _detect_handheld()
	index = GraphicsPresets.from_env(GraphicsPresets.Id.LOW)
	fps_cap = 40
	cap_index = 1
	fsr_index = 1
	fsr_on = true
	var had_save := FileAccess.file_exists(SAVE_PATH)
	_load()
	var metro_gfx := OS.get_environment("METRO_GRAPHICS").strip_edges()
	if not metro_gfx.is_empty():
		index = GraphicsPresets.id_from_name(metro_gfx)
	# Deck / first-run: ALWAYS Low / 40 / FSR2 0.67. Saved FPS/FSR persist.
	# Ultra is never the Deck default (FAIL 48.66/23.16).
	if handheld or OS.has_feature("steam_deck"):
		if not had_save and metro_gfx.is_empty():
			apply_deck_defaults()
		else:
			apply_deck_detect()
	_sync_cap_index()
	apply_fps()


func name() -> String:
	return NAMES[clampi(index, 0, NAMES.size() - 1)]


func label() -> String:
	return LABELS[clampi(index, 0, LABELS.size() - 1)]


func fps_label() -> String:
	return cap_label()


func cap_value() -> int:
	return fps_cap


func cap_label() -> String:
	var i := FPS_STEPS.find(fps_cap)
	if i < 0:
		return "Uncapped" if fps_cap <= 0 else str(fps_cap)
	return FPS_LABELS[i]


func fsr_name() -> String:
	return FSR_NAMES[clampi(fsr_index, 0, FSR_NAMES.size() - 1)]


func fsr_label() -> String:
	return FSR_LABELS[clampi(fsr_index, 0, FSR_LABELS.size() - 1)]


func cycle(dir: int) -> String:
	return cycle_preset(dir)


func cycle_preset(dir: int) -> String:
	var prev := index
	index = posmod(index + dir, NAMES.size())
	if handheld and index == GraphicsPresets.Id.ULTRA and prev != GraphicsPresets.Id.ULTRA:
		fsr_index = 1
		fsr_on = true
	_save()
	return name()


func cycle_fps(dir: int) -> int:
	return cycle_cap(dir)


func cycle_cap(dir: int) -> int:
	var i := FPS_STEPS.find(fps_cap)
	if i < 0:
		i = 1
	i = posmod(i + dir, FPS_STEPS.size())
	fps_cap = FPS_STEPS[i]
	cap_index = i
	apply_fps()
	_save()
	return fps_cap


func cycle_fsr(dir: int = 1) -> String:
	fsr_index = posmod(fsr_index + dir, FSR_NAMES.size())
	fsr_on = fsr_index != 0
	_save()
	return fsr_name()


func shift_row(dir: int) -> int:
	menu_row = posmod(menu_row + dir, 3)
	return menu_row


func set_fps_cap(fps: int) -> void:
	if fps != 0 and fps != 30 and fps != 40 and fps != 60:
		return
	fps_cap = fps
	_sync_cap_index()
	apply_fps()
	_save()


func apply_fps() -> void:
	Engine.max_fps = fps_cap


func apply_fsr(vp: Viewport) -> void:
	if vp == null:
		return
	var i := clampi(fsr_index, 0, FSR_NAMES.size() - 1)
	if i == 0:
		vp.scaling_3d_mode = 0
		vp.scaling_3d_scale = 1.0
		fsr_on = false
	else:
		vp.scaling_3d_mode = 2
		vp.scaling_3d_scale = FSR_SCALES[i]
		if "fsr_sharpness" in vp:
			vp.fsr_sharpness = 0.2
		fsr_on = true


func apply(vp: Viewport, world: Node) -> void:
	if world != null and world.has_method("apply_graphics_preset"):
		world.apply_graphics_preset(index)
	else:
		GraphicsPresets.apply(world, vp, index, 1 if handheld else 0)
	apply_fps()
	apply_fsr(vp)


func apply_deck_detect() -> void:
	## Deck-detect path. Never auto-up. Ultra is never the Deck default.
	handheld = true
	if index >= 3 or str(name()) == "ultra":
		index = 0


func apply_deck_defaults() -> void:
	## First-run / Deck boot profile. ALWAYS Low / 40 / FSR2 0.67.
	index = GraphicsPresets.Id.LOW
	fps_cap = 40
	fsr_index = 1
	fsr_on = true
	handheld = true
	_sync_cap_index()


func is_deck_like() -> bool:
	return _detect_handheld() or OS.has_feature("steam_deck")


func dlss_enabled() -> bool:
	## 0.1.6: never on. Godot 4.7 has no DLSS enum.
	return false


func show_dlss_row() -> bool:
	## NVIDIA Windows only. Hidden / forced-off on Deck, steam_deck, Linux.
	if OS.has_feature("steam_deck"):
		return false
	if OS.get_name() == "Linux":
		return false
	if is_deck_like():
		return false
	return OS.get_name() == "Windows"


func apply_dlss(_vp: Viewport = null) -> void:
	## Disabled hook labeled "DLSS — 0.1.7". Never set scaling_3d_mode to a fake DLSS.
	pass


func dlss_label() -> String:
	return "DLSS — 0.1.7"


func apply_bench_lock(vp: Viewport, world: Node) -> void:
	## Temporary Low / 40 / FSR2 0.67. Does not persist over the user's pick.
	if world != null and world.has_method("apply_graphics_preset"):
		world.apply_graphics_preset(GraphicsPresets.Id.LOW)
	else:
		GraphicsPresets.apply(world, vp, GraphicsPresets.Id.LOW)
	Engine.max_fps = 40
	if vp:
		vp.scaling_3d_mode = 2
		vp.scaling_3d_scale = 0.67
		vp.fsr_sharpness = 0.2


func _detect_handheld() -> bool:
	if OS.has_feature("steam_deck"):
		return true
	var sz := DisplayServer.screen_get_size()
	if sz.x > 0 and sz.x <= 1280 and sz.y <= 800:
		return true
	return false


func _sync_cap_index() -> void:
	var i := FPS_STEPS.find(fps_cap)
	cap_index = i if i >= 0 else 1


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var s := str(cfg.get_value("graphics", "preset", "")).to_lower()
	var pi := NAMES.find(s)
	if pi >= 0:
		index = pi
	if cfg.has_section_key("graphics", "fps_cap"):
		var raw = cfg.get_value("graphics", "fps_cap", 40)
		var n := 40
		if typeof(raw) == TYPE_STRING and str(raw).to_lower() == "uncapped":
			n = 0
		else:
			n = int(raw)
		if n == 0 or n == 30 or n == 40 or n == 60:
			fps_cap = n
	if cfg.has_section_key("graphics", "fsr"):
		var raw_f = cfg.get_value("graphics", "fsr", "quality")
		if typeof(raw_f) == TYPE_BOOL:
			fsr_index = 1 if bool(raw_f) else 0
		else:
			var f := str(raw_f).to_lower()
			if f == "0" or f == "off" or f == "false":
				fsr_index = 0
			elif f == "2" or f == "balanced" or f == "perf" or f == "quality" or f == "1" or f == "on":
				fsr_index = 1
			else:
				fsr_index = 1
		fsr_on = fsr_index != 0


func _load_saved() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return -1
	var s := str(cfg.get_value("graphics", "preset", "")).to_lower()
	return NAMES.find(s)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("graphics", "preset", name())
	cfg.set_value("graphics", "fps_cap", fps_cap)
	cfg.set_value("graphics", "fsr", fsr_name())
	cfg.save(SAVE_PATH)
