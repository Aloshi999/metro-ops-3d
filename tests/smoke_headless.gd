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
const CampaignSystem = preload("res://scripts/systems/campaign_system.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const Glyphs = preload("res://scripts/ui/glyphs.gd")


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


	## 0.1.6 Act I + heatmap + landmarks. Do not invent Acts II–IV or FPS numbers.
	var camp := CampaignSystem.new()
	var g0: Dictionary = camp.goal_card()
	if not g0.has("title") or not g0.has("body") or str(g0["title"]) == "":
		ok = false
		errors.append("Act I goal_card missing title/body")
	if str(g0.get("act_id", "")) != "act_i":
		ok = false
		errors.append("campaign act_id is %s not act_i" % str(g0.get("act_id", "")))
	if camp.next_act_id() == "act_ii" or camp.has_method("start_act_ii"):
		ok = false
		errors.append("invented Act II — only Act I is live")
	for _p in 24:
		camp.note_paint()
	var g1: Dictionary = camp.evaluate(1200.0, 0.55, 30000)
	if not bool(g1.get("complete", false)):
		ok = false
		errors.append("Act I did not complete at charter mass + session floor")
	if camp.next_act_id() != "":
		ok = false
		errors.append("next_act_id after Act I should be empty (no fake Act II)")
	# live idle city should expose a real goal card without auto-completing at boot
	var live_camp := CampaignSystem.new()
	var live_card: Dictionary = live_camp.tick(idle_map, idle_budget, idle_sim)
	if not live_card.has("title") or str(live_card["body"]) == "":
		ok = false
		errors.append("live Act I card empty")
	if bool(live_card.get("complete", false)):
		ok = false
		errors.append("Act I completed on idle boot city — charter bar too short")

	## Post-tutor acts: grow / industry / shock / recover. After first-10 only.
	if camp == null or not (camp is CampaignSystem):
		ok = false
		errors.append("campaign does not exist")
	if not camp.has_method("is_unlocked") or not camp.has_method("acts"):
		ok = false
		errors.append("campaign missing is_unlocked / acts")
	var lock_camp := CampaignSystem.new()
	if lock_camp.is_unlocked("zone_c") or lock_camp.is_unlocked("zone_i"):
		ok = false
		errors.append("C/I unlocked before grow/industry")
	if not lock_camp.is_unlocked("zone_r") or not lock_camp.is_unlocked("road"):
		ok = false
		errors.append("zone_r/road should start unlocked")
	var lock_adv := AdvisorSystem.new()
	if not lock_adv.should_block_paint("zone_c", idle_map, lock_camp):
		ok = false
		errors.append("advisor did not block locked zone_c")
	if lock_adv.should_block_paint("zone_r", idle_map, lock_camp):
		ok = false
		errors.append("advisor blocked unlocked zone_r")
	var early_sim := SimSystem.new()
	early_sim.mass_r = 80.0
	early_sim.mass_c = 40.0
	early_sim.happiness = 0.8
	var early_camp := CampaignSystem.new()
	early_camp.tick(MapData.new(), BudgetSystem.new(), early_sim)
	if early_camp.is_unlocked("zone_c") or early_camp.act_grow_done:
		ok = false
		errors.append("grow advanced before first-10 tutor")
	var prog_map := MapData.new()
	var prog_budget := BudgetSystem.new()
	var prog_sim := SimSystem.new()
	prog_sim.tick_count = 1200
	prog_sim.mass_r = 80.0
	prog_sim.mass_c = 0.0
	prog_sim.happiness = 0.30
	var prog_camp := CampaignSystem.new()
	prog_sim.campaign = prog_camp
	var prog_card: Dictionary = prog_camp.tick(prog_map, prog_budget, prog_sim)
	if not prog_camp.act_grow_done or not prog_camp.is_unlocked("zone_c"):
		ok = false
		errors.append("tutor-complete path did not advance grow / unlock zone_c")
	if prog_camp.is_unlocked("zone_i") or prog_camp.act_industry_done:
		ok = false
		errors.append("industry unlocked before C mass + cash")
	if str(prog_camp.current_act_id()) != "industry":
		ok = false
		errors.append("current_act_id after grow is %s not industry" % str(prog_camp.current_act_id()))
	prog_sim.mass_c = 40.0
	prog_budget.cash = 30000
	prog_camp.tick(prog_map, prog_budget, prog_sim)
	if not prog_camp.act_industry_done or not prog_camp.is_unlocked("zone_i"):
		ok = false
		errors.append("industry did not unlock zone_i")
	if lock_adv.should_block_paint("zone_c", prog_map, prog_camp):
		ok = false
		errors.append("advisor still blocks zone_c after grow")
	prog_sim.happiness = 0.70
	prog_camp.last_occ = 0.50
	prog_camp.tick(prog_map, prog_budget, prog_sim)
	if not prog_camp.act_shock_done or int(prog_sim.disaster_timer) <= 0:
		ok = false
		errors.append("campaign shock did not call start_disaster")
	if str(prog_camp.shock_kind) != "disaster":
		ok = false
		errors.append("shock_kind is %s not disaster" % str(prog_camp.shock_kind))
	prog_sim.disaster_timer = 0
	prog_sim.event_cooldown = 0
	prog_sim.happiness = 0.70
	prog_camp.last_occ = 0.50
	prog_camp.tick(prog_map, prog_budget, prog_sim)
	if not prog_camp.act_recover_done or not prog_camp.is_unlocked("trade_recovery"):
		ok = false
		errors.append("recover did not unlock trade-recovery bonus")
	if prog_budget.demand_mult < 1.10:
		ok = false
		errors.append("recover demand_mult bonus missing (got %s)" % str(prog_budget.demand_mult))
	var act_ids: PackedStringArray = PackedStringArray()
	for a in prog_camp.acts():
		act_ids.append(str(a.get("id", "")))
	if act_ids != PackedStringArray(["grow", "industry", "shock", "recover"]):
		ok = false
		errors.append("acts() ids are %s" % str(act_ids))
	## start_war / start_disaster still work on a clean sim (tutor_active default false).
	var ev_map := MapData.new()
	var ev_budget := BudgetSystem.new()
	var ev_sim := SimSystem.new()
	var ev_war: Dictionary = ev_sim.start_war(ev_budget)
	if ev_budget.tax_mult >= 1.0 or int(ev_sim.war_timer) <= 0 or not ev_war.has("title"):
		ok = false
		errors.append("start_war broken after campaign acts")
	ev_sim.war_timer = 0
	ev_sim.event_cooldown = 0
	ev_budget.tax_mult = 1.0
	var ev_dis: Dictionary = ev_sim.start_disaster(ev_map, ev_budget)
	if ev_budget.demand_mult >= 1.0 or int(ev_sim.disaster_timer) <= 0 or not ev_dis.has("title"):
		ok = false
		errors.append("start_disaster broken after campaign acts")
	print("campaign acts grow=%s industry=%s shock=%s recover=%s post=%s" % [
		prog_camp.act_grow_done, prog_camp.act_industry_done,
		prog_camp.act_shock_done, prog_camp.act_recover_done, prog_card.get("post_act", "")
	])

	var view_ps = load("res://scenes/city_view.tscn")
	if view_ps == null:
		ok = false
		errors.append("city_view.tscn failed to load")
	# Do not instantiate the packed scene here — SceneTree._init never runs @onready.
	# Script-only CityView still seeds overlays + landmarks + heatmap.
	var view_map := MapData.new()
	var view := CityView.new()
	view.map = view_map
	view.catalog = catalog
	if view.has_method("_seed_park"):
		view._seed_park()
	if view.has_method("_seed_waterfront"):
		view._seed_waterfront()
	if view.has_method("_seed_midrise_ring"):
		view._seed_midrise_ring()
	if view.has_method("_ensure_overlay_roots"):
		view._ensure_overlay_roots()
	if view.has_method("_scatter_park"):
		view._scatter_park()
	if view.has_method("_scatter_waterfront"):
		view._scatter_waterfront()
	if view.has_method("_instance_landmarks"):
		view._instance_landmarks()
	if view.has_method("_ensure_midrise_landmark"):
		view._ensure_midrise_landmark()
	if view.has_method("_recount_landmarks"):
		view._recount_landmarks()
	var parks: int = int(view.get("park_count"))
	var wfs: int = int(view.get("waterfront_count"))
	var lms: int = int(view.get("landmark_count"))
	print("city_view park=%d waterfront=%d landmarks=%d heatmap=%s" % [
		parks, wfs, lms, view.get("heatmap_mode")
	])
	if parks < 1:
		ok = false
		errors.append("park not instanced in-scene (park_count=%d)" % parks)
	if wfs < 1:
		ok = false
		errors.append("waterfront not instanced in-scene (waterfront_count=%d)" % wfs)
	if lms < 2:
		ok = false
		errors.append("landmarks missing in-scene (landmark_count=%d)" % lms)
	if view.has_method("landmark_world"):
		var pw: Vector3 = view.landmark_world("park")
		var ww: Vector3 = view.landmark_world("waterfront")
		var mw: Vector3 = view.landmark_world("midrise")
		if pw == Vector3.ZERO or ww == Vector3.ZERO or mw == Vector3.ZERO:
			ok = false
			errors.append("landmark_world returned ZERO")
	if view.has_method("cycle_heatmap"):
		var m1: int = int(view.cycle_heatmap())
		if m1 != 1:
			ok = false
			errors.append("heatmap cycle 1 got %d" % m1)
		var m2: int = int(view.cycle_heatmap())
		if m2 != 2:
			ok = false
			errors.append("heatmap cycle 2 got %d" % m2)
		var m0: int = int(view.cycle_heatmap())
		if m0 != 0:
			ok = false
			errors.append("heatmap cycle off got %d" % m0)
	if view.has_method("set_heatmap_mode"):
		view.set_heatmap_mode(1)
		view.set_heatmap_mode(0)
	var hud_src := FileAccess.get_file_as_string("res://scenes/hud.tscn")
	if hud_src.find("font_size = 16") >= 0:
		ok = false
		errors.append("HUD has font_size 16 — body must be >= 18")
	if hud_src.find("GoalTitle") < 0 or hud_src.find("GoalBody") < 0:
		ok = false
		errors.append("HUD missing Act I GoalTitle/GoalBody")
	if hud_src.find("offset_right = -96.0") < 0:
		ok = false
		errors.append("HUD missing QAM right inset 96")
	view.free()

	var hud_src2 := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	if hud_src2.find("set_goal") < 0:
		ok = false
		errors.append("hud.gd missing set_goal")
	if main_src.find("CampaignSystem") < 0 or main_src.find("_boot_campaign") < 0:
		ok = false
		errors.append("main.gd missing Act I campaign wiring")
	if main_src.find("cycle_heatmap") < 0 and main_src.find("_on_heatmap_toggled") < 0:
		ok = false
		errors.append("main.gd missing heatmap toggle")


	## 0.1.6 MUST-FIX — FPS cap persist, 3-row graphics menu, HUD SafeArea.
	## Do not assert measured FPS values (headless has no GPU).
	var d_user := DirAccess.open("user://")
	if d_user and d_user.file_exists("metro_ops_graphics.cfg"):
		d_user.remove("metro_ops_graphics.cfg")
	Engine.max_fps = GameConstants.TARGET_FPS
	if Engine.max_fps != 40:
		ok = false
		errors.append("default max_fps %d not 40" % Engine.max_fps)
	var gs := GraphicsSettings.new()
	gs.boot()
	gs.apply_fps()
	if Engine.max_fps != 40:
		ok = false
		errors.append("GraphicsSettings boot default max_fps %d not 40" % Engine.max_fps)
	gs.set_fps_cap(0)
	if Engine.max_fps != 0:
		ok = false
		errors.append("Uncapped did not set Engine.max_fps = 0 (got %d)" % Engine.max_fps)
	gs.set_fps_cap(30)
	if Engine.max_fps != 30:
		ok = false
		errors.append("FPS cap 30 did not apply (got %d)" % Engine.max_fps)
	gs.set_fps_cap(60)
	if Engine.max_fps != 60:
		ok = false
		errors.append("FPS cap 60 did not apply (got %d)" % Engine.max_fps)
	var gs2 := GraphicsSettings.new()
	gs2.boot()
	if int(gs2.fps_cap) != 60:
		ok = false
		errors.append("saved FPS 60 was overwritten on boot (got %s)" % str(gs2.fps_cap))
	gs2.apply_fps()
	if Engine.max_fps != 60:
		ok = false
		errors.append("re-boot after save 60 set max_fps %d" % Engine.max_fps)
	gs2.set_fps_cap(0)
	var gs3 := GraphicsSettings.new()
	gs3.boot()
	if int(gs3.fps_cap) != 0:
		ok = false
		errors.append("saved Uncapped overwritten by Deck detect (got %s)" % str(gs3.fps_cap))
	gs3.apply_fps()
	if Engine.max_fps != 0:
		ok = false
		errors.append("saved Uncapped apply max_fps %d not 0" % Engine.max_fps)
	var fps_stub := Node.new()
	GraphicsPresets.apply(fps_stub, null, GraphicsPresets.Id.LOW)
	if Engine.max_fps != 0:
		ok = false
		errors.append("GraphicsPresets.apply stomped Uncapped (max_fps=%d)" % Engine.max_fps)
	fps_stub.free()
	gs3.set_fps_cap(40)
	Engine.max_fps = GameConstants.TARGET_FPS

	if hud_src2.find("show_graphics_screen") < 0 and hud_src.find("GraphicsMenu") < 0:
		ok = false
		errors.append("pause has no Graphics screen (not only a HUD one-liner)")
	if hud_src2.find("ExitButton") < 0 and hud_src2.find("TitleExit") < 0:
		ok = false
		errors.append("pause/title missing Exit")
	if hud_src.find("RowPreset") < 0 or hud_src.find("RowCap") < 0 or hud_src.find("RowFsr") < 0:
		ok = false
		errors.append("HUD missing graphics menu rows RowPreset/RowCap/RowFsr")
	if hud_src.find("Preset") < 0 or hud_src.find("FPS cap") < 0 or hud_src.find("FSR") < 0:
		ok = false
		errors.append("HUD graphics menu missing Preset / FPS cap / FSR labels")
	if hud_src.find("offset_left = 48.0") < 0 or hud_src.find("offset_top = 48.0") < 0 or hud_src.find("offset_bottom = -48.0") < 0:
		ok = false
		errors.append("HUD Root missing 48px safe insets")
	if hud_src2.find("cycle_graphics_focus") < 0 and hud_src2.find("cycle_gfx_row") < 0:
		ok = false
		errors.append("hud.gd missing graphics row cycle")
	if main_src.find("cycle_fps") < 0 or main_src.find("apply_fps") < 0:
		ok = false
		errors.append("main.gd missing FPS cap apply/cycle")

	var hud_ps2 = load("res://scenes/hud.tscn")
	if hud_ps2 == null:
		ok = false
		errors.append("hud.tscn failed to load for SafeArea check")
	else:
		var hud_n: CanvasLayer = hud_ps2.instantiate()
		root.add_child(hud_n)
		if hud_n.has_method("_ensure_graphics_menu"):
			hud_n._ensure_graphics_menu()
		if hud_n.has_method("_ensure_bench_ui"):
			hud_n._ensure_bench_ui()
		if hud_n.has_method("set_paused"):
			hud_n.set_paused(true)
		if hud_n.has_method("show_graphics_screen"):
			hud_n.show_graphics_screen()
			var gscr := hud_n.get_node_or_null("%GraphicsMenu") as Control
			if gscr == null:
				gscr = hud_n.find_child("GraphicsMenu", true, false) as Control
			if gscr == null:
				gscr = hud_n.find_child("GraphicsScreen", true, false) as Control
			if hud_n.get("screen") != null and int(hud_n.screen) != 3 and (gscr == null or not gscr.visible):
				# Screen.GRAPHICS == 3
				ok = false
				errors.append("Graphics screen did not show (still a HUD one-liner)")
			if hud_n.has_method("show_pause"):
				hud_n.show_pause()
		if hud_n.has_method("set_goal"):
			hud_n.set_goal({"title": "Act I — First District", "body": "Grow the first district."})
		if hud_n.has_method("set_heatmap"):
			hud_n.set_heatmap("Off")
		if hud_n.has_method("set_graphics_menu"):
			hud_n.set_graphics_menu("Low", "40", "On/Quality")
		if hud_n.has_method("set_bench_live"):
			hud_n.set_bench_live(true, 0.0, 0.0, 3.0)
		if hud_n.has_method("show_event"):
			hud_n.show_event("Event", "Body")
		if hud_n.has_method("layout_for_deck"):
			hud_n.layout_for_deck()
		var safe := GameConstants.HUD_SAFE_RECT
		var hud_root := hud_n.get_node_or_null("Root") as Control
		if hud_root == null:
			hud_root = hud_n.get_node_or_null("SafeArea") as Control
		if hud_root == null:
			ok = false
			errors.append("HUD missing Root/SafeArea")
		else:
			var rr: Rect2 = hud_root.get_global_rect()
			if absf(rr.position.x - 48.0) > 1.0 or absf(rr.position.y - 48.0) > 1.0:
				ok = false
				errors.append("HUD Root global pos %s not SafeArea (48,48)" % str(rr.position))
			if absf(rr.size.x - 1136.0) > 2.0 or absf(rr.size.y - 704.0) > 2.0:
				ok = false
				errors.append("HUD Root size %s not 1136x704" % str(rr.size))
			var rad = load("res://scripts/ui/radial_menu.gd").new()
			hud_root.add_child(rad)
			if rad.has_method("set_open"):
				rad.set_open(true)
			var row_ok := hud_n.get_node_or_null("%RowPreset") != null
			row_ok = row_ok and hud_n.get_node_or_null("%RowCap") != null
			row_ok = row_ok and hud_n.get_node_or_null("%RowFsr") != null
			if not row_ok:
				row_ok = hud_root.find_child("RowPreset", true, false) != null
				row_ok = row_ok and hud_root.find_child("RowCap", true, false) != null
				row_ok = row_ok and hud_root.find_child("RowFsr", true, false) != null
			if not row_ok:
				ok = false
				errors.append("graphics menu rows not in instantiated HUD")
			if hud_n.has_method("cycle_graphics_focus") or hud_n.has_method("cycle_gfx_row"):
				var before := str(hud_n.graphics_focus_id()) if hud_n.has_method("graphics_focus_id") else str(hud_n.get("gfx_row"))
				if hud_n.has_method("cycle_graphics_focus"):
					hud_n.cycle_graphics_focus(1)
				else:
					hud_n.cycle_gfx_row(1)
				var mid := str(hud_n.graphics_focus_id()) if hud_n.has_method("graphics_focus_id") else str(hud_n.get("gfx_row"))
				if mid == before:
					ok = false
					errors.append("graphics menu row did not cycle without mouse")
				if hud_n.has_method("cycle_graphics_focus"):
					hud_n.cycle_graphics_focus(1)
					hud_n.cycle_graphics_focus(1)
				else:
					hud_n.cycle_gfx_row(1)
					hud_n.cycle_gfx_row(1)
			var adv := hud_n.get_node_or_null("%AdvisorPanel") as Control
			if adv:
				var ar := adv.get_global_rect()
				if ar.position.x < 47.5:
					ok = false
					errors.append("Advisor global x=%.1f still tighter than 48" % ar.position.x)
			var nerr := errors.size()
			_assert_hud_safe(hud_n, safe, errors)
			if errors.size() > nerr:
				ok = false
		if hud_n.get_parent():
			hud_n.get_parent().remove_child(hud_n)
		hud_n.free()

	## 0.1.6 B abort: keyboard B + joy B → ABORTED, brush unchanged.
	var DeckScr = load("res://scripts/input/deck_controller.gd")
	if DeckScr == null or BenchScr == null:
		ok = false
		errors.append("deck/bench scripts failed to load for B-abort")
	else:
		var deck_n = DeckScr.new()
		var brush0: int = int(deck_n.brush_size)
		var bench3 = BenchScr.new()
		bench3.setup(null, MapData.new(), null)
		deck_n.bench_blocking = true
		deck_n.cancel_pressed.connect(func(): bench3.abort())
		bench3.start_smoke("low")
		if not bench3.is_running():
			ok = false
			errors.append("start_smoke did not enter RUNNING")
		var key_b := InputEventKey.new()
		key_b.pressed = true
		key_b.physical_keycode = KEY_B
		key_b.keycode = KEY_B
		deck_n._input(key_b)
		if bench3.is_running() or not bench3.is_aborted():
			ok = false
			errors.append("keyboard B did not abort (running=%s state=%s)" % [str(bench3.is_running()), str(bench3.state)])
		if int(deck_n.brush_size) != brush0:
			ok = false
			errors.append("keyboard B changed brush %d -> %d" % [brush0, int(deck_n.brush_size)])
		bench3.start_smoke("low")
		var joy_b := InputEventJoypadButton.new()
		joy_b.pressed = true
		joy_b.button_index = JOY_BUTTON_B
		deck_n._input(joy_b)
		if bench3.is_running() or not bench3.is_aborted():
			ok = false
			errors.append("joy B did not abort (running=%s state=%s)" % [str(bench3.is_running()), str(bench3.state)])
		if int(deck_n.brush_size) != brush0:
			ok = false
			errors.append("joy B changed brush")
		bench3.start_smoke("low")
		var joy_x := InputEventJoypadButton.new()
		joy_x.pressed = true
		joy_x.button_index = JOY_BUTTON_X
		deck_n._unhandled_input(joy_x)
		if int(deck_n.brush_size) != brush0:
			ok = false
			errors.append("X-brush cycled while bench running")
		if bench3 is Node:
			bench3.free()
		if deck_n is Node:
			deck_n.free()

	var gs_deck := GraphicsSettings.new()
	gs_deck.index = GraphicsPresets.Id.ULTRA
	gs_deck.fps_cap = 40
	if gs_deck.has_method("apply_deck_detect"):
		gs_deck.apply_deck_detect()
		if gs_deck.index == GraphicsPresets.Id.ULTRA:
			ok = false
			errors.append("Deck-detect path applied Ultra")
		if str(gs_deck.name()) != "low":
			ok = false
			errors.append("Deck-detect path preset %s not low" % gs_deck.name())
	else:
		ok = false
		errors.append("GraphicsSettings missing apply_deck_detect")
	var gs_low := GraphicsSettings.new()
	gs_low.index = GraphicsPresets.Id.LOW
	if gs_low.has_method("apply_deck_detect"):
		gs_low.apply_deck_detect()
		if gs_low.index != GraphicsPresets.Id.LOW:
			ok = false
			errors.append("Deck-detect auto-up from Low to %s" % gs_low.name())

	## 0.1.6 DLSS hook (disabled only) + FSR two-way + SafeArea constant + hide brush.
	if GameConstants.HUD_SAFE_RECT != Rect2(48, 48, 1136, 704):
		ok = false
		errors.append("HUD_SAFE_RECT %s not Rect2(48,48,1136,704)" % str(GameConstants.HUD_SAFE_RECT))
	if GraphicsSettings.FSR_NAMES.size() != 2:
		ok = false
		errors.append("FSR must be Off vs On/Quality (got %s)" % str(GraphicsSettings.FSR_NAMES))
	var gs_dlss := GraphicsSettings.new()
	if not gs_dlss.has_method("dlss_enabled") or gs_dlss.dlss_enabled():
		ok = false
		errors.append("DLSS hook missing or enabled")
	if gs_dlss.has_method("show_dlss_row") and gs_dlss.show_dlss_row() and OS.get_name() == "Linux":
		ok = false
		errors.append("DLSS row visible on Linux")
	if gs_dlss.has_method("apply_dlss"):
		gs_dlss.apply_dlss(null)
	if gs_dlss.has_method("apply_deck_defaults"):
		gs_dlss.apply_deck_defaults()
		if gs_dlss.index != 0 or int(gs_dlss.fps_cap) != 40 or int(gs_dlss.fsr_index) != 1:
			ok = false
			errors.append("apply_deck_defaults not Low/40/FSR (i=%s cap=%s fsr=%s)" % [
				str(gs_dlss.index), str(gs_dlss.fps_cap), str(gs_dlss.fsr_index)])
	var gs_src := FileAccess.get_file_as_string("res://scripts/ui/graphics_settings.gd")
	if gs_src.find("DLSS — 0.1.7") < 0:
		ok = false
		errors.append("DLSS label 0.1.7 missing")
	if gs_src.find("scaling_3d_mode = 3") >= 0 or gs_src.find("scaling_3d_mode = 4") >= 0:
		ok = false
		errors.append("fake DLSS scaling_3d_mode written")
	var apply_fsr_fn := _func_slice(gs_src, "func apply_fsr")
	if apply_fsr_fn.find("scaling_3d_mode = 1") >= 0:
		ok = false
		errors.append("apply_fsr used FSR1 mode as fake DLSS")
	if hud_src2.find("B abort") < 0:
		ok = false
		errors.append("help missing B abort")
	if hud_src2.find("set_brush_hidden") < 0:
		ok = false
		errors.append("hud.gd missing hide-brush")
	if main_src.find("cursor_hidden") < 0:
		ok = false
		errors.append("main.gd missing cursor hide during bench")
	if hud_src.find("RowDlss") < 0 and hud_src2.find("RowDlss") < 0:
		ok = false
		errors.append("DLSS row hook missing from HUD")

	## Deck / handheld Ultra: no SDFGI, VoxelGI, SSIL, SSR, volumetric fog.
	var deck_world := Node.new()
	var deck_we := WorldEnvironment.new()
	deck_we.name = "WorldEnvironment"
	deck_world.add_child(deck_we)
	GraphicsPresets.apply(deck_world, null, GraphicsPresets.Id.ULTRA, 1)
	var denv: Environment = deck_we.environment
	if denv == null:
		ok = false
		errors.append("handheld Ultra apply left no Environment")
	else:
		if denv.sdfgi_enabled:
			ok = false
			errors.append("Deck/handheld Ultra enabled SDFGI")
		if denv.ssil_enabled:
			ok = false
			errors.append("Deck/handheld Ultra enabled SSIL")
		if denv.ssr_enabled:
			ok = false
			errors.append("Deck/handheld Ultra enabled SSR")
		if denv.volumetric_fog_enabled:
			ok = false
			errors.append("Deck/handheld Ultra enabled volumetric fog")
		if not denv.ssao_enabled:
			ok = false
			errors.append("Deck/handheld Ultra missing SSAO")
	for ch in deck_world.get_children():
		if ch is VoxelGI and (ch as VoxelGI).visible:
			ok = false
			errors.append("Deck/handheld Ultra left VoxelGI visible")
	deck_world.free()

	## 0.1.6 glyphs: textures exist; help/pause/bench strings have no standalone LB/RB or View.
	var glyph_need: PackedStringArray = PackedStringArray([
		"res://assets/ui/glyphs/face_south.png",
		"res://assets/ui/glyphs/face_east.png",
		"res://assets/ui/glyphs/face_west.png",
		"res://assets/ui/glyphs/face_north.png",
		"res://assets/ui/glyphs/shoulder_l.png",
		"res://assets/ui/glyphs/shoulder_r.png",
		"res://assets/ui/glyphs/menu.png",
		"res://assets/ui/glyphs/stick_l.png",
		"res://assets/ui/glyphs/stick_r.png",
	])
	for gp in glyph_need:
		if not FileAccess.file_exists(gp):
			ok = false
			errors.append("missing glyph %s" % gp)
	var ui_blob := FileAccess.get_file_as_string("res://scripts/ui/hud.gd") + "\n" + FileAccess.get_file_as_string("res://scenes/hud.tscn") + "\n" + FileAccess.get_file_as_string("res://scripts/ui/glyphs.gd")
	# Scan assigned UI copy, not comments: quoted strings only.
	var ui_copy := ""
	var qi := 0
	while true:
		var a := ui_blob.find("\"", qi)
		if a < 0:
			break
		var b := ui_blob.find("\"", a + 1)
		if b < 0:
			break
		ui_copy += ui_blob.substr(a, b - a + 1) + "\n"
		qi = b + 1
	for bad in ["LB/RB", " LB ", " RB ", "View resume", "L3", "B abort", "A paint", "A Benchmark", "View pause"]:
		if ui_copy.find(bad) >= 0:
			ok = false
			errors.append("UI string still has console token %s" % bad.strip_edges())
	var GlyphsScr = load("res://scripts/ui/glyphs.gd")
	if GlyphsScr:
		for hf2 in ["help_play", "help_pause", "help_title", "help_bench", "help_graphics"]:
			if GlyphsScr.has_method(hf2):
				var ht := str(GlyphsScr.call(hf2))
				for tok in [" A ", " B ", "View", "LB", "RB", "L3", "L1", "R1"]:
					if ht.find(tok) >= 0:
						ok = false
						errors.append("HUD help %s has player-facing %s" % [hf2, tok.strip_edges()])

	## P0 Exit — title + pause must request_quit without killing this smoke process.
	if not InputMap.has_action("cancel"):
		ok = false
		errors.append("InputMap missing cancel action")
	else:
		var cancel_b := false
		for ev in InputMap.action_get_events("cancel"):
			if ev is InputEventJoypadButton and int(ev.button_index) == JOY_BUTTON_B:
				cancel_b = true
		if not cancel_b:
			ok = false
			errors.append("cancel is not bound to JOY_BUTTON_B")
	var hud_ps_exit = load("res://scenes/hud.tscn")
	if hud_ps_exit == null:
		ok = false
		errors.append("hud.tscn failed to load for Exit check")
	else:
		var hx: CanvasLayer = hud_ps_exit.instantiate()
		root.add_child(hx)
		if hx.has_method("show_title"):
			hx.show_title()
		if not (hx.has_method("is_title_open") and hx.is_title_open()):
			ok = false
			errors.append("title screen did not open")
		if hx.has_method("focused_action") and str(hx.focused_action()) != "play":
			ok = false
			errors.append("title default focus is %s not play" % str(hx.focused_action()))
		if not bool(hx.get("paused")):
			ok = false
			errors.append("opening title did not set paused")
		if not _tree_is_paused(hx):
			ok = false
			errors.append("opening title did not set tree.paused")
		# A / activate on title Play is not quit.
		if hx.has_method("activate_focused"):
			hx.activate_focused()
		if bool(hx.get("quit_requested")) or bool(hx.get("would_quit")):
			ok = false
			errors.append("title Play activate quit")
		if hx.has_method("is_title_open") and not hx.is_title_open():
			ok = false
			errors.append("title Play activate closed title without Play wiring")
		if hx.get_script():
			hx.set("quit_requested", false)
			hx.set("would_quit", false)
		if hx.has_method("highlight_exit"):
			hx.highlight_exit()
		if hx.has_method("focused_action") and str(hx.focused_action()) != "exit":
			ok = false
			errors.append("title Exit highlight failed (got %s)" % str(hx.focused_action() if hx.has_method("focused_action") else "?"))
		if hx.has_method("activate_focused"):
			hx.activate_focused()
		if not bool(hx.get("quit_requested")):
			ok = false
			errors.append("title Exit did not set quit_requested")
		if not bool(hx.get("would_quit")):
			ok = false
			errors.append("title Exit did not set would_quit")
		if hx.get_script():
			hx.set("quit_requested", false)
			hx.set("would_quit", false)
		if hx.has_method("hide_title"):
			hx.hide_title()
		if bool(hx.get("paused")):
			ok = false
			errors.append("hide_title did not clear paused")
		if _tree_is_paused(hx):
			ok = false
			errors.append("hide_title did not clear tree.paused")
		if hx.has_method("show_pause"):
			hx.show_pause()
		if hx.has_method("focused_action") and str(hx.focused_action()) != "resume":
			ok = false
			errors.append("pause default focus is %s not resume" % str(hx.focused_action()))
		if not bool(hx.get("paused")):
			ok = false
			errors.append("opening pause did not set paused")
		if not _tree_is_paused(hx):
			ok = false
			errors.append("opening pause did not set tree.paused")
		# 0.1.8: A on Resume must unpause. Re-open pause for Exit / FOCUS_IN checks.
		if hx.has_method("focused_action") and str(hx.focused_action()) == "resume":
			if hx.has_method("activate_focused"):
				hx.activate_focused()
			if bool(hx.get("paused")) or _tree_is_paused(hx):
				ok = false
				errors.append("confirm on Resume did not unpause")
			if bool(hx.get("quit_requested")):
				ok = false
				errors.append("confirm on Resume requested quit")
			if hx.has_method("show_pause"):
				hx.show_pause()
		# FOCUS_IN must not auto-resume.
		if hx.has_method("_notification"):
			hx._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			hx._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		if not bool(hx.get("paused")) or not _tree_is_paused(hx):
			ok = false
			errors.append("FOCUS_IN auto-resumed")
		# A on Graphics opens the graphics screen (not quit). Resume(0)·Exit(1)·Graphics(2).
		if hx.has_method("move_menu"):
			hx.move_menu(1)
			hx.move_menu(1)
		if hx.has_method("focused_action") and str(hx.focused_action()) != "graphics":
			ok = false
			errors.append("pause Graphics is not two flicks from Resume (got %s)" % str(hx.focused_action() if hx.has_method("focused_action") else "?"))
		if hx.has_method("activate_focused"):
			hx.activate_focused()
		if not (hx.has_method("is_graphics_screen") and hx.is_graphics_screen()):
			ok = false
			errors.append("pause Graphics did not open graphics screen")
		if bool(hx.get("quit_requested")):
			ok = false
			errors.append("pause Graphics requested quit")
		if hx.has_method("show_pause"):
			hx.show_pause()
		if hx.get_script():
			hx.set("quit_requested", false)
			hx.set("would_quit", false)
		if hx.has_method("move_menu"):
			hx.move_menu(1)
		if hx.has_method("focused_action") and str(hx.focused_action()) != "exit":
			ok = false
			errors.append("pause Exit is not one flick from Resume (got %s)" % str(hx.focused_action() if hx.has_method("focused_action") else "?"))
		if hx.has_method("activate_focused"):
			hx.activate_focused()
		if not bool(hx.get("quit_requested")):
			ok = false
			errors.append("pause Exit did not set quit_requested")
		if not bool(hx.get("would_quit")):
			ok = false
			errors.append("pause Exit did not set would_quit")
		if hx.has_method("get_exit_control"):
			var ex = hx.get_exit_control()
			if ex == null:
				ok = false
				errors.append("pause Exit control missing")
		if hx.has_method("set_paused"):
			hx.set_paused(false)
		if bool(hx.get("paused")):
			ok = false
			errors.append("resume did not clear paused")
		if _tree_is_paused(hx):
			ok = false
			errors.append("resume did not clear tree.paused")
		hx.free()
	for gn in ["pause", "confirm", "cancel", "paint", "radial", "brush", "orbit", "zoom", "pan", "heatmap"]:
		if not FileAccess.file_exists("res://assets/ui/glyphs/deck/%s.png" % gn):
			ok = false
			errors.append("missing action-named deck glyph %s.png" % gn)
	if main_src.find("show_title") < 0 or main_src.find("_on_title_play") < 0:
		ok = false
		errors.append("main.gd does not boot title / wire Play")
	var rq_main := _func_slice(main_src, "func request_quit")
	if rq_main.find("get_tree().quit()") < 0:
		ok = false
		errors.append("main request_quit missing get_tree().quit()")
	if rq_main.find("or OS.has_feature") >= 0 or rq_main.find("skip := Engine.is_editor_hint() or OS.has_feature") >= 0:
		ok = false
		errors.append("main request_quit still skips on OS.has_feature(headless)")
	var rq_hud := _func_slice(hud_src2, "func request_quit")
	if rq_hud.find("get_tree().quit()") < 0:
		ok = false
		errors.append("hud request_quit missing get_tree().quit()")
	if rq_hud.find("or OS.has_feature") >= 0 or rq_hud.find("skip := Engine.is_editor_hint() or OS.has_feature") >= 0:
		ok = false
		errors.append("hud request_quit still skips on OS.has_feature(headless)")
	if main_src.find("get_tree().paused") < 0 and main_src.find("t.paused") < 0:
		ok = false
		errors.append("main.gd does not set get_tree().paused")
	var focus_in := _func_slice(main_src, "func _on_overlay_focus_in")
	if focus_in == "":
		ok = false
		errors.append("main.gd missing _on_overlay_focus_in")
	else:
		if focus_in.find("paused = false") >= 0 or focus_in.find("_apply_city_pause(false)") >= 0 or focus_in.find("set_paused(false)") >= 0:
			ok = false
			errors.append("FOCUS_IN still auto-resumes")
	if rq_main.find("OS.has_feature") >= 0 or rq_hud.find("OS.has_feature") >= 0:
		ok = false
		errors.append("request_quit still mentions OS.has_feature")
	if rq_main.find("_is_headless_smoke") < 0 or rq_hud.find("_is_headless_smoke") < 0:
		ok = false
		errors.append("request_quit missing smoke-only _is_headless_smoke guard")

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


func _tree_is_paused(n: Node) -> bool:
	## Live tree when inside a running SceneTree; smoke _init uses the HUD tree_paused flag.
	if n.is_inside_tree():
		var t := n.get_tree()
		if t:
			return bool(t.paused)
	return bool(n.get("tree_paused"))


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


func _assert_hud_safe(n: Node, safe: Rect2, errors: PackedStringArray) -> void:
	if n is Control:
		var c := n as Control
		if not c.visible:
			return
		if c.visible:
			var r := c.get_global_rect()
			if r.size.x >= 1.0 and r.size.y >= 1.0:
				if r.position.x < safe.position.x - 0.6 or r.position.y < safe.position.y - 0.6 \
						or r.end.x > safe.end.x + 0.6 or r.end.y > safe.end.y + 0.6:
					var pname := str(c.name)
					if c.is_inside_tree():
						pname = str(c.get_path())
					errors.append("HUD %s rect %s outside safe %s" % [pname, str(r), str(safe)])
	for ch in n.get_children():
		_assert_hud_safe(ch, safe, errors)

