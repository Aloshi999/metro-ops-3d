# district_rail

Kenney **Train Kit 1.1** promoted to its own rail district so Mesh can instance tracks / rolling stock without treating downtown MegaKit as a toy-train folder.

Kenney City Kit suburban / commercial / industrial / roads stays in `assets/city/kenney_*`. **Kept. Expand, do not replace.** `district_downtown/` MegaKit is unchanged (including `props/train/` — copied, not moved).

No official Kenney or Quaternius **$0 rail-station building** kit was added this pass. Quaternius Modular Train Pack is more trains (FBX/OBJ era), not a station. Station sheds / platforms are a growth slot.

## Lot contract
- Model unit: **~1**
- Lots: **16 m**
- Instance scale / `kenney_scale`: **14.5**
- `instance`: true
- `unique_per_lot`: false
- `shared_materials`: true
- Shared Kenney colormap once in `models/Textures/` — do not unique materials per lot

## On disk (`du -sh`)

| Piece | Path | Size | Count | Source |
|-------|------|------|-------|--------|
| Kenney Train Kit 1.1 | `models/` | 6.9M | 103 GLB | https://kenney.nl/assets/train-kit — copied from `district_downtown/props/train/` |

District total: **7.0M**. Manifest slots: **103** GLB.

Flatten: `*.glb` + `License.txt` + `Textures/colormap.png` under `models/`. No Godot `.import`. FBX/OBJ not kept.

## How to drop in

1. Point the catalog / Mesh at `res://assets/city/district_rail/instance_manifest.json`.
2. Instance from the listed paths. **Do not unique materials per lot.**
3. Do not overwrite `district_downtown/instance_manifest.json` scale fields (`DISTRICT_DOWNTOWN_SCALE=1.0`, Kenney catalog 14.5).

## Deck Low floor (not this pack)

**FSR2 0.67 / 40 FPS / SSAO off** is Mesh / Look / Perf. This pack does not change FSR, the 40 cap, HUD, or camera.

## Fat-asset shipping

GLB / texture bulk should go via **GitHub Releases / LFS**, not a giant main commit. Growth sidecar: `assets/optional/bulk/` (gitignored). Station buildings, extra platforms, long stereo rail beds — **not downloaded now**.

Owners: **Content** drops packs + these docs · **Mesh** instances from the manifest · **Look** LOD / district scale · **Builder** wires catalog · **Ops** Git / Releases.
