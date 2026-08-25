# Metro Ops 3D — CONTENT_MAP

Honest inventory after the first dense downtown drop. Sizes from `du -sh` on disk. Do not treat this as a promise of files that are not here.

Deck Low floor (**do not change**): **FSR2 0.67 / 40 FPS / SSAO off**. That is Mesh / Look / Perf, not a content pack.

## Core Kenney 4-pack (stays)

| Pack | Path | du | GLB | Source |
|------|------|----|-----|--------|
| City Kit Suburban 2.0 | `assets/city/kenney_suburban/` | 2.8M | 40 | https://kenney.nl/assets/city-kit-suburban |
| City Kit Commercial 2.1 | `assets/city/kenney_commercial/` | 3.9M | 41 | https://kenney.nl/assets/city-kit-commercial |
| City Kit Industrial 1.0 | `assets/city/kenney_industrial/` | 2.6M | 25 | https://kenney.nl/assets/city-kit-industrial |
| City Kit Roads | `assets/city/kenney_roads/` | 2.1M | 95 | https://kenney.nl/assets/city-kit-roads |

**Expand, do not replace.** `kenney_*` folders were not touched.

## district_downtown — first dense kit (234M)

Capsule-readable Boston/NYC modular kit. Shared MegaKit textures once (`unique_per_lot: false`).

| Piece | Path | du | Count | Notes |
|-------|------|----|-------|-------|
| MegaKit Standard glTF + bins | `city/district_downtown/buildings/` | 9.9M | 142 `.gltf` | Official Standard zip (223 MB). FBX/OBJ/source deleted. URIs → `../textures/` |
| Shared MegaKit PBR + interior HDRs | `city/district_downtown/textures/` | 101M | 36 files | One copy. No Unreal-Normals. No per-lot copies |
| House Interior + MegaKit rooms | `city/district_downtown/interiors/` | 1.8M | 123 `.glb` + 6 `.gltf` | Official Drive OBJ → GLB; interior walls/floors from MegaKit |
| Cars + transit + MegaKit/PH props | `city/district_downtown/props/` | 76M | 7 cars + 12 transit + 5 MegaKit props + PH 2K lamp/bench (+ leftover Kenney extras on disk) | itch Cars + official Drive Public Transport |
| Audio bed | `city/district_downtown/audio/bed/downtown_day.ogg` | 903K (folder 46M with extra Mixkit day/night WAV/OGG) | 1 looping bed | Mixkit 2930, Mixkit Sound Effects Free License |

Manifest counts (files that exist): **142 buildings / 129 interiors / 30 props** + `audio_bed`.

## Other folders already on disk (not this downtown drop’s job)

| Tree | du |
|------|-----|
| `city/district_midrise/` | 124M |
| `city/district_park/` | 39M |
| `city/district_waterfront/` | 134M |
| `city/district_rail/` | 7.0M |
| `city/district_night_market/` | 6.6M |
| `city/skyline/` | 43M |
| `city/interiors_dropin/` | 112M |
| `assets/env/` | 4.1M |
| `assets/optional/` | 16K (gitignored bulk sidecar) |

## district_rail — Kenney Train Kit (7.0M)

Promote of leftover downtown `props/train/` into its own district. Downtown MegaKit and Kenney 4-pack **not replaced**. Copied, not moved.

| Piece | Path | du | GLB | Source |
|-------|------|----|-----|--------|
| Kenney Train Kit 1.1 | `city/district_rail/models/` | 6.9M | 103 | https://kenney.nl/assets/train-kit (copy of `district_downtown/props/train/`) |

Lot **16 m**, `kenney_scale` **14.5**, `instance` / shared mats. No official $0 rail-**station** kit added (Quaternius Modular Train is more trains). Station sheds: Releases / LFS.

## district_night_market — Food + Holiday plaza stalls (6.6M)

Food Kit + Holiday/plaza props as night-market stalls. Copied so downtown `props/food/` and `district_park/plaza/` stay intact.

| Piece | Path | du | GLB | Source |
|-------|------|----|-----|--------|
| Kenney Food Kit 2.0 | `city/district_night_market/food/` | 3.7M | 200 | https://kenney.nl/assets/food-kit |
| Kenney Holiday Kit 2.0 (stalls) | `city/district_night_market/plaza/` | 2.9M | 99 | https://kenney.nl/assets/holiday-kit |

Lot **16 m**, `kenney_scale` **14.5**, `instance` / shared mats. Manifest slots: **299**. No extra download (Mini Market = supermarket; Fantasy Props MegaKit Standard ~143 MB medieval skipped). Fat extras: Releases / LFS.

## Totals (`du -sh`)

| Tree | du |
|------|-----|
| `assets/` | 724M |
| `assets/city/` | 720M |
| `assets/env/` | 4.1M |
| `assets/city/district_downtown/` | 246M |
| `assets/city/district_rail/` | 7.0M |
| `assets/city/district_night_market/` | 6.6M |
| `assets/city/interiors_dropin/` | 112M |
| `assets/optional/bulk/` | empty / gitignored |

## Growth (~40 GB) — not downloaded now

Fat extras live under `assets/optional/bulk/` (gitignored) and ship via **GitHub Releases / LFS**, not a giant main commit:

- 4K / 8K PBR
- Extra HDRIs
- More districts / fat extras: waterfront boats, industrial waterfront, station sheds, dedicated stall buildings (rail + night-market Kenney slices are now on disk)
- Long stereo beds — **now on disk as OGG** (`*_long.ogg`, ~6–8 MB each). Fat Mixkit WAVs stay in downloads/LFS

## Owners

| Owner | Owns |
|-------|------|
| Content | Packs, flatten, this map, licenses |
| Mesh | Instances from each manifest; **no per-lot unique meshes/mats** |
| Look | Palette / LOD / district scale |
| Builder | Catalog wiring |
| Ops | Git + GitHub Releases / LFS |

Never change FSR / 40.

## Gaps / notes

- MegaKit Standard is the **free** slice (153 official Godot glTF in the zip; 142 stay in `buildings/` after moving interior walls/floors/props). Paid Source zip (918 MB / UE5 projects) was **not** downloaded.
- Ultimate Furniture Pack skipped — Ultimate House Interior already covers furniture / windows / rooms.
- Older Quaternius cars / transport / house interior ship FBX/OBJ/Blend only; GLB on disk is a lossless-enough OBJ→GLB convert for Godot drop-in (source FBX/OBJ/Blend not kept).
- Mixkit beds are **not CC0**; license name + URL are in `audio/bed/SOURCE.txt`.

## Drop 2026-08-25 evening (halt lifted)

| Path | Size | What |
|------|------|------|
| `city/district_rail/` | 7.0M | Kenney Train Kit (103 GLB), scale 14.5 |
| `city/district_night_market/` | 6.6M | Food stalls (Kenney food) + holiday plaza (299 GLB), scale 14.5 |
| `city/interiors_dropin/` | 112M | 190m window/cutaway cards — 8 new PH 2K indoor HDRIs (see Interiors section). Downtown glow textures stay in `district_downtown/textures/` |
| Long audio beds | ~33M OGG | 8+ min ffmpeg crossfade-loops (Mixkit SFX Free). See **Audio long-beds** |

Downtown MegaKit scale stays **1.0** (Look-measured). Kenney catalog **14.5**. Fat extras: Releases/LFS, not a giant main commit. Owners unchanged.

## Interiors (190m High window / cutaway cards)

Not first-person rooms. Shared materials only (`unique_per_lot: false`). Scale n/a for textures. Downtown mesh scale stays **1.0**.

| Piece | Path | du | Notes |
|-------|------|----|-------|
| Interiors drop-in | `city/interiors_dropin/` | **112M** | `PACK.md` + `LICENSES.md` + `instance_manifest.json` |
| Window cards | `city/interiors_dropin/window_cards/` | 112M | 14× 2K HDR + 7 tonemapped JPG + Kenney side PNGs |
| Cutaway window GLBs | `city/interiors_dropin/cutaways/` | 80K | 6 CC0 copies (Kenney wallWindow + Quaternius Window_*) |
| Midrise window cards (same HDRIs landed here) | `city/district_midrise/interiors/window_cards/` | 112M | Canonical midrise path |
| Midrise furniture (unchanged) | `city/district_midrise/interiors/furniture/` | 2.3M | Kenney 140 GLB — not re-downloaded |
| Downtown interiors (unchanged) | `city/district_downtown/interiors/` | 1.8M | Bathroom_* + house interior set |
| Downtown interior glow (unchanged) | `city/district_downtown/textures/` | 101M | `T_lit_interior_*`, `T_dark_interior`, blinds, curtains, `CM_*` |

**8 new Poly Haven indoor HDRIs (2K only, CC0):** `hotel_room`, `anniversary_lounge`, `fireplace`, `brown_photostudio_02`, `studio_small_03`, `studio_small_08`, `studio_small_09`, `photo_studio_01`. Skipped IDs already on disk. No 8K. New bytes ~66 MB per copy; landed at both drop-in and midrise (~132 MB, under 150 MB cap).

`district_downtown/instance_manifest.json` was **not** rewritten. `kenney_*` city kits were **not** touched. FSR / HUD / camera / scripts / scenes / `project.godot` were **not** touched.

Honest `du -sh` after this drop: `assets/` **724M** · `assets/city/` **720M** · `district_midrise/` **124M** · `interiors_dropin/` **112M**.

## Audio long-beds (2026-08-25 evening)

No official Mixkit/Pixabay file of 8+ minutes matched the existing downtown/park beds (Mixkit city beds are 1–2 min). Harbor used official Mixkit 1208 (1:18). Rail used official Mixkit 1634 (0:42, closest station bed). Long OGGs are **End Product** ffmpeg crossfade-loops of those Items (trim fade tails, seamless cycle = body[C:D] + fade_out(tail)×fade_in(head), concat N cycles, libvorbis `-q:a 4`). Not a stock redistrib of the raw WAV. Fat source WAVs for 1208/1634 stay in `downloads/audio/` for LFS later — not in-tree.

| File | Bytes | Duration | License | Source |
|------|------:|----------|---------|--------|
| `city/district_downtown/audio/bed/downtown_day_long.ogg` | 6,850,589 | 08:06.40 | Mixkit Sound Effects Free License | Mixkit 2930 *City traffic background ambience* (trim 0–60.80 s, C=3.5 s, 8 cycles) |
| `city/district_downtown/audio/bed/downtown_night_long.ogg` | 6,552,367 | 08:19.20 | Mixkit Sound Effects Free License | Mixkit 2678 *Urban city ambience at night* (trim 0.50–125.30 s, C=3.0 s, 4 cycles) |
| `city/district_park/audio/bed/park_day_long.ogg` | 7,540,240 | 08:54.00 | Mixkit Sound Effects Free License | Mixkit 2932 *Urban park and traffic* (trim 0–106.80 s, C=3.5 s, 5 cycles) |
| `city/district_waterfront/audio/bed/harbor_day_long.ogg` | 7,025,597 | 08:24.00 | Mixkit Sound Effects Free License | Mixkit 1208 *Small waves harbor rocks* (trim 2.20–74.20 s, C=3.5 s, 7 cycles) |
| `city/district_rail/audio/bed/rail_day_long.ogg` | 5,748,803 | 08:29.60 | Mixkit Sound Effects Free License | Mixkit 1634 *Train waiting at station* (trim 0.30–39.50 s, C=2.5 s, 13 cycles) |

Short Mixkit OGGs/WAVs were **kept**. `SOURCE.txt` + `LICENSES.md` in each `audio/bed/` quote the Mixkit SFX Free modal. Manifest `audio_bed_long` fields only (downtown also `audio_bed_night_long`). Downtown MegaKit scale still **1.0**.
