# Childhood prologue — the Enclave bunker, top-down 2D room layout.
# (cafeteria → family quarters → unnamed NPC quarters → guarded area → surface)
# Built from loom-generated seamless textures, pxl-generated sprites (20x28),
# chirp-generated audio. Free 2D movement with tile collision.
extends Node2D

const Kid = preload("res://scripts/kid.gd")
const KidState = preload("res://scripts/kid_state.gd")
const NPC = preload("res://scripts/npc.gd")
const WALL_TEX = preload("res://assets/textures/bunker_wall/bunker_wall_albedo.png")
const FLOOR_TEX = preload("res://assets/textures/bunker_floor/bunker_floor_albedo.png")
const FLAME_TEX = preload("res://assets/sprites/anims/flame.png")

const TILE := 16
const W := 44
const H := 28
const WALK := 3.4
const VIEW_W := 320
const VIEW_H := 176
const ZOOM := 1.5
const FL_W := int(VIEW_W / ZOOM)
const FL_H := int(VIEW_H / ZOOM)

const MEMORY_LINES := {
	"cafeteria": "I was a kid in the Enclave. The way out is to the right.",
	"quarters": "Everyone here was a memory by the end.",
	"guarded": "The way out is to the right — and the surface is far.",
}

# furniture solid props — type: table|bed|chest|nightstand|locker|crate|barrel|barrier
const FURNITURE: Array = [
	{"type": "table", "x": 5, "y": 13, "w": 3, "h": 2},
	{"type": "table", "x": 12, "y": 17, "w": 3, "h": 2},
	{"type": "table", "x": 20, "y": 13, "w": 3, "h": 2},
	{"type": "bed", "x": 2, "y": 2, "w": 4, "h": 3},
	{"type": "chest", "x": 18, "y": 2, "w": 2, "h": 2},
	{"type": "nightstand", "x": 14, "y": 6, "w": 2, "h": 2},
	{"type": "bed", "x": 25, "y": 2, "w": 4, "h": 3},
	{"type": "bed", "x": 31, "y": 2, "w": 4, "h": 3},
	{"type": "locker", "x": 40, "y": 2, "w": 2, "h": 2},
	{"type": "table", "x": 29, "y": 6, "w": 2, "h": 2},
	{"type": "crate", "x": 33, "y": 12, "w": 2, "h": 2},
	{"type": "crate", "x": 37, "y": 12, "w": 2, "h": 2},
	{"type": "barrel", "x": 36, "y": 23, "w": 2, "h": 2},
	{"type": "barrier", "x": 41, "y": 11, "w": 2, "h": 3},
	{"type": "barrier", "x": 41, "y": 18, "w": 2, "h": 8},
]

# torches: side "south" = wall face hangs into cafeteria/guarded floor,
# side "north" = wall face hangs into a north-room
const TORCHES: Array = [
	{"x": 5, "y": 10, "side": "south"},
	{"x": 14, "y": 10, "side": "south"},
	{"x": 24, "y": 10, "side": "south"},
	{"x": 10, "y": 27, "side": "north"},
	{"x": 22, "y": 27, "side": "north"},
	{"x": 12, "y": 10, "side": "north"},
	{"x": 35, "y": 10, "side": "north"},
	{"x": 33, "y": 10, "side": "south"},
	{"x": 39, "y": 10, "side": "south"},
]

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
var _room := "cafeteria"

var _npcs: Array[Dictionary] = []
var _talk_index := -1
var _talk_line := 0
var _done_npcs: Array = []

static var _flame_frames: Array = []
static var _filters_set := false
static var _tile_tex: Dictionary = {}
static var _furn_solid: Dictionary = {}

func _ensure_textures() -> void:
	if _filters_set:
		return
	_filters_set = true
	for tex in [WALL_TEX, FLOOR_TEX]:
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		var iw := img.get_width()
		var ih := img.get_height()
		var tiled := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		for y in TILE:
			for x in TILE:
				var sx := int((float(x) + 0.5) * iw / TILE) % iw
				var sy := int((float(y) + 0.5) * ih / TILE) % ih
				tiled.set_pixel(x, y, img.get_pixel(sx, sy))
		_tile_tex[tex.resource_path] = ImageTexture.create_from_image(tiled)

	if _flame_frames.is_empty():
		var imgf: Image = FLAME_TEX.get_image()
		if imgf != null:
			for i in 6:
				var region := imgf.get_region(Rect2i(i * 9, 0, 9, 12))
				_flame_frames.append(ImageTexture.create_from_image(region))

func _ensure_furn_solid() -> void:
	if _furn_solid.is_empty():
		for f in FURNITURE:
			for fy in range(int(f["y"]), int(f["y"]) + int(f["h"])):
				for fx in range(int(f["x"]), int(f["x"]) + int(f["w"])):
					_furn_solid[str(fx) + "," + str(fy)] = true

func _make_npc(feet: Vector2, kind: String, name: String, lines: Array, room_x0: float, room_y0: float, room_x1: float, room_y1: float) -> Dictionary:
	var w := 20.0
	var h := 28.0
	return {
		"kind": kind, "name": name, "lines": lines,
		"w": w, "h": h,
		"x": feet.x - w / 2.0, "y": feet.y - h,
		"facing": "front", "face": 1,
		"state": "idle",
		"timer": randf_range(0.5, 3.5),
		"phase": randf_range(0.0, 6.0),
		"stuck": 0.0,
		"target_x": feet.x, "target_y": feet.y,
		"room_x0": room_x0, "room_y0": room_y0,
		"room_x1": room_x1, "room_y1": room_y1,
	}

func _npc_feet(n: Dictionary) -> Vector2:
	return Vector2(float(n["x"]) + float(n["w"]) / 2.0, float(n["y"]) + float(n["h"]))

func _npc_blocked_by_other(n: Dictionary) -> bool:
	var f := _npc_feet(n)
	for other in _npcs:
		if other == n: continue
		var of := _npc_feet(other)
		var dx: float = of.x - f.x
		var dy: float = of.y - f.y
		if sqrt(dx * dx + dy * dy) < 15.0:
			return true
	return false

func _pick_npc_target(n: Dictionary) -> void:
	var fx: float = float(n["x"]) + float(n["w"]) / 2.0
	var fy: float = float(n["y"]) + float(n["h"])
	for attempt in 8:
		var tx: float = randf_range(float(n["room_x0"]), float(n["room_x1"]))
		var ty: float = randf_range(float(n["room_y0"]), float(n["room_y1"]))
		var d: float = sqrt((tx - fx) * (tx - fx) + (ty - fy) * (ty - fy))
		if d > 14.0:
			n["target_x"] = tx
			n["target_y"] = ty
			n["state"] = "walk"
			return
	# fallback — just idle
	n["state"] = "idle"
	n["timer"] = randf_range(1.0, 3.0)

func _update_npc(n: Dictionary, delta: float) -> void:
	if _talk_index >= 0 and _npcs[_talk_index] == n:
		# frozen mid-conversation, but gets to face the kid (drawn as not-walk)
		n["state"] = "idle"
		return
	var state: String = str(n["state"])
	if state == "idle":
		n["timer"] = float(n["timer"]) - delta
		if float(n["timer"]) <= 0.0:
			if _npc_blocked_by_other(n):
				n["timer"] = randf_range(0.5, 1.5)
				return
			_pick_npc_target(n)
			if str(n["state"]) == "walk":
				n["stuck"] = 0.0
		return
	# state == walk — notice the kid up close and pause to face him
	var kx: float = kid.x + kid.w / 2.0
	var ky: float = kid.y + kid.h / 2.0
	var kdx: float = kx - (float(n["x"]) + float(n["w"]) / 2.0)
	var kdy: float = ky - (float(n["y"]) + float(n["h"]) - 14.0)
	if sqrt(kdx * kdx + kdy * kdy) < 28.0:
		n["state"] = "idle"
		n["timer"] = randf_range(1.0, 2.5)
		n["stuck"] = 0.0
		return
	var feet_x: float = float(n["x"]) + float(n["w"]) / 2.0
	var feet_y: float = float(n["y"]) + float(n["h"])
	var tx: float = float(n["target_x"])
	var ty: float = float(n["target_y"])
	var dx: float = tx - feet_x
	var dy: float = ty - feet_y
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist < 3.5:
		n["state"] = "idle"
		n["timer"] = randf_range(1.0, 4.5)
		return
	var spd: float = WALK * TILE * 0.88 * delta
	var step: float = min(spd, dist)
	var vx: float = dx / dist if dist > 0.001 else 0.0
	var vy: float = dy / dist if dist > 0.001 else 0.0
	var new_x: float = float(n["x"]) + vx * step
	var new_y: float = float(n["y"]) + vy * step
	var corrected := _collide_pos(new_x, new_y, float(n["w"]), float(n["h"]))
	var new_feet_x: float = corrected.x + float(n["w"]) / 2.0
	var new_feet_y: float = corrected.y + float(n["h"])
	var after: float = sqrt((tx - new_feet_x) * (tx - new_feet_x) + (ty - new_feet_y) * (ty - new_feet_y))
	n["x"] = corrected.x
	n["y"] = corrected.y
	# walk phase / facing toward target
	n["phase"] = float(n["phase"]) + delta * 9.0
	if abs(vx) > abs(vy):
		n["facing"] = "side"
		n["face"] = 1 if vx > 0.0 else -1
	else:
		n["facing"] = "back" if vy < 0.0 else "front"
	# stuck if we made no real progress
	if after >= dist * 0.98:
		n["stuck"] = float(n["stuck"]) + delta
		if float(n["stuck"]) > 0.5:
			n["stuck"] = 0.0
			n["state"] = "idle"
			n["timer"] = randf_range(1.0, 3.5)
	else:
		n["stuck"] = 0.0

func _ready() -> void:
	self.scale = Vector2(ZOOM, ZOOM)
	_ensure_textures()
	_ensure_furn_solid()
	kid.x = 2 * TILE
	kid.y = 11 * TILE
	# debug-only: place the kid via --kidpos=x,y (world coords, kid is 20x28)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kidpos="):
			var parts := arg.substr(9).split(",")
			if parts.size() == 2:
				kid.x = clamp(float(parts[0]), 0.0, float(W * TILE - 20))
				kid.y = clamp(float(parts[1]), 0.0, float(H * TILE - 28))
	kid.w = 20
	kid.h = 28
	kid.facing = "front"
	kid.face = 1
	fade = 1.0
	_cam = _target_cam()
	_step_pitch = 0.0
	_npcs = [
		_make_npc(Vector2(9.5 * TILE, 12 * TILE), "kid", "Perry", [
			"You still got the locket?",
			"Our secret. Never tell on us!",
			"...I need to study for my lines.",
		], 3 * TILE, 12.5 * TILE, 28 * TILE, 25.5 * TILE),
		_make_npc(Vector2(8 * TILE, 5.5 * TILE), "mother", "Mumma", [
			"You're supposed to stay home.",
			"The locket is yours. Bring it back.",
			"Don't be like — oh my. You're not a kid.",
		], 2.5 * TILE, 2.5 * TILE, 19.5 * TILE, 8 * TILE),
		_make_npc(Vector2(17 * TILE, 5.5 * TILE), "father", "Pap", [
			"The Enclave lives in the dark. By night.",
			"Don't come looking for it in the bunkers.",
			"Wherever you go, remember the path home.",
		], 11.5 * TILE, 2.5 * TILE, 20.5 * TILE, 8 * TILE),
		_make_npc(Vector2(37.5 * TILE, 15.5 * TILE), "guard", "Enclave guard", [
			"Who are you?",
			"...you came back for something?",
			"The last thing that crosses before dawn...",
			"Leave the way you came. Leave now.",
		], 32.5 * TILE, 12.5 * TILE, 38.5 * TILE, 23.5 * TILE),
	]
	Audio.start_loop("ambience")
	Audio.start_loop("torch_crackle")

func _exit_tree() -> void:
	Audio.stop_loop("torch_crackle")

func debug_advance_dialogue() -> void:
	_advance_dialogue()

func debug_state() -> String:
	var out := "kid.x=%.1f kid.y=%.1f cam=(%.1f,%.1f) talk=%d done=%s | room=%s" % [kid.x, kid.y, _cam.x, _cam.y, _talk_index, str(_done_npcs), _room]
	for i in _npcs.size():
		var n: Dictionary = _npcs[i]
		var d := _npc_feet(n)
		var dx: float = (kid.x + kid.w / 2.0) - d.x
		var dy: float = (kid.y + kid.h / 2.0) - (d.y - 14.0)
		var facing := "front"
		var face := 1
		var dist: float = sqrt(dx * dx + dy * dy)
		if str(n["state"]) == "walk":
			facing = str(n["facing"])
			face = int(n["face"])
		elif dist < 34.0:
			if abs(dy) > abs(dx) * 1.4:
				facing = "back" if dy < 0.0 else "front"
			else:
				facing = "side"
				face = 1 if dx > 0.0 else -1
		out += " | npc%d %s d=(%.0f,%.0f) [%s] facing=%s/%d t=(%.0f,%.0f)" % [i, n["kind"], d.x, d.y, str(n["state"]), facing, face, float(n["target_x"]), float(n["target_y"])]
	return out

func debug_scene_name() -> String:
	return "bunkers"

func debug_teleport_to_end() -> void:
	kid.x = 41.8 * TILE
	kid.y = 15 * TILE - 14

func room_of(px: float, py: float) -> String:
	if py < 9.5 * TILE:
		return "quarters"
	if px < 30.5 * TILE:
		return "cafeteria"
	return "guarded"

func _make_map() -> Array:
	var m: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append("#")
		m.append(row)
	_carve(m, 1, 1, 21, 9)
	_carve(m, 23, 1, 42, 9)
	_carve(m, 1, 11, 29, 26)
	_carve(m, 31, 11, 42, 26)
	# doors
	m[10][7] = " "; m[10][8] = " "
	m[10][32] = " "; m[10][33] = " "
	m[15][30] = " "; m[16][30] = " "; m[17][30] = " "
	return m

func _carve(m: Array, x0: int, y0: int, x1: int, y1: int) -> void:
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			m[ty][tx] = " "

var map: Array = []
func _is_solid(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= W or ty >= H:
		return true
	if map[ty][tx] == "#":
		return true
	if _furn_solid.has(str(tx) + "," + str(ty)):
		return true
	return false

func _memory_line_index() -> String:
	return _room

func _near_npc_index() -> int:
	var kx := kid.x + kid.w / 2.0
	var ky := kid.y + kid.h / 2.0
	for i in _npcs.size():
		if i in _done_npcs:
			continue
		var d := _npc_feet(_npcs[i])
		var dist := Vector2(kx, ky).distance_to(Vector2(d.x, d.y - 14))
		if dist < 26.0:
			return i
	return -1

var map_built := false
func _map() -> Array:
	if not map_built:
		map = _make_map()
		map_built = true
	return map

func _physics_process(delta: float) -> void:
	time += delta
	if fade > 0.0:
		fade = max(0.0, fade - delta * 2.0)
	_map()

	if _just_key(KEY_ESCAPE):
		Game.scene_change_to("title")
		return

	var near := _near_npc_index()
	if near >= 0:
		if _talk_index != near:
			_talk_index = near
			_talk_line = 0
			var d := _npc_feet(_npcs[near])
			var dx: float = d.x - (kid.x + kid.w / 2.0)
			var dy: float = d.y - (kid.y + kid.h / 2.0)
			if abs(dy) > abs(dx) * 1.4:
				kid.facing = "back" if dy < 0.0 else "front"
			else:
				kid.facing = "side"
				kid.face = 1 if dx > 0.0 else -1
			Audio.play_sfx("dialogue_blip", 0.6)
	else:
		if _talk_index != -1:
			_talk_index = -1
		_talk_line = 0
	var talking := _talk_index >= 0

	if talking and (_just_key(KEY_ENTER) or _just_key(KEY_SPACE) or _just_key(KEY_E)):
		_advance_dialogue()

	if not talking and not surface:
		# tap assist
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
			kid.facing = "side"
			kid.face = -1
		if right:
			vx = WALK
			kid.facing = "side"
			kid.face = 1
		if up:
			vy = -WALK
			kid.facing = "back"
		if down:
			vy = WALK
			kid.facing = "front"

		_moving = (vx != 0.0 or vy != 0.0)
		if _moving:
			_walk_phase += delta * 11.0
			if _walk_phase - _step_pitch >= 0.55:
				_step_pitch = _walk_phase
				Audio.play_sfx("walk_step", 0.35)

		kid.x += vx * TILE * delta
		kid.y += vy * TILE * delta
		_resolve_collisions()
		_resolve_npc()
		kid.x = clamp(kid.x, 0.0, float(W * TILE - kid.w))
		kid.y = clamp(kid.y, 0.0, float(H * TILE - kid.h))
	else:
		_moving = false

	# NPCs wander their rooms
	for n in _npcs:
		_update_npc(n, delta)

	# room detection + surface trigger
	var kx := kid.x + kid.w / 2.0
	var ky := kid.y + kid.h / 2.0
	_room = room_of(kx, ky)
	if not surface and kx > 41.5 * TILE and kid.y + kid.h > 13.8 * TILE and kid.y + kid.h < 18.4 * TILE:
		surface = true
		surface_fade = 0.0
	if surface:
		surface_fade = min(1.0, surface_fade + delta * 0.9)
		if surface_fade >= 1.0:
			_finish()

	_cam = _cam.lerp(_target_cam(), min(1.0, delta * 12.0))

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
	var cam_x: float = clamp(kid.x + kid.w / 2.0 - FL_W / 2.0, 0.0, float(W * TILE - FL_W))
	var cam_y: float = clamp(kid.y + kid.h / 2.0 - FL_H / 2.0, 0.0, float(H * TILE - FL_H))
	return Vector2(cam_x, cam_y)

func _resolve_collisions() -> void:
	var p := _collide_pos(kid.x, kid.y, kid.w, kid.h)
	kid.x = p.x
	kid.y = p.y

func _collide_pos(px: float, py: float, pw: float, ph: float) -> Vector2:
	var x := px
	var y := py
	var hit := false
	var x0 := int(x / TILE)
	var x1 := int((x + pw) / TILE)
	var y0 := int(y / TILE)
	var y1 := int((y + ph) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not _is_solid(tx, ty):
				continue
			var left_edge := tx * TILE
			var right_edge := (tx + 1) * TILE
			var mid_x: float = x + pw / 2.0
			if mid_x < (left_edge + right_edge) / 2.0:
				x = left_edge - pw
			else:
				x = right_edge
			hit = true
	if hit:
		x0 = int(x / TILE)
		x1 = int((x + pw) / TILE)
		y0 = int(y / TILE)
		y1 = int((y + ph) / TILE)
		for ty in range(y0, y1 + 1):
			for tx in range(x0, x1 + 1):
				if not _is_solid(tx, ty):
					continue
				var top_edge := ty * TILE
				var bottom_edge := (ty + 1) * TILE
				var mid_y: float = y + ph / 2.0
				if mid_y < (top_edge + bottom_edge) / 2.0:
					y = top_edge - ph
				else:
					y = bottom_edge
	return Vector2(x, y)

func _resolve_npc() -> void:
	var kx := kid.x + kid.w / 2.0
	var ky := kid.y + kid.h / 2.0
	for n in _npcs:
		var d := _npc_feet(n)
		var dx: float = kx - d.x
		var dy: float = ky - (d.y - 14)
		var dist := sqrt(dx * dx + dy * dy)
		var min_dist := 16.0
		if dist < min_dist and dist > 0.001:
			var push := (min_dist - dist) / dist
			kid.x += dx * push
			kid.y += dy * push

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Game.carry["flag"] = "bunkers-cleared"
	Game.carry["age"] = 13
	Game.save_game()
	Game.scene_change_to("overworld")

func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 0x7fffffff

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh: bool = cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh

func _draw() -> void:
	var cam_x := _cam.x
	var cam_y := _cam.y
	var m := _map()

	draw_rect(Rect2(0, 0, FL_W, FL_H), Color("#0d0906"))

	var tx0: int = max(0, int(cam_x / TILE) - 1)
	var ty0: int = max(0, int(cam_y / TILE) - 1)
	var tx1: int = min(W - 1, int((cam_x + FL_W) / TILE) + 1)
	var ty1: int = min(H - 1, int((cam_y + FL_H) / TILE) + 1)

	var floor_tex: Texture2D = _tile_tex.get(FLOOR_TEX.resource_path, null)
	var wall_tex: Texture2D = _tile_tex.get(WALL_TEX.resource_path, null)

	# floor (interior) tiles
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if m[ty][tx] == "#":
				continue
			var px := float(tx * TILE) - cam_x
			var py := float(ty * TILE) - cam_y
			if px < -TILE or px > FL_W or py < -TILE or py > FL_H:
				continue
			if floor_tex != null:
				draw_texture_rect(floor_tex, Rect2(px, py, TILE, TILE), false, Color(0.95, 0.88, 0.76, 1.0))
			else:
				draw_rect(Rect2(px, py, TILE, TILE), Color("#221a10"))

	# walls (solid) + speckles
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if m[ty][tx] != "#":
				continue
			var px := float(tx * TILE) - cam_x
			var py := float(ty * TILE) - cam_y
			if px < -TILE or px > FL_W or py < -TILE or py > FL_H:
				continue
			if wall_tex != null:
				draw_texture_rect(wall_tex, Rect2(px, py, TILE, TILE), false)
			else:
				draw_rect(Rect2(px, py, TILE, TILE), Color("#2b1e12"))
			# depth cue: darken far edge of top-floor-row / near edge of wall
			draw_rect(Rect2(px, py + TILE - 2, TILE, 2), Color(0, 0, 0, 0.45))

	_speckle_floors(cam_x, cam_y, ty0, ty1, tx0, tx1)
	_draw_furniture(cam_x, cam_y)
	_draw_exit_gate(cam_x, cam_y)
	_draw_torches(cam_x, cam_y)

	# shadows + NPCs + kid
	for n in _npcs:
		var d := _npc_feet(n)
		var px: float = d.x - cam_x
		var py: float = d.y - cam_y
		if px < -40 or px > VIEW_W + 40:
			continue
		fill_ellipse(px, py + 1, 14, 3, Color(0, 0, 0, 0.55))
	var kid_px := kid.x - cam_x
	var kid_py := kid.y - cam_y
	fill_ellipse(kid_px + kid.w / 2.0, kid_py + kid.h - 2, 11, 2, Color(0, 0, 0, 0.55))

	for n in _npcs:
		var d := _npc_feet(n)
		var px: float = d.x - cam_x
		var py: float = d.y - cam_y
		if px < -40 or px > VIEW_W + 40:
			continue
		var kx := kid.x + kid.w / 2.0
		var ky := kid.y + kid.h / 2.0
		var dx: float = kx - d.x
		var dy: float = ky - (d.y - 14.0)
		var dist: float = sqrt(dx * dx + dy * dy)
		var npc_facing := "front"
		var npc_face := 1
		var bob := 0
		if str(n["state"]) == "walk":
			npc_facing = str(n["facing"])
			npc_face = int(n["face"])
			bob = int(round(sin(float(n["phase"])) * 1.5))
		elif dist < 34.0:
			if abs(dy) > abs(dx) * 1.4:
				npc_facing = "back" if dy < 0.0 else "front"
			else:
				npc_facing = "side"
				npc_face = 1 if dx > 0.0 else -1
			bob = int(round(sin(time * 2.0 + d.x * 0.13)))
		NPC.draw(self, px - 10.0, py - 28.0, npc_facing, npc_face, str(n["kind"]), bob)

	var bob := 0
	var step := -1
	if _moving:
		bob = int(round(sin(_walk_phase) * 1.0))
		step = int(_walk_phase / PI) % 2
	Kid.draw(self, kid_px, kid_py, kid.facing, kid.face, bob, step)

	# memory band — only when no NPC is talking
	if _talk_index < 0 and not surface:
		draw_rect(Rect2(0, FL_H - 15, FL_W, 15), Color("#140f0a"))
		draw_rect(Rect2(0, FL_H - 15, FL_W, 1), Color("#362718"))
		draw_centered(MEMORY_LINES[_room], FL_W / 2.0, FL_H - 4, 7, Color("#c9b088"))

	# speech bubble above the speaking NPC
	if _talk_index >= 0:
		var n: Dictionary = _npcs[_talk_index]
		var d := _npc_feet(n)
		_draw_bubble(d.x - cam_x, d.y - cam_y, str(n["name"]), str(n["lines"][_talk_line]))

	# age HUD — top left
	draw_left("AGE 6", 6, 11, 7, Color("#9a8352"))

	if surface:
		draw_centered("you fall, wake at the surface...", FL_W / 2.0, FL_H / 2.0 - 6, 9, Color("#c99a44"))

	# vignette — dark edges, Fallout mood
	draw_rect(Rect2(0, 0, FL_W, 6), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, FL_H - 6, FL_W, 6), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, 0, 6, FL_H), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(FL_W - 6, 0, 6, FL_H), Color(0, 0, 0, 0.30))

	if fade > 0.0:
		draw_rect(Rect2(0, 0, FL_W, FL_H), Color(0.023, 0.015, 0.007, fade))
	if surface_fade > 0.0:
		draw_rect(Rect2(0, 0, FL_W, FL_H), Color(0.023, 0.015, 0.007, surface_fade))

func _draw_furniture(cam_x: float, cam_y: float) -> void:
	for f in FURNITURE:
		var px := float(f["x"]) * TILE - cam_x
		var py := float(f["y"]) * TILE - cam_y
		var pw := float(f["w"]) * TILE
		var ph := float(f["h"]) * TILE
		if px + pw < 0 or px > VIEW_W or py + ph < 0 or py > VIEW_H:
			continue
		var t: String = str(f["type"])
		match t:
			"table":
				draw_rect(Rect2(px, py, pw, ph), Color("#4a2f1a"))
				draw_rect(Rect2(px, py, pw, 2), Color("#6b4f2e"))
				draw_rect(Rect2(px, py + ph - 2, pw, 2), Color("#241407"))
				draw_rect(Rect2(px, py, 2, ph), Color("#241407"))
				draw_rect(Rect2(px + pw - 2, py, 2, ph), Color("#241407"))
				draw_rect(Rect2(px + 2, py + ph / 2.0 - 1, pw - 4, 2), Color("#3a2410"))
				# mug speck
				draw_rect(Rect2(px + pw / 2.0 - 2, py + 3, 4, 3), Color("#8a6a24"))
			"bed":
				draw_rect(Rect2(px, py, pw, ph), Color("#33241a"))
				draw_rect(Rect2(px, py, pw, 2), Color("#4d3826"))
				draw_rect(Rect2(px + 2, py + 3, pw - 4, ph - 6), Color("#3a4132"))
				draw_rect(Rect2(px + 2, py + 4, pw - 4, 2), Color("#4a5540"))
				draw_rect(Rect2(px + 3, py + 2, pw - 6, 4), Color("#a89a72"))
			"chest":
				draw_rect(Rect2(px, py, pw, ph), Color("#3a2614"))
				draw_rect(Rect2(px, py, pw, 2), Color("#5c3f22"))
				draw_rect(Rect2(px + 2, py + 2, pw - 4, ph - 4), Color("#2b1c0c"))
				draw_rect(Rect2(px + pw / 2.0 - 2, py + ph / 2.0 - 2, 4, 4), Color("#c9a03a"))
			"nightstand":
				draw_rect(Rect2(px, py, pw, ph), Color("#2e2015"))
				draw_rect(Rect2(px, py, pw, 2), Color("#483a24"))
			"locker":
				draw_rect(Rect2(px, py, pw, ph), Color("#2e3328"))
				draw_rect(Rect2(px, py, pw, 2), Color("#4a5244"))
				draw_rect(Rect2(px + 2, py + 1, pw - 4, 1), Color("#141a12"))
				draw_rect(Rect2(px + 2, py + ph / 2.0, pw - 4, 1), Color("#141a12"))
				draw_rect(Rect2(px + pw / 2.0 - 1, py + 4, 2, 6), Color("#77714a"))
			"crate":
				draw_rect(Rect2(px, py, pw, ph), Color("#33240f"))
				draw_rect(Rect2(px, py, pw, 2), Color("#4e3720"))
				draw_rect(Rect2(px + 2, py + 2, pw - 4, ph - 4), Color("#241a0c"))
				draw_rect(Rect2(px + 3, py + 3, pw - 6, ph - 6), Color("#33241a"))
			"barrel":
				draw_rect(Rect2(px, py, pw, ph), Color("#3a2510"))
				draw_rect(Rect2(px + 2, py, pw - 4, ph), Color("#4e3016"))
				draw_rect(Rect2(px + 1, py + ph / 3.0 - 1, pw - 2, 2), Color("#1c1008"))
				draw_rect(Rect2(px + 1, py + 2 * ph / 3.0 - 1, pw - 2, 2), Color("#1c1008"))
			"barrier":
				draw_rect(Rect2(px, py, pw, ph), Color("#1c1712"))
				draw_rect(Rect2(px, py, pw, 2), Color("#33281c"))
				draw_rect(Rect2(px, py + ph / 2.0 - 1, pw, 2), Color("#33281c"))
				for i in range(int(f["w"])):
					var lx := px + (i + 1) * TILE - 1
					draw_rect(Rect2(lx, py, 2, ph), Color("#0e0a05"))

func _draw_exit_gate(cam_x: float, cam_y: float) -> void:
	var px := float(43 * TILE) - cam_x
	var py := float(14 * TILE) - cam_y
	var rw := float(TILE)
	var rh := float(4 * TILE)
	if px + rw < 0 or px > VIEW_W:
		return
	# stone frame around the dark doorway
	draw_rect(Rect2(px - 3, py - 3, rw + 6, rh + 6), Color("#1a130c"))
	draw_rect(Rect2(px - 3, py - 3, rw + 6, 3), Color("#4d3826"))
	draw_rect(Rect2(px - 3, py + rh, rw + 6, 3), Color("#4d3826"))
	draw_rect(Rect2(px - 3, py - 3, 3, rh + 6), Color("#4d3826"))
	draw_rect(Rect2(px + rw, py - 3, 3, rh + 6), Color("#4d3826"))
	# dark opening + warm light glow from the threshold
	draw_rect(Rect2(px, py, rw, rh), Color("#070503"))
	draw_rect(Rect2(px + 1, py + 1, rw - 2, rh - 2), Color("#0d0a06"))
	var flicker := sin(time * 6.0) * 0.5 + 0.5
	draw_rect(Rect2(px + 1, py + 1, rw - 2, rh - 2), Color(0.95, 0.55, 0.14, 0.10 + flicker * 0.06))
	draw_rect(Rect2(px + 1, py + 1, rw - 2, rh - 2), Color(0.55, 0.75, 0.45, 0.04))

func _draw_torches(cam_x: float, cam_y: float) -> void:
	for i in TORCHES.size():
		var t: Dictionary = TORCHES[i]
		var tx := int(t["x"])
		var twow := tx * TILE + 3 - cam_x
		var flicker := sin(time * 9.0 + i * 2.2) * 1.5
		var glow_y := 0.0
		var flame_y := 0.0
		if str(t["side"]) == "south":
			# sconce on the bottom edge of a north-facing wall, flame hanging down
			glow_y = float(t["y"]) * TILE + TILE - 1 - cam_y
			flame_y = glow_y - 2
		elif str(t["side"]) == "north":
			# sconce on the top edge of a south-facing wall (cafeteria south wall)
			# or on the top edge of a north-room's south wall — flame rises into the room
			glow_y = float(t["y"]) * TILE + 2 - cam_y
			flame_y = glow_y - 4
		var glow_x := twow + 4
		draw_circle(Vector2(glow_x, glow_y), 46 + flicker, Color(0.85, 0.35, 0.10, 0.19))
		draw_circle(Vector2(glow_x, glow_y), 21 + flicker * 0.5, Color(0.95, 0.45, 0.12, 0.28))
		if not _flame_frames.is_empty():
			var fi := int(time * 10.0 + i * 1.7) % _flame_frames.size()
			if fi >= 0 and fi < _flame_frames.size():
				draw_texture_rect(_flame_frames[fi], Rect2(twow - 2, flame_y - 12, 14, 18), false)

func _speckle_floors(cam_x: float, cam_y: float, ty0: int, ty1: int, tx0: int, tx1: int) -> void:
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if map[ty][tx] == "#":
				continue
			var px := float(tx * TILE) - cam_x
			var py := float(ty * TILE) - cam_y
			var seed := tx * 131 + ty * 17
			for i in 3:
				var hx := _hash(seed + i, 1) % 13
				var hy := _hash(seed + i, 2) % 13
				var dark := _hash(seed + i, 3) % 2 == 0
				var col: Color
				if dark:
					col = Color(0.06, 0.04, 0.02, 0.55)
				else:
					col = Color(0.30, 0.22, 0.12, 0.35)
				draw_rect(Rect2(px + 1.5 + float(hx), py + 1.5 + float(hy), 2.0, 1.0), col)

func _draw_bubble(nx: float, ny: float, name: String, text: String) -> void:
	var bw: float = min(FL_W - 12.0, 230.0)
	var bh := 40.0
	var bx := float(clamp(nx - bw / 2.0, 4.0, FL_W - bw - 4.0))
	var by := float(clamp(ny - 28.0 - bh - 10.0, 4.0, FL_H - bh - 4.0))
	draw_rect(Rect2(bx, by, bw, bh), Color("#100b07"))
	draw_rect(Rect2(bx, by, bw, 1), Color("#c99a44"))
	draw_rect(Rect2(bx, by + bh - 1, bw, 1), Color("#c99a44"))
	draw_rect(Rect2(bx, by, 1, bh), Color("#c99a44"))
	draw_rect(Rect2(bx + bw - 1, by, 1, bh), Color("#c99a44"))
	draw_centered(name, bx + bw / 2.0, by + 11, 6, Color("#b8935a"))
	draw_centered(text, bx + bw / 2.0, by + 27, 7, Color("#dcc394"))
	var tail_x := float(clamp(nx, bx + 16.0, bx + bw - 16.0))
	draw_rect(Rect2(tail_x - 2, by + bh, 4, 4), Color("#100b07"))
	draw_rect(Rect2(tail_x - 2, by + bh, 4, 1), Color("#c99a44"))

func fill_ellipse(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for dy in range(-int(ry), int(ry) + 1):
		var w := int(rx * sqrt(max(0.0, 1.0 - float(dy * dy) / (ry * ry))))
		draw_rect(Rect2(float(cx) - w, float(cy) + dy, w * 2, 1), col)

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_left(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
