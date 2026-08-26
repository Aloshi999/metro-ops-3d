extends CanvasLayer
## Cash HUD, tool strip, RCI, advisor side card, War/Disaster chips, optional FPS.
## Root is the Deck SafeArea: anchors full, offsets L48 T48 R-96 B-48.
## 0.1.8: same gold focus fill on every menu item. Title Play/Exit. Pause Resume/Exit/Graphics.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const AdvisorSystem = preload("res://scripts/systems/advisor_system.gd")
const Glyphs = preload("res://scripts/ui/glyphs.gd")

signal war_clicked
signal disaster_clicked
signal advisor_dismissed
signal resume_clicked
signal play_pressed
signal overlay_focus_out
signal overlay_focus_in
signal exit_clicked
signal graphics_opened

const GFX_ROWS: PackedStringArray = ["preset", "cap", "fsr"]

enum Screen { NONE, TITLE, PAUSE, GRAPHICS }

@onready var cash_label: Label = %CashLabel
@onready var flow_label: Label = %FlowLabel
@onready var tool_label: Label = %ToolLabel
@onready var rci_label: Label = %RciLabel
@onready var event_status: Label = %EventStatus
@onready var advisor_panel: PanelContainer = %AdvisorPanel
@onready var advisor_text: RichTextLabel = %AdvisorText
@onready var event_toast: PanelContainer = %EventToast
@onready var event_title: Label = %EventTitle
@onready var event_body: Label = %EventBody
@onready var fps_label: Label = %FpsLabel
@onready var help_label: Label = %HelpLabel
@onready var paused_label: Label = %PausedLabel
@onready var flash: ColorRect = %FlashRect
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var graphics_label: Label = %GraphicsLabel
@onready var graphics_menu: Control = get_node_or_null("%GraphicsScreen") as Control

var show_fps: bool = false
var _toast_timer: float = 0.0
var _flash_timer: float = 0.0
var _focus_armed: bool = false
var gfx_row: int = 0
var _gfx_preset: String = "Low"
var _gfx_cap: String = "40"
var _gfx_fsr: String = "On Quality"
var screen: int = Screen.NONE
var title_index: int = 0
var pause_index: int = 0
var quit_requested: bool = false
var would_quit: bool = false
var paused: bool = false
var menu_open: bool = false
var tree_paused: bool = false
var _brush_hidden: bool = false
var brush_chrome_hidden: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	event_toast.visible = false
	if paused_label:
		paused_label.visible = false
	if fps_label:
		fps_label.visible = false
	if pause_overlay:
		pause_overlay.visible = false
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flash:
		flash.visible = false
	if advisor_panel:
		advisor_panel.visible = false
		advisor_panel.modulate.a = 1.0
	_ensure_title_ui()
	_ensure_pause_menu()
	_ensure_graphics_menu()
	_force_mouse_ignore(get_node_or_null("Root"))
	# Arm after main.gd has connected — skip boot FOCUS_IN, never pause on advisor.
	call_deferred("_arm_focus_watch")
	_ensure_bench_ui()
	_paint_graphics_rows()
	_set_help(Glyphs.help_play())


func _force_mouse_ignore(n: Node) -> void:
	if n == null:
		return
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not n.is_in_group("menu_item"):
			(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_force_mouse_ignore(c)


func _process(dt: float) -> void:
	if show_fps:
		var cap := Engine.max_fps
		if cap <= 0:
			fps_label.text = "FPS %.0f / uncapped" % Engine.get_frames_per_second()
		else:
			fps_label.text = "FPS %.0f / target %d" % [Engine.get_frames_per_second(), cap]
	if _toast_timer > 0.0:
		_toast_timer -= dt
		if _toast_timer <= 0.0:
			event_toast.visible = false
	if _flash_timer > 0.0 and flash:
		_flash_timer -= dt
		flash.color.a = clampf(_flash_timer / 0.9, 0.0, 0.35)
		if _flash_timer <= 0.0:
			flash.visible = false


func set_cash(cash: int, income: int, upkeep: int) -> void:
	cash_label.text = "$%s" % _fmt(cash)
	var net := income - upkeep
	var sign_s: String = "+" if net >= 0 else ""
	flow_label.text = "Δ %s%d" % [sign_s, net]
	flow_label.modulate = Color(0.5, 1.0, 0.6) if net >= 0 else Color(1.0, 0.45, 0.4)


func set_tool(label: String, brush: int = 1) -> void:
	if _brush_hidden:
		tool_label.text = ""
		tool_label.visible = false
		return
	tool_label.visible = true
	var short := label
	if "Residential" in label:
		short = "R"
	elif "Commercial" in label:
		short = "C"
	elif "Industrial" in label:
		short = "I"
	elif "Power" in label:
		short = "Pwr"
	elif "Water" in label:
		short = "Wtr"
	elif "Road" in label:
		short = "Rd"
	tool_label.text = "%s %d×%d" % [short, brush, brush]


func set_rci(label: String) -> void:
	# Compact so War/Dis chips cannot clip the top bar.
	var s := label.replace("RCI demand  ", "").replace("RCI ", "")
	s = s.replace(" · ", " ").replace("%", "")
	rci_label.text = s


func set_graphics(label: String) -> void:
	_gfx_preset = label
	var line := label
	if _gfx_cap != "":
		line += " · %s" % _gfx_cap
	if graphics_label:
		graphics_label.text = line
	_paint_graphics_rows()


func set_graphics_menu(preset: String, cap: String, fsr: String) -> void:
	_gfx_preset = preset
	_gfx_cap = cap
	_gfx_fsr = fsr
	var line := "%s · %s" % [preset, cap]
	if graphics_label:
		graphics_label.text = line
	_paint_graphics_rows()


func graphics_row_ids() -> PackedStringArray:
	_ensure_graphics_menu()
	return GFX_ROWS.duplicate()


func graphics_focus_id() -> String:
	return GFX_ROWS[clampi(gfx_row, 0, GFX_ROWS.size() - 1)]


func set_graphics_state(preset_label: String, fps_label_s: String, fsr_label: String) -> void:
	set_graphics_menu(preset_label, fps_label_s, fsr_label)


func cycle_gfx_row(dir: int) -> int:
	return cycle_graphics_focus(dir)


func cycle_graphics_focus(dir: int) -> int:
	gfx_row = posmod(gfx_row + dir, GFX_ROWS.size())
	_paint_graphics_rows()
	return gfx_row


func request_quit() -> void:
	## P0 Exit. Flag first so headless smoke can intercept. Process dies on Deck.
	quit_requested = true
	would_quit = true
	exit_clicked.emit()
	OS.set_restart_on_exit(false)
	# Documented headless smoke guard: skip process death ONLY for
	# tests/smoke_headless.gd or --quit-smoke. Never the engine headless feature tag
	# — that tag is compiled into Linux templates and made Deck Exit a no-op.
	if Engine.is_editor_hint() or _is_headless_smoke():
		return
	if is_inside_tree() and get_tree():
		get_tree().quit()


func _is_headless_smoke() -> bool:
	## Smoke-only. A real Deck/Linux export never matches these tokens or this script.
	## Never use OS.has_feature("headless") — Linux export templates compile that tag in.
	for a in OS.get_cmdline_args():
		if a == "--quit-smoke" or a.contains("smoke_headless.gd"):
			return true
	for a in OS.get_cmdline_user_args():
		if a == "--quit-smoke" or a.contains("smoke_headless.gd"):
			return true
	var loop := Engine.get_main_loop()
	if loop and loop.get_script():
		if str(loop.get_script().resource_path).contains("smoke_headless"):
			return true
	return false


func _apply_menu_pause(p: bool) -> void:
	## Stop the city while a menu is up. HUD stays PROCESS_MODE_ALWAYS under tree.paused.
	paused = p
	menu_open = p
	tree_paused = p
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t: SceneTree = get_tree() if is_inside_tree() else null
	if t == null:
		t = Engine.get_main_loop() as SceneTree
	if t:
		t.paused = p
	_push_menu_exclusive()


func is_title_open() -> bool:
	return screen == Screen.TITLE


func is_pause_open() -> bool:
	return screen == Screen.PAUSE or screen == Screen.GRAPHICS


func is_graphics_open() -> bool:
	return screen == Screen.GRAPHICS


func is_graphics_screen() -> bool:
	return screen == Screen.GRAPHICS


func open_graphics_screen() -> void:
	show_graphics_screen()
	var gscr := get_node_or_null("%GraphicsScreen") as Control
	if gscr == null:
		gscr = find_child("GraphicsScreen", true, false) as Control
	if gscr:
		gscr.visible = true
	var prt := get_node_or_null("%PauseRoot") as Control
	if prt:
		prt.visible = false


func back_to_pause_root() -> void:
	show_pause()
	var gscr := get_node_or_null("%GraphicsScreen") as Control
	if gscr == null:
		gscr = find_child("GraphicsScreen", true, false) as Control
	if gscr:
		gscr.visible = false
	var prt := get_node_or_null("%PauseRoot") as Control
	if prt:
		prt.visible = true


func confirm_pause_item() -> String:
	var id := focused_action()
	activate_focused()
	return id


func is_menu_open() -> bool:
	return screen != Screen.NONE


func focused_action() -> String:
	if screen == Screen.TITLE:
		return "exit" if title_index == 1 else "play"
	if screen == Screen.GRAPHICS:
		return "graphics"
	if screen == Screen.PAUSE:
		if pause_index == 1:
			return "exit"
		if pause_index == 2:
			return "graphics"
		return "resume"
	return ""


func get_exit_control() -> Control:
	if screen == Screen.TITLE:
		return _title_exit()
	return _pause_exit()


func grab_default_focus() -> void:
	if screen == Screen.TITLE:
		title_index = 0
		_apply_title_focus()
	elif screen == Screen.PAUSE:
		pause_index = 0
		_apply_pause_focus()
	elif screen == Screen.GRAPHICS:
		_paint_graphics_rows()


func move_menu(dir: int) -> void:
	if screen == Screen.TITLE:
		title_index = posmod(title_index + dir, 2)
		_apply_title_focus()
	elif screen == Screen.PAUSE:
		# Resume (0) · Exit (1) · Graphics (2). One flick from Resume = Exit.
		pause_index = posmod(pause_index + dir, 3)
		_apply_pause_focus()
	elif screen == Screen.GRAPHICS:
		cycle_graphics_focus(dir)


func highlight_exit() -> void:
	## Cancel on title — highlight Exit, do not quit.
	if screen == Screen.TITLE:
		title_index = 1
		_apply_title_focus()
	elif screen == Screen.PAUSE:
		pause_index = 1
		_apply_pause_focus()


func activate_focused() -> void:
	if screen == Screen.TITLE:
		if title_index == 1:
			request_quit()
		else:
			play_pressed.emit()
	elif screen == Screen.PAUSE:
		var act := focused_action()
		if act == "exit":
			request_quit()
		elif act == "graphics":
			show_graphics_screen()
		elif act == "benchmark":
			pass
		else:
			# 0.1.8: A / confirm activates Resume (0.1.7 "A never unpauses" overridden).
			resume_clicked.emit()
			set_paused(false)
	elif screen == Screen.GRAPHICS:
		# A keeps the focused row selected; L/R already applied the value.
		_paint_graphics_rows()



func _push_menu_exclusive() -> void:
	## Tell City Controls a menu is up. Play / hide_title / set_paused(false) clears it.
	## MUST be true whenever screen != NONE so Deck A cannot paint the city.
	var on := screen != Screen.NONE
	var n := get_parent()
	var d: Node = null
	if n:
		d = n.get_node_or_null("DeckController")
		if d == null and n.get("deck") != null:
			d = n.deck as Node
	if d == null and is_inside_tree():
		var t := get_tree()
		if t and t.root:
			d = t.root.find_child("DeckController", true, false)
	if d == null:
		return
	if d.has_method("set_menu_exclusive"):
		d.set_menu_exclusive(on)
	else:
		d.set("menu_focus", on)
		d.set("graphics_focus", on)


func show_title() -> void:
	_ensure_title_ui()
	_ensure_pause_menu()
	screen = Screen.TITLE
	title_index = 0
	var title := _title_overlay()
	if title:
		title.visible = true
	if pause_overlay:
		pause_overlay.visible = false
	if paused_label:
		paused_label.visible = false
	_set_play_chrome(false)
	_set_help(Glyphs.help_title())
	_claim_visible_menu_buttons()
	_apply_title_focus()
	_apply_menu_pause(true)
	call_deferred("_deferred_title_focus")


func hide_title() -> void:
	var title := _title_overlay()
	if title:
		title.visible = false
	if screen == Screen.TITLE:
		screen = Screen.NONE
	_set_play_chrome(true)
	_set_help(Glyphs.help_play())
	_apply_menu_pause(false)


func show_pause() -> void:
	_ensure_pause_menu()
	_ensure_graphics_menu()
	screen = Screen.PAUSE
	pause_index = 0
	var title := _title_overlay()
	if title:
		title.visible = false
	if pause_overlay:
		pause_overlay.visible = true
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if paused_label:
		paused_label.visible = true
	_show_pause_items(true)
	_show_graphics_items(false)
	_set_help(Glyphs.help_pause())
	_set_play_chrome(false)
	_claim_visible_menu_buttons()
	_apply_pause_focus()
	_apply_menu_pause(true)
	call_deferred("_deferred_pause_focus")


func show_graphics_screen() -> void:
	_ensure_graphics_menu()
	screen = Screen.GRAPHICS
	if pause_overlay:
		pause_overlay.visible = true
	_show_pause_items(false)
	_show_graphics_items(true)
	_set_help(Glyphs.help_graphics())
	# Do not gui_release_focus — paint the focused gfx row and keep it.
	_paint_graphics_rows()
	graphics_opened.emit()
	_apply_menu_pause(true)
	call_deferred("_deferred_graphics_focus")


func back_from_menu() -> String:
	## Cancel while a menu is open. Returns the screen we landed on.
	if screen == Screen.GRAPHICS:
		show_pause()
		return "pause"
	if screen == Screen.PAUSE:
		return "pause"
	if screen == Screen.TITLE:
		highlight_exit()
		return "title"
	return "play"


func _ensure_title_ui() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	var overlay := root.get_node_or_null("TitleOverlay") as Control
	if overlay == null:
		overlay = Control.new()
		overlay.name = "TitleOverlay"
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = 0.0
		overlay.offset_top = 0.0
		overlay.offset_right = 0.0
		overlay.offset_bottom = 0.0
		overlay.z_index = 70
		root.add_child(overlay)
	var dim := overlay.get_node_or_null("TitleDim") as ColorRect
	if dim == null:
		dim = ColorRect.new()
		dim.name = "TitleDim"
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.02, 0.03, 0.05, 0.55)
		overlay.add_child(dim)
	var box := overlay.get_node_or_null("TitleBox") as VBoxContainer
	if box == null:
		box = VBoxContainer.new()
		box.name = "TitleBox"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.offset_left = -260.0
		box.offset_top = -200.0
		box.offset_right = 260.0
		box.offset_bottom = 200.0
		box.add_theme_constant_override("separation", 16)
		overlay.add_child(box)
	if box.get_node_or_null("TitleName") == null:
		var name_l := Label.new()
		name_l.name = "TitleName"
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.focus_mode = Control.FOCUS_NONE
		name_l.add_theme_font_size_override("font_size", 36)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.text = "METRO OPS 3D"
		box.add_child(name_l)
	if box.get_node_or_null("TitleSub") == null:
		var sub := Label.new()
		sub.name = "TitleSub"
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.focus_mode = Control.FOCUS_NONE
		sub.add_theme_font_size_override("font_size", 18)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.modulate = Color(0.78, 0.84, 0.90, 1.0)
		sub.text = "First District"
		box.add_child(sub)
	_ensure_menu_button(box, "PlayButton", "Play", _on_play_pressed)
	_ensure_menu_button(box, "TitleExit", "Exit", _on_exit_pressed)
	if box.get_node_or_null("TitleHint") == null:
		var hint := Label.new()
		hint.name = "TitleHint"
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.focus_mode = Control.FOCUS_NONE
		hint.add_theme_font_size_override("font_size", 18)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.text = Glyphs.help_title()
		box.add_child(hint)


func _ensure_pause_menu() -> void:
	if pause_overlay == null:
		return
	var box := _pause_box()
	if box == null:
		box = VBoxContainer.new()
		box.name = "PauseRoot"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.offset_left = -260.0
		box.offset_top = -200.0
		box.offset_right = 260.0
		box.offset_bottom = 200.0
		box.add_theme_constant_override("separation", 10)
		pause_overlay.add_child(box)
	box.visible = true
	_mute_leftover_pause_box()
	var leftover := pause_overlay.get_node_or_null("PauseBox") as Control
	if leftover and leftover != box:
		leftover.visible = false
		leftover.focus_mode = Control.FOCUS_NONE
		for ch in leftover.get_children():
			if ch is Control:
				(ch as Control).unique_name_in_owner = false
				(ch as Control).visible = false
				(ch as Control).focus_mode = Control.FOCUS_NONE
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := box.get_node_or_null("PauseTitle") as Label
	if title == null:
		title = box.get_node_or_null("PauseRootTitle") as Label
	if title == null:
		title = Label.new()
		title.name = "PauseTitle"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 28)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		box.move_child(title, 0)
	title.text = "PAUSED"
	_ensure_menu_button(box, "ResumeButton", "Resume", _on_resume_pressed)
	resume_button = box.get_node_or_null("ResumeButton") as Button
	_ensure_menu_button(box, "ExitButton", "Exit", _on_exit_pressed)
	_ensure_menu_button(box, "GraphicsButton", "Graphics", _on_graphics_pressed)
	for extra in ["AudioButton", "ControlsButton", "Item_audio", "Item_controls", "Item_benchmark", "Item_resume", "Item_exit", "Item_graphics"]:
		var ex := box.get_node_or_null(extra) as CanvasItem
		if ex:
			ex.visible = false
	var resume_n := box.get_node_or_null("ResumeButton")
	var exit_n := box.get_node_or_null("ExitButton")
	var gfx_n := box.get_node_or_null("GraphicsButton")
	var insert_at := 1 if title else 0
	if resume_n:
		box.move_child(resume_n, insert_at)
	if exit_n:
		box.move_child(exit_n, insert_at + 1)
	if gfx_n:
		box.move_child(gfx_n, insert_at + 2)
	var hint := box.get_node_or_null("PauseHint") as Label
	if hint:
		hint.text = Glyphs.help_pause()


func _ensure_menu_button(box: Node, node_name: String, caption: String, cb: Callable) -> Button:
	var b := box.get_node_or_null(node_name) as Button
	if b == null:
		b = Button.new()
		b.name = node_name
		box.add_child(b)
	b.text = caption
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 24)
	_paint_menu_button(b, false)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_ALL
	b.visible = true
	if not b.is_in_group("menu_item"):
		b.add_to_group("menu_item")
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)
	# Unique name so smoke can %Find
	if not b.unique_name_in_owner:
		b.unique_name_in_owner = true
	return b


func _title_overlay() -> Control:
	return get_node_or_null("Root/TitleOverlay") as Control


func _title_play() -> Button:
	return _find_visible_button("PlayButton")


func _title_exit() -> Button:
	return _find_visible_button("TitleExit")


func _pause_exit() -> Button:
	return _find_visible_button("ExitButton")


func _graphics_button() -> Button:
	return _find_visible_button("GraphicsButton")


func _apply_title_focus() -> void:
	_claim_visible_menu_buttons()
	var play_b := _title_play()
	var exit_b := _title_exit()
	_paint_menu_button(play_b, title_index == 0)
	_paint_menu_button(exit_b, title_index == 1)
	var target := play_b if title_index == 0 else exit_b
	_grab_row(target)


func _pause_item(node_name: String) -> Button:
	if pause_overlay == null:
		return null
	var root := pause_overlay.get_node_or_null("PauseRoot") as Control
	if root:
		var b := root.get_node_or_null(node_name) as Button
		if b:
			return b
	return pause_overlay.find_child(node_name, true, false) as Button


func _pause_resume() -> Button:
	return _find_visible_button("ResumeButton")


func _apply_pause_focus() -> void:
	_claim_visible_menu_buttons()
	var resume_b := _pause_resume()
	resume_button = resume_b
	var exit_b := _pause_exit()
	var gfx_b := _graphics_button()
	_paint_menu_button(resume_b, pause_index == 0)
	_paint_menu_button(exit_b, pause_index == 1)
	_paint_menu_button(gfx_b, pause_index == 2)
	var target: Button = resume_b
	if pause_index == 1:
		target = exit_b
	elif pause_index == 2:
		target = gfx_b
	_grab_row(target)


func _is_under_leftover_pause_box(n: Node) -> bool:
	var p: Node = n
	while p:
		if p.name == "PauseBox":
			return true
		p = p.get_parent()
	return false


func _collect_buttons_named(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name and n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons_named(c, node_name, out)


func _find_visible_button(node_name: String) -> Button:
	## Prefer the control Allawi actually sees. Skip leftover PauseBox / hidden copies.
	var hits: Array = []
	_collect_buttons_named(self, node_name, hits)
	var fallback: Button = null
	for item in hits:
		var b := item as Button
		if b == null or _is_under_leftover_pause_box(b):
			continue
		if fallback == null:
			fallback = b
		if b.is_inside_tree() and b.is_visible_in_tree():
			return b
	if fallback:
		return fallback
	var uniq := get_node_or_null("%" + node_name) as Button
	if uniq and not _is_under_leftover_pause_box(uniq):
		return uniq
	return null


func _mute_leftover_pause_box() -> void:
	if pause_overlay == null:
		return
	var live := _pause_box()
	var leftover := pause_overlay.get_node_or_null("PauseBox") as Control
	if leftover and leftover != live:
		leftover.visible = false
		leftover.focus_mode = Control.FOCUS_NONE
		leftover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in leftover.get_children():
			if ch is Control:
				var c := ch as Control
				c.unique_name_in_owner = false
				c.visible = false
				c.focus_mode = Control.FOCUS_NONE
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if live:
		for extra in ["AudioButton", "ControlsButton", "Item_audio", "Item_controls", "Item_benchmark", "Item_resume", "Item_exit", "Item_graphics", "ItemGraphics"]:
			var ex := live.get_node_or_null(extra)
			if ex is Control:
				(ex as Control).visible = false
				(ex as Control).focus_mode = Control.FOCUS_NONE
				(ex as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _claim_visible_menu_buttons() -> void:
	## Look's tscn buttons may not be in group menu_item — _force_mouse_ignore
	## then sets FOCUS_NONE and grab_focus is a no-op (no gold box on Deck).
	_mute_leftover_pause_box()
	var names: PackedStringArray = ["PlayButton", "TitleExit", "ResumeButton", "ExitButton", "GraphicsButton"]
	for nm in names:
		var b := _find_visible_button(nm)
		if b == null:
			continue
		if not b.is_in_group("menu_item"):
			b.add_to_group("menu_item")
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.visible = true


func _deferred_title_focus() -> void:
	_claim_visible_menu_buttons()
	_apply_title_focus()


func _deferred_pause_focus() -> void:
	_claim_visible_menu_buttons()
	_apply_pause_focus()


func _deferred_graphics_focus() -> void:
	_paint_graphics_rows()


func _grab_row(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.visible = true
	c.focus_mode = Control.FOCUS_ALL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not c.is_in_group("menu_item"):
		c.add_to_group("menu_item")
	c.grab_focus()
	if not c.has_focus():
		c.call_deferred("grab_focus")


func _menu_style(on: bool) -> StyleBoxFlat:
	## Same selected chrome on every item. Gold fill + 4px ring, not a 1px outline.
	var s := StyleBoxFlat.new()
	if on:
		s.bg_color = Color(1.0, 0.84, 0.14, 1.0)
		s.border_color = Color(1.0, 1.0, 1.0, 1.0)
		s.set_border_width_all(4)
	else:
		s.bg_color = Color(0.08, 0.10, 0.14, 0.94)
		s.border_color = Color(0.52, 0.58, 0.68, 0.55)
		s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 12.0
	return s


func _paint_menu_button(b: Button, on: bool) -> void:
	## One selected style for Play / Exit / Resume / Graphics / gfx rows. No Exit special-case.
	if b == null:
		return
	b.visible = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate = Color.WHITE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 24)
	var box := _menu_style(on)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(key, box)
	var ink := Color(0.08, 0.07, 0.03, 1.0) if on else Color(0.90, 0.93, 0.97, 1.0)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, ink)


func _show_pause_items(vis: bool) -> void:
	_ensure_pause_menu()
	var box := _pause_box()
	if box:
		box.visible = vis
	var leftover := pause_overlay.get_node_or_null("PauseBox") as Control if pause_overlay else null
	if leftover and leftover != box:
		leftover.visible = false
	var title := box.get_node_or_null("PauseTitle") as Label if box else null
	if title:
		title.visible = vis
		title.text = "PAUSED"
	resume_button = _pause_resume()
	if resume_button:
		resume_button.visible = vis
		resume_button.focus_mode = Control.FOCUS_ALL if vis else Control.FOCUS_NONE
		resume_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var exit_b := _pause_exit()
	if exit_b:
		exit_b.visible = vis
	var gfx_b := _graphics_button()
	if gfx_b:
		gfx_b.visible = vis
	var audio_b := get_node_or_null("%AudioButton") as Button
	if audio_b:
		audio_b.visible = false
	var ctrl_b := get_node_or_null("%ControlsButton") as Button
	if ctrl_b:
		ctrl_b.visible = false
	var hint := box.get_node_or_null("PauseHint") as Label if box else null
	if hint:
		hint.visible = vis
		hint.text = Glyphs.help_pause()


func _show_graphics_items(vis: bool) -> void:
	_ensure_graphics_menu()
	var gscr := get_node_or_null("%GraphicsScreen") as Control
	if gscr == null and pause_overlay:
		gscr = pause_overlay.find_child("GraphicsScreen", true, false) as Control
	if gscr:
		graphics_menu = gscr
	if graphics_menu:
		graphics_menu.visible = vis
	var box := _pause_box()
	if box:
		box.visible = not vis
	var leftover := pause_overlay.get_node_or_null("PauseBox") as Control if pause_overlay else null
	if leftover and leftover != box:
		leftover.visible = false


func _set_play_chrome(vis: bool) -> void:
	var top := get_node_or_null("Root/TopBar") as Control
	if top:
		top.visible = vis
	if advisor_panel:
		advisor_panel.visible = vis
	var goal := get_node_or_null("%GoalPanel") as Control
	if goal:
		goal.visible = vis
	var reticle := get_node_or_null("%Reticle") as Control
	if reticle:
		reticle.visible = vis


func set_help_play() -> void:
	_set_help(Glyphs.help_play())
	_fill_help_chips([
		["paint", "Paint"],
		["radial", "Tools"],
		["brush", "Brush"],
		["pause", "Pause"],
		["heatmap", "Heatmap"],
	])


func set_help_bench() -> void:
	_set_help(Glyphs.help_bench())
	_fill_help_chips([["cancel", "Abort"]])


func _set_help(text: String) -> void:
	if help_label:
		help_label.visible = false
		help_label.text = text
	if text == Glyphs.help_play():
		_fill_help_chips([
			["paint", "Paint"],
			["radial", "Tools"],
			["brush", "Brush"],
			["pause", "Pause"],
			["heatmap", "Heatmap"],
		])
	elif text == Glyphs.help_bench():
		_fill_help_chips([["cancel", "Abort"]])
	elif text == Glyphs.help_pause():
		_fill_help_chips([["pause", "Resume"], ["cancel", "Back"]])
	elif text == Glyphs.help_graphics():
		_fill_help_chips([["cancel", "Back"], ["pause", "Resume"]])
	elif text == Glyphs.help_title():
		_fill_help_chips([["confirm", "Play"], ["cancel", "Exit"]])
	else:
		_fill_help_chips([])


func _ensure_help_strip() -> HBoxContainer:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return null
	var strip := root.get_node_or_null("HelpStrip") as HBoxContainer
	if strip == null:
		strip = HBoxContainer.new()
		strip.name = "HelpStrip"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 14)
		strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		strip.anchor_left = 0.0
		strip.anchor_top = 1.0
		strip.anchor_right = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = 0.0
		strip.offset_top = -40.0
		strip.offset_right = 0.0
		strip.offset_bottom = 0.0
		root.add_child(strip)
	return strip


func _fill_help_chips(pairs: Array) -> void:
	var strip := _ensure_help_strip()
	if strip == null:
		return
	GlyphStrip.fill(strip, pairs, 18)
	strip.visible = pairs.size() > 0


func _on_play_pressed() -> void:
	## ui_accept may land on the wrong Button; index + highlight own the action.
	activate_focused()


func _on_graphics_pressed() -> void:
	activate_focused()


func _on_exit_pressed() -> void:
	activate_focused()


func _ensure_graphics_menu() -> void:
	if pause_overlay == null:
		return
	var box := _pause_box()
	var menu := pause_overlay.get_node_or_null("GraphicsScreen") as Control
	if menu == null:
		var host := pause_overlay.get_node_or_null("MenuHost") as Control
		if host:
			menu = host.get_node_or_null("GraphicsScreen") as Control
	if menu == null and box:
		menu = box.get_node_or_null("GraphicsScreen") as Control
	if menu == null and box:
		menu = box.get_node_or_null("GraphicsMenu") as Control
	if menu == null:
		menu = VBoxContainer.new()
		menu.name = "GraphicsScreen"
		menu.unique_name_in_owner = true
		menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(menu as VBoxContainer).add_theme_constant_override("separation", 8)
		var hint := box.get_node_or_null("PauseHint")
		if hint:
			box.add_child(menu)
			box.move_child(menu, hint.get_index())
		else:
			box.add_child(menu)
	if menu.get_node_or_null("GraphicsHeader") == null:
		var header := Label.new()
		header.name = "GraphicsHeader"
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.focus_mode = Control.FOCUS_NONE
		header.add_theme_font_size_override("font_size", 28)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.text = "GRAPHICS"
		menu.add_child(header)
		menu.move_child(header, 0)
	_ensure_gfx_row(menu, "RowPreset", "Preset     < Low >")
	_ensure_gfx_row(menu, "RowCap", "FPS cap    < 40 >")
	_ensure_gfx_row(menu, "RowFsr", "FSR        < On >")

	# DLSS row hook (hidden on Linux / Deck). Labeled 0.1.7, never a live scaler.
	if menu.get_node_or_null("RowDlss") == null:
		var dl := Label.new()
		dl.name = "RowDlss"
		dl.visible = false
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dl.text = "DLSS — 0.1.7"
		menu.add_child(dl)
	graphics_menu = menu
	# Hidden on the pause list — this is a real SCREEN, not a HUD one-liner.
	if screen != Screen.GRAPHICS:
		menu.visible = false


func _ensure_gfx_row(menu: Control, row_name: String, text: String) -> void:
	var n := menu.get_node_or_null(row_name)
	if n is Button:
		var existing := n as Button
		if not existing.is_in_group("menu_item"):
			existing.add_to_group("menu_item")
		existing.focus_mode = Control.FOCUS_ALL
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.visible = true
		return
	if n != null:
		n.name = row_name + "_old"
		if n is Control:
			var oldc := n as Control
			oldc.visible = false
			oldc.focus_mode = Control.FOCUS_NONE
			oldc.unique_name_in_owner = false
		n.queue_free()
	var b := Button.new()
	b.name = row_name
	b.text = text
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_ALL
	b.unique_name_in_owner = true
	if not b.is_in_group("menu_item"):
		b.add_to_group("menu_item")
	menu.add_child(b)
	_paint_menu_button(b, false)


func _paint_graphics_rows() -> void:
	_ensure_graphics_menu()
	var menu := graphics_menu
	if menu == null:
		return
	var vals: PackedStringArray = [_gfx_preset, _gfx_cap, _gfx_fsr]
	var titles: PackedStringArray = ["Preset", "FPS cap", "FSR"]
	var nodes: PackedStringArray = ["RowPreset", "RowCap", "RowFsr"]
	for i in nodes.size():
		var row := menu.get_node_or_null(nodes[i])
		if row == null:
			continue
		var mark := "▸ " if i == gfx_row else "  "
		var line := "%s%s     < %s >" % [mark, titles[i], vals[i]]
		if row is Button:
			(row as Button).text = line
			_paint_menu_button(row as Button, i == gfx_row)
			if i == gfx_row:
				_grab_row(row as Button)
		elif row is Label:
			(row as Label).text = line
			(row as Label).add_theme_font_size_override("font_size", 24)
			(row as Label).modulate = Color.WHITE


func set_occupancy(pct: float) -> void:
	var occ := get_node_or_null("%OccLabel") as Label
	if occ:
		occ.text = "Occ %.0f%%" % pct


func set_happiness(h: float) -> void:
	var mood := get_node_or_null("%MoodLabel") as Label
	if mood:
		mood.text = "Mood %.0f%%" % (clampf(h, 0.0, 1.0) * 100.0)


func set_event_status(war_timer: int, disaster_timer: int) -> void:
	var bits: PackedStringArray = []
	if war_timer > 0:
		bits.append("WAR %d" % war_timer)
	if disaster_timer > 0:
		bits.append("DISASTER %d" % disaster_timer)
	if event_status:
		event_status.text = "  ·  ".join(bits)
		event_status.visible = bits.size() > 0
		event_status.modulate = Color(1.0, 0.55, 0.4) if war_timer > 0 else Color(1.0, 0.75, 0.35)


func set_advisor(messages: Array) -> void:
	var bb := ""
	var shown := 0
	for m in messages:
		if shown >= 2:
			break
		shown += 1
		var sev: int = m.get("sev", 0)
		var t: String = m.get("text", "")
		match sev:
			AdvisorSystem.Severity.BLOCK:
				bb += "[color=#ff6b6b]⛔ %s[/color]\n" % t
			AdvisorSystem.Severity.WARN:
				bb += "[color=#ffd93d]⚠ %s[/color]\n" % t
			_:
				bb += "[color=#a0e7a0]ℹ %s[/color]\n" % t
	advisor_text.text = bb
	if advisor_text:
		advisor_text.fit_content = true
		advisor_text.scroll_active = false
		advisor_text.size_flags_vertical = 0
	if advisor_panel:
		if shown <= 0 or screen == Screen.TITLE:
			advisor_panel.visible = false
			advisor_panel.custom_minimum_size = Vector2(300, 0)
			advisor_panel.size = Vector2(300, 0)
			return
		advisor_panel.visible = true
		advisor_panel.modulate.a = 1.0
		var h: float = clampf(44.0 + float(mini(shown, 4)) * 22.0 + 12.0, 72.0, 160.0)
		advisor_panel.custom_minimum_size = Vector2(300, h)
		advisor_panel.size = Vector2(300, h)


func set_paused(p: bool) -> void:
	# Advisor stays a side card. Pause is a screen — Resume / Exit / Graphics.
	if paused_label == null:
		paused_label = get_node_or_null("%PausedLabel") as Label
	if paused_label:
		paused_label.visible = false  # pause is a SCREEN, not this one-liner
	_set_pause_bench_hint(p)
	if advisor_panel and (advisor_text == null or advisor_text.text.strip_edges() == ""):
		advisor_panel.visible = false
	if p:
		show_pause()
	else:
		if screen == Screen.PAUSE or screen == Screen.GRAPHICS:
			screen = Screen.NONE
		if pause_overlay:
			pause_overlay.visible = false
			pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if resume_button:
			resume_button.visible = false
			resume_button.focus_mode = Control.FOCUS_NONE
			resume_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := get_viewport()
		if vp:
			vp.gui_release_focus()
		_set_help(Glyphs.help_play())
		_set_play_chrome(true)
		_apply_menu_pause(false)
	# Arm after main.gd has connected — skip boot FOCUS_IN, never pause on advisor.
	call_deferred("_arm_focus_watch")
	_paint_graphics_rows()


func toggle_fps_overlay() -> void:
	show_fps = not show_fps
	fps_label.visible = show_fps


func show_event(title: String, body: String) -> void:
	if event_title:
		event_title.text = title
	if event_body:
		event_body.text = body
	if event_toast:
		event_toast.visible = true
	_toast_timer = 5.0
	_keep_in_safe()


func flash_color(c: Color) -> void:
	if flash == null:
		return
	flash.color = Color(c.r, c.g, c.b, 0.32)
	flash.visible = true
	_flash_timer = 0.9


func set_goal(card: Dictionary) -> void:
	var panel := get_node_or_null("%GoalPanel") as Control
	var title := get_node_or_null("%GoalTitle") as Label
	var body := get_node_or_null("%GoalBody") as Label
	if title:
		title.text = str(card.get("title", "Act I — First District"))
		title.add_theme_font_size_override("font_size", 28)
	if body:
		body.text = str(card.get("body", ""))
		body.add_theme_font_size_override("font_size", 18)
	if panel:
		panel.visible = screen != Screen.TITLE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(0, 0)
		if panel.size.y > 140.0:
			panel.size.y = 140.0
	_keep_in_safe()


func set_heatmap(label: String) -> void:
	var heat := get_node_or_null("%HeatLabel") as Label
	if heat:
		heat.text = "Heatmap %s" % label
		heat.add_theme_font_size_override("font_size", 18)
	var box := heat.get_parent() if heat else null
	if box:
		var icon := box.get_node_or_null("HeatGlyph") as TextureRect
		if icon == null:
			icon = TextureRect.new()
			icon.name = "HeatGlyph"
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.focus_mode = Control.FOCUS_NONE
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)
			box.move_child(icon, heat.get_index() if heat else 0)
		icon.texture = GlyphStrip.texture("heatmap")


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out


func _on_war_button_pressed() -> void:
	war_clicked.emit()


func _on_disaster_button_pressed() -> void:
	disaster_clicked.emit()


func _on_advisor_close_pressed() -> void:
	advisor_dismissed.emit()


func _on_resume_pressed() -> void:
	activate_focused()


func _arm_focus_watch() -> void:
	_focus_armed = true


func _notification(what: int) -> void:
	if not _focus_armed:
		return
	# Steam overlay / QAM / sleep — pause sim so the city does not tick under the overlay.
	# APPLICATION_FOCUS: Steam overlay. WM_WINDOW_FOCUS: Gamescope/windowed. Pause on out; never auto-resume.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		overlay_focus_out.emit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		overlay_focus_in.emit()


func layout_for_deck() -> void:
	## Force 1280×800 SafeArea: Root is Rect2(48,48,1136,704). Fit only Root chrome.
	## Never write global_position on nested kids (CanvasLayer stacks the 48px inset).
	var r := get_node_or_null("Root") as Control
	if r == null:
		return
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 0.0
	r.anchor_bottom = 0.0
	r.offset_left = 48.0
	r.offset_top = 48.0
	r.offset_right = 1184.0
	r.offset_bottom = 752.0
	r.position = Vector2(48.0, 48.0)
	r.size = Vector2(1136.0, 704.0)
	for c in r.get_children():
		if not (c is Control):
			continue
		var child := c as Control
		_fit_direct_child(child, r.size)
		if child is BoxContainer:
			continue
		for gc in child.get_children():
			if not (gc is Control) or gc is BoxContainer:
				continue
			var g := gc as Control
			if (g.anchor_left + g.anchor_right + g.anchor_top + g.anchor_bottom) > 0.01:
				_fit_direct_child(g, child.size)
	_keep_in_safe()


func _fit_direct_child(c: Control, parent_size: Vector2) -> void:
	var x := c.offset_left + parent_size.x * c.anchor_left
	var y := c.offset_top + parent_size.y * c.anchor_top
	var right := c.offset_right + parent_size.x * c.anchor_right
	var bottom := c.offset_bottom + parent_size.y * c.anchor_bottom
	var sz := Vector2(maxf(right - x, 1.0), maxf(bottom - y, 1.0))
	if sz.x > parent_size.x:
		sz.x = parent_size.x
	if sz.y > parent_size.y:
		sz.y = parent_size.y
	x = clampf(x, 0.0, maxf(parent_size.x - sz.x, 0.0))
	y = clampf(y, 0.0, maxf(parent_size.y - sz.y, 0.0))
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
	c.position = Vector2(x, y)
	c.size = sz


func _ensure_bench_ui() -> void:
	_ensure_pause_bench_item()
	if get_node_or_null("%BenchOverlay") != null or get_node_or_null("Root/BenchOverlay") != null:
		return
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	var overlay := Control.new()
	overlay.name = "BenchOverlay"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_index = 60
	root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.name = "BenchPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -220.0
	panel.offset_top = 16.0
	panel.offset_right = 220.0
	panel.offset_bottom = 260.0
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "BenchBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.name = "BenchTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "BENCHMARK"
	box.add_child(title)
	var body := Label.new()
	body.name = "BenchBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 18)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = ""
	box.add_child(body)
	var hint := Label.new()
	hint.name = "BenchHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = Glyphs.help_bench()
	box.add_child(hint)


func _ensure_pause_bench_item() -> void:
	_ensure_pause_menu()
	if pause_overlay == null:
		return
	var box := pause_overlay.get_node_or_null("PauseRoot") as VBoxContainer
	if box == null:
		box = pause_overlay.get_node_or_null("PauseBox") as VBoxContainer
	if box == null:
		return
	var bench_lab := box.get_node_or_null("Item_benchmark") as Label
	if bench_lab == null:
		bench_lab = box.get_node_or_null("BenchItem") as Label
	if bench_lab == null:
		bench_lab = Label.new()
		bench_lab.name = "BenchItem"
		bench_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bench_lab.focus_mode = Control.FOCUS_NONE
		bench_lab.add_theme_font_size_override("font_size", 18)
		bench_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bench_lab.visible = false
		box.add_child(bench_lab)
	bench_lab.text = "Benchmark"
	bench_lab.visible = false
	var hint2 := box.get_node_or_null("PauseHint") as Label
	if hint2:
		hint2.text = Glyphs.help_pause()


func _set_pause_bench_hint(_p: bool) -> void:
	_ensure_pause_bench_item()


func set_bench_live(vis: bool, fps: float, elapsed: float, duration: float) -> void:
	_ensure_bench_ui()
	var overlay := get_node_or_null("Root/BenchOverlay") as Control
	if overlay == null:
		return
	_brush_hidden = vis
	if tool_label:
		tool_label.visible = not vis
	if not vis:
		overlay.visible = false
		if help_label and screen == Screen.NONE:
			_set_help(Glyphs.help_play())
		return
	overlay.visible = true
	var title := overlay.get_node_or_null("BenchPanel/BenchBox/BenchTitle") as Label
	var body := overlay.get_node_or_null("BenchPanel/BenchBox/BenchBody") as Label
	var hint := overlay.get_node_or_null("BenchPanel/BenchBox/BenchHint") as Label
	if title:
		title.text = "BENCHMARK"
	if body:
		body.text = "FPS %.0f\n%.0f / %.0f s" % [fps, elapsed, duration]
	if hint:
		hint.text = "Abort"
	_set_help(Glyphs.help_bench())
	if help_label:
		help_label.visible = true
		help_label.text = Glyphs.help_bench()
	_keep_in_safe()


func set_bench_results(vis: bool, r: Dictionary = {}) -> void:
	_ensure_bench_ui()
	var overlay := get_node_or_null("Root/BenchOverlay") as Control
	if overlay == null:
		return
	_brush_hidden = vis
	if tool_label:
		tool_label.visible = not vis
	if not vis:
		overlay.visible = false
		return
	overlay.visible = true
	var title := overlay.get_node_or_null("BenchPanel/BenchBox/BenchTitle") as Label
	var body := overlay.get_node_or_null("BenchPanel/BenchBox/BenchBody") as Label
	var hint := overlay.get_node_or_null("BenchPanel/BenchBox/BenchHint") as Label
	if title:
		title.text = "BENCHMARK RESULTS"
	if body:
		body.text = "Avg FPS    %.2f\n1%% low     %.2f\nDuration   %.1f s\nPreset     %s" % [
			float(r.get("avg", 0.0)),
			float(r.get("1pct_low", 0.0)),
			float(r.get("duration", 0.0)),
			str(r.get("preset", "low")).capitalize(),
		]
	if hint:
		hint.text = "Abort"



func set_brush_hidden(hidden: bool) -> void:
	## Hide brush chrome while bench is running. B abort must not cycle 1→3.
	_brush_hidden = hidden
	brush_chrome_hidden = hidden
	if tool_label:
		tool_label.visible = not hidden
		if hidden:
			tool_label.text = ""

# B abort


func _pause_box() -> VBoxContainer:
	if pause_overlay == null:
		return null
	var found := pause_overlay.find_child("PauseRoot", true, false) as VBoxContainer
	if found:
		return found
	return pause_overlay.get_node_or_null("PauseBox") as VBoxContainer


func cycle_pause_item(dir: int) -> void:
	move_menu(dir)


func activate_pause_item() -> String:
	return confirm_pause_item()


func set_dlss_row(_show: bool) -> void:
	## RowDlss hook — never implement DLSS. Hidden / forced-off in 0.1.6.
	_ensure_graphics_menu()
	var lab: Label = null
	if graphics_menu:
		lab = graphics_menu.get_node_or_null("RowDlss") as Label
	if lab == null:
		lab = find_child("RowDlss", true, false) as Label
	if lab:
		lab.visible = false
		lab.text = "DLSS — 0.1.7"
		lab.modulate = Color(0.55, 0.58, 0.62, 0.75)


func show_dlss_row() -> bool:
	## DLSS row hook. Hidden. Never enable.
	return false


func _keep_in_safe() -> void:
	layout_for_deck()


func _clamp_one(n: Control, safe: Rect2) -> void:
	## Local-space clamp. Do not assign global_position (CanvasLayer stacks insets).
	var gr := n.get_global_rect()
	if gr.size.x < 1.0 or gr.size.y < 1.0:
		return
	var sz := Vector2(minf(gr.size.x, safe.size.x), minf(gr.size.y, safe.size.y))
	var nx := clampf(gr.position.x, safe.position.x, maxf(safe.end.x - sz.x, safe.position.x))
	var ny := clampf(gr.position.y, safe.position.y, maxf(safe.end.y - sz.y, safe.position.y))
	var parent := n.get_parent()
	if parent is Control:
		var origin := (parent as Control).get_global_rect().position
		n.position = Vector2(nx - origin.x, ny - origin.y)
	else:
		n.position = Vector2(nx, ny)
	n.size = sz
