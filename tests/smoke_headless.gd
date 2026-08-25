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

	var war := sim.start_war(budget)
	if budget.tax_mult >= 1.0:
		ok = false
		errors.append("war tax_mult not applied")
	if not war.has("title"):
		ok = false
		errors.append("war event malformed")
	if "Commercial" not in str(war.get("body", "")):
		ok = false
		errors.append("war body missing demand feedback")

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
