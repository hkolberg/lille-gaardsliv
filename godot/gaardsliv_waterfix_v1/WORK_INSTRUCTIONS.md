# WORK_INSTRUCTIONS.md — WaterFix v1.1

Repository:
hkolberg/lille-gaardsliv

Install at:
godot/gaardsliv_waterfix_v1/

Replace any previous WaterFix v1 folder if present.

Update main.gd so water uses this package instead of v4 water.

Required direction mapping:
- game grid N -> asset E
- game grid E -> asset S
- game grid S -> asset W
- game grid W -> asset N

Rules:
1. `water/base/water_center_plain.png` is the default interior tile.
2. Straight/corner shore tiles are structural and selected only from topology.
3. Rocks/reeds/lilies are optional variants and must remain sparse.
4. Ford assets are NOT traversable yet.
5. Do not change map layout, movement rules, roads, plaza, forest, fences, or MDD.

Do NOT delete v4 water files until:
- Pages build succeeds
- current test pond is visually verified
- no visible grid seams remain in normal interior water

After successful verification, replaced v4 water assets may be removed in the same cleanup commit.

Suggested commit:
Add normalized WaterFix v1.1 assets
