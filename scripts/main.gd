extends Node3D
## Metro Ops 3D — Kenney city, aggregate RCI, war & disaster. Steam Deck product path.
## Instances scenes/world.tscn (City Mesh) + HUD. No orbit_camera.gd.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")
const MapData = preload("res://scripts/systems/map_data.gd")
const BudgetSystem = preload("res://scripts/systems/budget_system.gd")
const SimSystem = preload("res://scripts/systems/sim_system.gd")
const AdvisorSystem = preload("res://scripts/systems/advisor_system.gd")
const ToolSystem = preload("res://scripts/systems/tool_system.gd")
const BuildingCatalog = preload("res://scripts/world/building_catalog.gd")
const CityView = preload("res://scripts/world/city_view.gd")
const WorldRoot = preload("res://scripts/world/world_root.gd")

@onready var deck: Node = $DeckController
@onready var hud: CanvasLayer = $HUD

var world: Node3D
var camera_rig: Node3D
var city_view: Node3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D

var map: MapData
var budget: BudgetSystem
var sim: SimSystem
var advisor: AdvisorSystem
var tools: ToolSystem
var catalog: BuildingCatalog
var radial: Control

var paused: bool = false
var sim_accum: float = 0.0
var cursor: Vector2i = Vector2i(64, 64)


func _bind_world_nodes() -> void:
	world = get_node_or_null("World") as Node3D
	if world == null:
		world = get_node_or_null("WorldRoot") as Node3D
	city_view = get_node_or_null("World/CityView") as Node3D
	if city_view == null and world:
		city_view = world.get_node_or_null("CityView") as Node3D
	if city_view == null:
		city_view = get_node_or_null("CityView") as Node3D
	camera_rig = get_node_or_null("World/CityCamera") as Node3D
	if camera_rig == null and world:
		camera_rig = world.get_node_or_null("CityCamera") as Node3D
	if camera_rig == null:
		camera_rig = get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		camera_rig = get_node_or_null("CityCamera") as Node3D
	world_env = get_node_or_null("World/WorldEnvironment") as WorldEnvironment
	if world_env == null and world:
		world_env = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	sun = get_node_or_null("World/DirectionalLight3D") as DirectionalLight3D
	if sun == null and world:
		sun = world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun == null:
		sun = get_node_or_null("Sun") as DirectionalLight3D


func _ready() -> void:
	_bind_world_nodes()
	Engine.max_fps = GameConstants.TARGET_FPS
	get_viewport().scaling_3d_mode = GameConstants.FSR_MODE
	get_viewport().scaling_3d_scale = GameConstants.FSR_SCALE
	get_viewport().fsr_sharpness = GameConstants.FSR_SHARPNESS
	_apply_deck_window()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_environment()

	# WorldRoot bootstraps MapData + BuildingCatalog in its _ready (child first).
	if world != null and world.get("map") != null:
		map = world.map
		catalog = world.catalog
	else:
		map = MapData.new()
		catalog = BuildingCatalog.new()
		catalog.load_all()
		if world != null and world.has_method("setup"):
			world.setup(map, catalog)
		elif city_view != null and city_view.has_method("setup"):
			city_view.setup(map, catalog, world_env)

	if catalog != null and catalog.failed.size() > 0:
		push_warning("Kenney load failed: %s" % str(catalog.failed))

	budget = BudgetSystem.new()
	sim = SimSystem.new()
	advisor = AdvisorSystem.new()
	tools = ToolSystem.new()

	var hq_w: Vector3 = map.lot_to_world(map.hq.x, map.hq.y)
	if camera_rig != null and camera_rig.has_method("setup"):
		camera_rig.setup(hq_w, map.world_size())
	cursor = map.hq

	radial = preload("res://scripts/ui/radial_menu.gd").new()
	var hud_root := hud.get_node_or_null("Root") as Control
	if hud_root:
		hud_root.add_child(radial)
	else:
		hud.add_child(radial)
	radial.set_open(false)

	deck.paint_pressed.connect(_on_paint)
	deck.cycle_next.connect(func(): tools.cycle(1); _refresh_advisor())
	deck.cycle_prev.connect(func(): tools.cycle(-1); _refresh_advisor())
	deck.toggle_pause.connect(_toggle_pause)
	deck.toggle_fps.connect(hud.toggle_fps_overlay)
	deck.war_pressed.connect(_trigger_war)
	deck.disaster_pressed.connect(_trigger_disaster)
	deck.radial_toggled.connect(_on_radial_toggled)
	deck.radial_select.connect(_on_radial_select)
	deck.brush_cycled.connect(_on_brush_cycled)

	hud.war_clicked.connect(_trigger_war)
	hud.disaster_clicked.connect(_trigger_disaster)
	hud.advisor_dismissed.connect(func(): pass)
	if hud.has_signal("resume_clicked"):
		hud.resume_clicked.connect(_resume_play)
	if hud.has_signal("overlay_focus_out"):
		hud.overlay_focus_out.connect(_on_overlay_focus_out)
	if hud.has_signal("overlay_focus_in"):
		hud.overlay_focus_in.connect(_on_overlay_focus_in)

	tools.tool_changed.connect(func(_id, label): hud.set_tool(label, tools.brush))
	budget.cash_changed.connect(hud.set_cash)
	sim.demand_changed.connect(_on_demand_changed)
	sim.tick_done.connect(func(): hud.set_event_status(sim.war_timer, sim.disaster_timer))

	hud.set_tool(tools.label(), tools.brush)
	hud.set_cash(budget.cash, 0, 0)
	hud.set_rci(sim.demand_label())
	hud.set_event_status(0, 0)
	_refresh_advisor()
	paused = false
	hud.set_paused(false)
	_update_cursor_visual()


func _setup_environment() -> void:
	## WorldRoot owns 0.1.4 filmic look (sun 0.58 / exposure 0.78 / fill / cheap SSAO).
	## Do not restore high-key sun/exposure — that is the Kenney diorama.
	if world != null and world.has_method("_setup_environment"):
		world._setup_environment()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and deck.rmb_orbit:
		if camera_rig != null and camera_rig.has_method("apply_mouse_orbit"):
			camera_rig.apply_mouse_orbit((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_rig != null and camera_rig.has_method("apply_wheel"):
				camera_rig.apply_wheel(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_rig != null and camera_rig.has_method("apply_wheel"):
				camera_rig.apply_wheel(1.0)
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if not deck.radial_open:
		if camera_rig != null and camera_rig.has_method("apply_input"):
			camera_rig.apply_input(deck.pan_vector, deck.orbit_vector, deck.zoom_delta, dt)

	_update_cursor_from_input()
	_update_cursor_visual()
	if city_view != null:
		city_view.cursor_lot = cursor
		city_view.cursor_brush = tools.brush

	if deck.radial_open and radial:
		radial.set_aim(deck.radial_aim)
		if radial.get("sticky_index") != deck.radial_index:
			radial.set_index(deck.radial_index)

	if deck.painting and not paused and not deck.radial_open:
		_try_paint_at(cursor)

	if not paused:
		sim_accum += dt
		while sim_accum >= GameConstants.SIM_TICK_SEC:
			sim_accum -= GameConstants.SIM_TICK_SEC
			sim.tick(map, budget)
			if city_view != null and city_view.has_method("notify_occupancy"):
				city_view.notify_occupancy()
			elif city_view != null and city_view.has_method("_mark_dirty"):
				city_view._mark_dirty()
			if hud.has_method("set_occupancy"):
				hud.set_occupancy(map.occupancy_percent())
			if hud.has_method("set_event_status"):
				hud.set_event_status(sim.war_timer, sim.disaster_timer)
			_refresh_advisor()


func _update_cursor_from_input() -> void:
	if deck.using_mouse() and not deck.radial_open:
		var mouse := get_viewport().get_mouse_position()
		var hit := _ray_lot(mouse)
		if hit.x >= 0:
			cursor = hit
			return
	if camera_rig != null and camera_rig.has_method("look_point"):
		var look: Vector3 = camera_rig.look_point()
		cursor = map.world_to_lot(look)
	cursor.x = clampi(cursor.x, 0, map.size - 1)
	cursor.y = clampi(cursor.y, 0, map.size - 1)


func _ray_lot(screen: Vector2) -> Vector2i:
	var cam: Camera3D = null
	if camera_rig != null:
		cam = camera_rig.get("camera") as Camera3D
		if cam == null:
			cam = camera_rig.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return Vector2i(-1, -1)
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var p := from + dir * t
	var lot := map.world_to_lot(p)
	if not map.in_bounds(lot.x, lot.y):
		return Vector2i(-1, -1)
	return lot


func _cursor_tint() -> Color:
	if tools == null:
		return Color(1.0, 0.92, 0.18, 0.72)
	match tools.current:
		ToolSystem.Tool.ROAD:
			return Color(0.88, 0.88, 0.90, 0.75)
		ToolSystem.Tool.ZONE_R:
			return Color(0.28, 0.95, 0.42, 0.78)
		ToolSystem.Tool.ZONE_C:
			return Color(0.28, 0.55, 1.0, 0.78)
		ToolSystem.Tool.ZONE_I:
			return Color(1.0, 0.86, 0.16, 0.78)
		ToolSystem.Tool.POWER:
			return Color(1.0, 0.92, 0.28, 0.78)
		ToolSystem.Tool.WATER:
			return Color(0.28, 0.82, 1.0, 0.78)
		_:
			return Color(1.0, 0.92, 0.18, 0.72)


func _update_cursor_visual() -> void:
	if city_view != null:
		city_view.cursor_lot = cursor
		city_view.cursor_brush = tools.brush
		city_view.cursor_tint = _cursor_tint()


func _apply_deck_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(GameConstants.VIEWPORT_W, GameConstants.VIEWPORT_H))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _resume_play() -> void:
	paused = false
	hud.set_paused(false)
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()


func _on_paint() -> void:
	if deck.radial_open:
		return
	if paused:
		_resume_play()
		return
	_try_paint_at(cursor)


func _try_paint_at(tile: Vector2i) -> void:
	if advisor.should_block_paint(tools.id_name(), map):
		hud.show_event("Advisor Block", "Build power before mass zoning.")
		_refresh_advisor()
		return
	if _paint_brush(tile):
		_on_paint_success(tile)
		return
	# HQ / road / water under the reticle — find a nearby buildable lot so A is never a dead click.
	for rad in range(1, 3):
		for oy in range(-rad, rad + 1):
			for ox in range(-rad, rad + 1):
				if ox == 0 and oy == 0:
					continue
				var n := Vector2i(tile.x + ox, tile.y + oy)
				if _paint_brush(n):
					_on_paint_success(n)
					return
	hud.show_event("Can't paint", "No buildable lot under cursor.")
	if city_view != null and city_view.has_method("flash_paint"):
		city_view.flash_paint(tile, false)


func _paint_brush(tile: Vector2i) -> bool:
	var half: int = tools.brush / 2
	var any := false
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			if tools.brush > 1 and ox * ox + oy * oy > half * half + 1:
				continue
			var t := Vector2i(tile.x + ox, tile.y + oy)
			if _paint_one(t):
				any = true
	return any


func _on_paint_success(tile: Vector2i) -> void:
	_refresh_advisor()
	hud.flash_color(Color(0.95, 0.85, 0.25))
	if city_view != null:
		if city_view.has_method("flash_paint"):
			city_view.flash_paint(tile, true)
		if city_view.has_method("notify_occupancy"):
			city_view.notify_occupancy()
		elif city_view.has_method("_mark_dirty"):
			city_view._mark_dirty()


func _paint_one(tile: Vector2i) -> bool:
	if not map.in_bounds(tile.x, tile.y):
		return false
	var cost := tools.cost()
	if not budget.can_afford(cost):
		hud.show_event("Broke", "Not enough cash ($%d needed)." % cost)
		return false
	var ok := false
	match tools.current:
		ToolSystem.Tool.ROAD:
			ok = map.paint_road(tile.x, tile.y)
		ToolSystem.Tool.ZONE_R:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.RESIDENTIAL)
		ToolSystem.Tool.ZONE_C:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.COMMERCIAL)
		ToolSystem.Tool.ZONE_I:
			ok = map.paint_zone(tile.x, tile.y, TileTypes.Zone.INDUSTRIAL)
		ToolSystem.Tool.POWER:
			ok = map.place_service(tile.x, tile.y, TileTypes.Service.POWER_PLANT)
		ToolSystem.Tool.WATER:
			ok = map.place_service(tile.x, tile.y, TileTypes.Service.WATER_TOWER)
	if ok:
		budget.spend(cost)
	return ok


func _on_radial_toggled(open: bool) -> void:
	radial.set_open(open)
	if open:
		radial.set_index(deck.radial_index)
		radial.set_aim(deck.radial_aim)


func _on_radial_select(index: int) -> void:
	if index < 0 or index >= ToolSystem.ORDER.size():
		return
	tools.set_tool(ToolSystem.ORDER[index])
	_refresh_advisor()


func _on_brush_cycled(size: int) -> void:
	tools.brush = size
	hud.set_tool(tools.label(), tools.brush)


func _toggle_pause() -> void:
	if deck.radial_open:
		return
	paused = not paused
	hud.set_paused(paused)
	if not paused:
		var vp := get_viewport()
		if vp:
			vp.gui_release_focus()
	_refresh_advisor()



func _on_overlay_focus_out() -> void:
	# QAM / Steam overlay / sleep — stop the sim. Stay paused until View (no auto-resume on FOCUS_IN).
	if paused:
		return
	paused = true
	hud.set_paused(true)


func _on_overlay_focus_in() -> void:
	# Deck Tech: no auto-resume. View / A still unpause via _toggle_pause / _resume_play.
	pass


func _on_demand_changed(_r: float, _c: float, _i: float) -> void:
	hud.set_rci(sim.demand_label())


func _refresh_advisor() -> void:
	var msgs: Array = advisor.evaluate(map, budget, tools.id_name(), sim)
	hud.set_advisor(msgs)


func _trigger_war() -> void:
	if paused:
		paused = false
		hud.set_paused(false)
	var info: Dictionary = sim.start_war(budget)
	hud.show_event(info["title"], info["body"])
	hud.set_event_status(sim.war_timer, sim.disaster_timer)
	hud.flash_color(Color(1.0, 0.25, 0.12))
	if city_view != null and city_view.has_method("pulse_war"):
		city_view.pulse_war()
	_refresh_advisor()


func _trigger_disaster() -> void:
	if paused:
		paused = false
		hud.set_paused(false)
	var info: Dictionary = sim.start_disaster(map, budget)
	hud.show_event(info["title"], info["body"])
	hud.set_event_status(sim.war_timer, sim.disaster_timer)
	hud.flash_color(Color(0.55, 0.12, 0.05))
	if city_view != null and city_view.has_method("pulse_disaster"):
		city_view.pulse_disaster()
	_refresh_advisor()
