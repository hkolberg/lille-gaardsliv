extends Node2D

# Minimal 20x20 isometric test of the tile model agreed in the MDD discussion.
const GRID_W := 20
const GRID_H := 20
const TILE_W := 64.0
const TILE_H := 32.0
const ORIGIN := Vector2(576, 90)

enum Dir { N = 1, E = 2, S = 4, W = 8 }

var tiles: Array = []

func _ready() -> void:
	_build_world()
	queue_redraw()

func _build_world() -> void:
	tiles.clear()
	for y in GRID_H:
		var row: Array = []
		for x in GRID_W:
			row.append(_tile("meadow", "grass", 0))
		tiles.append(row)

	# Water area
	for y in range(2, 7):
		for x in range(14, 19):
			tiles[y][x] = _tile("water", "water", 0)

	# Field
	for y in range(12, 18):
		for x in range(2, 8):
			tiles[y][x] = _tile("field", "soil", 0)

	# Forest
	for y in range(11, 18):
		for x in range(13, 18):
			tiles[y][x] = _tile("forest", "forest_floor", 0)

	# Gravel path: straight + turn.
	for y in range(2, 10):
		tiles[y][5] = _tile("road", "gravel", Dir.N | Dir.S)
	tiles[10][5] = _tile("road", "gravel", Dir.N | Dir.E)
	for x in range(6, 11):
		tiles[10][x] = _tile("road", "gravel", Dir.E | Dir.W)

	# Cobblestone road: visually wider, same centerline connection logic.
	for x in range(2, 10):
		tiles[6][x] = _tile("road", "cobblestone", Dir.E | Dir.W)
	tiles[6][10] = _tile("road", "cobblestone", Dir.W | Dir.S)
	for y in range(7, 13):
		tiles[y][10] = _tile("road", "cobblestone", Dir.N | Dir.S)

	# Full cobblestone square.
	for y in range(13, 17):
		for x in range(8, 12):
			tiles[y][x] = _tile("road", "cobblestone_square", Dir.N | Dir.E | Dir.S | Dir.W)

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
			"walking": {"traversable": true, "cost": 10.0},
			"tractor": {"traversable": false},
			"boat": {"traversable": true, "cost": 1.0}
		}
	var walk_cost := 1.0
	var tractor_cost := 1.4
	if surface == "gravel":
		walk_cost = 0.9
		tractor_cost = 0.9
	elif surface == "cobblestone" or surface == "cobblestone_square":
		walk_cost = 0.8
		tractor_cost = 0.8
	elif category == "forest":
		walk_cost = 1.5
		tractor_cost = 2.5
	elif category == "field":
		walk_cost = 1.3
		tractor_cost = 1.2
	return {
		"walking": {"traversable": true, "cost": walk_cost},
		"tractor": {"traversable": true, "cost": tractor_cost},
		"boat": {"traversable": false}
	}

func _iso(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2((x - y) * TILE_W * 0.5, (x + y) * TILE_H * 0.5)

func _draw() -> void:
	for y in GRID_H:
		for x in GRID_W:
			_draw_tile(x, y, tiles[y][x])

func _draw_tile(x: int, y: int, tile: Dictionary) -> void:
	var c := _iso(x, y)
	var diamond := PackedVector2Array([
		c + Vector2(0, -TILE_H * 0.5),
		c + Vector2(TILE_W * 0.5, 0),
		c + Vector2(0, TILE_H * 0.5),
		c + Vector2(-TILE_W * 0.5, 0)
	])
	var base := Color("#77a85b")
	match tile.category:
		"field": base = Color("#9b6c3f")
		"forest": base = Color("#477545")
		"water": base = Color("#5798bd")
	draw_colored_polygon(diamond, base)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0,0,0,0.12), 1.0)

	if tile.category == "road":
		if tile.surface == "cobblestone_square":
			draw_colored_polygon(diamond, Color("#a49d90"))
		else:
			var width := 12.0 if tile.surface == "gravel" else 22.0
			var color := Color("#b79b70") if tile.surface == "gravel" else Color("#9c978e")
			_draw_connections(c, tile.connections, width, color)

func _edge_point(c: Vector2, d: int) -> Vector2:
	match d:
		Dir.N: return c + Vector2(0, -TILE_H * 0.5)
		Dir.E: return c + Vector2(TILE_W * 0.5, 0)
		Dir.S: return c + Vector2(0, TILE_H * 0.5)
		Dir.W: return c + Vector2(-TILE_W * 0.5, 0)
	return c

func _draw_connections(c: Vector2, mask: int, width: float, color: Color) -> void:
	for d in [Dir.N, Dir.E, Dir.S, Dir.W]:
		if mask & d:
			draw_line(c, _edge_point(c, d), color, width, true)
