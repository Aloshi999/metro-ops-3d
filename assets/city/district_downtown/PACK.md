# district_downtown

First **dense** downtown kit for Metro Ops 3D. Boston/NYC modular blocks that can actually read on a Steam capsule at Deck 800p / 190 m High — not another Kenney toy slice.

Kenney City Kit suburban / commercial / industrial / roads stays in `assets/city/kenney_*`. **Kept. Expand, do not replace.**

## What is on disk (measured after extract)

| Piece | Path | Count | du |
|-------|------|------:|----|
| Quaternius Downtown City MegaKit **Standard** (CC0) | `buildings/` + `textures/` | 142 Godot `.gltf` (+ `.bin`) + **36 shared textures** (no Unreal-Normals, no per-lot copies) | 9.9M + 101M |
| Ultimate House Interior Pack (CC0) | `interiors/*.glb` | 123 furniture / doors / windows / rooms | with MegaKit interiors: 1.8M |
| MegaKit interior walls / floors | `interiors/*.gltf` | 6 (`Brick_InteriorWall_*`, `Floor_*`) | (same) |
| Quaternius Cars Pack (CC0, itch $0) | `props/car_*.glb` | 7 | ~760K |
| Quaternius Public Transport Pack (CC0) | `props/transit_*.glb` | 12 | ~440K |
| MegaKit street props | `props/Prop_*.gltf` | 5 | small |
| Poly Haven urban extras (CC0, **2K max**) | `props/polyhaven_street_lamp_01/`, `props/polyhaven_painted_wooden_bench/` | 2 glTF | 5.7M + 7.7M |
| Audio bed | `audio/bed/downtown_day.ogg` | 1 looping Mixkit traffic/crowd bed (67s) | 903K |

`instance_manifest.json` lists **only files that exist** (measured after extract): 142 buildings + 129 interiors + 30 props + `audio_bed`.

Kenney extras already flattened under `props/cars|factory|food|train` and `props/polyhaven/` by a parallel drop stay on disk; they are **not** this pack’s identity. Do not treat them as a replacement for the MegaKit.

## How to drop in

1. Point the catalog / Mesh at `res://assets/city/district_downtown/instance_manifest.json`.
2. Instance from the listed paths. **Do not unique materials per lot.**
3. Shared PBR lives once in `textures/` (MegaKit glTF URIs are `../textures/T_*.png`). Mesh can instance without uniquing lots.
4. Audio: loop `res://assets/city/district_downtown/audio/bed/downtown_day.ogg`.

Godot `.import` files are **not** shipped. Do not run Godot just to generate them.

## Instance rules

- `instance: true`
- `unique_per_lot: false`
- `shared_materials: true`
- One shared texture set for the MegaKit. No per-lot unique mats. No unique material copies per building.
- Quaternius cars / transport / house interior were official OBJ/FBX (no glTF in those free zips). Converted OBJ→GLB for Godot drop-in; they use pack-shared vertex-color materials, not per-lot uniques.
- Poly Haven extras keep their own **2K** texture folders (not 8K, not copied per lot).

## Deck Low floor (not this pack)

**FSR2 0.67 / 40 FPS / SSAO off** is Mesh / Look / Perf. This pack does not change FSR, the 40 cap, HUD, or camera.

## Fat-asset shipping

GLB / texture bulk should go via **GitHub Releases / LFS**, not a giant main commit. Growth sidecar: `assets/optional/bulk/` (gitignored). Target ~40 GB immersive install later (4K/8K PBR, extra HDRIs, more districts, long stereo beds) — **not downloaded now**.

Owners: **Content** drops packs + these docs · **Mesh** instances from the manifest · **Look** LOD / district scale · **Builder** wires catalog · **Ops** Git / Releases.

## Sources (official only)

- Downtown City MegaKit Standard (~223 MB zip): https://quaternius.com/packs/downtowncitymegakit.html · itch $0 https://quaternius.itch.io/downtown-city-megakit — **not** the paid Source zip (918 MB).
- Ultimate House Interior: https://quaternius.com/packs/ultimatehomeinterior.html (official “Download” → Quaternius Google Drive).
- Cars: https://quaternius.itch.io/lowpoly-cars
- Public Transport: https://quaternius.com/packs/publictransport.html (official Drive).
- Poly Haven 2K: https://polyhaven.com/a/street_lamp_01 · https://polyhaven.com/a/painted_wooden_bench
- Audio: Mixkit “City traffic background ambience” id 2930 — see `audio/bed/SOURCE.txt`
