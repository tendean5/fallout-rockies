# Procedural world map — 72x52 tiles, ported from the old browser build.
class_name WorldMap

const TILE := 16
const MAP_W := 72
const MAP_H := 52

const T_GRASS := 0
const T_DIRT := 1
const T_ROAD := 2
const T_CITY := 3
const T_MTN := 4
const T_FOREST := 5
const T_WATER := 6
const T_SNOW := 7

static func _rand(x: int, y: int) -> float:
	var h := sin(x * 127.1 + y * 311.7) * 43758.5453
	return h - floor(h)

static func make_map() -> Array:
	var map: Array = []
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			row.append(T_GRASS)
		map.append(row)

	# mountain ridge across the top-right, with a pass through
	for y in range(0, 9):
		for x in range(30, MAP_W):
			if x >= 46 and x <= 49:
				map[y][x] = T_SNOW
			else:
				map[y][x] = T_MTN

	# dense forest across the top-left
	for y in range(0, 9):
		for x in range(0, 30):
			if _rand(x, y) < 0.55:
				map[y][x] = T_FOREST

	# Denver grid: blocks with dirt streets
	for y in range(10, 34):
		for x in range(4, 40):
			if x % 5 == 0 or y % 5 == 0:
				map[y][x] = T_DIRT
			else:
				map[y][x] = T_CITY

	# airport zone (southwest): walkable dirt + a few concrete blocks
	for y in range(36, 46):
		for x in range(2, 15):
			map[y][x] = T_DIRT
	map[40][4] = T_CITY
	map[40][8] = T_CITY
	map[41][12] = T_CITY

	# high country (east): dirt + scattered trees
	for y in range(10, 34):
		for x in range(42, MAP_W):
			if map[y][x] == T_GRASS:
				map[y][x] = T_DIRT
			if _rand(x, y) < 0.16:
				map[y][x] = T_FOREST

	# desert (far west): open grass with a few trees
	for y in range(10, 34):
		for x in range(0, 4):
			if _rand(x, y) < 0.12:
				map[y][x] = T_FOREST

	# Platte River across the bottom (wavy), with a road bridge
	for y in range(45, MAP_H):
		for x in range(0, MAP_W):
			var wave := sin(x * 0.22) * 1.6
			if y >= round(45.0 + wave):
				map[y][x] = T_WATER
	# road bridge
	for y in range(44, MAP_H):
		for x in range(18, 21):
			map[y][x] = T_ROAD

	# road: airport -> Denver grid -> south to the bridge
	for x in range(2, 19):
		map[38][x] = T_ROAD
	for y in range(34, 46):
		for x in range(19, 21):
			map[y][x] = T_ROAD

	return map

static func is_solid(t: int) -> bool:
	return t == T_CITY or t == T_MTN or t == T_FOREST

static func tile_at(map: Array, tx: int, ty: int) -> int:
	if ty < 0 or ty >= MAP_H or tx < 0 or tx >= MAP_W:
		return T_CITY
	return map[ty][tx]

static func region_name(x: int, y: int) -> String:
	if y <= 9 and x >= 30:
		if x >= 46 and x <= 49:
			return "The High Country Pass"
		return "The Peaks"
	if y <= 9:
		return "The Woods"
	if y <= 33 and x >= 40:
		return "The High Country"
	if y <= 33 and x >= 4:
		return "Denver Ruins"
	if y <= 33:
		return "The Wastes"
	if y <= 45:
		return "The Airport"
	return "The Platte"

static func color_of(t: int, x: int, y: int) -> Color:
	var v := float((x * 7 + y * 13) % 3) / 3.0
	match t:
		T_GRASS:
			if v < 0.4: return Color("#3a3020")
			elif v < 0.75: return Color("#413627")
			else: return Color("#443a24")
		T_DIRT: return Color("#4a3a22")
		T_ROAD: return Color("#51422a")
		T_CITY: return Color("#2b2118")
		T_MTN:
			if v < 0.5: return Color("#33313a")
			else: return Color("#2e2c36")
		T_FOREST: return Color("#263d24")
		T_WATER: return Color("#1c3550")
		T_SNOW: return Color("#d8cfc0")
		_: return Color("#3a3020")
