class_name CampaignSystem
extends RefCounted
## Act I only — First District. Later acts stay off the tree until the city can last 50h.
## Wires to the existing one-card event toast (hud.show_event). No walker sim.

signal card_fired(title: String, body: String)
signal goal_changed(card: Dictionary)

const ACT_ID := "act_i"
const ACT_TITLE := "Act I — First District"
const PAINT_GOAL := 24
const CASH_FLOOR := 20000
const OCC_HOLD := 0.40
## Matches SimSystem.density_unlock_tier() midrise gate — the long charter bar.
const MASS_CHARTER := 1100.0

var paints: int = 0
var complete: bool = false
var charter_unlocked: bool = false
var milestone_survey: bool = false
var milestone_solvent: bool = false
var last_mass: float = 0.0
var last_occ: float = 0.0
var last_cash: int = 0


func note_paint() -> void:
	paints += 1
	_maybe_survey()


func evaluate(mass: float, occupancy_01: float, cash: int) -> Dictionary:
	## Pure evaluate — smoke can inject numbers. Tick() calls this from live sim.
	last_mass = mass
	last_occ = clampf(occupancy_01, 0.0, 1.0)
	last_cash = cash
	_maybe_survey()
	var session_ok := paints >= PAINT_GOAL and last_occ >= OCC_HOLD and cash >= CASH_FLOOR
	if session_ok and not milestone_solvent:
		milestone_solvent = true
		card_fired.emit(
			"District Holds",
			"Treasury solvent, occupancy holding. Keep growing toward the midrise charter."
		)
	var charter_ok := mass >= MASS_CHARTER
	if charter_ok and not charter_unlocked:
		charter_unlocked = true
		card_fired.emit(
			"Midrise Charter",
			"Occupied mass crossed the midrise gate. The ring can grow — later acts wait."
		)
	if charter_ok and session_ok and not complete:
		complete = true
		card_fired.emit(
			"Act I — First District",
			"Charter signed. Downtown stands. Acts II–IV stay locked until the city can last 50 hours."
		)
	var card := goal_card()
	goal_changed.emit(card)
	return card


func tick(map, budget, sim) -> Dictionary:
	var occ := 0.0
	if map != null and map.has_method("occupancy_percent"):
		occ = float(map.occupancy_percent()) / 100.0
	var mass := 0.0
	if sim != null:
		mass = float(sim.mass_r) + float(sim.mass_c) + float(sim.mass_i)
	var cash := 0
	if budget != null:
		cash = int(budget.cash)
	return evaluate(mass, occ, cash)


func goal_card() -> Dictionary:
	var p_paint := clampf(float(paints) / float(PAINT_GOAL), 0.0, 1.0)
	var p_occ := clampf(last_occ / OCC_HOLD, 0.0, 1.0)
	var p_cash := 1.0 if last_cash >= CASH_FLOOR else clampf(float(maxi(0, last_cash)) / float(CASH_FLOOR), 0.0, 1.0)
	var p_mass := clampf(last_mass / MASS_CHARTER, 0.0, 1.0)
	## Charter is the long bar; session floor is the short one. Act I progress is the min of charter and session.
	var session := (p_paint + p_occ + p_cash) / 3.0
	var progress := minf(p_mass, session) if not complete else 1.0
	if complete:
		progress = 1.0
	var body := "Paint %d/%d lots · Occ %.0f%% / %.0f%% · $%s / $%s\nCharter mass %.0f / %.0f%s\nLandmarks park · waterfront · midrise  ·  heatmap" % [
		paints, PAINT_GOAL,
		last_occ * 100.0, OCC_HOLD * 100.0,
		_fmt(last_cash), _fmt(CASH_FLOOR),
		last_mass, MASS_CHARTER,
		" — COMPLETE" if complete else "",
	]
	return {
		"title": ACT_TITLE,
		"body": body,
		"progress": progress,
		"complete": complete,
		"act_id": ACT_ID,
		"charter": charter_unlocked,
		"paints": paints,
		"mass": last_mass,
	}


func advisor_line() -> String:
	if complete:
		return "Act I chartered — midrise ring unlocked. Later acts wait."
	if last_mass < 200.0 and paints < 8:
		return "Act I: grow the first district. Heatmap reads land value and occupancy."
	return "Act I: grow mass to %.0f (now %.0f) · paint %d/%d · hold occ + cash." % [
		MASS_CHARTER, last_mass, paints, PAINT_GOAL
	]


func next_act_id() -> String:
	## Honest: only Act I is live. Do not invent Act II.
	if complete:
		return ""
	return ACT_ID


func _maybe_survey() -> void:
	if paints >= 12 and not milestone_survey:
		milestone_survey = true
		card_fired.emit(
			"Survey Logged",
			"First lots painted. Keep the core serviced — Act I is the midrise charter, not a tutorial skip."
		)


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if n < 0 else "") + out
