# Metro Ops 3D

Steam Deck–first **3D** city-builder product path (Godot **4.7.2**, Forward+).

Opens on a real **Kenney City Kit** suburban / commercial / industrial / roads city (GLB meshes), not cubes or voxels. Aggregate RCI sim, budget ledger, advisor, war embargo, disaster chunk damage.

War-room locks from day one: **40 FPS** target, **FSR2** at **0.67** scale, **1280×800**. Do not change FSR or FPS.

## Product path

```
/workspace/metro-ops-3d
```

Godot binary:

```
/workspace/tools/godot/godot
```

Linux Deck tarball (after export):

```
/workspace/MetroOps3D-deck.tar.gz
```

This tree is the **sellable 3D product**. The 2D slice lives at `/workspace/metro-ops` (read-only for porting). Do not touch `/workspace/scrap-orbit`.

## How to run

```bash
/workspace/tools/godot/godot --path /workspace/metro-ops-3d
```

or:

```bash
/workspace/metro-ops-3d/run_godot.sh
```

Windowed Deck-native viewport: **1280×800**. Engine cap: `Engine.max_fps = 40` (also `debug/settings/fps/force_fps=40`).

### Headless smoke

```bash
/workspace/tools/godot/godot --headless --path /workspace/metro-ops-3d -s res://tests/smoke_headless.gd
```

Expect `SMOKE_OK` and exit code 0. The smoke paints R/C zones, fires **War** + **Disaster**, and asserts Kenney GLBs instantiate as real meshes (not `BoxMesh`).

### Linux / Steam Deck export

```bash
/workspace/tools/godot/godot --headless --path /workspace/metro-ops-3d --export-release "Steam Deck (Linux x86_64)" builds/linux/MetroOps3D.x86_64
tar czf /workspace/MetroOps3D-deck.tar.gz -C /workspace/metro-ops-3d/builds/linux MetroOps3D.x86_64 MetroOps3D.pck
```

## Deck / FSR / 40 FPS (locked)

| Setting | Value |
|--------|--------|
| Renderer | Forward+ (`rendering_method=forward_plus`) |
| Viewport | 1280×800 |
| Max FPS | **40** (`force_fps=40`, physics 40 Hz) |
| FSR | `scaling_3d/mode=2` (FSR2), `scale=0.67`, `fsr_sharpness=0.2` |
| Shadows | Directional map 1024, FillLight (no shadows), cheap SSAO quality 0 (kill first if 1% lows slip); no glow / volumetrics |

Do **not** raise FSR scale, switch FSR off, or lift the 40 FPS cap.

## Controls (gamepad-first)

HUD shows **action glyphs + verbs** (Paint / Tools / Brush / Pause / Heatmap). No console button names.

Godot InputMap (config only — never printed in HUD):

| Action | Bind |
|--------|------|
| `pan_*` | L-stick / D-pad / WASD |
| orbit / zoom | R-stick |
| `paint` | joy 0 + Space + LMB |
| `radial` | joy 3 + R |
| `brush_size` | joy 2 + B key |
| `cancel` | joy 1 (B) — Back / Abort; opens pause if closed |
| `pause_advisor` | joy 6 (Start) + Esc — Pause / Resume |
| `cycle_tool_prev` / `cycle_tool_next` | joy 4/5 (Back/Guide) + Q / E |
| `toggle_heatmap` | joy 7 + H |
| `toggle_fps` | joy 8 + F3 |
| War / Disaster | keys `1` / `2` |

Boot **Title**: Play (default) + Exit. Pause: Resume (default) · Exit · Graphics. Exit is a menu item (`get_tree().quit()`). Steam Input IGA draft lives in `extras/steam/metro_ops_iga.vdf` — CoS must approve any Steamworks upload. AppID unknown.

Mouse picking only takes over **after real pointer motion** — sticks stay in charge on Deck.

## Map & sim

- **Map:** 128×128 lots × **16 m** → 2048 m city
- **Chunk:** 16×16 lots → **8×8** chunks
- **Fog-of-build:** paint only on revealed lots (HQ / roads reveal)
- **Active-chunk sim:** occupancy + tax only on touched chunks
- **No** per-citizen agents, **no** car pathfinding

HQ seeds a visible downtown (road grid + mixed RCI + power/water) so the product **opens as a 3D city**.

## Playable slice

1. Orbit the Kenney downtown (houses, shops, factories, road tiles).
2. Paint **roads** then **R / C / I** — lots spawn / swap Kenney GLBs as occupancy tiers grow (house → midrise → tower / factory).
3. **Power plant** + **water tower** radii; zones need power + water + road to fill.
4. **Budget** — occupancy-weighted R/C/I tax minus service upkeep; cash HUD.
5. **Advisor** — warns / soft-blocks mass zoning before power.
6. **War** — trade embargo (tax ×0.45) + levy −$4000; C/I demand crushed.
7. **Disaster** — damages a random **active** chunk (buildings overlay-dark, occupancy crash).
8. HUD: cash, Δ tax/upkeep, RCI demand, advisor, War/Disaster buttons + timers.

## Kenney city (not cubes)

Zone paint instantiates **real GLBs** from `assets/city/`:

| Pack | Path | Use |
|------|------|-----|
| City Kit Suburban 2.0 | `kenney_suburban/` | Houses (R) |
| City Kit Commercial 2.1 | `kenney_commercial/` | Shops + skyscrapers (C, HQ) |
| City Kit Industrial 1.0 | `kenney_industrial/` | Factories, tanks, chimneys (I, power, water) |
| City Kit Roads | `kenney_roads/` | Straight / bend / T / cross, lamps |

`scripts/world/building_catalog.gd` picks occupancy tiers. Empty lots never fall back to `BoxMesh` cubes.

## Systems

| Module | Role |
|--------|------|
| `scripts/core/game_constants.gd` | Locked sizes, costs, FSR/FPS, camera |
| `scripts/core/tile_types.gd` | Terrain / zone / service enums + colors |
| `scripts/core/chunk_data.gd` | Per-chunk aggregate occupancy |
| `scripts/systems/map_data.gd` | 128² lots, fog, paint, downtown seed |
| `scripts/systems/sim_system.gd` | Active-chunk growth + war/disaster |
| `scripts/systems/budget_system.gd` | Cash, tax, upkeep |
| `scripts/systems/advisor_system.gd` | Warnings / soft blocks |
| `scripts/systems/tool_system.gd` | Road / RCI / power / water |
| `scripts/world/building_catalog.gd` | Kenney GLB catalog + road masks |
| `scripts/world/city_view.gd` | Ground + instance/swap GLBs |
| `scripts/world/orbit_camera.gd` | Orbit / pan / zoom rig |
| `scripts/input/deck_controller.gd` | Deck + keyboard / mouse |
| `scripts/ui/hud.gd` | Cash, RCI, advisor, War/Disaster |
| `scripts/main.gd` | Product glue |
| `scenes/main.tscn` | WorldEnvironment + sun + ground + city + camera |
| `tests/smoke_headless.gd` | Headless SMOKE_OK |

## Licenses

- **Kenney City Kit** (Suburban / Commercial / Industrial / Roads) — **CC0 1.0**. See `assets/city/LICENSES.md` and each pack’s `License.txt`. Credit [Kenney](https://kenney.nl) appreciated.
- **Poly Haven** grass / dirt / asphalt / HDRI sky — **CC0 1.0**. See `assets/env/LICENSES.md`.

## Non-goals

- Per-citizen agents / traffic pathfinding
- Changing FSR2 0.67 or 40 FPS
- Git commits (ops owns the repo)
- Editing `/workspace/scrap-orbit` or the 2D `/workspace/metro-ops` product (except reading systems to port)
