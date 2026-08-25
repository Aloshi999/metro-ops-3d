extends CanvasLayer
## Cash HUD, tool strip, RCI, advisor side card, War/Disaster chips, optional FPS.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const AdvisorSystem = preload("res://scripts/systems/advisor_system.gd")

signal war_clicked
signal disaster_clicked
signal advisor_dismissed
signal resume_clicked
signal overlay_focus_out
signal overlay_focus_in

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
@onready var graphics_menu: Label = get_node_or_null("%GraphicsMenu") as Label

var show_fps: bool = false
var _toast_timer: float = 0.0
var _flash_timer: float = 0.0
var _focus_armed: bool = false


func _ready() -> void:
	event_toast.visible = false
	paused_label.visible = false
	fps_label.visible = false
	if pause_overlay:
		pause_overlay.visible = false
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flash:
		flash.visible = false
	if advisor_panel:
		advisor_panel.visible = true
		advisor_panel.modulate.a = 1.0
	help_label.text = "L-stick pan · R-stick orbit · A paint · Y tools · LB/RB graphics · X brush · View pause · L3 FPS · A Benchmark (paused)"
	_force_mouse_ignore(get_node_or_null("Root"))
	if resume_button:
		resume_button.visible = false
		resume_button.focus_mode = Control.FOCUS_NONE
		resume_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Arm after main.gd has connected — skip boot FOCUS_IN, never pause on advisor.
	call_deferred("_arm_focus_watch")
	_ensure_bench_ui()


func _force_mouse_ignore(n: Node) -> void:
	if n == null:
		return
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_force_mouse_ignore(c)


func _process(dt: float) -> void:
	if show_fps:
		fps_label.text = "FPS %.0f / target %d" % [Engine.get_frames_per_second(), GameConstants.TARGET_FPS]
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
	flow_label.text = "Δ %s%d  (tax +%d / upkeep −%d)" % [sign_s, net, income, upkeep]
	flow_label.modulate = Color(0.5, 1.0, 0.6) if net >= 0 else Color(1.0, 0.45, 0.4)


func set_tool(label: String, brush: int = 1) -> void:
	tool_label.text = "Tool: %s  ·  brush %d×%d" % [label, brush, brush]


func set_rci(label: String) -> void:
	rci_label.text = label


func set_graphics(label: String) -> void:
	var line := "GFX %s" % label
	if graphics_label:
		graphics_label.text = line
	if graphics_menu:
		graphics_menu.text = "Graphics  < %s >" % label


func set_occupancy(pct: float) -> void:
	var occ := get_node_or_null("%OccLabel") as Label
	if occ:
		occ.text = "Occupancy %.0f%%" % pct


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
	event_status.text = "  ·  ".join(bits)
	event_status.modulate = Color(1.0, 0.55, 0.4) if war_timer > 0 else Color(1.0, 0.75, 0.35)


func set_advisor(messages: Array) -> void:
	var bb := ""
	for m in messages:
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
	if advisor_panel:
		advisor_panel.visible = true
		advisor_panel.modulate.a = 1.0


func set_paused(p: bool) -> void:
	# Advisor stays a side card. Pause is a chip + dim, no mouse modal.
	paused_label.visible = p
	_set_pause_bench_hint(p)
	if advisor_panel:
		advisor_panel.modulate.a = 1.0
		advisor_panel.visible = true
	if pause_overlay:
		pause_overlay.visible = p
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if resume_button:
		resume_button.visible = false
		resume_button.focus_mode = Control.FOCUS_NONE
		resume_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Arm after main.gd has connected — skip boot FOCUS_IN, never pause on advisor.
	call_deferred("_arm_focus_watch")
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()


func toggle_fps_overlay() -> void:
	show_fps = not show_fps
	fps_label.visible = show_fps


func show_event(title: String, body: String) -> void:
	event_title.text = title
	event_body.text = body
	event_toast.visible = true
	_toast_timer = 5.0


func flash_color(c: Color) -> void:
	if flash == null:
		return
	flash.color = Color(c.r, c.g, c.b, 0.32)
	flash.visible = true
	_flash_timer = 0.9


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
	resume_clicked.emit()


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
	overlay.offset_left = 24.0
	overlay.offset_top = 16.0
	overlay.offset_right = -96.0
	overlay.offset_bottom = -16.0
	overlay.z_index = 60
	root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.name = "BenchPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -220.0
	panel.offset_top = 88.0
	panel.offset_right = 220.0
	panel.offset_bottom = 280.0
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
	hint.text = "B abort"
	box.add_child(hint)


func _ensure_pause_bench_item() -> void:
	if pause_overlay == null:
		return
	var box := pause_overlay.get_node_or_null("PauseBox") as VBoxContainer
	if box == null:
		return
	if box.get_node_or_null("BenchItem") == null:
		var lab := Label.new()
		lab.name = "BenchItem"
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.focus_mode = Control.FOCUS_NONE
		lab.add_theme_font_size_override("font_size", 18)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.text = "Benchmark   A start"
		var hint := box.get_node_or_null("PauseHint")
		if hint:
			box.add_child(lab)
			box.move_child(lab, hint.get_index())
		else:
			box.add_child(lab)
	var hint2 := box.get_node_or_null("PauseHint") as Label
	if hint2:
		hint2.text = "A Benchmark · LB/RB graphics · View resume"


func _set_pause_bench_hint(_p: bool) -> void:
	_ensure_pause_bench_item()


func set_bench_live(vis: bool, fps: float, elapsed: float, duration: float) -> void:
	_ensure_bench_ui()
	var overlay := get_node_or_null("Root/BenchOverlay") as Control
	if overlay == null:
		return
	if not vis:
		overlay.visible = false
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
		hint.text = "B abort"


func set_bench_results(vis: bool, r: Dictionary = {}) -> void:
	_ensure_bench_ui()
	var overlay := get_node_or_null("Root/BenchOverlay") as Control
	if overlay == null:
		return
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
		hint.text = "B dismiss · View resume"
