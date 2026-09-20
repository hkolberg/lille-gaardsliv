extends Node2D

# First playable 20x20 concept world. The player can walk through the landscape
# while fences are treated as edge barriers, separate from tile traversability.
const GRID_W := 20
const GRID_H := 20
const TILE_W := 64.0
const TILE_H := 32.0
const ORIGIN := Vector2(576, 70)
const WALK_SPEED := 110.0

enum Dir { N = 1, E = 2, S = 4, W = 8 }

var tiles: Array = []
var fences: Dictionary = {}
var player_grid := Vector2(4.5, 4.5)
var player_screen := Vector2.ZERO
var target_screen := Vector2.ZERO
var has_target := false

func _ready() -> void:
	_setup_input()
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
		target_screen = event.position
		has_target = true
	elif event is InputEventScreenTouch and event.pressed:
		target_screen = event.position
		has_target = true

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
	for y in GRID_H:
		for x in GRID_W:
			_draw_tile(x, y, tiles[y][x])
	# Draw paths after every ground tile, so adjacent tiles cannot cover them.
	for y in GRID_H:
		for x in GRID_W:
			if tiles[y][x].category == "road":
				_draw_road(x, y, tiles[y][x])
	_draw_all_fences()
	_draw_player()
	_draw_ui()

func _draw_tile(x: int, y: int, tile: Dictionary) -> void:
	var c := _iso(x, y)
	var diamond := PackedVector2Array([
		c + Vector2(0, -TILE_H * 0.5), c + Vector2(TILE_W * 0.5, 0),
		c + Vector2(0, TILE_H * 0.5), c + Vector2(-TILE_W * 0.5, 0)
	])
	var base := Color("#79aa5b")
	if tile.category == "forest": base = Color("#527d49")
	draw_colored_polygon(diamond, base)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0,0,0,0.10), 1.0)
	if tile.category == "forest":
		draw_circle(c + Vector2(0,-8), 8, Color("#315f38"))
		draw_line(c + Vector2(0,-2), c + Vector2(0,5), Color("#64462d"), 3)

func _draw_road(x: int, y: int, tile: Dictionary) -> void:
	var c := _iso(x, y)
	if tile.surface == "cobblestone_square":
		draw_colored_polygon(PackedVector2Array([
			_iso_f(x, y), _iso_f(x + 1, y),
			_iso_f(x + 1, y + 1), _iso_f(x, y + 1)
		]), Color("#aaa49a"))
	else:
		var width := 11.0 if tile.surface == "gravel" else 21.0
		var col := Color("#c0a174") if tile.surface == "gravel" else Color("#9f9a91")
		_draw_connections(c, tile.connections, width, col)

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
		var x := int(parts[0]); var y := int(parts[1]); var edge := int(parts[2])
		# The same integer grid edges used by floor() in collision checks.
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		match edge:
			Dir.N: a = _iso_f(x, y); b = _iso_f(x + 1, y)
			Dir.E: a = _iso_f(x + 1, y); b = _iso_f(x + 1, y + 1)
			Dir.S: a = _iso_f(x, y + 1); b = _iso_f(x + 1, y + 1)
			Dir.W: a = _iso_f(x, y); b = _iso_f(x, y + 1)
		# A gate is an entirely open edge, matching its collision rule.
		# End posts mark the entrance without drawing a barrier across it.
		if not fences[key].gate:
			draw_line(a, b, Color("#704d2b"), 3, true)
		var post_color := Color("#ba925f") if fences[key].gate else Color("#704d2b")
		draw_line(a, a + Vector2(0, -6), post_color, 3, true)
		draw_line(b, b + Vector2(0, -6), post_color, 3, true)

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
