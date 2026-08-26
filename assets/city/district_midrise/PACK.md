# district_midrise

Support district so the capsule is not one Kenney commercial block. No midrise *tower* GLB kit this pass — furniture + **shared window cards**.

## Lot contract
- Model unit: **~1**
- Lots: **16 m**
- Instance scale: **14.5**
- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- Interiors: 190 m High camera window/cutaway cards — **not** first-person rooms


## On disk (`du -sh`)

| Piece | Path | Size | Count | Source |
|-------|------|------|-------|--------|
| Kenney Furniture Kit | `interiors/furniture/` | 2.2M | 140 GLB | https://kenney.nl/media/pages/assets/furniture-kit/440e0608a4-1677580847/kenney_furniture-kit.zip |
| Window cards (shared) | `interiors/window_cards/` | 112M | 14 HDR + photo cards + side PNGs | Poly Haven 2K interiors |
| Shared brick maps | `textures/brick_wall_02/` | 9.8M | 2K JPG | https://polyhaven.com/a/brick_wall_02 |

District total: **124M**. Furniture slots: **140**.

## Window / cutaway cards (instance-shared)

These are **not** walkable first-person rooms. Read from a 190 m High camera as facade cards.

| Asset | Path | URL |
|-------|------|-----|
| unfinished_office 2K HDR | `interiors/window_cards/office_unfinished_office/` | https://polyhaven.com/a/unfinished_office |
| kiara_interior 2K HDR + tonemapped JPG | `interiors/window_cards/apartment_kiara_interior/` | https://polyhaven.com/a/kiara_interior |
| comfy_cafe 2K HDR + tonemapped JPG | `interiors/window_cards/shop_comfy_cafe/` | https://polyhaven.com/a/comfy_cafe |
| small_empty_room_1 2K HDR | `interiors/window_cards/apartment_small_empty_room_1/` | https://polyhaven.com/a/small_empty_room_1 |
| cayley_interior 2K HDR | `interiors/window_cards/cayley_interior_2k.hdr` | https://polyhaven.com/a/cayley_interior |
| empty_play_room 2K HDR | `interiors/window_cards/empty_play_room_2k.hdr` | https://polyhaven.com/a/empty_play_room |
| Kenney furniture side cards | `interiors/window_cards/kenney_furniture_side/` | Furniture Kit Side PNGs |
| hotel_room 2K HDR + tonemapped JPG | `interiors/window_cards/hotel_room_2k.hdr` | https://polyhaven.com/a/hotel_room |
| anniversary_lounge 2K HDR + tonemapped JPG | `interiors/window_cards/anniversary_lounge_2k.hdr` | https://polyhaven.com/a/anniversary_lounge |
| fireplace 2K HDR + tonemapped JPG | `interiors/window_cards/fireplace_2k.hdr` | https://polyhaven.com/a/fireplace |
| brown_photostudio_02 2K HDR | `interiors/window_cards/brown_photostudio_02_2k.hdr` | https://polyhaven.com/a/brown_photostudio_02 |
| studio_small_03 2K HDR + tonemapped JPG | `interiors/window_cards/studio_small_03_2k.hdr` | https://polyhaven.com/a/studio_small_03 |
| studio_small_08 2K HDR | `interiors/window_cards/studio_small_08_2k.hdr` | https://polyhaven.com/a/studio_small_08 |
| studio_small_09 2K HDR | `interiors/window_cards/studio_small_09_2k.hdr` | https://polyhaven.com/a/studio_small_09 |
| photo_studio_01 2K HDR + tonemapped JPG | `interiors/window_cards/photo_studio_01_2k.hdr` | https://polyhaven.com/a/photo_studio_01 |

`instance:true`, `unique_per_lot:false`, `shared_materials:true`. No per-lot unique interiors.


## Building exteriors (this pass)

Official CC0 Quaternius **free/standard** packs (not paid Source). Finished building meshes only — no modular doors/windows/AC, no furniture-as-towers, no Kenney skyscraper-a..e.

| Pack | Official | On disk |
|------|----------|---------|
| Downtown City MegaKit Standard | itch $0 / quaternius.com | `Building_Small_1`, `Building_Medium_2_001`, `Building_Large_2` (1u=1m) |
| Ultimate Buildings Pack | https://quaternius.com/packs/ultimatetexturedbuildings.html (official Drive) | Finished 2/3/4/6-story OBJ → glTF. Shared `textures/Texture_*.png`. **3.0 baked** (pack was ~1.25u/story). |
| Buildings Pack | https://quaternius.com/packs/buildings.html (official Drive) | `Building1_*`…`Building4` vertex-color OBJ → glTF. 3.0 baked. |
| Simple Buildings Pack | https://quaternius.com/packs/simplebuildings.html (official Drive) | `Bank`, `Flat`, `Flat2`, `Hospital`, `Shop`. Shared `Hotel.png`/`Shop.png`. 3.0 baked. |

`building_scale` **1.0**. `unique_per_lot` false. `shared_materials` true. Image URIs → `../textures/` (MegaKit pair still share downtown PBR).
