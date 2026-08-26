class_name CampaignSystem
extends RefCounted
## Act I (First District) + post-tutor Acts II–IV.
## Drop in after 0.1.8 tag. Same signals/methods main already wires.
## Aggregate only. No walkers. Shocks reuse SimSystem.start_war / start_disaster.

signal card_fired(title: String, body: String)
signal goal_changed(card: Dictionary)

const ACT_I := "act_i"
const ACT_II := "act_ii"
const ACT_III := "act_iii"
const ACT_IV := "act_iv"

const ACT_ID := ACT_I
const ACT_TITLE := "Act I — First District"
const PAINT_GOAL := 24
const CASH_FLOOR := 20000
const OCC_HOLD := 0.40
const MASS_CHARTER := 1100.0

const ACT_II_COM_MASS := 40.0
const ACT_III_IND_MASS := 30.0
const ACT_III_CASH := 18000
const ACT_IV_HAPPY := 0.42
const ACT_IV_MASS := 400.0
const RECOVER_OCC := 0.35

var paints: int = 0
var complete: bool = false
var charter_unlocked: bool = false
var milestone_survey: bool = false
var milestone_solvent: bool = false
var last_mass: float = 0.0
var last_occ: float = 0.0
var last_cash: int = 0

var act_ii_done: bool = false
var act_iii_done: bool = false
var act_iv_done: bool = false
var shock_fired: bool = false
var recover_done: bool = false
var unlock_c: bool = true
var unlock_i: bool = true
var last_act_id: String = ACT_I


func note_paint() -> void:
	paints += 1
	_maybe_survey()


func evaluate(mass: float, occupancy_01: float, cash: int) -> Dictionary:
	last_mass = mass
	last_occ = clampf(occupancy_01, 0.0, 1.0)
	last_cash = cash
	_maybe_survey()
	_eval_act_i(cash)
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
	_eval_act_i(cash)
	if sim != null and sim.has_method("first_ten_complete") and bool(sim.first_ten_complete()):
		_eval_post_tutor(map, budget, sim)
	last_mass = mass
	last_occ = clampf(occ, 0.0, 1.0)
	last_cash = cash
	var card := goal_card()
	goal_changed.emit(card)
	return card


func _eval_act_i(cash: int) -> void:
	_maybe_survey()
	var session_ok := paints >= PAINT_GOAL and last_occ >= OCC_HOLD and cash >= CASH_FLOOR
	if session_ok and not milestone_solvent:
		milestone_solvent = true
		card_fired.emit(
			"District Holds",
			"Treasury solvent, occupancy holding. Keep growing toward the midrise charter."
		)
	var charter_ok := last_mass >= MASS_CHARTER
	if charter_ok and not charter_unlocked:
		charter_unlocked = true
		card_fired.emit(
			"Midrise Charter",
			"Occupied mass crossed the midrise gate. The ring can grow — later acts wait for the first-10 tutor."
		)
	if charter_ok and session_ok and not complete:
		complete = true
		card_fired.emit(
			"Act I — First District",
			"Charter signed. Downtown stands. Acts II–IV open after the first-10 tutor."
		)
		last_act_id = ACT_I


func _eval_post_tutor(map, budget, sim) -> void:
	## Soft-gate C/I only after tutor so smoke + first-10 stay unlocked.
	if not unlock_c:
		unlock_c = false
	if not act_ii_done:
		unlock_c = complete
	if not act_iii_done:
		unlock_i = act_ii_done
	if complete and not act_ii_done:
		unlock_c = true
		if float(sim.mass_c) >= ACT_II_COM_MASS or float(sim.mass_r) >= 80.0:
			act_ii_done = true
			last_act_id = ACT_II
			card_fired.emit(
				"Act II — Shop Streets",
				"Commerce charter. Commercial is the jobs lever — keep it on roads."
			)
	if act_ii_done and not act_iii_done:
		unlock_i = true
		if float(sim.mass_i) >= ACT_III_IND_MASS or (last_cash >= ACT_III_CASH and float(sim.mass_c) >= ACT_II_COM_MASS * 0.5):
			act_iii_done = true
			last_act_id = ACT_III
			card_fired.emit(
				"Act III — Smoke Stacks",
				"Industry charter. Jobs rise, renters hate the smoke — watch pollution opinion."
			)
	if act_iii_done and not shock_fired and not _event_busy(sim):
		var happy := 0.5
		if "happiness" in sim:
			happy = float(sim.happiness)
		var mass := float(sim.mass_r) + float(sim.mass_c) + float(sim.mass_i)
		if happy >= ACT_IV_HAPPY or mass >= ACT_IV_MASS:
			shock_fired = true
			var info: Dictionary = {}
			if sim.has_method("start_disaster") and map != null and budget != null:
				info = sim.start_disaster(map, budget)
			if info.is_empty():
				info = {"title": "Act IV — Shock", "body": "The district takes a hit. Rebuild services."}
			card_fired.emit(str(info.get("title", "Act IV — Shock")), "Act IV shock. " + str(info.get("body", "")))
			last_act_id = ACT_IV
	if shock_fired and not recover_done and not _event_busy(sim):
		if last_occ >= RECOVER_OCC:
			recover_done = true
			act_iv_done = true
			if budget != null:
				budget.tax_mult = minf(1.0, float(budget.tax_mult) + 0.08)
			card_fired.emit(
				"Act IV — Recovered",
				"Services back. Trade eases. The city held."
			)


func _event_busy(sim) -> bool:
	if sim == null:
		return false
	return int(sim.war_timer) > 0 or int(sim.disaster_timer) > 0


func is_unlocked(tool_id: String) -> bool:
	## During first-10 / before Act I charter, do not soft-lock tools (smoke + tutor).
	if not complete:
		return true
	match tool_id:
		"zone_c":
			return unlock_c
		"zone_i":
			return unlock_i
		_:
			return true


func goal_card() -> Dictionary:
	var p_paint := clampf(float(paints) / float(PAINT_GOAL), 0.0, 1.0)
	var p_occ := clampf(last_occ / OCC_HOLD, 0.0, 1.0)
	var p_cash := 1.0 if last_cash >= CASH_FLOOR else clampf(float(maxi(0, last_cash)) / float(CASH_FLOOR), 0.0, 1.0)
	var p_mass := clampf(last_mass / MASS_CHARTER, 0.0, 1.0)
	var session := (p_paint + p_occ + p_cash) / 3.0
	var progress := minf(p_mass, session) if not complete else 1.0
	if complete:
		progress = 1.0
	if act_iv_done:
		progress = 1.0
	elif shock_fired:
		progress = 0.85
	elif act_iii_done:
		progress = 0.7
	elif act_ii_done:
		progress = 0.55
	var title := ACT_TITLE
	if last_act_id == ACT_II:
		title = "Act II — Shop Streets"
	elif last_act_id == ACT_III:
		title = "Act III — Smoke Stacks"
	elif last_act_id == ACT_IV:
		title = "Act IV — Shock + Recover"
	var body := "Paint %d/%d lots · Occ %.0f%% / %.0f%% · $%s / $%s\nCharter mass %.0f / %.0f%s\nLandmarks park · waterfront · midrise  ·  heatmap" % [
		paints, PAINT_GOAL,
		last_occ * 100.0, OCC_HOLD * 100.0,
		_fmt(last_cash), _fmt(CASH_FLOOR),
		last_mass, MASS_CHARTER,
		" — COMPLETE" if complete else "",
	]
	if complete:
		body += "\nII shops %s · III industry %s · IV shock %s / recover %s" % [
			"done" if act_ii_done else "open",
			"done" if act_iii_done else "locked",
			"fired" if shock_fired else "armed",
			"done" if recover_done else "wait",
		]
	return {
		"title": title,
		"body": body,
		"progress": progress,
		"complete": complete,
		"act_id": last_act_id,
		"charter": charter_unlocked,
		"paints": paints,
		"mass": last_mass,
		"act_ii": act_ii_done,
		"act_iii": act_iii_done,
		"act_iv": act_iv_done,
		"shock": shock_fired,
	}


func advisor_line() -> String:
	if act_iv_done:
		return "Acts I–IV done. City held the shock. Grow the ring."
	if shock_fired and not recover_done:
		return "Act IV: rebuild power/water/roads. Hold occupancy."
	if act_iii_done:
		return "Act IV armed — a war/disaster shock will hit when the district is alive."
	if act_ii_done:
		return "Act III: paint Industrial beside roads. Jobs now, smoke later."
	if complete:
		return "Act I chartered. After first-10: grow shops (Act II), then industry (Act III)."
	if last_mass < 200.0 and paints < 8:
		return "Act I: grow the first district. Heatmap reads land value and occupancy."
	return "Act I: grow mass to %.0f (now %.0f) · paint %d/%d · hold occ + cash." % [
		MASS_CHARTER, last_mass, paints, PAINT_GOAL
	]


func next_act_id() -> String:
	if act_iv_done:
		return ""
	if shock_fired:
		return ACT_IV
	if act_iii_done:
		return ACT_IV
	if act_ii_done:
		return ACT_III
	if complete:
		return ACT_II
	return ACT_I


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
