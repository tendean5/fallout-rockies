# Childhood prologue — the Enclave bunker, walked like a childhood town.
# Side-view platform corridor built from loom-generated seamless textures,
# pxl-generated sprites (kid + childhood cast + torch), chirp-generated audio.
extends Node2D

const WorldMap = preload("res://scripts/world_map.gd")
const Kid = preload("res://scripts/kid.gd")
const KidState = preload("res://scripts/kid_state.gd")
const NPC = preload("res://scripts/npc.gd")
const WALL_TEX = preload("res://assets/textures/bunker_wall/bunker_wall_albedo.png")
const FLOOR_TEX = preload("res://assets/textures/bunker_floor/bunker_floor_albedo.png")
const PILLAR_TEX = preload("res://assets/textures/bunker_pillar/bunker_pillar_albedo.png")
const FLAME_TEX = preload("res://assets/sprites/anims/flame.png")
const BRACKET_TEX = preload("res://assets/sprites/sprites/torch_bracket.png")

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
var _step_pitch := 0.0

var _npcs: Array[Dictionary] = []
var _talk_index := -1
var _talk_line := 0
var _done_npcs: Array = []

static var _flame_frames: Array = []
static var _filters_set := false

static var _tile_tex: Dictionary = {}

func _ensure_textures() -> void:
	if _filters_set:
		return
	_filters_set = true

	# pre-downscale loom albedo textures to tile size once (crisp + cheap)
	for tex in [WALL_TEX, FLOOR_TEX, PILLAR_TEX]:
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		var iw: int = img.get_width()
		var ih: int = img.get_height()
		var tiled := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		for y in TILE:
			for x in TILE:
				var sx := int((float(x) + 0.5) * iw / TILE) % iw
				var sy := int((float(y) + 0.5) * ih / TILE) % ih
				tiled.set_pixel(x, y, img.get_pixel(sx, sy))
		_tile_tex[tex.resource_path] = ImageTexture.create_from_image(tiled)

	if _flame_frames.is_empty():
		var img: Image = FLAME_TEX.get_image()
		if img != null:
			for i in 6:
				var region := img.get_region(Rect2i(i * 9, 0, 9, 12))
				var t := ImageTexture.create_from_image(region)
				_flame_frames.append(t)

func _ready() -> void:
	_ensure_textures()
	map = _make_map()
	kid.x = 3 * TILE
	kid.y = (H - 1) * TILE - 13
	kid.w = 11
	kid.h = 13
	kid.face = 1
	fade = 1.0
	_cam = _target_cam()
	_step_pitch = 0.0
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
	Audio.start_loop("ambience")
	Audio.start_loop("torch_crackle")

func _exit_tree() -> void:
	Audio.stop_loop("torch_crackle")

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
			Audio.play_sfx("dialogue_blip", 0.6)
	else:
		if _talk_index != -1:
			_talk_index = -1
		_talk_line = 0
	var talking := _talk_index >= 0

	if talking and (_just_key(KEY_ENTER) or _just_key(KEY_SPACE) or _just_key(KEY_E)):
		_advance_dialogue()

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
		var n: Dictionary = _npcs[_talk_index]
		if kid.x + kid.w > float(n["x"]) - 10.0:
			kid.x = float(n["x"]) - 10.0 - kid.w
		vx = 0.0

	_moving = (vx != 0.0)
	if _moving:
		_walk_phase += delta * 11.0
		if _walk_phase - _step_pitch >= 0.55:
			_step_pitch = _walk_phase
			Audio.play_sfx("walk_step", 0.35)
	kid.x += vx * TILE * delta
	_resolve_x()

	_cam = _cam.lerp(_target_cam(), min(1.0, delta * 12.0))

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
	Audio.play_sfx("dialogue_blip", 0.6)
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

	# interior void tiles -> dark wall texture (corridor room), pillars get pillar texture
	for ty in range(1, H - 1):
		for tx in range(1, W - 1):
			var px: float = float(tx * TILE) - cam_x
			if px < -TILE or px > VIEW_W:
				continue
			var py := ty * TILE
			var tiled: Texture2D = _tile_tex.get(WALL_TEX.resource_path, null)
			if tiled != null:
				draw_texture_rect(tiled, Rect2(px, py, TILE, TILE), false, Color(0.68, 0.62, 0.55, 1.0))

	# textured walls / floor / pillars (only the stripe on screen)
	for ty in H:
		for tx in W:
			if map[ty][tx] == " ":
				continue
			var px: float = float(tx * TILE) - cam_x
			if px < -TILE or px > VIEW_W:
				continue
			var py := ty * TILE
			var tex: Texture2D = null
			if ty == 0:
				tex = WALL_TEX
			elif ty == H - 1:
				tex = FLOOR_TEX
			else:
				tex = PILLAR_TEX
			var tiled: Texture2D = _tile_tex.get(tex.resource_path, null) if tex != null else null
			draw_rect(Rect2(px, py, TILE, TILE), Color("#0e0906"))
			if tiled != null:
				draw_texture_rect(tiled, Rect2(px, py, TILE, TILE), false)
			# darken the far edge of the top row / near edge of the floor — depth cue
			if ty == 0:
				draw_rect(Rect2(px, py, TILE, 3), Color(0, 0, 0, 0.45))
				draw_rect(Rect2(px, py + TILE - 1, TILE, 1), Color(0, 0, 0, 0.35))
			elif ty == H - 1:
				draw_rect(Rect2(px, py, TILE, 2), Color(0.35, 0.26, 0.13, 0.35))
				draw_rect(Rect2(px, py + TILE - 1, TILE, 1), Color(0, 0, 0, 0.5))
			else:
				draw_rect(Rect2(px, py, TILE, 2), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(px, py + TILE - 2, TILE, 2), Color(0, 0, 0, 0.5))

	# torches — wall sconces with a generated flame anim, warm glow
	for i in range(4):
		var tx := 6 + i * 7
		var px: float = float(tx * TILE + 6) - cam_x
		if px < -40 or px > VIEW_W + 40:
			continue
		var flicker: float = sin(time * 9.0 + i * 2.2) * 1.5
		draw_circle(Vector2(px + 2, 16), 42 + flicker, Color(0.85, 0.35, 0.10, 0.16))
		draw_circle(Vector2(px + 2, 16), 20 + flicker * 0.6, Color(0.95, 0.45, 0.12, 0.24))
		draw_texture_rect(BRACKET_TEX, Rect2(px - 2, 12, 9, 7), false)
		var fi := int(time * 10.0 + i * 1.7) % _flame_frames.size()
		if fi >= 0 and fi < _flame_frames.size():
			draw_texture_rect(_flame_frames[fi], Rect2(px - 1, 2, 9, 12), false)

	# speckle/grime dither over solid tiles — the Fallout 1 grain
	_speckle_tiles(cam_x)

	# NPCs — childhood cast, same walk-right layout
	for n in _npcs:
		var nx: float = float(n["x"]) - cam_x
		if nx < -40 or nx > VIEW_W + 40:
			continue
		var sway := int(round(sin(time * 2.0 + float(n["x"])) * 1.0))
		var face := 1 if kid.x + kid.w / 2.0 > float(n["x"]) else -1
		NPC.draw(self, nx - 5.5, kid.y, face, n["kind"], sway)

	# kid (locket baked into the sprite)
	var bob := 0
	var step := -1
	if _moving:
		bob = int(round(sin(_walk_phase) * 1.0))
		step = int(_walk_phase / PI) % 2
	Kid.draw(self, kid.x - cam_x, kid.y, kid.face, bob, step)

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
	var tail_x := float(clamp(nx, bx + 16.0, bx + bw - 16.0))
	draw_rect(Rect2(tail_x - 2, by + bh, 4, 4), Color("#100b07"))
	draw_rect(Rect2(tail_x - 2, by + bh, 4, 1), Color("#c99a44"))

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
