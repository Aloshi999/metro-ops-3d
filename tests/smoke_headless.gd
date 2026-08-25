extends SceneTree
## Headless smoke: Kenney GLBs, paint, services, budget, war, disaster.
## Run: godot --headless --path /workspace/metro-ops-3d -s res://tests/smoke_headless.gd
const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const ChunkData = preload("res://scripts/core/chunk_data.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")
const SimSystem = preload("res://scripts/systems/sim_system.gd")
const AdvisorSystem = preload("res://scripts/systems/advisor_system.gd")
const ToolSystem = preload("res://scripts/systems/tool_system.gd")
const BuildingCatalog = preload("res://scripts/world/building_catalog.gd")
const CityView = preload("res://scripts/world/city_view.gd")
const CityCamera = preload("res://scripts/world/city_camera.gd")
const WorldRoot = preload("res://scripts/world/world_root.gd")
const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")


func _init() -> void:
	var ok := true
	var errors: PackedStringArray = []

	Engine.max_fps = GameConstants.TARGET_FPS

	if GameConstants.MAP_SIZE != 128:
		ok = false
		errors.append("MAP_SIZE != 128")
	if GameConstants.CHUNK_SIZE != 16:
		ok = false
		errors.append("CHUNK_SIZE != 16")
	if GameConstants.CHUNKS_PER_SIDE != 8:
		ok = false
		errors.append("CHUNKS_PER_SIDE != 8")
	if GameConstants.TARGET_FPS != 40:
		ok = false
		errors.append("TARGET_FPS != 40")
	if GameConstants.FSR_MODE != 2 or GameConstants.FSR_SCALE != 0.67:
		ok = false
		errors.append("FSR constants wrong")

	if GraphicsPresets.Id.LOW != 0 or GraphicsPresets.Id.MEDIUM != 1 or GraphicsPresets.Id.HIGH != 2 or GraphicsPresets.Id.ULTRA != 3:
		ok = false
		errors.append("GraphicsPresets.Id LOW..ULTRA missing or remapped")
	if GraphicsPresets.name_of(GraphicsPresets.Id.LOW) != "low" or GraphicsPresets.name_of(GraphicsPresets.Id.MEDIUM) != "medium" or GraphicsPresets.name_of(GraphicsPresets.Id.HIGH) != "high" or GraphicsPresets.name_of(GraphicsPresets.Id.ULTRA) != "ultra":
		ok = false
		errors.append("GraphicsPresets.name_of mismatch")
	var gfx_stub := Node.new()
	for pid in [GraphicsPresets.Id.LOW, GraphicsPresets.Id.MEDIUM, GraphicsPresets.Id.HIGH, GraphicsPresets.Id.ULTRA]:
		GraphicsPresets.apply(gfx_stub, null, pid)
	GraphicsPresets.apply(gfx_stub, null, GraphicsPresets.Id.LOW)
	gfx_stub.free()
	if GameConstants.LOT_METERS != 16.0:
		ok = false
		errors.append("LOT_METERS != 16")
	if GameConstants.CAM_DIST_MIN < 100.0:
		ok = false
		errors.append("CAM_DIST_MIN too close (%.1f) — would spawn inside Kenney roofs" % GameConstants.CAM_DIST_MIN)
	if GameConstants.CAM_DIST_DEFAULT > GameConstants.CAM_DIST_MAX:
		ok = false
		errors.append("CAM_DIST_DEFAULT > MAX")
	if GameConstants.CAM_PITCH_MAX > -35.0:
		ok = false
		errors.append("CAM_PITCH_MAX %.1f too flat (yeets into sky)" % GameConstants.CAM_PITCH_MAX)
	if GameConstants.CAM_PITCH_DEFAULT > -48.0 or GameConstants.CAM_PITCH_DEFAULT < GameConstants.CAM_PITCH_MIN:
		ok = false
		errors.append("CAM_PITCH_DEFAULT %.1f not a skyline orbit" % GameConstants.CAM_PITCH_DEFAULT)
	if GameConstants.CAM_ROOF_CLEARANCE < 90.0:
		ok = false
		errors.append("CAM_ROOF_CLEARANCE %.1f below HQ tower" % GameConstants.CAM_ROOF_CLEARANCE)

	var map := MapData.new()
	if map.size != 128 or map.chunks.size() != 64:
		ok = false
		errors.append("map alloc failed size=%d chunks=%d" % [map.size, map.chunks.size()])
	if map.service[map.idx(map.hq.x, map.hq.y)] != TileTypes.Service.HQ:
		ok = false
		errors.append("HQ missing")
	if map.revealed[map.idx(map.hq.x, map.hq.y)] != 1:
		ok = false
		errors.append("HQ not revealed")
	if map.power_plants.is_empty() or map.water_towers.is_empty():
		ok = false
		errors.append("downtown seed missing power/water")

	var seeded_occ := 0
	for i in map.occupancy.size():
		if map.occupancy[i] > 0.2 and map.zone[i] != TileTypes.Zone.NONE:
			seeded_occ += 1
	if seeded_occ < 8:
		ok = false
		errors.append("downtown seed has too few occupied lots (%d)" % seeded_occ)

	var catalog := BuildingCatalog.new()
	catalog.load_all()
	print("kenney loaded=%d failed=%d" % [catalog.loaded_count, catalog.failed.size()])
	if not catalog.has_meshes():
		ok = false
		errors.append("Kenney catalog has_meshes() false loaded=%d" % catalog.loaded_count)
	if catalog.failed.size() > 0:
		ok = false
		errors.append("Kenney failed paths: %s" % str(catalog.failed))

	print("kits downtown ready=%s midrise ready=%s skip=%s park ready=%s loaded=%s waterfront ready=%s loaded=%s" % [
		catalog.downtown.ready if catalog.downtown else false,
		catalog.midrise.ready if catalog.midrise else false,
		catalog.midrise.skip_reason if catalog.midrise else "no kit",
		catalog.park.ready if catalog.park else false,
		catalog.park.loaded_count if catalog.park else 0,
		catalog.waterfront.ready if catalog.waterfront else false,
		catalog.waterfront.loaded_count if catalog.waterfront else 0,
	])
	print("seed downtown=%d midrise=%d park=%d waterfront=%d" % [
		map.seed_downtown_lots, map.seed_midrise_lots, map.seed_park_lots, map.seed_waterfront_lots
	])
	if map.seed_park_lots < 20:
		ok = false
		errors.append("park seed too small (%d)" % map.seed_park_lots)
	if map.seed_waterfront_lots < 20:
		ok = false
		errors.append("waterfront seed too small (%d)" % map.seed_waterfront_lots)
	if map.seed_midrise_lots < 20:
		ok = false
		errors.append("midrise seed too small (%d)" % map.seed_midrise_lots)
	if catalog.park == null or not catalog.park.ready:
		ok = false
		errors.append("ParkKit not ready (need real nature GLBs)")
	else:
		var park_n := catalog.pick_park_piece(3)
		if park_n == null or _first_mesh_class(park_n) == "":
			ok = false
			errors.append("ParkKit pick_piece returned no mesh")
		elif park_n:
			park_n.free()
	if catalog.waterfront == null or not catalog.waterfront.ready:
		ok = false
		errors.append("WaterfrontKit not ready (need pier/crane/palm GLBs)")
	else:
		var wf_n := catalog.pick_waterfront_piece(0, false)
		var wf_p := catalog.pick_waterfront_piece(1, true)
		if wf_n == null or _first_mesh_class(wf_n) == "":
			ok = false
			errors.append("WaterfrontKit shore pick returned no mesh")
		if wf_p == null or _first_mesh_class(wf_p) == "":
			ok = false
			errors.append("WaterfrontKit pier pick returned no mesh")
		if wf_n:
			wf_n.free()
		if wf_p:
			wf_p.free()
	if catalog.midrise and catalog.midrise.ready:
		ok = false
		errors.append("MidriseKit ready=true but pack has no exterior buildings — do not stub")

	var rail_n: int = int(catalog.rail.loaded_count) if catalog.rail else 0
	var rail_ready: bool = bool(catalog.rail.ready) if catalog.rail else false
	var mkt_n: int = int(catalog.market.loaded_count) if catalog.market else 0
	var mkt_ready: bool = bool(catalog.market.ready) if catalog.market else false
	print("kits rail ready=%s loaded=%s market ready=%s loaded=%s" % [rail_ready, rail_n, mkt_ready, mkt_n])
	if catalog.rail == null or (not rail_ready and rail_n <= 0):
		ok = false
		errors.append("RailKit not ready / loaded_count=0")
	else:
		var rail_piece := catalog.pick_rail_piece("track", 0)
		if rail_piece == null or _first_mesh_class(rail_piece) == "":
			ok = false
			errors.append("RailKit pick_rail_piece returned no mesh")
		elif rail_piece:
			rail_piece.free()
	if catalog.market == null or (not mkt_ready and mkt_n <= 0):
		ok = false
		errors.append("NightMarketKit not ready / loaded_count=0")
	else:
		var mkt_piece := catalog.pick_market_prop(0)
		if mkt_piece == null or _first_mesh_class(mkt_piece) == "":
			ok = false
			errors.append("NightMarketKit pick_market_prop returned no mesh")
		elif mkt_piece:
			mkt_piece.free()
	var card := catalog.pick_window_card_texture(0)
	if card == null:
		ok = false
		errors.append("window-card texture picker returned null")

	var house := catalog.pick_zone_building(TileTypes.Zone.RESIDENTIAL, 0.9, 3)
	var shop := catalog.pick_zone_building(TileTypes.Zone.COMMERCIAL, 0.9, 4)
	var plant := catalog.pick_zone_building(TileTypes.Zone.INDUSTRIAL, 0.9, 5)
	var road := catalog.instantiate_road(5)
	var hq := catalog.instantiate_hq()
	for pair in [["R", house], ["C", shop], ["I", plant], ["road", road], ["hq", hq]]:
		var n: Node3D = pair[1]
		if n == null:
			ok = false
			errors.append("Kenney instantiate null for %s" % pair[0])
			continue
		var kind := _first_mesh_class(n)
		if kind == "":
			ok = false
			errors.append("Kenney %s has no MeshInstance3D" % pair[0])
		elif kind == "BoxMesh" or kind == "PrismMesh" or kind == "CapsuleMesh":
			ok = false
			errors.append("Kenney %s used primitive %s — city must be real GLBs" % [pair[0], kind])
		n.free()

	var budget := BudgetSystem.new()
	var start_cash := budget.cash

	# Idle city must not bleed cash in the first 5s (10 ticks) with no extra paints.
	var idle_map := MapData.new()
	var idle_budget := BudgetSystem.new()
	var idle_sim := SimSystem.new()
	var idle_start := idle_budget.cash
	for _idle in 10:
		idle_sim.tick(idle_map, idle_budget)
	if idle_budget.cash < idle_start:
		ok = false
		errors.append("idle cash collapsed %d -> %d upkeep=%d (starter city must not bleed)" % [
			idle_start, idle_budget.cash, idle_budget.last_upkeep
		])
	if idle_budget.last_upkeep != 0:
		ok = false
		errors.append("starter services billed upkeep=%d with no player-placed plants" % idle_budget.last_upkeep)
	if idle_budget.cash <= 0:
		ok = false
		errors.append("idle cash bankrupt")
	var idle_parts: int = idle_budget.last_rent + idle_budget.last_jobs + idle_budget.last_trade + idle_budget.last_land
	if absi(idle_budget.last_income - idle_parts) > 1:
		ok = false
		errors.append("idle last_income %d != rent+jobs+trade+land %d" % [idle_budget.last_income, idle_parts])
	var idle_op_ok := false
	for ic in idle_map.chunks:
		if ic.active and ic.opinion_r >= GameConstants.OPINION_MIN and ic.opinion_r <= GameConstants.OPINION_MAX:
			idle_op_ok = true
			break
	if not idle_op_ok:
		ok = false
		errors.append("no active chunk opinion_r in [OPINION_MIN, OPINION_MAX]")
	if idle_sim.happiness < 0.0 or idle_sim.happiness > 1.0:
		ok = false
		errors.append("happiness %.3f not in 0..1" % idle_sim.happiness)
	for ic2 in idle_map.chunks:
		if not ic2.active:
			continue
		for pair in [["r", ic2.opinion_r], ["c", ic2.opinion_c], ["i", ic2.opinion_i]]:
			var ov: float = float(pair[1])
			if ov < GameConstants.OPINION_MIN or ov > GameConstants.OPINION_MAX:
				ok = false
				errors.append("idle opinion_%s %.3f not in [%.2f, %.2f]" % [
					pair[0], ov, GameConstants.OPINION_MIN, GameConstants.OPINION_MAX])
		if ic2.amenity < 0.0 or ic2.amenity > 1.0:
			ok = false
			errors.append("idle amenity %.3f not in 0..1" % ic2.amenity)
		if ic2.power_cover < 0.0 or ic2.power_cover > 1.0 or ic2.water_cover < 0.0 or ic2.water_cover > 1.0:
			ok = false
			errors.append("idle power/water cover out of 0..1")
	if idle_sim.city_opinion_r < GameConstants.OPINION_MIN or idle_sim.city_opinion_r > GameConstants.OPINION_MAX:
		ok = false
		errors.append("city_opinion_r %.3f out of range" % idle_sim.city_opinion_r)
	var idle_rjt: int = idle_budget.last_rent + idle_budget.last_jobs + idle_budget.last_trade
	if absi(idle_budget.last_income - idle_rjt) > 5:
		ok = false
		errors.append("idle last_income %d not approx rent+jobs+trade %d (land=%d)" % [
			idle_budget.last_income, idle_rjt, idle_budget.last_land])
	var r_hit := {}
	var saw_water := false
	var saw_empty := false
	for yy in range(idle_map.hq.y - 10, idle_map.hq.y + 11):
		for xx in range(idle_map.hq.x - 10, idle_map.hq.x + 11):
			if not idle_map.in_bounds(xx, yy):
				continue
			var ii := idle_map.idx(xx, yy)
			var d: Dictionary = idle_sim.inspect_lot(idle_map, xx, yy)
			if idle_map.terrain[ii] == TileTypes.Terrain.WATER:
				saw_water = true
				if not d.is_empty():
					ok = false
					errors.append("inspect_lot on water not empty")
			elif idle_map.zone[ii] == TileTypes.Zone.NONE and idle_map.occupancy[ii] <= 0.0:
				saw_empty = true
				if not d.is_empty():
					ok = false
					errors.append("inspect_lot on empty lot not empty")
			if r_hit.is_empty() and idle_map.zone[ii] == TileTypes.Zone.RESIDENTIAL and idle_map.occupancy[ii] > 0.0:
				r_hit = d
	if r_hit.is_empty() or not r_hit.has("name") or not r_hit.has("tags"):
		ok = false
		errors.append("inspect_lot occupied R missing name/tags")
	elif str(r_hit["name"]) == "" or r_hit["tags"].size() < 2:
		ok = false
		errors.append("inspect_lot name/tags too thin")
	var voices: Array = idle_sim.sampled_voices(idle_map, 6)
	if voices.size() > 6:
		ok = false
		errors.append("sampled_voices size %d > 6" % voices.size())
	if not saw_water:
		# Map always has water somewhere; probe a known water scan if HQ neighborhood is dry.
		for yi in idle_map.size:
			var found_w := false
			for xi in idle_map.size:
				if idle_map.terrain[idle_map.idx(xi, yi)] == TileTypes.Terrain.WATER:
					if not idle_sim.inspect_lot(idle_map, xi, yi).is_empty():
						ok = false
						errors.append("inspect_lot on water not empty")
					found_w = true
					break
			if found_w:
				break

	var lot_changed := false
	var occ_ready := false
	for yy in range(map.hq.y - 14, map.hq.y + 15):
		for xx in range(map.hq.x - 14, map.hq.x + 15):
			if not map.in_bounds(xx, yy):
				continue
			var ii := map.idx(xx, yy)
			if map.revealed[ii] != 1:
				continue
			if map.terrain[ii] == TileTypes.Terrain.WATER:
				continue
			if map.service[ii] != TileTypes.Service.NONE:
				continue
			if map.road[ii] == 1:
				continue
			var before_z: int = map.zone[ii]
			var target_z: int = TileTypes.Zone.INDUSTRIAL
			if before_z == target_z:
				target_z = TileTypes.Zone.RESIDENTIAL
			if map.paint_zone(xx, yy, target_z):
				if map.zone[ii] != before_z and map.zone[ii] == target_z:
					lot_changed = true
					if map.occupancy[ii] >= 0.08:
						occ_ready = true
					budget.spend(GameConstants.ZONE_COST)
			if lot_changed:
				break
		if lot_changed:
			break
	if not lot_changed:
		ok = false
		errors.append("paint did not change a lot")
	if not occ_ready:
		ok = false
		errors.append("painted lot occupancy too low to spawn a Kenney building")

	var painted_road := false
	for d in range(9, 16):
		if map.paint_road(map.hq.x + d, map.hq.y):
			budget.spend(GameConstants.ROAD_COST)
			painted_road = true
	if not painted_road:
		ok = false
		errors.append("road paint failed")

	var zcount := 0
	for dx in range(9, 15):
		var zx := map.hq.x + dx
		var zy := map.hq.y + 1
		if map.paint_zone(zx, zy, TileTypes.Zone.RESIDENTIAL):
			budget.spend(GameConstants.ZONE_COST)
			zcount += 1
		if map.paint_zone(zx, map.hq.y - 1, TileTypes.Zone.COMMERCIAL):
			budget.spend(GameConstants.ZONE_COST)
			zcount += 1
	if zcount == 0:
		ok = false
		errors.append("zone paint failed")

	var sim := SimSystem.new()
	for _i in 10:
		sim.tick(map, budget)

	var advisor := AdvisorSystem.new()
	var msgs := advisor.evaluate(map, budget, "zone_r", sim)
	if msgs.is_empty():
		ok = false
		errors.append("advisor empty")
	if sim.demand_r <= 0.0 or sim.demand_c <= 0.0 or sim.demand_i <= 0.0:
		ok = false
		errors.append("RCI demand not computed")
	var ledger: int = budget.last_rent + budget.last_jobs + budget.last_trade + budget.last_land
	if absi(budget.last_income - ledger) > 1:
		ok = false
		errors.append("last_income %d != rent+jobs+trade+land %d" % [budget.last_income, ledger])
	if sim.happiness < 0.0 or sim.happiness > 1.0:
		ok = false
		errors.append("painted-map happiness %.3f not in 0..1" % sim.happiness)
	var op_ok := false
	for oc in map.chunks:
		if not oc.active:
			continue
		if oc.opinion_r >= GameConstants.OPINION_MIN and oc.opinion_r <= GameConstants.OPINION_MAX:
			op_ok = true
		for pair2 in [["r", oc.opinion_r], ["c", oc.opinion_c], ["i", oc.opinion_i]]:
			var ov2: float = float(pair2[1])
			if ov2 < GameConstants.OPINION_MIN or ov2 > GameConstants.OPINION_MAX:
				ok = false
				errors.append("painted opinion_%s %.3f out of range" % [pair2[0], ov2])
	if not op_ok:
		ok = false
		errors.append("painted-map opinion_r not in [OPINION_MIN, OPINION_MAX]")
	if sim.city_opinion_r < GameConstants.OPINION_MIN or sim.city_opinion_r > GameConstants.OPINION_MAX:
		ok = false
		errors.append("painted city_opinion_r %.3f out of range" % sim.city_opinion_r)

	var trade_pre_war: int = budget.last_trade
	var war := sim.start_war(budget)
	if budget.tax_mult >= 1.0:
		ok = false
		errors.append("war tax_mult not applied")
	sim.tick(map, budget)
	if trade_pre_war > 2 and budget.last_trade >= trade_pre_war:
		ok = false
		errors.append("war trade %d not below pre-war %d" % [budget.last_trade, trade_pre_war])
	if not war.has("title"):
		ok = false
		errors.append("war event malformed")
	if "Commercial" not in str(war.get("body", "")):
		ok = false
		errors.append("war body missing demand feedback")

	var blocked_dis := sim.start_disaster(map, budget)
	if budget.demand_mult < 1.0 or sim.disaster_timer > 0:
		ok = false
		errors.append("disaster started while war active")
	if not blocked_dis.has("title") or not blocked_dis.has("body"):
		ok = false
		errors.append("blocked disaster missing title/body")
	sim.war_timer = 0
	sim.event_cooldown = 0
	budget.tax_mult = 1.0
	var dis := sim.start_disaster(map, budget)
	if budget.demand_mult >= 1.0:
		ok = false
		errors.append("disaster demand_mult not applied")
	if not dis.has("body"):
		ok = false
		errors.append("disaster event malformed")
	var damaged_any := false
	for c in map.chunks:
		if c.damaged:
			damaged_any = true
			break
	if not damaged_any:
		ok = false
		errors.append("disaster did not damage a chunk")

	var main_ps = load("res://scenes/main.tscn")
	if main_ps == null:
		ok = false
		errors.append("main.tscn failed to load")

	var cam_ps = load("res://scenes/city_camera.tscn")
	if cam_ps == null:
		ok = false
		errors.append("city_camera.tscn failed to load")
	else:
		var rig: Node3D = cam_ps.instantiate()
		if rig.get_node_or_null("Camera3D") == null:
			ok = false
			errors.append("CityCamera missing Camera3D")
		var hq_w := Vector3(64.5 * GameConstants.LOT_METERS, 0.0, 64.5 * GameConstants.LOT_METERS)
		rig.setup(hq_w, 2048.0)
		rig._process(1.0)
		var dist: float = float(rig.get("distance"))
		var pitch: float = float(rig.get("pitch"))
		var boot_y: float = -sin(pitch) * dist
		var boot_h: float = absf(cos(pitch)) * dist
		var tgt: Vector3 = rig.get("target")
		## City Mesh lock: 190m / -56° / 6 lots south (+96 Z). Not GameConstants 390/620.
		if absf(dist - 190.0) > 1.0:
			ok = false
			errors.append("boot distance %.1f not Mesh lock 190" % dist)
		if absf(rad_to_deg(pitch) - (-56.0)) > 1.0:
			ok = false
			errors.append("boot pitch %.1f deg not Mesh lock -56" % rad_to_deg(pitch))
		if absf(tgt.z - (hq_w.z + 96.0)) > 1.0:
			ok = false
			errors.append("boot target.z=%.1f not HQ+96 (offset %.1f)" % [tgt.z, tgt.z - hq_w.z])
		if boot_y < GameConstants.CAM_ROOF_CLEARANCE - 0.5:
			ok = false
			errors.append("boot camera Y=%.1f under roofs (clearance %.1f)" % [boot_y, GameConstants.CAM_ROOF_CLEARANCE])
		print("boot camera Y=%.1f horiz=%.1f dist=%.1f pitch=%.1f target.z=%.1f" % [
			boot_y, boot_h, dist, rad_to_deg(pitch), tgt.z
		])
		rig.apply_wheel(1.0)
		rig._process(1.0)
		var dist_notch: float = float(rig.get("distance"))
		if absf(dist_notch - dist - 12.0) > 1.0:
			ok = false
			errors.append("one wheel notch moved %.1f m (want ~12, not yeet)" % (dist_notch - dist))
		for _w in 48:
			rig.apply_wheel(1.0)
		rig._process(1.0)
		var dmaxed: float = float(rig.get("distance"))
		if absf(dmaxed - 215.0) > 0.2:
			ok = false
			errors.append("wheel zoom-out clamp %.1f not Mesh lock 215" % dmaxed)
		for _w2 in 80:
			rig.apply_wheel(-1.0)
		rig._process(1.0)
		var dmin: float = float(rig.get("distance"))
		if absf(dmin - 155.0) > 0.2:
			ok = false
			errors.append("wheel zoom-in clamp %.1f not Mesh lock 155" % dmin)
		var min_y: float = -sin(float(rig.get("pitch"))) * dmin
		if min_y < GameConstants.CAM_ROOF_CLEARANCE - 1.0:
			ok = false
			errors.append("min zoom camera Y=%.1f inside roofs" % min_y)
		print("zoom clamps dist=%.1f..%.1f minY=%.1f notch=%.1f" % [dmin, dmaxed, min_y, dist_notch])
		rig.free()

	## 0.1.4 View-only pause lock — source strings only, do not instantiate Main.
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	if main_src.is_empty():
		ok = false
		errors.append("pause lock: main.gd unreadable")
	else:
		var stay_i := main_src.find("if paused:")
		var stay_win := "" if stay_i < 0 else main_src.substr(stay_i, 200)
		if stay_i < 0 or (stay_win.find("Stay paused") < 0 and stay_win.find("View") < 0 and stay_win.find("return") < 0):
			ok = false
			errors.append("pause lock: if paused: missing Stay-paused/View/return")
		if main_src.find("func _resume_play") < 0 or _func_slice(main_src, "func _resume_play").find("pass") < 0:
			ok = false
			errors.append("pause lock: _resume_play is not a pass")
		if main_src.find("func _on_overlay_focus_in") < 0 or _func_slice(main_src, "func _on_overlay_focus_in").find("paused = false") >= 0:
			ok = false
			errors.append("pause lock: _on_overlay_focus_in missing or sets paused = false")
		if main_src.find("func _trigger_war") < 0 or _func_slice(main_src, "func _trigger_war").find("paused = false") >= 0:
			ok = false
			errors.append("pause lock: _trigger_war missing or sets paused = false")
		if main_src.find("func _trigger_disaster") < 0 or _func_slice(main_src, "func _trigger_disaster").find("paused = false") >= 0:
			ok = false
			errors.append("pause lock: _trigger_disaster missing or sets paused = false")

	## 0.1.5 Benchmark — wiring only. Do not assert specific FPS (headless has no GPU).
	var BenchScr = load("res://scripts/systems/benchmark.gd")
	if BenchScr == null:
		ok = false
		errors.append("benchmark.gd failed to load")
	else:
		var bench_map := MapData.new()
		var bench_cam: Node3D = null
		if cam_ps != null:
			bench_cam = cam_ps.instantiate()
			var hq_b := bench_map.lot_to_world(bench_map.hq.x, bench_map.hq.y)
			bench_cam.setup(hq_b, bench_map.world_size())
			bench_cam._process(1.0)
		var bench = BenchScr.new()
		if bench.has_method("setup"):
			bench.setup(bench_cam, bench_map, null)
		if bench.has_method("default_preset") and str(bench.default_preset()) != "low":
			ok = false
			errors.append("default bench preset is %s not low" % str(bench.default_preset()))
		elif str(bench.get("preset_name")) != "low":
			ok = false
			errors.append("bench preset_name %s not low at boot" % str(bench.get("preset_name")))
		bench.start_smoke("low")
		for _f in 36:
			bench.tick(0.1)
		if bench.is_running():
			bench.force_finish()
		var last_path := "user://benchmark_last.txt"
		if not FileAccess.file_exists(last_path):
			ok = false
			errors.append("user://benchmark_last.txt not written")
		else:
			var txt := FileAccess.get_file_as_string(last_path)
			var avg_ok := false
			var low_ok := false
			var preset_ok := false
			for line in txt.split("\n"):
				var s := line.strip_edges()
				if s.begins_with("avg="):
					var vs := s.substr(4).strip_edges()
					if vs.is_valid_float():
						avg_ok = true
				elif s.begins_with("1pct_low="):
					var ls := s.substr(9).strip_edges()
					if ls.is_valid_float():
						low_ok = true
				elif s.begins_with("preset="):
					if s.substr(7).strip_edges().to_lower() == "low":
						preset_ok = true
			if not avg_ok:
				ok = false
				errors.append("benchmark_last.txt missing numeric avg=")
			if not low_ok:
				ok = false
				errors.append("benchmark_last.txt missing numeric 1pct_low=")
			if not preset_ok:
				ok = false
				errors.append("benchmark_last.txt preset is not low")
		# B abort must not crash.
		var bench2 = BenchScr.new()
		bench2.setup(bench_cam, bench_map, null)
		bench2.start_smoke("low")
		bench2.tick(0.08)
		bench2.tick(0.08)
		bench2.abort()
		if bench2.is_running():
			ok = false
			errors.append("B abort left benchmark running")
		if bench_cam != null:
			var bd: float = float(bench_cam.get("distance"))
			var bp: float = rad_to_deg(float(bench_cam.get("pitch")))
			if bd < 154.8 or bd > 215.2:
				ok = false
				errors.append("bench path left dist clamp (%.1f)" % bd)
			if bp < -62.2 or bp > -43.8:
				ok = false
				errors.append("bench path left pitch clamp (%.1f)" % bp)
			# restore + boot lock still hold
			if bench_cam.has_method("end_scripted"):
				bench_cam.end_scripted(true)
			bench_cam._process(1.0)
			var rd: float = float(bench_cam.get("distance"))
			var rp: float = rad_to_deg(float(bench_cam.get("pitch")))
			if absf(rd - 190.0) > 1.0:
				ok = false
				errors.append("after bench, camera dist %.1f not 190" % rd)
			if absf(rp - (-56.0)) > 1.0:
				ok = false
				errors.append("after bench, camera pitch %.1f not -56" % rp)
			bench_cam.free()
		if bench is Node:
			bench.free()
		if bench2 is Node:
			bench2.free()
		# source wiring
		if main_src.find("BenchmarkMode") < 0 or main_src.find("_start_benchmark") < 0:
			ok = false
			errors.append("main.gd missing Benchmark wiring")
		if main_src.find("_start_benchmark_from_pause") < 0:
			ok = false
			errors.append("main.gd missing A-from-pause Benchmark start")

	print("=== Metro Ops 3D smoke ===")
	print("map=%dx%d chunks=%dx%d lot_m=%.1f kenney=%d" % [
		GameConstants.MAP_SIZE, GameConstants.MAP_SIZE,
		GameConstants.CHUNKS_PER_SIDE, GameConstants.CHUNKS_PER_SIDE,
		GameConstants.LOT_METERS, catalog.loaded_count
	])
	print("cash=%d start=%d zones_painted=%d power=%d water=%d seeded_occ=%d" % [
		budget.cash, start_cash, zcount, map.power_plants.size(), map.water_towers.size(), seeded_occ
	])
	print("war=%s" % war["title"])
	print("disaster=%s" % dis["title"])
	if ok:
		print("SMOKE_OK")
		quit(0)
	else:
		print("SMOKE_FAIL")
		for e in errors:
			print("  - ", e)
		quit(1)


func _func_slice(src: String, header: String) -> String:
	var start := src.find(header)
	if start < 0:
		return ""
	var rest := src.substr(start + header.length())
	var nxt := rest.find("\nfunc ")
	if nxt < 0:
		return src.substr(start)
	return src.substr(start, header.length() + nxt)


func _first_mesh_class(n: Node) -> String:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh.get_class()
	for c in n.get_children():
		var k := _first_mesh_class(c)
		if k != "":
			return k
	return ""
