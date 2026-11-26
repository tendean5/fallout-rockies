# Childhood prologue — the Enclave bunker, walked like childhood town.
# A side-view platform corridor, not a top-down overworld. NPCs grown
# childhood towns: friend, parents, and a guard who casts the kid out.
extends Node2D

const WorldMap = preload("res://scripts/world_map.gd")
const Kid = preload("res://scripts/kid.gd")
const KidState = preload("res://scripts/kid_state.gd")
const NPC = preload("res://scripts/npc.gd")

const TILE := WorldMap.TILE
const W := 40
const H := 11
const WALK := 3.1
const VIEW_W := 320
const VIEW_H := 176

const MEMORY_LINES := [
	"I was a kid in the Enclave. The way out is to the right.",
	"Everyone here was a memory by the end.",
	"The way out is to the right — and the surface is far.",
]

var map: Array = []
var kid := KidState.new()
var time := 0.0
var fade := 1.0
var surface := false
var surface_fade := 0.0
var _prev_keys: Dictionary = {}
var _finished := false
var _moving := false
var _walk_phase := 0.0
var _cam := Vector2(0, 0)

var _npcs: Array[Dictionary] = []
var _talk_index := -1
var _talk_line := 0
var _done_npcs: Array = []

func _ready() -> void:
	map = _make_map()
	kid.x = 3 * TILE
	kid.y = (H - 1) * TILE - 13
	kid.w = 11
	kid.h = 13
	kid.face = 1
	fade = 1.0
	_cam = _target_cam()
	_npcs = [
		{"x": 7 * TILE, "kind": "kid", "name": "Perry", "lines": [
			"Perry: You still got the locket?",
			"Perry: Our secret. Never tell on us!",
			"Perry: ...I need to study for my lines.",
		]},
		{"x": 14 * TILE, "kind": "mother", "name": "Mumma", "lines": [
			"Mumma: You're supposed to stay home.",
			"Mumma: The locket is yours. Bring it back.",
			"Mumma: Don't be like — oh my. You're not a kid.",
		]},
		{"x": 17 * TILE, "kind": "father", "name": "Pap", "lines": [
			"Pap: The Enclave lives in the dark. By night.",
			"Pap: Don't come looking for it in the bunkers.",
			"Pap: Wherever you go, remember the path home.",
		]},
		{"x": 28 * TILE, "kind": "guard", "name": "Enclave guard", "lines": [
			"Guard: Who are you?",
			"Guard: ...you came back for something?",
			"Guard: The last thing that crosses before dawn...",
			"Guard: Leave the way you came. Leave now.",
		]},
	]

func debug_advance_dialogue() -> void:
	_advance_dialogue()

func debug_state() -> String:
	var out := "kid.x=%.1f kid.y=%.1f cam=%.1f talk=%d done=%s" % [kid.x, kid.y, _cam.x, _talk_index, str(_done_npcs)]
	for i in _npcs.size():
		var n: Dictionary = _npcs[i]
		out += " | npc%d %s x=%d nx=%.1f" % [i, n["kind"], int(n["x"]), float(n["x"]) - _cam.x]
	return out

func debug_scene_name() -> String:
	return "bunkers"

func debug_teleport_to_end() -> void:
	kid.x = (W - 2) * TILE

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

func _memory_line_index() -> int:
	var x := kid.x
	if x < 7 * TILE:
		return 0
	elif x < 24 * TILE:
		return 1
	return 2

func _near_npc_index() -> int:
	var kid_cx := kid.x + kid.w / 2.0
	for i in _npcs.size():
		if i in _done_npcs:
			continue
		var n := _npcs[i]
		if abs(kid_cx - float(n["x"])) < 26.0:
			return i
	return -1

func _physics_process(delta: float) -> void:
	time += delta
	if fade > 0.0:
		fade = max(0.0, fade - delta * 2.0)

	if _just_key(KEY_ESCAPE):
		Game.scene_change_to("title")
		return

	var near := _near_npc_index()
	if near >= 0:
		if _talk_index != near:
			_talk_index = near
			_talk_line = 0
			kid.face = 1 if float(_npcs[near]["x"]) > kid.x + kid.w / 2.0 else -1
	else:
		_talk_index = -1
		_talk_line = 0
	var talking := _talk_index >= 0

	# advance the dialogue
	if talking and (_just_key(KEY_ENTER) or _just_key(KEY_SPACE) or _just_key(KEY_E)):
		_advance_dialogue()

	# tap assist (one nudge per fresh tap)
	if not talking:
		if _just_key(KEY_RIGHT) or _just_key(KEY_D):
			kid.x += 3.2
		if _just_key(KEY_LEFT) or _just_key(KEY_A):
			kid.x -= 3.2

	var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Game.virtual_left
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Game.virtual_right
	var vx := 0.0
	if left:
		vx = -WALK
		kid.face = -1
	if right:
		vx = WALK
		kid.face = 1

	if talking:
		# pin the kid against the NPC — no walking past mid-conversation
		var n: Dictionary = _npcs[_talk_index]
		if kid.x + kid.w > float(n["x"]) - 10.0:
			kid.x = float(n["x"]) - 10.0 - kid.w
		vx = 0.0

	_moving = (vx != 0.0)
	if _moving:
		_walk_phase += delta * 11.0
	kid.x += vx * TILE * delta
	_resolve_x()

	_cam = _cam.lerp(_target_cam(), min(1.0, delta * 12.0))

	# walk off the end of the corridor -> surface
	if kid.x > (W - 3) * TILE:
		surface = true
		surface_fade = min(1.0, surface_fade + delta * 0.8)
		if surface_fade >= 1.0:
			_finish()
	queue_redraw()

func _advance_dialogue() -> void:
	if _talk_index < 0:
		return
	_talk_line += 1
	if _talk_line >= _npcs[_talk_index]["lines"].size():
		_done_npcs.append(_talk_index)
		_talk_index = -1
		_talk_line = 0

func _target_cam() -> Vector2:
	var cam_x: float = clamp(kid.x - VIEW_W / 2.0, 0.0, float(W * TILE - VIEW_W))
	return Vector2(cam_x, 0.0)

func _resolve_x() -> void:
	var k = kid
	var x0 := int(k.x / TILE)
	var x1 := int((k.x + k.w) / TILE)
	var y0 := int(k.y / TILE)
	var y1 := int((k.y + k.h) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _is_solid(tx, ty):
				continue
			if k.x + k.w > tx * TILE and k.x < tx * TILE:
				k.x = tx * TILE - k.w
			elif k.x < (tx + 1) * TILE and k.x + k.w > (tx + 1) * TILE:
				k.x = (tx + 1) * TILE

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Game.carry["flag"] = "bunkers-cleared"
	Game.carry["age"] = 13
	Game.save_game()
	Game.scene_change_to("overworld")

func _draw() -> void:
	var cam_x := _cam.x

	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color("#0d0906"))

	# corridor walls/pillars (only the stripe on screen)
	for ty in H:
		for tx in W:
			if map[ty][tx] == " ":
				continue
			var px: float = float(tx * TILE) - cam_x
			if px < -TILE or px > VIEW_W:
				continue
			var py := ty * TILE
			if ty == 0:
				draw_rect(Rect2(px, py, TILE, TILE), Color("#2b2114"))
				draw_rect(Rect2(px, py + TILE - 2, TILE, 2), Color("#1c140c"))
				draw_rect(Rect2(px, py, 1, 3), Color("#17100a"))
			elif ty == H - 1:
				draw_rect(Rect2(px, py, TILE, TILE), Color("#2a1e12"))
				draw_rect(Rect2(px, py, TILE, 2), Color("#3b2a17"))
				if tx % 2 == 0:
					draw_rect(Rect2(px, py + 4, 1, 10), Color("#1a110a"))
				if (tx * 7 + ty) % 5 == 0:
					draw_rect(Rect2(px + 4 + (tx % 3), py + 8, 4, 1), Color("#0e0906"))
			elif map[ty][tx] == "#":
				draw_rect(Rect2(px, py, TILE, TILE), Color("#33241a"))
				draw_rect(Rect2(px, py, 2, TILE), Color("#241a10"))
				draw_rect(Rect2(px + TILE - 2, py, 2, TILE), Color("#50382c"))
				draw_rect(Rect2(px, py, TILE, 3), Color("#4a3620"))

	# torches — wall-mounted sconces, warm flicker + glow
	for i in range(4):
		var tx := 6 + i * 7
		var px: float = float(tx * TILE + 6) - cam_x
		if px < -40 or px > VIEW_W + 40:
			continue
		var flicker: float = sin(time * 9.0 + i * 2.2) * 1.5
		draw_circle(Vector2(px + 1, 25), 28 + flicker, Color(0.85, 0.35, 0.10, 0.08))
		draw_circle(Vector2(px + 1, 25), 16 + flicker * 0.6, Color(0.95, 0.45, 0.12, 0.12))
		draw_rect(Rect2(px - 2, 14, 7, 3), Color("#241a10"))
		draw_rect(Rect2(px - 1, 18 + flicker * 0.5, 4, 9 + flicker), Color(0.98, 0.62, 0.16, 0.95))
		draw_rect(Rect2(px, 22 + flicker, 2, 5), Color(0.99, 0.83, 0.33, 0.95))

	# speckle/grime dither over solid tiles — the Fallout 1 grain
	_speckle_tiles(cam_x)

	# NPCs — same walk-right layout, same palette, childhood town
	for n in _npcs:
		var nx: float = float(n["x"]) - cam_x
		if nx < -40 or nx > VIEW_W + 40:
			continue
		var sway := int(round(sin(time * 2.0 + float(n["x"])) * 1.0))
		var face := 1 if kid.x + kid.w / 2.0 > float(n["x"]) else -1
		NPC.draw(self, nx - 5.5, kid.y, face, n["kind"], sway)

	# kid + locket charm
	var bob := 0
	var step := -1
	if _moving:
		bob = int(round(sin(_walk_phase) * 1.0))
		step = int(_walk_phase / PI) % 2
	Kid.draw(self, kid.x - cam_x, kid.y, kid.face, bob, step)
	# locket on the jacket — the one thing carried out
	draw_rect(Rect2(kid.x - cam_x + 4, kid.y + 6, 3, 4), Color("#d19a45"))
	draw_rect(Rect2(kid.x - cam_x + 5, kid.y + 8, 1, 2), Color("#e8d5a0"))

	# childhood memory band — only when no NPC is talking
	if _talk_index < 0 and not surface:
		draw_rect(Rect2(0, VIEW_H - 15, VIEW_W, 15), Color("#140f0a"))
		draw_rect(Rect2(0, VIEW_H - 15, VIEW_W, 1), Color("#362718"))
		draw_centered(MEMORY_LINES[_memory_line_index()], VIEW_W / 2, VIEW_H - 4, 7, Color("#c9b088"))

	# speech bubble over the speaking NPC
	if _talk_index >= 0:
		var n: Dictionary = _npcs[_talk_index]
		var name: String = str(n["name"])
		var text: String = str(n["lines"][_talk_line])
		_draw_bubble(float(n["x"]) - cam_x, kid.y, name, text)

	# age HUD — top left
	draw_left("AGE 6", 6, 11, 7, Color("#9a8352"))

	if surface:
		draw_centered("you fall, wake at the surface...", VIEW_W / 2, VIEW_H / 2 - 6, 9, Color("#c99a44"))

	if fade > 0.0:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.023, 0.015, 0.007, fade))
	if surface_fade > 0.0:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.023, 0.015, 0.007, surface_fade))

func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 0x7fffffff

func _speckle_tiles(cam_x: float) -> void:
	for ty in H:
		for tx in W:
			if map[ty][tx] == " ":
				continue
			var px: float = float(tx * TILE) - cam_x
			if px < -TILE or px > VIEW_W:
				continue
			var py := ty * TILE
			var seed := tx * 131 + ty * 17
			# per-tile speckles — dark grime dots + pale highlights, deterministic
			for i in 4:
				var hx := _hash(seed + i, 1) % 13
				var hy := _hash(seed + i, 2) % 13
				var dark := _hash(seed + i, 3) % 2 == 0
				var col: Color
				if ty == 0:
					col = Color(0.10, 0.06, 0.04, 0.55) if dark else Color(0.32, 0.23, 0.12, 0.40)
				elif ty == H - 1:
					col = Color(0.05, 0.03, 0.02, 0.60) if dark else Color(0.30, 0.22, 0.12, 0.40)
				else:
					col = Color(0.08, 0.05, 0.03, 0.55) if dark else Color(0.33, 0.24, 0.13, 0.42)
				draw_rect(Rect2(px + 1.5 + float(hx), py + 1.5 + float(hy), 2.0, 1.0), col)

func _draw_bubble(nx: float, ny: float, name: String, text: String) -> void:
	var bw := 276.0
	var bh := 42.0
	var bx := float(clamp(nx - bw / 2.0, 4.0, VIEW_W - bw - 4.0))
	var by := float(clamp(ny - 66.0, 4.0, VIEW_H - bh - 4.0))
	draw_rect(Rect2(bx, by, bw, bh), Color("#100b07"))
	draw_rect(Rect2(bx, by, bw, 1), Color("#c99a44"))
	draw_rect(Rect2(bx, by + bh - 1, bw, 1), Color("#c99a44"))
	draw_rect(Rect2(bx, by, 1, bh), Color("#c99a44"))
	draw_rect(Rect2(bx + bw - 1, by, 1, bh), Color("#c99a44"))
	draw_centered(name, bx + bw / 2.0, by + 11, 6, Color("#b8935a"))
	draw_centered(text, bx + bw / 2.0, by + 29, 7, Color("#dcc394"))
	# tail — small diamond toward the NPC
	var tail_x := float(clamp(nx, bx + 16.0, bx + bw - 16.0))
	draw_rect(Rect2(tail_x - 2, by + bh, 4, 4), Color("#100b07"))

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_left(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh: bool = cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh
