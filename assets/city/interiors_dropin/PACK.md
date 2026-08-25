# interiors_dropin

Window-glow / cutaway cards for the **190 m High** camera. **Not** first-person rooms. Shared materials only — `unique_per_lot: false`.

Drop-in folder. Mesh instances from `instance_manifest.json`. Scale is **n/a (textures)** for the HDR / photo cards; cutaway window GLBs keep their source kit scale (Kenney furniture ~1, downtown MegaKit / House Interior **1.0**).

Do **not** unique materials per lot. Do **not** treat these as walkable interiors.

## Lot / camera contract

- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- `scale`: n/a (textures)
- `camera_read`: 190m High
- Interiors **read** as facade cards (window glow + cutaway frames), not rooms

Downtown Look/Mesh keep `DISTRICT_DOWNTOWN_SCALE=1.0`. This pack does not rewrite `district_downtown/instance_manifest.json`.

## On disk (`du -sh`)

| Piece | Path | Size | Count | Notes |
|-------|------|------|-------|-------|
| 2K indoor HDRIs + photo cards | `window_cards/` | 112M | 14 HDR + 7 tonemapped JPG + 17 Kenney side PNG | Shared window-glow cards |
| Cutaway / window GLBs | `cutaways/` | 80K | 6 GLB | Copies of files already on disk |
| Pack total | `.` | **112M** | | |

Furniture GLBs stay where they already live (not re-downloaded):

- `district_midrise/interiors/furniture/` — Kenney Furniture Kit, 140 GLB, 2.3M
- `district_downtown/interiors/` — House Interior + MegaKit rooms
- `district_downtown/textures/` — MegaKit `T_lit_interior_*`, `T_dark_interior`, blinds, curtains, `CM_*` interior HDRs

Same 8 new HDRIs also land at `district_midrise/interiors/window_cards/` so midrise can instance them without this folder.

## New this drop — 8 Poly Haven indoor HDRIs (2K only)

Skipped IDs already on disk (`cayley_interior`, `empty_play_room`, `kiara_interior`, `small_empty_room_1`, `unfinished_office`, `comfy_cafe`). No 8K.

| ID | Files | Page | 2K HDR |
|----|-------|------|--------|
| `hotel_room` | `hotel_room_2k.hdr` + tonemapped JPG | https://polyhaven.com/a/hotel_room | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/hotel_room_2k.hdr |
| `anniversary_lounge` | `anniversary_lounge_2k.hdr` + tonemapped JPG | https://polyhaven.com/a/anniversary_lounge | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/anniversary_lounge_2k.hdr |
| `fireplace` | `fireplace_2k.hdr` + tonemapped JPG | https://polyhaven.com/a/fireplace | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/fireplace_2k.hdr |
| `brown_photostudio_02` | `brown_photostudio_02_2k.hdr` | https://polyhaven.com/a/brown_photostudio_02 | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/brown_photostudio_02_2k.hdr |
| `studio_small_03` | `studio_small_03_2k.hdr` + tonemapped JPG | https://polyhaven.com/a/studio_small_03 | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/studio_small_03_2k.hdr |
| `studio_small_08` | `studio_small_08_2k.hdr` | https://polyhaven.com/a/studio_small_08 | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/studio_small_08_2k.hdr |
| `studio_small_09` | `studio_small_09_2k.hdr` | https://polyhaven.com/a/studio_small_09 | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/studio_small_09_2k.hdr |
| `photo_studio_01` | `photo_studio_01_2k.hdr` + tonemapped JPG | https://polyhaven.com/a/photo_studio_01 | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/photo_studio_01_2k.hdr |

Huge official tonemapped extras (19–39 MB JPGs for `brown_photostudio_02` / `studio_small_08` / `studio_small_09`) were **not** downloaded.

## How to drop in

1. Point Mesh at `res://assets/city/interiors_dropin/instance_manifest.json` **or** keep using midrise `window_cards` (same new HDRIs).
2. Instance as shared cards. One material / one texture per ID.
3. Godot `.import` files are **not** shipped.

## Deck Low floor (not this pack)

**FSR2 0.67 / 40 FPS / SSAO off** is Mesh / Look / Perf. This pack does not change FSR, HUD, or camera.
