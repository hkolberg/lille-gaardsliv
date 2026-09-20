# WORK_INSTRUCTIONS.md — Gårdsspillet assets v4

Repository:
hkolberg/lille-gaardsliv

## Goal
Add the v4 plaza and water asset pack without changing gameplay, map layout, movement rules, or the MDD.

## Install location
Place this package at:

godot/gaardsliv_assets_v4/

Preserve all folders and filenames.

## What v4 replaces
V4 replaces the visual role of these files after code has been updated and verified:
- all files under `godot/gaardsliv_assets_v3/plazas/`
- all files under `godot/gaardsliv_assets_v3/water/`
- any temporary plaza/water fallbacks currently hard-coded in `main.gd`

## Do NOT delete yet
Do not delete v3 plaza/water files until:
1. the code references v4,
2. GitHub Pages builds successfully,
3. plaza repetition, water continuity, and ford orientation are visually verified in-game.

After those checks, the replaced v3 plaza/water files may be deleted in the SAME cleanup commit.

Do not delete any v1/v2/v3 assets still used for grass, trees, roads, fences, or gates.

## Validation
Confirm:
- PNG alpha/transparency is preserved.
- tiles open correctly as real PNG files.
- logical tile footprint remains 64×32.
- tile sprite canvas remains 96×72.
- `meta/manifest.json` and `meta/master_tile_64x32.png` are present.

## Commit
Suggested commit message:
Add Gårdsspillet v4 plaza and water asset pack

Push to `main` and report:
- commit SHA
- PNG count
- any files not copied

## Extra verification
- confirm `water/base/water_center_plain.png` is present and preserved as a plain open-water tile with no lilies, rocks, reeds, or shore decoration.
