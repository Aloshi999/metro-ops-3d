# district_night_market

Food stalls + festive plaza props so the capsule can read a night market without inventing a new mesh set.

Kenney **Food Kit 2.0** (produce / bottles / barrels / bags) plus **Holiday Kit 2.0** (`district_park/plaza/` cabins, lanterns, lights, benches) used as stall structures and night-market dressing.

Kenney City Kit 4-pack stays in `assets/city/kenney_*`. **Kept. Expand, do not replace.** Downtown MegaKit and `district_park/plaza/` are unchanged (copied, not moved).

No extra official stall kit downloaded this pass: Kenney Mini Market is supermarket aisles/carts, not stalls; Quaternius Fantasy Props MegaKit Standard (~143 MB, medieval) was skipped as not a night-market stall kit.

## Lot contract
- Model unit: **~1**
- Lots: **16 m**
- Instance scale / `kenney_scale`: **14.5**
- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- Shared Kenney colormap once per kit (`food/Textures/`, `plaza/Textures/`) — do not unique materials per lot

## On disk (`du -sh`)

| Piece | Path | Size | Count | Source |
|-------|------|------|-------|--------|
| Kenney Food Kit 2.0 | `food/` | 3.7M | 200 GLB | https://kenney.nl/assets/food-kit — copied from `district_downtown/props/food/` |
| Kenney Holiday Kit 2.0 (as stalls) | `plaza/` | 2.9M | 99 GLB | https://kenney.nl/assets/holiday-kit — copied from `district_park/plaza/` |

District total: **6.6M**. Manifest slots: **299** GLB.

Flatten: `*.glb` + `License.txt` + `Textures/colormap.png` in each kit folder. No Godot `.import`.

## How to drop in

1. Point the catalog / Mesh at `res://assets/city/district_night_market/instance_manifest.json`.
2. Instance from the listed paths. **Do not unique materials per lot.**
3. Holiday cabins / lanterns / lights / benches read as stall frames; food GLBs dress the counters.

## Deck Low floor (not this pack)

**FSR2 0.67 / 40 FPS / SSAO off** is Mesh / Look / Perf. This pack does not change FSR, the 40 cap, HUD, or camera.

## Fat-asset shipping

GLB / texture bulk should go via **GitHub Releases / LFS**, not a giant main commit. Dedicated stall-building kits, 4K stall PBR, long stereo market beds — **not downloaded now**.

Owners: **Content** drops packs + these docs · **Mesh** instances from the manifest · **Look** LOD / district scale · **Builder** wires catalog · **Ops** Git / Releases.
