# Childhood prologue — walkthrough corridor → fade → surface → overworld.
extends Node2D

const TILE := WorldMap.TILE
const W := 40
const H := 11
const WALK := 3.1

const HINT_TIME := 3.0

var map: Array = []
var kid := {"x": 3 * TILE, "y": (H - 1) * TILE - 13, "w": 11, "h": 13, "face": 1}
var time := 0.0
var fade := 1.0
var surface := false
var surface_fade := 0.0
var hint_timer := HINT_TIME
var _prev_keys: Dictionary = {}
var _finished := false

func _ready() -> void:
	map = _make_map()
	kid = {"x": 3 * TILE, "y": (H - 1) * TILE - 13, "w": 11, "h": 13, "face": 1}
	fade = 1.0

func debug_scene_name() -> String:
	return "bunkers"

func debug_teleport_to_end() -> void:
	kid["x"] = (W - 2) * TILE

func _make_map() -> Array:
	var m: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(" ")
		m.append(row)
	for x in W:
		m[0][x] = "#"
		m[H - 1][x] = "#"
	for y in H:
		m[y][0] = "#"
		m[y][W - 1] = "#"
	# decorative pillars
	m[5][8] = "#"; m[6][8] = "#"
	m[4][13] = "#"; m[5][13] = "#"
	return m

func _is_solid(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= W or ty >= H:
		return true
	return map[ty][tx] == "#"

func _physics_process(delta: float) -> void:
	time += delta
	# fade IN from black (fixed from the old browser build)
	if fade > 0.0:
		fade = max(0.0, fade - delta * 2.0)

	if _just_key(KEY_ESCAPE):
		Game.scene_change_to("title")
		return

	if hint_timer > 0.0:
		hint_timer -= delta

	# tap assist (one nudge per fresh tap)
	if _just_key(KEY_RIGHT) or _just_key(KEY_D):
		kid["x"] += 3.2
	if _just_key(KEY_LEFT) or _just_key(KEY_A):
		kid["x"] -= 3.2

	var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Game.virtual_left
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Game.virtual_right
	var vx := 0.0
	if left:
		vx = -WALK
		kid["face"] = -1
	if right:
		vx = WALK
		kid["face"] = 1
	kid["x"] += vx * TILE * delta
	_resolve_x()

	# walk off the end of the corridor -> surface
	if kid["x"] > (W - 3) * TILE:
		surface = true
		surface_fade = min(1.0, surface_fade + delta * 0.8)
		if surface_fade >= 1.0:
			_finish()

func _resolve_x() -> void:
	var k = kid
	var x0 := int(k["x"] / TILE)
	var x1 := int((k["x"] + k["w"]) / TILE)
	var y0 := int(k["y"] / TILE)
	var y1 := int((k["y"] + k["h"]) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _is_solid(tx, ty):
				continue
			if k["x"] + k["w"] > tx * TILE and k["x"] < tx * TILE:
				k["x"] = tx * TILE - k["w"]
			elif k["x"] < (tx + 1) * TILE and k["x"] + k["w"] > (tx + 1) * TILE:
				k["x"] = (tx + 1) * TILE

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Game.carry["flag"] = "bunkers-cleared"
	Game.carry["age"] = 13
	Game.save_game()
	Game.scene_change_to("overworld")

func _input(event) -> void:
	# unused; movement reads physical keys (see _just_key)
	pass

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 176), Color("#16100a"))

	# current camera: center on kid, clamped along x
	var cam_x := max(0.0, min(kid["x"] - 320 / 2, W * TILE - 320))

	# corridor walls (only visible stripe)
	for ty in H:
		for tx in W:
			if map[ty][tx] == " ":
				continue
			var px := float(tx * TILE) - cam_x
			if px < -TILE or px > 320:
				continue
			var color := Color("#2c2117")
			if ty == 0:
				color = Color("#241a10")
			elif ty == H - 1:
				color = Color("#2b2013")
			draw_rect(Rect2(px, ty * TILE, TILE, TILE), color)
			if ty == 0:
				continue
			draw_rect(Rect2(px, ty * TILE, TILE, 2), Color("#4a3620") if ty == H - 1 else Color("#3d2c1a"))

	# kid
	Kid.draw(self, kid["x"] - cam_x, kid["y"], kid["face"])

	# hint text
	if hint_timer > 0.0:
		draw_centered("the bunkers are deep and dark...", 160, 32, 7, Color("#9a8c70"))
	if surface:
		draw_centered("you fall, wake at the surface...", 160, 88, 9, Color("#e8c55a"))

	# HUD age
	draw_left("AGE 6", 6, 162, 7, Color("#8a7d63"))

	if fade > 0.0:
		draw_rect(Rect2(0, 0, 320, 176), Color(0.023, 0.015, 0.007, fade))
	if surface_fade > 0.0:
		draw_rect(Rect2(0, 0, 320, 176), Color(0.023, 0.015, 0.007, surface_fade))

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)

func draw_left(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh := cur and not _prev_keys.get(code, false)
	_prev_keys[code] = cur
	return fresh

func _force_draw() -> void:
	_draw()
