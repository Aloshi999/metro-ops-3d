class_name CampaignSystem
extends RefCounted
## Act I First District (tutor-era charter) + post-tutor acts (grow / industry / shock / recover).
## Aggregate sim only. Unlocks gate C/I paint. Shocks reuse SimSystem.start_disaster.

signal card_fired(title: String, body: String)
signal goal_changed(card: Dictionary)

const ACT_ID := "act_i"
const ACT_TITLE := "Act I — First District"
const PAINT_GOAL := 24
const CASH_FLOOR := 20000
const OCC_HOLD := 0.40
## Matches SimSystem.density_unlock_tier() midrise gate — the long charter bar.
const MASS_CHARTER := 1100.0

## Post-tutor act ids. Not act_ii — next_act_id() stays the Act I charter hook.
const ACT_GROW := "grow"
const ACT_INDUSTRY := "industry"
const ACT_SHOCK := "shock"
const ACT_RECOVER := "recover"

const GROW_R_MASS := 48.0
const INDUSTRY_C_MASS := 24.0
const INDUSTRY_CASH := 22000
const SHOCK_OCC := 0.35
const SHOCK_HAPPINESS := 0.42
const RECOVER_OCC := 0.28
const RECOVER_HAPPINESS := 0.40
const RECOVERY_DEMAND := 1.12

var paints: int = 0
var complete: bool = false
var charter_unlocked: bool = false
var milestone_survey: bool = false
var milestone_solvent: bool = false
var last_mass: float = 0.0
var last_occ: float = 0.0
var last_cash: int = 0

var last_tutor_done: bool = false
var last_mass_r: float = 0.0
var last_mass_c: float = 0.0
var last_happiness: float = 0.0
var act_grow_done: bool = false
var act_industry_done: bool = false
var act_shock_done: bool = false
var act_recover_done: bool = false
var shock_fired: bool = false
var shock_kind: String = ""
var shock_occ_at_fire: float = 0.0
var recovery_bonus: bool = false
var last_act_line: String = "Grow homes first — Commercial unlocks when R mass holds."


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
		last_mass_r = float(sim.mass_r)
		last_mass_c = float(sim.mass_c)
		last_happiness = float(sim.happiness)
	var cash := 0
	if budget != null:
		cash = int(budget.cash)
	var card := evaluate(mass, occ, cash)
	last_tutor_done = sim != null and sim.has_method("first_ten_complete") and bool(sim.first_ten_complete())
	if last_tutor_done:
		_advance_acts(map, budget, sim)
		card = goal_card()
		goal_changed.emit(card)
	return card


func is_unlocked(tool_id: String) -> bool:
	match tool_id:
		"zone_c":
			return act_grow_done
		"zone_i":
			return act_industry_done
		"trade_recovery":
			return recovery_bonus
		_:
			return true


func acts() -> Array:
	return [
		{
			"id": ACT_GROW,
			"title": "Grow",
			"unlocks": ["zone_c"],
			"shock": "",
			"done": act_grow_done,
			"line": "Grow homes — Commercial unlocks when R occupancy mass holds.",
		},
		{
			"id": ACT_INDUSTRY,
			"title": "Industry",
			"unlocks": ["zone_i"],
			"shock": "",
			"done": act_industry_done,
			"line": "Shops need factories — Industrial unlocks after C mass + cash.",
		},
		{
			"id": ACT_SHOCK,
			"title": "Shock",
			"unlocks": [],
			"shock": "disaster",
			"done": act_shock_done,
			"line": "City is alive — a disaster shock is coming. Rebuild when it hits.",
		},
		{
			"id": ACT_RECOVER,
			"title": "Recover",
			"unlocks": ["trade_recovery"],
			"shock": "",
			"done": act_recover_done,
			"line": "Shock ended — hold occupancy to unlock the trade-recovery bonus.",
		},
	]


func current_act_id() -> String:
	if not last_tutor_done:
		return ACT_ID
	if not act_grow_done:
		return ACT_GROW
	if not act_industry_done:
		return ACT_INDUSTRY
	if not act_shock_done:
		return ACT_SHOCK
	if not act_recover_done:
		return ACT_RECOVER
	return ""


func act_done(id: String) -> bool:
	match id:
		ACT_GROW:
			return act_grow_done
		ACT_INDUSTRY:
			return act_industry_done
		ACT_SHOCK:
			return act_shock_done
		ACT_RECOVER:
			return act_recover_done
		ACT_ID:
			return complete
		_:
			return false


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
		"post_act": current_act_id() if last_tutor_done else "",
		"grow": act_grow_done,
		"industry": act_industry_done,
		"shock": act_shock_done,
		"recover": act_recover_done,
	}


func advisor_line() -> String:
	if last_tutor_done:
		return last_act_line
	if complete:
		return "Act I chartered — midrise ring unlocked. Later acts wait."
	if last_mass < 200.0 and paints < 8:
		return "Act I: grow the first district. Heatmap reads land value and occupancy."
	return "Act I: grow mass to %.0f (now %.0f) · paint %d/%d · hold occ + cash." % [
		MASS_CHARTER, last_mass, paints, PAINT_GOAL
	]


func next_act_id() -> String:
	## Honest: Act I charter has no Act II id. Post-tutor acts use current_act_id().
	if complete:
		return ""
	return ACT_ID


func _advance_acts(map, budget, sim) -> void:
	## One act per tick. Progression starts only after first-10 tutor.
	if not act_grow_done:
		if last_mass_r >= GROW_R_MASS:
			act_grow_done = true
			last_act_line = "Commercial unlocked. Paint shops beside homes."
			card_fired.emit("Grow", "Residential mass holds. Commercial is unlocked — paint shops beside roads.")
		else:
			last_act_line = "Grow homes first — Commercial unlocks at R mass %.0f (now %.0f)." % [GROW_R_MASS, last_mass_r]
		return
	if not act_industry_done:
		if last_mass_c >= INDUSTRY_C_MASS and last_cash >= INDUSTRY_CASH:
			act_industry_done = true
			last_act_line = "Industrial unlocked. Jobs feed the shops."
			card_fired.emit("Industry", "Shops and treasury ready. Industrial is unlocked.")
		else:
			last_act_line = "Industry: C mass %.0f/%.0f · cash $%s / $%s." % [
				last_mass_c, INDUSTRY_C_MASS, _fmt(last_cash), _fmt(INDUSTRY_CASH)
			]
		return
	if not act_shock_done:
		var alive := last_occ >= SHOCK_OCC or last_happiness >= SHOCK_HAPPINESS
		if alive and sim != null and sim.has_method("start_disaster"):
			var busy := int(sim.war_timer) > 0 or int(sim.disaster_timer) > 0 or int(sim.event_cooldown) > 0
			if busy:
				last_act_line = "Shock waiting — an event is already running."
				return
			var info: Dictionary = sim.start_disaster(map, budget)
			if int(sim.disaster_timer) > 0:
				act_shock_done = true
				shock_fired = true
				shock_kind = "disaster"
				shock_occ_at_fire = last_occ
				last_act_line = "Disaster shock is live. Repair services, hold occupancy."
				card_fired.emit(str(info.get("title", "Shock")), str(info.get("body", "Disaster struck the district.")))
			else:
				last_act_line = "Shock held — %s" % str(info.get("body", "event busy"))
		else:
			last_act_line = "Shock: city must be alive (occ or mood) before the hit."
		return
	if not act_recover_done:
		var timers_clear := true
		if sim != null:
			timers_clear = int(sim.war_timer) <= 0 and int(sim.disaster_timer) <= 0
		var rebound := last_occ >= RECOVER_OCC or last_happiness >= RECOVER_HAPPINESS
		if shock_occ_at_fire > 0.0 and last_occ >= shock_occ_at_fire * 0.75:
			rebound = true
		if timers_clear and rebound:
			act_recover_done = true
			recovery_bonus = true
			if budget != null:
				budget.demand_mult = maxf(float(budget.demand_mult), RECOVERY_DEMAND)
			last_act_line = "Recovered. Trade-recovery bonus is live."
			card_fired.emit("Recover", "Shock ended and occupancy held. Trade-recovery bonus is on.")
		else:
			last_act_line = "Recover: wait out the shock, then hold occupancy."
		return
	last_act_line = "City recovered. Trade bonus is live. Keep the district solvent."


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
