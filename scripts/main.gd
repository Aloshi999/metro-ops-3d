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
const GraphicsPresets = preload("res://scripts/world/graphics_presets.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const AudioBed = preload("res://scripts/systems/audio_bed.gd")
const BenchmarkMode = preload("res://scripts/systems/benchmark.gd")
const CampaignSystem = preload("res://scripts/systems/campaign_system.gd")

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
var gfx: GraphicsSettings

var audio_bed: AudioBed
var bench: BenchmarkMode
var campaign: CampaignSystem

var paused: bool = false
var menu_open: bool = false
var quit_requested: bool = false
var would_quit: bool = false
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
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = GameConstants.FSR_MODE
		vp.scaling_3d_scale = GameConstants.FSR_SCALE
		vp.fsr_sharpness = GameConstants.FSR_SHARPNESS
	_apply_deck_window()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var preset: int = GraphicsPresets.Id.LOW
	var metro_gfx := OS.get_environment("METRO_GRAPHICS").strip_edges()
	if not metro_gfx.is_empty():
		preset = GraphicsPresets.id_from_name(metro_gfx)
	if world != null and world.has_method("apply_graphics_preset"):
		world.apply_graphics_preset(preset)
	else:
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
	sim.tutor_active = true
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
	if deck.has_signal("open_menu"):
		deck.open_menu.connect(_open_pause_from_start)
	deck.toggle_fps.connect(hud.toggle_fps_overlay)
	deck.war_pressed.connect(_trigger_war)
	deck.disaster_pressed.connect(_trigger_disaster)
	deck.radial_toggled.connect(_on_radial_toggled)
	deck.radial_select.connect(_on_radial_select)
	deck.brush_cycled.connect(_on_brush_cycled)
	if deck.has_signal("gfx_cycle"):
		deck.gfx_cycle.connect(_on_gfx_cycle)
	if deck.has_signal("gfx_row"):
		deck.gfx_row.connect(_on_gfx_row)
	if deck.has_signal("gfx_row_move"):
		deck.gfx_row_move.connect(_on_gfx_row)
	if deck.has_signal("menu_row_shift"):
		deck.menu_row_shift.connect(_on_gfx_row)
	if deck.has_signal("heatmap_toggled"):
		deck.heatmap_toggled.connect(_on_heatmap_toggled)

	hud.war_clicked.connect(_trigger_war)
	hud.disaster_clicked.connect(_trigger_disaster)
	hud.advisor_dismissed.connect(func(): pass)
	# View-only resume. Do not wire A / Resume button / events to _resume_play.
	if hud.has_signal("overlay_focus_out"):
		hud.overlay_focus_out.connect(_on_overlay_focus_out)
	if hud.has_signal("overlay_focus_in"):
		hud.overlay_focus_in.connect(_on_overlay_focus_in)
	if hud.has_signal("resume_clicked"):
		hud.resume_clicked.connect(_resume_from_menu)
	if hud.has_signal("exit_clicked"):
		hud.exit_clicked.connect(_on_hud_exit)

	tools.tool_changed.connect(func(_id, label): hud.set_tool(label, tools.brush))
	budget.cash_changed.connect(hud.set_cash)
	sim.demand_changed.connect(_on_demand_changed)
	sim.tick_done.connect(func(): hud.set_event_status(sim.war_timer, sim.disaster_timer))

	hud.set_tool(tools.label(), tools.brush)
	hud.set_cash(budget.cash, 0, 0)
	hud.set_rci(sim.demand_label())
	if hud.has_method("set_occupancy"):
		hud.set_occupancy(map.occupancy_percent())
	if hud.has_method("set_happiness"):
		hud.set_happiness(sim.happiness)
	hud.set_event_status(0, 0)
	_refresh_advisor()
	if hud:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if deck:
		deck.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_city_pause(false)
	hud.set_paused(false)
	_boot_graphics()
	_boot_audio()
	_boot_benchmark()
	_boot_campaign()
	_update_cursor_visual()
	if hud.has_signal("play_pressed") and not hud.play_pressed.is_connected(_on_title_play):
		hud.play_pressed.connect(_on_title_play)
	if hud.has_signal("resume_clicked") and not hud.resume_clicked.is_connected(_resume_from_menu):
		hud.resume_clicked.connect(_resume_from_menu)
	if hud.has_method("show_title"):
		hud.show_title()
		_apply_city_pause(true)



func _sync_menu_exclusive() -> void:
	## Title / pause / graphics → city input dead. Play / Resume is the only clear.
	if deck == null:
		return
	var on := false
	if hud:
		if hud.has_method("is_menu_open"):
			on = bool(hud.is_menu_open())
		else:
			on = paused
			if hud.has_method("is_title_open") and hud.is_title_open():
				on = true
	if deck.has_method("set_menu_exclusive"):
		deck.set_menu_exclusive(on)
	else:
		deck.menu_focus = on
		deck.graphics_focus = on
		if on:
			deck.pan_vector = Vector2.ZERO
			deck.orbit_vector = Vector2.ZERO
			deck.zoom_delta = 0.0
			deck.painting = false


func _setup_environment() -> void:
	## WorldRoot owns 0.1.4 filmic look (sun 0.58 / exposure 0.78 / fill / cheap SSAO).
	## Do not restore high-key sun/exposure — that is the Kenney diorama.
	if world != null and world.has_method("_setup_environment"):
		world._setup_environment()


func _unhandled_input(event: InputEvent) -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		get_viewport().set_input_as_handled()
		return
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
	if bench != null and bench.is_running():
		bench.tick(dt)
	var menu_up: bool = deck != null and deck.has_method("is_menu_exclusive") and bool(deck.is_menu_exclusive())
	if not menu_up and not deck.radial_open and not (bench != null and bench.is_blocking()):
		if camera_rig != null and camera_rig.has_method("apply_input"):
			camera_rig.apply_input(deck.pan_vector, deck.orbit_vector, deck.zoom_delta, dt)

	_update_cursor_from_input()
	_update_cursor_visual()
	_sync_bench_block()
	if city_view != null:
		city_view.cursor_lot = cursor
		var blocking := bench != null and bench.is_blocking()
		city_view.cursor_hidden = blocking
		city_view.cursor_brush = 0 if blocking else tools.brush
		if deck:
			deck.bench_blocking = blocking
		city_view.cursor_hidden = bench != null and bench.is_blocking()

	if deck.radial_open and radial:
		radial.set_aim(deck.radial_aim)
		if radial.get("sticky_index") != deck.radial_index:
			radial.set_index(deck.radial_index)

	if deck.painting and not menu_up and not paused and not deck.radial_open and not (bench != null and bench.is_blocking()):
		_try_paint_at(cursor)

	if not paused or (bench != null and bench.is_running()):
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
			if hud.has_method("set_happiness"):
				hud.set_happiness(sim.happiness)
			if hud.has_method("set_event_status"):
				hud.set_event_status(sim.war_timer, sim.disaster_timer)
			_refresh_advisor()


func _update_cursor_from_input() -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		return
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
		city_view.cursor_hidden = bench != null and bench.is_blocking()
		city_view.cursor_lot = cursor
		city_view.cursor_brush = 0 if (bench != null and bench.is_blocking()) else tools.brush
		city_view.cursor_tint = _cursor_tint()


func _apply_deck_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(GameConstants.VIEWPORT_W, GameConstants.VIEWPORT_H))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _resume_play() -> void:
	# Unused. Resume only via _toggle_pause (View). Kept so leftover HUD signals cannot unpause.
	pass


func _on_title_play() -> void:
	if hud != null and hud.has_method("hide_title"):
		hud.hide_title()
	_apply_city_pause(false)
	hud.set_paused(false)


func _on_paint() -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		if hud != null and hud.has_method("activate_focused"):
			hud.activate_focused()
		return
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		if hud.has_method("activate_focused"):
			hud.activate_focused()
		return
	if deck.radial_open:
		return
	if bench != null and bench.is_blocking():
		if bench.is_results():
			_dismiss_benchmark()
		return
	if paused:
		# Stay paused until View or A-on-Resume. A confirms the focused item.
		_on_pause_confirm()
		return
	_try_paint_at(cursor)


func _on_pause_confirm() -> void:
	if hud == null:
		return
	if hud.has_method("is_graphics_screen") and hud.is_graphics_screen():
		if hud.has_method("activate_focused"):
			hud.activate_focused()
		return
	var id := ""
	if hud.has_method("confirm_pause_item"):
		id = str(hud.confirm_pause_item())
	elif hud.has_method("activate_pause_item"):
		id = str(hud.activate_pause_item())
	if id == "benchmark":
		_start_benchmark_from_pause()
	elif id == "resume":
		_resume_from_menu()
	elif id == "" and hud.has_method("activate_focused"):
		hud.activate_focused()


func _try_paint_at(tile: Vector2i) -> void:
	if advisor.should_block_paint(tools.id_name(), map, campaign):
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
		if campaign != null:
			campaign.note_paint()
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



func _boot_graphics() -> void:
	gfx = GraphicsSettings.new()
	gfx.boot()
	## Saved preset/fps/fsr win. Do not copy world.graphics_preset over a player pick.
	gfx.apply(get_viewport(), world)
	_refresh_graphics_hud()
	if hud.has_method("set_dlss_row"):
		hud.set_dlss_row(bool(gfx.show_dlss_row()) if gfx.has_method("show_dlss_row") else false)


func _boot_audio() -> void:
	audio_bed = AudioBed.new()
	audio_bed.name = "AudioBed"
	add_child(audio_bed)
	audio_bed.load_all()
	audio_bed.play_boot()


func set_district(district: String) -> void:
	## Optional Mesh/Look hook: downtown / park / waterfront / rail / night.
	if audio_bed != null:
		audio_bed.set_district(district)


func _on_gfx_row(dir: int) -> void:
	if bench != null and bench.is_running():
		return
	if hud == null:
		return
	if hud.has_method("is_title_open") and hud.is_title_open():
		if hud.has_method("move_menu"):
			hud.move_menu(dir)
		return
	if not paused:
		return
	if hud.has_method("is_graphics_screen") and hud.is_graphics_screen():
		if hud.has_method("cycle_graphics_focus"):
			hud.cycle_graphics_focus(dir)
		elif hud.has_method("cycle_gfx_row"):
			hud.cycle_gfx_row(dir)
	elif hud.has_method("cycle_pause_item"):
		hud.cycle_pause_item(dir)


func _on_gfx_cycle(dir: int) -> void:
	if bench != null and bench.is_running():
		return
	if not paused:
		return
	if hud == null or not (hud.has_method("is_graphics_screen") and hud.is_graphics_screen()):
		return
	if gfx == null:
		_boot_graphics()
	var row := 0
	if hud != null:
		row = int(hud.get("gfx_row"))
	var toast := "Graphics"
	var body := gfx.label()
	if row == 1:
		gfx.cycle_fps(dir)
		toast = "FPS cap"
		body = gfx.fps_label()
	elif row == 2:
		gfx.cycle_fsr(dir)
		gfx.apply_fsr(get_viewport())
		toast = "FSR"
		body = gfx.fsr_label()
	else:
		gfx.cycle_preset(dir)
		if world != null and world.has_method("apply_graphics_preset"):
			world.apply_graphics_preset(gfx.index)
		else:
			gfx.apply(get_viewport(), world)
		## Preset apply must not keep a stomp on player FPS/FSR.
		gfx.apply_fps()
		gfx.apply_fsr(get_viewport())
		body = gfx.label()
	_refresh_graphics_hud()
	hud.show_event(toast, body)


func _refresh_graphics_hud() -> void:
	if gfx == null or hud == null:
		return
	if hud.has_method("set_graphics_menu"):
		hud.set_graphics_menu(gfx.label(), gfx.fps_label() if gfx.has_method("fps_label") else gfx.cap_label(), gfx.fsr_label())
	elif hud.has_method("set_graphics_state"):
		hud.set_graphics_state(gfx.label(), gfx.fps_label(), gfx.fsr_label())
	elif hud.has_method("set_graphics"):
		hud.set_graphics(gfx.label())


func _on_brush_cycled(size: int) -> void:
	if bench != null and bench.is_blocking():
		return
	tools.brush = size
	hud.set_tool(tools.label(), tools.brush)


func request_quit() -> void:
	## Confirm on Exit. Flag first so headless smoke can intercept. Process must die on Deck.
	quit_requested = true
	would_quit = true
	OS.set_restart_on_exit(false)
	if hud != null:
		hud.quit_requested = true
		hud.set("would_quit", true)
	# Documented headless smoke guard: skip process death ONLY for
	# tests/smoke_headless.gd or --quit-smoke. Never the engine headless feature tag
	# — that tag is compiled into Linux templates and made Deck Exit a no-op.
	if Engine.is_editor_hint() or _is_headless_smoke():
		return
	if get_tree():
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


func _apply_city_pause(p: bool) -> void:
	## Stop city cash / RCI / camera idle / events. HUD + Deck stay live for menus.
	paused = p
	menu_open = p
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
		hud.set("paused", p)
		hud.set("menu_open", p)
		hud.set("tree_paused", p)
	if deck:
		deck.process_mode = Node.PROCESS_MODE_ALWAYS
	var t: SceneTree = get_tree() if is_inside_tree() else null
	if t == null:
		t = Engine.get_main_loop() as SceneTree
	if t:
		t.paused = p
	_sync_menu_exclusive()


func _on_hud_exit() -> void:
	request_quit()


func _resume_from_menu() -> void:
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		return
	_apply_city_pause(false)
	hud.set_paused(false)
	_refresh_advisor()


func _open_pause_from_start() -> void:
	## Start / Menu also emits toggle_pause first. Re-opening here after a resume
	## toggle would make Start a no-op. View/Start unpause via _toggle_pause only.
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		return
	if deck.radial_open:
		return
	if bench != null and bench.is_running():
		bench.abort()
		return
	if bench != null and bench.is_results():
		_dismiss_benchmark()
		return


func _toggle_pause() -> void:
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		return
	if deck.radial_open:
		return
	if bench != null and bench.is_running():
		bench.abort()
		return
	if bench != null and bench.is_results():
		_dismiss_benchmark()
	_apply_city_pause(not paused)
	hud.set_paused(paused)
	if not paused:
		var vp := get_viewport()
		if vp:
			vp.gui_release_focus()
	_refresh_advisor()



func _on_overlay_focus_out() -> void:
	# QAM / Steam overlay / sleep — stop the sim. Stay paused until View (no auto-resume on FOCUS_IN).
	if bench != null and bench.is_running():
		bench.abort()
	if paused:
		return
	_apply_city_pause(true)
	hud.set_paused(true)


func _on_overlay_focus_in() -> void:
	# No auto-resume. Drop any GUI focus Steam overlay left behind. View unpauses.
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()


func _boot_benchmark() -> void:
	bench = BenchmarkMode.new()
	bench.name = "Benchmark"
	add_child(bench)
	bench.setup(camera_rig, map, city_view)
	if bench.has_signal("live_fps"):
		bench.live_fps.connect(_on_bench_live)
	if bench.has_signal("finished"):
		bench.finished.connect(_on_bench_finished)
	if bench.has_signal("aborted"):
		bench.aborted.connect(_on_bench_aborted)
	if deck.has_signal("cancel_pressed"):
		deck.cancel_pressed.connect(_on_cancel_pressed)
	call_deferred("_maybe_boot_benchmark")


func _maybe_boot_benchmark() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for a in OS.get_cmdline_user_args():
		args.append(a)
	var env := OS.get_environment("METRO_BENCH").strip_edges().to_lower()
	var want_smoke := env == "smoke"
	var want_full := env == "1" or env == "full" or env == "bench"
	for a in args:
		if a == "--bench-smoke":
			want_smoke = true
		elif a == "--bench":
			want_full = true
	if want_smoke:
		_start_benchmark(true, true)
	elif want_full:
		_start_benchmark(true, false)


func _start_benchmark_from_pause() -> void:
	## A from pause starts the path. Does not resume free play.
	_start_benchmark(false, false)


func _start_benchmark(lock_low: bool, p_smoke: bool) -> void:
	if bench == null:
		return
	if bench.is_running():
		return
	_lock_bench_low()
	if hud.has_method("set_bench_results"):
		hud.set_bench_results(false, {})
	_apply_city_pause(false)
	hud.set_paused(false)
	var preset := "low"
	if gfx != null:
		preset = gfx.name()
	elif world != null and world.get("graphics_preset") != null:
		preset = GraphicsPresets.name_of(int(world.graphics_preset))
	if lock_low:
		preset = "low"
	## Bench always caps at Deck 40. Restore player pick when the run ends.
	Engine.max_fps = GameConstants.TARGET_FPS
	if p_smoke:
		bench.start_smoke(preset)
	else:
		bench.start(preset)
	_sync_bench_block()
	if hud.has_method("set_bench_live"):
		hud.set_bench_live(true, 0.0, 0.0, bench.duration)


func _lock_bench_low() -> void:
	## Bench defaults: Low / 40 / FSR2 0.67. Do not persist over the player's cap.
	if gfx != null and gfx.has_method("apply_bench_lock"):
		gfx.apply_bench_lock(get_viewport(), world)
	else:
		if world != null and world.has_method("apply_graphics_preset"):
			world.apply_graphics_preset(GraphicsPresets.Id.LOW)
		Engine.max_fps = GameConstants.TARGET_FPS
		var vp := get_viewport()
		if vp:
			vp.scaling_3d_mode = GameConstants.FSR_MODE
			vp.scaling_3d_scale = GameConstants.FSR_SCALE
			vp.fsr_sharpness = GameConstants.FSR_SHARPNESS
	if hud.has_method("set_graphics"):
		hud.set_graphics("Low")


func _on_cancel_pressed() -> void:
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		if hud.has_method("highlight_exit"):
			hud.highlight_exit()
		return
	if bench != null and bench.is_running():
		bench.abort()
		return
	if bench != null and bench.is_results():
		_dismiss_benchmark()
		return
	if paused and hud != null and hud.has_method("is_graphics_screen") and hud.is_graphics_screen():
		if hud.has_method("back_to_pause_root"):
			hud.back_to_pause_root()
		elif hud.has_method("show_pause"):
			hud.show_pause()
		return
	if paused:
		# B on pause root stays paused. View resumes play.
		if hud.has_method("back_from_menu"):
			hud.back_from_menu()
		return
	# B opens pause if it is not already open.
	_apply_city_pause(true)
	hud.set_paused(true)
	_refresh_advisor()


func _on_bench_live(fps: float, elapsed: float, duration: float) -> void:
	if hud.has_method("set_bench_live"):
		hud.set_bench_live(true, fps, elapsed, duration)


func _on_bench_finished(results: Dictionary) -> void:
	_clear_bench_input()
	_restore_player_fps()
	if hud.has_method("set_bench_live"):
		hud.set_bench_live(false, 0.0, 0.0, 0.0)
	if hud.has_method("set_bench_results"):
		hud.set_bench_results(true, results)
	_apply_city_pause(true)
	hud.set_paused(true)


func _on_bench_aborted() -> void:
	_clear_bench_input()
	_restore_player_fps()
	if hud.has_method("set_bench_live"):
		hud.set_bench_live(false, 0.0, 0.0, 0.0)
	if hud.has_method("set_bench_results"):
		hud.set_bench_results(false, {})
	_apply_city_pause(true)
	hud.set_paused(true)


func _dismiss_benchmark() -> void:
	if bench != null:
		bench.dismiss()
	if hud.has_method("set_bench_results"):
		hud.set_bench_results(false, {})
	if hud.has_method("set_bench_live"):
		hud.set_bench_live(false, 0.0, 0.0, 0.0)
	_sync_bench_block()


func _clear_bench_input() -> void:
	if deck:
		deck.bench_blocking = false
	if city_view:
		city_view.cursor_hidden = false


func _restore_player_fps() -> void:
	if gfx != null:
		gfx.apply_fps()
		gfx.apply_fsr(get_viewport())
		_refresh_graphics_hud()
	else:
		Engine.max_fps = GameConstants.TARGET_FPS
	_sync_bench_block()


func _sync_bench_block() -> void:
	if deck:
		deck.bench_blocking = bench != null and bench.is_blocking()


func _boot_campaign() -> void:
	campaign = CampaignSystem.new()
	sim.campaign = campaign
	if campaign.has_signal("card_fired"):
		campaign.card_fired.connect(_on_campaign_card)
	if campaign.has_signal("goal_changed"):
		campaign.goal_changed.connect(_on_campaign_goal)
	campaign.tick(map, budget, sim)
	if hud.has_method("set_goal"):
		hud.set_goal(campaign.goal_card())


func _on_campaign_card(title: String, body: String) -> void:
	# Existing one-card toast. Do not unpause.
	hud.show_event(title, body)


func _on_campaign_goal(card: Dictionary) -> void:
	if hud.has_method("set_goal"):
		hud.set_goal(card)


func _on_heatmap_toggled() -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		return
	if hud != null and hud.has_method("is_title_open") and hud.is_title_open():
		return
	if bench != null and bench.is_blocking():
		return
	if city_view == null or not city_view.has_method("cycle_heatmap"):
		return
	var mode: int = int(city_view.cycle_heatmap())
	var label := "Off"
	if city_view.has_method("heatmap_label"):
		label = str(city_view.heatmap_label())
	elif mode == 1:
		label = "Land value"
	elif mode == 2:
		label = "Occupancy"
	if hud.has_method("set_heatmap"):
		hud.set_heatmap(label)
	hud.show_event("Heatmap", label)


func _on_demand_changed(_r: float, _c: float, _i: float) -> void:
	hud.set_rci(sim.demand_label())


func _refresh_advisor() -> void:
	var msgs: Array = advisor.evaluate(map, budget, tools.id_name(), sim, campaign)
	hud.set_advisor(msgs)


func _trigger_war() -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		return
	var info: Dictionary = sim.start_war(budget)
	hud.show_event(info["title"], info["body"])
	hud.set_event_status(sim.war_timer, sim.disaster_timer)
	hud.flash_color(Color(1.0, 0.25, 0.12))
	if city_view != null and city_view.has_method("pulse_war"):
		city_view.pulse_war()
	_refresh_advisor()


func _trigger_disaster() -> void:
	if deck and deck.has_method("is_menu_exclusive") and deck.is_menu_exclusive():
		return
	var info: Dictionary = sim.start_disaster(map, budget)
	hud.show_event(info["title"], info["body"])
	hud.set_event_status(sim.war_timer, sim.disaster_timer)
	hud.flash_color(Color(0.55, 0.12, 0.05))
	if city_view != null and city_view.has_method("pulse_disaster"):
		city_view.pulse_disaster()
	_refresh_advisor()
