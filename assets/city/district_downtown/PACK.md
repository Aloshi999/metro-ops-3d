# district_downtown

First dense district kit for Metro Ops 3D. Meant to read on a Steam capsule (800p / 1080p High), not another Kenney toy slice.

## Contents
- **Quaternius Downtown City MegaKit Standard** (CC0) — 153 Godot glTF pieces: 3 prebuilt buildings (`Building_Small_1`, `Building_Medium_2_001`, `Building_Large_2`), modular brick/metal/trim facades, window/cutaway interiors, streets, sidewalks, street props. Shared texture set in `textures/` (36 files) including `T_lit_interior_*` window-glow cards.
- **Kenney Car Kit** (CC0) — vehicle GLBs in `props/cars/`.

Kenney City Kit (suburban/commercial/industrial/roads) stays in `assets/city/kenney_*`. Expand, do not replace.

## Lot / scale / instance
- Lots are **16 m**.
- Kenney catalog scale stays **~14.5** on ~1u meshes.
- **Quaternius scale is TBD.** City Look measures the first GLB (`buildings/Building_Large_2.gltf`) and sets district scale. Do not stamp 14.5 on MegaKit.
- **Instance. Shared materials. No per-lot unique meshes or mats.** Path-cached textures only (`textures/`). glTF image URIs point at `../textures/`.

## Interiors
Window glow / cutaway cards for the **190 m High** camera (`T_lit_interior_1.png`, `T_lit_interior_2.png`, `T_dark_interior.png`, blinds/curtains, interior HDR cubemaps). Not first-person rooms. Furniture kit lives under `district_midrise` as support.

## Fat assets
This folder is drop-in on disk. Ops ships the bulk via **GitHub Releases / LFS**, not a giant commit to main. Sidecar growth: `assets/optional/bulk/`.

## Owners
City Content drops packs. City Mesh instances from `instance_manifest.json`. City Look palette / LOD / district scale (film 0.84/0.64/0.62, dirt brown vs charcoal). Builder wires catalog. Ops Git / Releases. Deck Low floor (FSR2 0.67 / 40 / SSAO off) is not this pack.
