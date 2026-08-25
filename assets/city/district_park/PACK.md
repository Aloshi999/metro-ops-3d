# district_park

Park / plaza / forest / graveyard so the Steam capsule is not one Kenney block.

## Lot contract
- Model unit: **~1**
- Lots: **16 m**
- Instance scale: **14.5**
- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- Interiors: 190 m High camera window/cutaway cards — **not** first-person rooms


## On disk (`du -sh`)

| Piece | Path | Size | Count | Source zip |
|-------|------|------|-------|------------|
| Kenney Nature Kit 2.1 | `nature/` | 3.6M | 329 GLB | https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip |
| Kenney Mini Forest 1.0 | `forest/` | 884K | 22 GLB | https://kenney.nl/media/pages/assets/mini-forest/44a89aed7f-1784024079/kenney_mini-forest_1.0.zip |
| Kenney Holiday Kit 2.0 | `plaza/` | 2.9M | 99 GLB | https://kenney.nl/media/pages/assets/holiday-kit/3976a6496a-1733923970/kenney_holiday-kit.zip |
| Kenney Graveyard Kit 5.0 | `graveyard/` | 3.4M | 91 GLB | scraped Kenney 3D category |
| Audio bed | `audio/bed/park_day.ogg` | 1.5M | 1 | Mixkit 2932 — see SOURCE.txt |

District total: **13M**. Manifest slots: **541** GLB.

Flatten: `*.glb` + `License.txt` + `Textures/` (colormap only) at pack root. FBX/OBJ/DAE/STL discarded.
