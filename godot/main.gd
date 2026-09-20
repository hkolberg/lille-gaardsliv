extends Node2D

# First playable 20x20 concept world. The player can walk through the landscape
# while fences are treated as edge barriers, separate from tile traversability.
const GRID_W := 20
const GRID_H := 20
const TILE_W := 64.0
const TILE_H := 32.0
const ORIGIN := Vector2(576, 70)
const WALK_SPEED := 110.0
const ASSET_ROOT_V1 := "res://gaardsliv_assets_v1/"
const ASSET_ROOT_V2 := "res://gaardsliv_assets_v2/"
const ASSET_ROOT_V3 := "res://gaardsliv_assets_v3/"
const ASSET_ROOT_V4 := "res://gaardsliv_assets_v4/"
const ASSET_ROOT_WATERFIX := "res://gaardsliv_waterfix_v1/"
const ASSET_ROOT_WATER_V2 := "res://gaardsliv_water_assets_v2/"
const TILE_TEXTURE_ORIGIN := Vector2(48.0, 52.0)
const PROP_TEXTURE_ORIGIN := Vector2(48.0, 108.0)

enum Dir { N = 1, E = 2, S = 4, W = 8 }

var tiles: Array = []
var asset_textures: Dictionary = {}
var fences: Dictionary = {}
var player_grid := Vector2(4.5, 4.5)
var player_screen := Vector2.ZERO
var target_screen := Vector2.ZERO
var has_target := false

# Mobile/tablet view controls.
var view_zoom := 1.0
var view_pan := Vector2.ZERO
var active_touches: Dictionary = {}
var pinch_last_distance := 0.0
var pinch_last_center := Vector2.ZERO
var pinch_in_progress := false
var block_tap_until_clear := false
var tap_candidate_index := -1
var tap_start_position := Vector2.ZERO
var tap_moved := false

func _ready() -> void:
	_setup_input()
	_load_asset_textures()
	_build_world()
	player_screen = _iso_f(player_grid.x, player_grid.y)
	queue_redraw()

func _setup_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("move_up", KEY_W)
	_add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_S)
	_add_key("move_down", KEY_DOWN)

func _add_key(action: String, key: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)

func _load_asset_textures() -> void:
	# v1 remains the source for base grass and oak.
	asset_textures = {
		"grass": load(ASSET_ROOT_V1 + "terrain/terrain_grass.png"),
		"tree_oak": load(ASSET_ROOT_V1 + "props/tree_oak.png"),

		# v3 remains the source for forest visuals.
		"tree_pine": load(ASSET_ROOT_V3 + "props/tree_pine.png"),
		"tree_pine_large_a": load(ASSET_ROOT_V3 + "props/tree_pine_large_a.png"),
		"tree_pine_medium_a": load(ASSET_ROOT_V3 + "props/tree_pine_medium_a.png"),
		"tree_pine_small_a": load(ASSET_ROOT_V3 + "props/tree_pine_small_a.png"),
		"forest_cluster_a": load(ASSET_ROOT_V3 + "props/forest_cluster_a.png"),
		"forest_cluster_b": load(ASSET_ROOT_V3 + "props/forest_cluster_b.png"),

		# v4 plaza bases: intentionally no edge/corner decorations yet.
		"plaza_base_v4": load(ASSET_ROOT_V4 + "plazas/plaza_base.png"),
		"plaza_variant_01_v4": load(ASSET_ROOT_V4 + "plazas/plaza_variant_01.png"),
		"plaza_variant_02_v4": load(ASSET_ROOT_V4 + "plazas/plaza_variant_02.png"),

		# New water asset pack.
		"water_plain_v2": load(ASSET_ROOT_WATER_V2 + "water/base/water_center_plain.png"),
		"water_rocks_small_v2": load(ASSET_ROOT_WATER_V2 + "water/base/water_center_rocks_small.png"),
		"water_reeds_v2": load(ASSET_ROOT_WATER_V2 + "water/base/water_center_reeds.png"),
		"water_lilies_v2": load(ASSET_ROOT_WATER_V2 + "water/base/water_center_lilies.png")
	}

	for suffix in ["n", "e", "s", "w", "ne", "nw", "se", "sw"]:
		var prefix := "water_edge_" if suffix.length() == 1 else "water_corner_"
		asset_textures["water_shore_%s_v2" % suffix] = load(
			ASSET_ROOT_WATER_V2 + "water/shores/%s%s.png" % [prefix, suffix]
		)

	for suffix in ["ne", "nw", "se", "sw"]:
		asset_textures["water_inner_%s_v2" % suffix] = load(
			ASSET_ROOT_WATER_V2 + "water/shores/water_inner_%s.png" % suffix
		)

	asset_textures["water_edge_n_rocks_v2"] = load(ASSET_ROOT_WATER_V2 + "water/variants/water_edge_n_rocks.png")
	asset_textures["water_edge_e_reeds_v2"] = load(ASSET_ROOT_WATER_V2 + "water/variants/water_edge_e_reeds.png")
	asset_textures["water_rocks_large_v2"] = load(ASSET_ROOT_WATER_V2 + "water/variants/water_center_rocks_large.png")
	asset_textures["water_rocks_cluster_v2"] = load(ASSET_ROOT_WATER_V2 + "water/variants/water_center_rocks_cluster.png")

	# Keep v2 road textures available as emergency fallback while roads remain geometric.
	for prefix in ["cobble", "gravel"]:
		var folder := "cobblestone" if prefix == "cobble" else "gravel"
		for suffix in ["ns", "ew", "ne", "nw", "se", "sw", "t_n", "t_e", "t_s", "t_w", "cross"]:
			asset_textures["road_%s_%s_v2" % [prefix, suffix]] = load(
				ASSET_ROOT_V2 + "roads/%s/road_%s_%s.png" % [folder, prefix, suffix]
			)

func _build_world() -> void:
	tiles.clear()
	fences.clear()
	for y in GRID_H:
		var row: Array = []
		for x in GRID_W:
			row.append(_tile("meadow", "grass", 0))
		tiles.append(row)

	# Northern forest with a meadow clearing.
	for y in range(1, 7):
		for x in range(1, 7):
			if not (x in range(3, 6) and y in range(3, 6)):
				tiles[y][x] = _tile("forest", "forest_floor", 0)

	# Eastern forest.
	for y in range(2, 10):
		for x in range(14, 19):
			tiles[y][x] = _tile("forest", "forest_floor", 0)

	# Southern meadow stays open. A fenced pasture occupies part of it.
	_add_fence_rect(2, 12, 7, 17, Vector2i(4, 12))

	# Small pond in the south-east part of the example world.
	# The irregular outline makes it read as a natural water body rather than a block.
	for p in [
		Vector2i(11, 17), Vector2i(12, 17),
		Vector2i(10, 18), Vector2i(11, 18), Vector2i(12, 18), Vector2i(13, 18),
		Vector2i(10, 19), Vector2i(11, 19), Vector2i(12, 19), Vector2i(13, 19)
	]:
		tiles[p.y][p.x] = _tile("water", "water", 0)

	# Smaller fenced meadow near the village, with a walking gate.
	_add_fence_rect(13, 12, 17, 16, Vector2i(15, 12))

	# Main cobblestone road: west -> village square -> south.
	for x in range(0, 9):
		tiles[9][x] = _tile("road", "cobblestone", Dir.E | Dir.W)
	tiles[9][9] = _tile("road", "cobblestone", Dir.W | Dir.E | Dir.S)
	for y in range(10, 20):
		tiles[y][9] = _tile("road", "cobblestone", Dir.N | Dir.S)

	# Village square, connected to the main road.
	for y in range(7, 11):
		for x in range(9, 13):
			tiles[y][x] = _tile("road", "cobblestone_square", Dir.N | Dir.E | Dir.S | Dir.W)

	# Gravel path north through forest clearing.
	for y in range(1, 7):
		tiles[y][8] = _tile("road", "gravel", Dir.N | Dir.S)
	tiles[6][8] = _tile("road", "gravel", Dir.N | Dir.S)
	tiles[7][8] = _tile("road", "gravel", Dir.N | Dir.E)
	tiles[7][9] = _tile("road", "gravel", Dir.W | Dir.E)

	# Gravel path east from square and then south beside fenced meadow.
	for x in range(13, 18):
		tiles[9][x] = _tile("road", "gravel", Dir.E | Dir.W)
	tiles[9][18] = _tile("road", "gravel", Dir.W | Dir.S)
	for y in range(10, 18):
		tiles[y][18] = _tile("road", "gravel", Dir.N | Dir.S)

func _tile(category: String, surface: String, connections: int) -> Dictionary:
	return {
		"tile_id": "%s_%s" % [category, surface],
		"category": category,
		"surface": surface,
		"variant": 0,
		"connections": connections,
		"terrain_state": "normal",
		"movement": _movement_for(category, surface)
	}

func _movement_for(category: String, surface: String) -> Dictionary:
	if category == "water":
		return {
			"walking": {"traversable": false},
			"tractor": {"traversable": false},
			"boat": {"traversable": true, "cost": 1.0}
		}
	var walk_cost := 2.0
	if surface == "gravel": walk_cost = 1.3
	elif surface == "cobblestone" or surface == "cobblestone_square": walk_cost = 1.0
	elif category == "forest": walk_cost = 3.0
	return {
		"walking": {"traversable": true, "cost": walk_cost},
		"tractor": {"traversable": category != "forest"},
		"boat": {"traversable": false}
	}

func _add_fence_rect(x0: int, y0: int, x1: int, y1: int, gate: Vector2i) -> void:
	for x in range(x0, x1 + 1):
		if Vector2i(x, y0) != gate: _set_fence(x, y0, Dir.N, false)
		else: _set_fence(x, y0, Dir.N, true)
		_set_fence(x, y1, Dir.S, false)
	for y in range(y0, y1 + 1):
		_set_fence(x0, y, Dir.W, false)
		_set_fence(x1, y, Dir.E, false)

func _set_fence(x: int, y: int, edge: int, gate: bool) -> void:
	fences["%d,%d,%d" % [x, y, edge]] = {"gate": gate}

func _iso(x: int, y: int) -> Vector2:
	return _iso_f(float(x) + 0.5, float(y) + 0.5)

func _iso_f(x: float, y: float) -> Vector2:
	return ORIGIN + Vector2((x - y) * TILE_W * 0.5, (x + y) * TILE_H * 0.5)

func _screen_to_grid(p: Vector2) -> Vector2:
	var q := p - ORIGIN
	return Vector2(q.x / TILE_W + q.y / TILE_H, q.y / TILE_H - q.x / TILE_W)

func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var walk_speed := _walking_speed_at(player_grid)
	if input.length() > 0.0:
		has_target = false
		_try_move_grid(input, walk_speed * delta)
	elif has_target:
		var d := player_screen.direction_to(target_screen)
		if player_screen.distance_to(target_screen) > 5.0:
			_try_move_screen(d * walk_speed * delta)
		else:
			has_target = false
	queue_redraw()

func _try_move_grid(input: Vector2, screen_distance: float) -> void:
	# Arrow/WASD directions are screen-relative:
	# Up/down move vertically on screen, left/right horizontally.
	# Combined keys therefore line up with the diagonal isometric tile axes.
	# Motion is still accumulated directly in grid space to avoid drift.
	var raw_grid_dir := Vector2(
		input.x + input.y,
		-input.x + input.y
	)
	if raw_grid_dir == Vector2.ZERO:
		return

	# Determine how many grid units correspond to the requested screen distance
	# for this exact direction under the 2:1 isometric projection.
	var projected := Vector2(
		(raw_grid_dir.x - raw_grid_dir.y) * TILE_W * 0.5,
		(raw_grid_dir.x + raw_grid_dir.y) * TILE_H * 0.5
	)
	var projected_len := projected.length()
	if projected_len <= 0.0001:
		return

	var grid_delta := raw_grid_dir * (screen_distance / projected_len)
	var new_grid := player_grid + grid_delta
	if _can_walk(player_grid, new_grid):
		player_grid = new_grid
		player_screen = _iso_f(player_grid.x, player_grid.y)

func _walking_speed_at(pos: Vector2) -> float:
	var x := clampi(int(floor(pos.x)), 0, GRID_W - 1)
	var y := clampi(int(floor(pos.y)), 0, GRID_H - 1)
	var walking: Dictionary = tiles[y][x].movement.walking
	if not walking.traversable:
		return 0.0
	var cost := float(walking.get("cost", 1.0))
	return WALK_SPEED / maxf(cost, 0.01)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target_screen = _view_to_world(event.position)
		has_target = true
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touches[event.index] = event.position
		if active_touches.size() == 1:
			tap_candidate_index = event.index
			tap_start_position = event.position
			tap_moved = false
		elif active_touches.size() >= 2:
			pinch_in_progress = true
			block_tap_until_clear = true
			has_target = false
			pinch_last_distance = _current_pinch_distance()
			pinch_last_center = _current_pinch_center()
	else:
		# A single, stationary finger is still a tap-to-walk command.
		if active_touches.size() == 1 and not block_tap_until_clear and event.index == tap_candidate_index and not tap_moved:
			target_screen = _view_to_world(event.position)
			has_target = true

		active_touches.erase(event.index)
		if active_touches.size() < 2:
			pinch_in_progress = false
			pinch_last_distance = 0.0
			pinch_last_center = Vector2.ZERO
		if active_touches.is_empty():
			block_tap_until_clear = false
			tap_candidate_index = -1
			tap_moved = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	# Preserve the previous two-finger gesture state before updating this touch.
	var old_distance := _current_pinch_distance()
	var old_center := _current_pinch_center()
	active_touches[event.index] = event.position

	if event.index == tap_candidate_index and event.position.distance_to(tap_start_position) > 12.0:
		tap_moved = true

	if active_touches.size() >= 2:
		pinch_in_progress = true
		block_tap_until_clear = true
		has_target = false

		var new_distance := _current_pinch_distance()
		var new_center := _current_pinch_center()

		if old_distance > 0.001 and new_distance > 0.001:
			# Keep the same world point under the gesture while the midpoint moves.
			# This gives simultaneous pinch-zoom and two-finger panning.
			var old_zoom := view_zoom
			var old_origin := _base_view_origin(old_zoom) + view_pan
			var world_under_gesture := (old_center - old_origin) / old_zoom

			var factor := new_distance / old_distance
			view_zoom = clampf(old_zoom * factor, 0.55, 2.75)

			var new_base_origin := _base_view_origin(view_zoom)
			view_pan = new_center - new_base_origin - world_under_gesture * view_zoom

		pinch_last_distance = new_distance
		pinch_last_center = new_center
		queue_redraw()
	elif tap_moved:
		# A one-finger drag pans the map. Once the threshold has been crossed,
		# releasing the finger will no longer issue a tap-to-walk command.
		view_pan += event.relative
		has_target = false
		queue_redraw()

func _current_pinch_distance() -> float:
	if active_touches.size() < 2:
		return 0.0
	var keys := active_touches.keys()
	var p1: Vector2 = active_touches[keys[0]]
	var p2: Vector2 = active_touches[keys[1]]
	return p1.distance_to(p2)

func _current_pinch_center() -> Vector2:
	if active_touches.size() < 2:
		return Vector2.ZERO
	var keys := active_touches.keys()
	var p1: Vector2 = active_touches[keys[0]]
	var p2: Vector2 = active_touches[keys[1]]
	return (p1 + p2) * 0.5

func _base_view_origin(zoom_value: float) -> Vector2:
	var center := get_viewport_rect().size * 0.5
	return center - center * zoom_value

func _view_origin() -> Vector2:
	return _base_view_origin(view_zoom) + view_pan

func _view_to_world(view_position: Vector2) -> Vector2:
	return (view_position - _view_origin()) / view_zoom

func _try_move_screen(delta_screen: Vector2) -> void:
	var old_grid := player_grid
	var candidate_screen := player_screen + delta_screen
	var new_grid := _screen_to_grid(candidate_screen)
	if _can_walk(old_grid, new_grid):
		player_grid = new_grid
		player_screen = candidate_screen
	else:
		has_target = false

func _can_walk(old_pos: Vector2, new_pos: Vector2) -> bool:
	if new_pos.x < 0.05 or new_pos.y < 0.05 or new_pos.x >= GRID_W - 0.05 or new_pos.y >= GRID_H - 0.05:
		return false
	var ox := clampi(int(floor(old_pos.x)), 0, GRID_W - 1)
	var oy := clampi(int(floor(old_pos.y)), 0, GRID_H - 1)
	var nx := clampi(int(floor(new_pos.x)), 0, GRID_W - 1)
	var ny := clampi(int(floor(new_pos.y)), 0, GRID_H - 1)
	if not tiles[ny][nx].movement.walking.traversable:
		return false
	if nx > ox and _edge_blocks_walking(ox, oy, Dir.E): return false
	if nx < ox and _edge_blocks_walking(ox, oy, Dir.W): return false
	if ny > oy and _edge_blocks_walking(ox, oy, Dir.S): return false
	if ny < oy and _edge_blocks_walking(ox, oy, Dir.N): return false
	return true

func _edge_blocks_walking(x: int, y: int, edge: int) -> bool:
	var f = fences.get("%d,%d,%d" % [x, y, edge])
	if f != null:
		return not f.gate
	var nx := x
	var ny := y
	var opposite := 0
	match edge:
		Dir.N: ny -= 1; opposite = Dir.S
		Dir.E: nx += 1; opposite = Dir.W
		Dir.S: ny += 1; opposite = Dir.N
		Dir.W: nx -= 1; opposite = Dir.E
	if nx >= 0 and ny >= 0 and nx < GRID_W and ny < GRID_H:
		f = fences.get("%d,%d,%d" % [nx, ny, opposite])
		if f != null: return not f.gate
	return false

func _draw() -> void:
	# Scale only the game world. Keep UI text at a fixed readable size.
	draw_set_transform(_view_origin(), 0.0, Vector2(view_zoom, view_zoom))

	# 1. Ground layer.
	for y in GRID_H:
		for x in GRID_W:
			_draw_tile(x, y, tiles[y][x])
	# 2. Roads and plazas use exact grid geometry.
	for y in GRID_H:
		for x in GRID_W:
			if tiles[y][x].category == "road":
				_draw_road(x, y, tiles[y][x])
	# 3. Forest vegetation is a prop layer above the ground.
	for y in GRID_H:
		for x in GRID_W:
			if tiles[y][x].category == "forest":
				_draw_forest_prop(x, y)
	# 4. Edge overlays and player.
	_draw_all_fences()
	_draw_player()

	# Reset transform before drawing UI.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ui()

func _draw_asset(texture: Texture2D, tile_center: Vector2) -> void:
	if texture != null:
		draw_texture(texture, tile_center - TILE_TEXTURE_ORIGIN)

func _draw_tile(x: int, y: int, tile: Dictionary) -> void:
	var c := _iso(x, y)
	var grass: Texture2D = asset_textures.get("grass")
	_draw_asset(grass, c)

	if tile.category == "water":
		var water_key := _water_texture_key(x, y)
		_draw_asset(asset_textures.get(water_key), c)

	# Fallback marker only if the base texture failed to load.
	if grass == null:
		var diamond := PackedVector2Array([
			c + Vector2(0, -TILE_H * 0.5), c + Vector2(TILE_W * 0.5, 0),
			c + Vector2(0, TILE_H * 0.5), c + Vector2(-TILE_W * 0.5, 0)
		])
		draw_colored_polygon(diamond, Color("#79aa5b"))

func _is_water(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < GRID_W and y < GRID_H and tiles[y][x].category == "water"

func _water_texture_key(x: int, y: int) -> String:
	var land_mask := 0
	if not _is_water(x, y - 1): land_mask |= Dir.N
	if not _is_water(x + 1, y): land_mask |= Dir.E
	if not _is_water(x, y + 1): land_mask |= Dir.S
	if not _is_water(x - 1, y): land_mask |= Dir.W

	# The current v2 atlas labels were a first-pass packaging. Visual inspection
	# shows water_edge_n/e/s/w are actually two-sided outer-corner banks:
	#   edge_n = grid N+W
	#   edge_e = grid N+E
	#   edge_s = grid E+S
	#   edge_w = grid S+W
	# Use them only for those exact topologies. This prevents grass wedges from
	# intruding into connected interior water.
	match land_mask:
		0:
			return "water_plain_v2"
		Dir.N | Dir.W:
			return "water_shore_n_v2"
		Dir.N | Dir.E:
			return "water_shore_e_v2"
		Dir.E | Dir.S:
			return "water_shore_s_v2"
		Dir.S | Dir.W:
			return "water_shore_w_v2"

	# The atlas does not contain a trustworthy true single-edge shoreline yet.
	# Plain water is intentionally safer for one-sided and complex cases than
	# drawing a bank across an internal water connection.
	return "water_plain_v2"

func _draw_forest_prop(x: int, y: int) -> void:
	var c := _iso(x, y)
	var selector := (x * 7 + y * 11) % 12
	var key := "tree_oak"
	if selector == 0:
		key = "forest_cluster_a"
	elif selector == 1:
		key = "forest_cluster_b"
	elif selector in [2, 3]:
		key = "tree_pine_large_a"
	elif selector in [4, 5]:
		key = "tree_pine_medium_a"
	elif selector == 6:
		key = "tree_pine_small_a"

	var texture: Texture2D = asset_textures.get(key)
	if texture != null:
		var offset := Vector2(float(((x + y * 2) % 5) - 2) * 2.0, float(((x * 2 + y) % 3) - 1))
		draw_texture(texture, c + offset - PROP_TEXTURE_ORIGIN)

func _grid_mask_to_asset_mask(mask: int) -> int:
	# Grid neighbour directions and sprite-diamond labels differ by 90 degrees:
	# grid N -> asset E, E -> S, S -> W, W -> N.
	var result := 0
	if (mask & Dir.N) != 0: result |= Dir.E
	if (mask & Dir.E) != 0: result |= Dir.S
	if (mask & Dir.S) != 0: result |= Dir.W
	if (mask & Dir.W) != 0: result |= Dir.N
	return result

func _road_suffix(mask: int) -> String:
	match mask:
		Dir.N | Dir.S: return "ns"
		Dir.E | Dir.W: return "ew"
		Dir.N | Dir.E: return "ne"
		Dir.N | Dir.W: return "nw"
		Dir.S | Dir.E: return "se"
		Dir.S | Dir.W: return "sw"
		Dir.N | Dir.E | Dir.W: return "t_n"
		Dir.N | Dir.E | Dir.S: return "t_e"
		Dir.E | Dir.S | Dir.W: return "t_s"
		Dir.N | Dir.S | Dir.W: return "t_w"
		Dir.N | Dir.E | Dir.S | Dir.W: return "cross"
	return ""

func _draw_road(x: int, y: int, tile: Dictionary) -> void:
	var c := _iso(x, y)

	if tile.surface == "cobblestone_square":
		# Repeat only clean v4 base tiles. Decorative plaza borders stay disabled
		# until the base surface is visually verified as seamless.
		var plaza_variant := (x * 5 + y * 7) % 9
		var plaza_key := "plaza_base_v4"
		if plaza_variant == 0:
			plaza_key = "plaza_variant_01_v4"
		elif plaza_variant == 1:
			plaza_key = "plaza_variant_02_v4"
		_draw_asset(asset_textures.get(plaza_key), c)
		return

	# Keep exact grid geometry until the v3 road crop directions are visually verified.
	if tile.surface == "gravel":
		_draw_grid_road(c, tile.connections, 12.0, Color("#d4ad72"), Color("#a47c4e"))
	else:
		_draw_grid_road(c, tile.connections, 18.0, Color("#aaa59c"), Color("#77736e"))

func _draw_grid_road(c: Vector2, mask: int, width: float, fill: Color, edge: Color) -> void:
	# Dark outer stroke then lighter surface gives a readable road edge
	# without changing the grid geometry.
	draw_circle(c, (width + 2.0) * 0.5, edge)
	for d in [Dir.N, Dir.E, Dir.S, Dir.W]:
		if (mask & d) != 0:
			draw_line(c, _edge_point(c, d), edge, width + 2.0, true)
	draw_circle(c, width * 0.5, fill)
	for d in [Dir.N, Dir.E, Dir.S, Dir.W]:
		if (mask & d) != 0:
			draw_line(c, _edge_point(c, d), fill, width, true)

func _edge_point(c: Vector2, d: int) -> Vector2:
	match d:
		Dir.N: return c + Vector2(TILE_W * 0.25, -TILE_H * 0.25)
		Dir.E: return c + Vector2(TILE_W * 0.25, TILE_H * 0.25)
		Dir.S: return c + Vector2(-TILE_W * 0.25, TILE_H * 0.25)
		Dir.W: return c + Vector2(-TILE_W * 0.25, -TILE_H * 0.25)
	return c

func _draw_connections(c: Vector2, mask: int, width: float, col: Color) -> void:
	draw_circle(c, width * 0.5, col)
	for d in [Dir.N, Dir.E, Dir.S, Dir.W]:
		if mask & d: draw_line(c, _edge_point(c, d), col, width, true)

func _draw_all_fences() -> void:
	for key in fences:
		var parts: PackedStringArray = key.split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var edge := int(parts[2])
		var gate := bool(fences[key].gate)
		_draw_fence_edge(x, y, edge, gate)

func _asset_edge_suffix(grid_edge: int) -> String:
	match grid_edge:
		Dir.N: return "e"
		Dir.E: return "s"
		Dir.S: return "w"
		Dir.W: return "n"
	return ""

func _draw_fence_edge(x: int, y: int, edge: int, gate: bool) -> void:
	var suffix := _asset_edge_suffix(edge)
	var key := ("%s_%s" % ["gate" if gate else "fence", suffix])
	var texture: Texture2D = asset_textures.get(key)
	if texture != null:
		_draw_asset(texture, _iso(x, y))
		return

	# Geometry fallback if the expected v2 overlay is missing.
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	match edge:
		Dir.N: a = _iso_f(x, y); b = _iso_f(x + 1, y)
		Dir.E: a = _iso_f(x + 1, y); b = _iso_f(x + 1, y + 1)
		Dir.S: a = _iso_f(x, y + 1); b = _iso_f(x + 1, y + 1)
		Dir.W: a = _iso_f(x, y); b = _iso_f(x, y + 1)
	if not gate:
		draw_line(a, b, Color("#8b5a31"), 3.0, true)

func _draw_player() -> void:
	draw_ellipse(player_screen + Vector2(0,7), Vector2(9,4), Color(0,0,0,.28))
	draw_rect(Rect2(player_screen.x-6, player_screen.y-13, 12, 18), Color("#315fbb"), true)
	draw_circle(player_screen + Vector2(0,-18), 7, Color("#edc39e"))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a)*radius.x, sin(a)*radius.y))
	draw_colored_polygon(pts, color)

func _draw_ui() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(16,24), "Gå: WASD / piltaster. På mobil/nettbrett: trykk dit du vil gå.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
