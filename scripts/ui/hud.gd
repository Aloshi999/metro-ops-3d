extends CanvasLayer
## Cash HUD, tool strip, RCI, advisor, War/Disaster event cards, optional FPS.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const AdvisorSystem = preload("res://scripts/systems/advisor_system.gd")

signal war_clicked
signal disaster_clicked
signal advisor_dismissed

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

var show_fps: bool = false
var _toast_timer: float = 0.0
var _flash_timer: float = 0.0


func _ready() -> void:
	event_toast.visible = false
	paused_label.visible = false
	fps_label.visible = false
	if flash:
		flash.visible = false
	help_label.text = "Deck: L-stick pan · R-stick orbit/zoom · A paint · L1/R1 cycle · Y radial · X brush · Start advisor · Select FPS  |  Keys: WASD pan · RMB orbit · Wheel zoom · Space/LMB paint · Q/E tools · R radial · B brush · Esc · F3 · 1 War / 2 Disaster"


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


func set_occupancy(pct: float) -> void:
	var occ := get_node_or_null("%OccLabel") as Label
	if occ:
		occ.text = "Occupancy %.0f%%" % pct


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


func set_paused(p: bool) -> void:
	paused_label.visible = p
	advisor_panel.modulate.a = 1.0 if p else 0.85


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
