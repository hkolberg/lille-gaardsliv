# WORK_INSTRUCTIONS.md — Gårdsspillet assets v3

Repository:
hkolberg/lille-gaardsliv

## Goal
Add the v3 visual repair assets without changing gameplay, map layout, movement rules, or MDD.

## Install
Place this package at:

godot/gaardsliv_assets_v3/

Preserve all subfolders and filenames.

## What v3 replaces
V3 replaces the VISUAL role of these v2 assets:
- godot/gaardsliv_assets_v2/roads/cobblestone/*
- godot/gaardsliv_assets_v2/roads/gravel/*
- godot/gaardsliv_assets_v2/roads/cobblestone/plaza_cobble_flat.png
- godot/gaardsliv_assets_v2/water/*
- godot/gaardsliv_assets_v2/fences/*
- godot/gaardsliv_assets_v2/gates/*
- godot/gaardsliv_assets_v2/props/tree_pine.png

## Do NOT delete yet
Do not delete the v2 files above until:
1. main.gd has been updated to reference v3,
2. the GitHub Pages build succeeds,
3. all road directions, gates/fences, water edges and pine transparency have been visually verified in-engine.

After those checks, the replaced v2 files above may be deleted in the SAME cleanup commit.

Do not delete:
- godot/gaardsliv_assets_v1/terrain/terrain_grass.png
- godot/gaardsliv_assets_v1/props/tree_oak.png
or any other v1 asset still referenced by the game.

## Validation
Confirm:
- PNG alpha/transparency is preserved.
- no gray/black rectangles around tree sprites.
- logical tile footprint remains 64×32.
- tile sprites use 96×72 canvas.
- props use 96×112 canvas.
- files open as real PNG binaries.
- meta/manifest.json and meta/master_tile_64x32.png are present.

## Commit
Commit message:
Add Gårdsspillet v3 visual asset pack

Push to main and report:
- commit SHA
- PNG count
- any files not copied
