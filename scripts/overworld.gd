# Overworld — THE GAME. Procedural map, kid movement, water drowning,
# checkpoint autonsave, death → reset-to-checkpoint.
extends Node2D

const WorldMap = preload("res://scripts/world_map.gd")
const Kid = preload("res://scripts/kid.gd")
const KidState = preload("res://scripts/kid_state.gd")

const TILE := WorldMap.TILE
const MAP_W := WorldMap.MAP_W
const MAP_H := WorldMap.MAP_H
const WALK := 3.4

const START_TILE := {"x": 6, "y": 38}
const HUD_W := 320
const HUD_H := 176

var map: Array = []
var kid := KidState.new()
var time := 0.0
var fade := 1.0
var dead := false
var dead_timer := 0.0
var drown := 0.0
var deaths := 0
var age := 13
var region := "Denver Ruins"
var checkpoint := {"x": START_TILE["x"] * TILE, "y": START_TILE["y"] * TILE}
var saved_time := 0.0

var _prev_keys: Dictionary = {}
var _cam := Vector2(0, 0)
var _moving := false
var _walk_phase := 0.0
var _step_pitch := 0.0

func _ready() -> void:
	map = WorldMap.make_map()
	time = 0.0
	fade = 1.0
	dead = false
	dead_timer = 0.0
	drown = 0.0
	deaths = int(Game.carry.get("deaths", 0)) if Game.carry != null else 0
	age = int(Game.carry.get("age", 13)) if Game.carry != null else 13

	var cp = Game.checkpoint
	if typeof(cp) == TYPE_DICTIONARY and int(cp.get("x", -1)) >= 0:
		checkpoint = {"x": int(cp["x"]) * TILE, "y": int(cp["y"]) * TILE}
	else:
		checkpoint = {"x": START_TILE["x"] * TILE, "y": START_TILE["y"] * TILE}

	kid.x = checkpoint["x"]
	kid.y = checkpoint["y"]
	region = WorldMap.region_name(int(kid.x / TILE), int(kid.y / TILE))
	_cam = _target_cam()
	_step_pitch = 0.0
	Audio.start_loop("ambience")

func debug_scene_name() -> String:
	return "overworld"

func debug_deaths() -> int:
	return deaths

func debug_is_dead() -> bool:
	return dead

func debug_teleport_to_water() -> void:
	for ty in MAP_H:
		for tx in MAP_W:
			if map[ty][tx] == WorldMap.T_WATER:
				kid.x = float(tx * TILE) + 1.0
				kid.y = float(ty * TILE) + 1.0
				drown = 0.0
				return

func _physics_process(delta: float) -> void:
	time += delta
	queue_redraw()
	if fade > 0.0:
		fade = max(0.0, fade - delta * 1.8)

	if _just_key(KEY_ESCAPE):
		Game.scene_change_to("title")
		return

	if dead:
		dead_timer += delta
		if dead_timer >= 1.3:
			_reset_kid()
		return

	# tap assist (one nudge per fresh tap)
	if _just_key(KEY_LEFT) or _just_key(KEY_A):
		kid.x -= 3.2
	if _just_key(KEY_RIGHT) or _just_key(KEY_D):
		kid.x += 3.2
	if _just_key(KEY_UP) or _just_key(KEY_W):
		kid.y -= 3.2
	if _just_key(KEY_DOWN) or _just_key(KEY_S):
		kid.y += 3.2

	var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Game.virtual_left
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Game.virtual_right
	var up := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Game.virtual_up
	var down := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) or Game.virtual_down

	var vx := 0.0
	var vy := 0.0
	if left:
		vx = -WALK
		kid.face = -1
	if right:
		vx = WALK
		kid.face = 1
	if up: vy = -WALK
	if down: vy = WALK
	kid.vx = vx * TILE

	_moving = (vx != 0.0 or vy != 0.0)
	if _moving:
		_walk_phase += delta * 11.0
		if _walk_phase - _step_pitch >= 0.55:
			_step_pitch = _walk_phase
			Audio.play_sfx("walk_step", 0.4)

	kid.x += kid.vx * delta
	kid.y += vy * TILE * delta
	_resolve_collisions()

	kid.x = clamp(kid.x, 0.0, float(MAP_W * TILE - kid.w))
	kid.y = clamp(kid.y, 0.0, float(MAP_H * TILE - kid.h))

	_cam = _cam.lerp(_target_cam(), min(1.0, delta * 12.0))

	# checkpoint tracking (only safe tiles)
	var tile := _tile_at_kid()
	var in_water := tile == WorldMap.T_WATER
	if not _is_in_solid() and not in_water and not dead:
		checkpoint = {"x": kid.x, "y": kid.y}
		saved_time += delta
		if saved_time >= Game.checkpoint_interval:
			saved_time = 0.0
			Game.checkpoint = {"x": int(kid.x / TILE), "y": int(kid.y / TILE)}
			Game.save_game({"flag": "overworld"})


	# drown timer
	if in_water:
		drown += delta
		if drown >= 1.6:
			_die()
			return
	else:
		drown = max(0.0, drown - delta * 2.0)

	region = WorldMap.region_name(int(kid.x / TILE), int(kid.y / TILE))

func _target_cam() -> Vector2:
	var cam_x: float = clamp(kid.x + kid.w / 2.0 - HUD_W / 2.0, 0.0, float(MAP_W * TILE - HUD_W))
	var cam_y: float = clamp(kid.y + kid.h / 2.0 - HUD_H / 2.0, 0.0, float(MAP_H * TILE - HUD_H))
	return Vector2(cam_x, cam_y)

func _tile_at(tx: int, ty: int) -> int:
	return WorldMap.tile_at(map, tx, ty)

func _is_solid_tile(tx: int, ty: int) -> bool:
	return WorldMap.is_solid(_tile_at(tx, ty))

func _is_in_solid() -> bool:
	var x0 := int(kid.x / TILE)
	var x1 := int((kid.x + kid.w) / TILE)
	var y0 := int(kid.y / TILE)
	var y1 := int((kid.y + kid.h) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if _is_solid_tile(tx, ty):
				return true
	return false

func _tile_at_kid() -> int:
	var cx := kid.x + kid.w / 2.0
	var cy := kid.y + kid.h / 2.0
	return _tile_at(int(cx / TILE), int(cy / TILE))

func _resolve_collisions() -> void:
	var resolved := _resolve_x()
	if resolved:
		_resolve_y()

func _resolve_x() -> bool:
	var k = kid
	var x0 := int(k.x / TILE)
	var x1 := int((k.x + k.w) / TILE)
	var y0 := int(k.y / TILE)
	var y1 := int((k.y + k.h) / TILE)
	var hit := false
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _is_solid_tile(tx, ty):
				continue
			var left_edge := tx * TILE
			var right_edge := (tx + 1) * TILE
			var mid_x: float = k.x + k.w / 2.0
			if mid_x < (left_edge + right_edge) / 2.0:
				k.x = left_edge - k.w
			else:
				k.x = right_edge
			hit = true
	return hit

func _resolve_y() -> void:
	var k = kid
	var x0 := int(k.x / TILE)
	var x1 := int((k.x + k.w) / TILE)
	var y0 := int(k.y / TILE)
	var y1 := int((k.y + k.h) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _is_solid_tile(tx, ty):
				continue
			var top_edge := ty * TILE
			var bottom_edge := (ty + 1) * TILE
			var mid_y: float = k.y + k.h / 2.0
			if mid_y < (top_edge + bottom_edge) / 2.0:
				k.y = top_edge - k.h
			else:
				k.y = bottom_edge

func _die() -> void:
	if dead:
		return
	dead = true
	dead_timer = 0.0
	drown = 0.0
	deaths += 1
	Game.carry["deaths"] = deaths

func _reset_kid() -> void:
	dead = false
	dead_timer = 0.0
	drown = 0.0
	kid.x = checkpoint["x"]
	kid.y = checkpoint["y"]

func _draw() -> void:
	var cam_x := _cam.x
	var cam_y := _cam.y

	draw_rect(Rect2(0, 0, HUD_W, HUD_H), Color("#14100b"))

	var tx0: int = max(0, int(cam_x / TILE) - 1)
	var ty0: int = max(0, int(cam_y / TILE) - 1)
	var tx1: int = min(MAP_W - 1, int((cam_x + HUD_W) / TILE) + 1)
	var ty1: int = min(MAP_H - 1, int((cam_y + HUD_H) / TILE) + 1)

	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			var t: int = map[ty][tx]
			var px := float(tx * TILE) - cam_x
			var py := float(ty * TILE) - cam_y
			if px < -TILE or px > HUD_W or py < -TILE or py > HUD_H:
				continue
			draw_rect(Rect2(px, py, TILE, TILE), WorldMap.color_of(t, tx, ty))
			if t == WorldMap.T_FOREST:
				draw_rect(Rect2(px + 2, py + 2, 3, 3), Color("#1c3319"))
				draw_rect(Rect2(px + 9, py + 6, 3, 3), Color("#1c3319"))
			elif t == WorldMap.T_MTN:
				draw_rect(Rect2(px + 3, py + 4, 4, 4), Color("#3c3a45"))
				draw_rect(Rect2(px + 9, py + 10, 3, 3), Color("#2a2833"))
			elif t == WorldMap.T_CITY:
				draw_rect(Rect2(px + 3, py + 3, 10, 10), Color("#1f1712"))
				draw_rect(Rect2(px + 4, py + 4, 8, 2), Color("#170f0b"))
			elif t == WorldMap.T_ROAD:
				draw_rect(Rect2(px + 6, py, 4, TILE), Color("#413422"))
			elif t == WorldMap.T_WATER:
				var w: int = int(fposmod(time * 3.0 + tx + ty, 3.0))
				draw_rect(Rect2(px, py + 5 + w * 2, TILE, 2), Color(0.47, 0.67, 0.82, 0.35))
			elif t == WorldMap.T_SNOW:
				draw_rect(Rect2(px + 3, py + 9, 10, 3), Color("#e6ddce"))

	var bob := 0
	var step := -1
	if _moving:
		bob = int(round(sin(_walk_phase) * 1.0))
		step = int(_walk_phase / PI) % 2
	Kid.draw(self, kid.x - cam_x, kid.y - cam_y, kid.face, bob, step)

	# HUD bar
	draw_rect(Rect2(0, 0, HUD_W, 14), Color(0.039, 0.031, 0.02, 0.82))
	draw_left("AGE %d   %s" % [age, region], 6, 9, 7, Color("#c8d4a0"))
	draw_right("DEATHS %d" % deaths, HUD_W - 6, 9, 7, Color("#8a7d63"))

	if drown > 0.2 and not dead:
		draw_centered("SPLASH \u2014 GET OUT OF THE WATER", HUD_W / 2, HUD_H / 2 - 12 + 4, 8, Color("#6ab0e0"))
		draw_centered("drowning in %.1fs" % max(0.0, 1.6 - drown), HUD_W / 2, HUD_H / 2 + 4 + 3, 6, Color("#3a5a78"))

	if dead:
		draw_rect(Rect2(0, 0, HUD_W, HUD_H), Color(0.20, 0.055, 0.03, 0.74))
		draw_centered("YOU DIED", HUD_W / 2, HUD_H / 2 - 4 + 4, 12, Color("#d96a3a"))
		draw_centered("back to the last safe tile...", HUD_W / 2, HUD_H / 2 + 12 + 4, 7, Color("#c8a08a"))

	if fade > 0.0:
		draw_rect(Rect2(0, 0, HUD_W, HUD_H), Color(0.023, 0.015, 0.007, fade))

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_left(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_right(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_RIGHT, -1, size, color)

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh: bool = cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh

