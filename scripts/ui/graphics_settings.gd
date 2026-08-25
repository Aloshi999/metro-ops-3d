class_name GraphicsSettings
extends RefCounted
## Gamepad graphics cycle + save. Look lives in GraphicsPresets.apply.
## Builder/Controls detect+menu may replace boot later. Do not auto-up from Low.

const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")

const NAMES: PackedStringArray = ["low", "medium", "high", "ultra"]
const LABELS: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
const SAVE_PATH := "user://metro_ops_graphics.cfg"

var index: int = 0
var handheld: bool = false


func boot() -> void:
	handheld = _detect_handheld()
	index = GraphicsPresets.from_env(GraphicsPresets.Id.LOW)


func name() -> String:
	return NAMES[clampi(index, 0, NAMES.size() - 1)]


func label() -> String:
	return LABELS[clampi(index, 0, LABELS.size() - 1)]


func cycle(dir: int) -> String:
	index = posmod(index + dir, NAMES.size())
	_save()
	return name()


func apply(vp: Viewport, world: Node) -> void:
	if world != null and world.has_method("apply_graphics_preset"):
		world.apply_graphics_preset(index)
	else:
		GraphicsPresets.apply(world, vp, index)


func _detect_handheld() -> bool:
	if OS.has_feature("steam_deck"):
		return true
	var sz := DisplayServer.screen_get_size()
	if sz.x > 0 and sz.x <= 1280 and sz.y <= 800:
		return true
	return false


func _load_saved() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return -1
	var s := str(cfg.get_value("graphics", "preset", "")).to_lower()
	var i := NAMES.find(s)
	return i


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "preset", name())
	cfg.save(SAVE_PATH)
