# district_waterfront

Kenney has **no waterfront kit**. This folder is assembled from CC0 pieces that actually landed.

No modern *boat* GLB this pass (Kenney pirate kit skipped per scrape rules; Poly Haven had no small modern boat in the 2K street-prop pull). Harbor *building* lots are still a growth slot.

## Lot contract
- Model unit: **~1**
- Lots: **16 m**
- Instance scale: **14.5**
- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- Interiors: 190 m High camera window/cutaway cards — **not** first-person rooms


## On disk (`du -sh`)

| Piece | Path | Size | Count | Notes |
|-------|------|------|-------|-------|
| Nature Kit water-adjacent subset | `nature_water/` | 220K | 17 GLB | Copied from `district_park/nature/` (trees, rivers, lilies, bridges, waterfall cliffs). Not industrial tanks. |
| Poly Haven dock/shore props | `models/` | 118M | 11 glTF 2K | modular_wooden_pier, Barrel_01, barrel_03, wooden_crate_01/02, wooden_barrels_01, lifebuoy, life_jacket, ocean_buoy, lateral_sea_marker, overhead_crane |
| Shared floor/plank maps | `textures/` | 9.4M | 2K JPG | cobblestone_floor_04, weathered_brown_planks |
| Industrial tank | *(reference)* | — | 1 | `../kenney_industrial/detail-tank.glb` — **not copied** |

District total: **128M**.

## Intended growth slots (Releases / LFS)

Harbor sheds, bulkheads, real boats, extra piers. Place fat extras under `assets/optional/bulk/`.
