# Battle — gen-3 grammar, Fallout flavor. Intro → choose → resolve → return/lost.
extends Node2D
const Data = preload("res://scripts/battle_data.gd")
const Kid = preload("res://scripts/kid.gd")
const VIEW_W := 320
const VIEW_H := 176
const MENU_LABELS := ["ATTACK", "ITEMS", "HOLD", "RUN"]
var time := 0.0
var zone := "Denver Ruins"
var palette := {}
var kid := {}
var enemy := {}
var state := "intro"
var _timer := 0.5
var _sel := 0
var _hover := -1
var _chosen := 0
var _resolve_elapsed := 0.0
var _resolved_kid := false
var _resolved_enemy := false
var _escaped := false
var _kid_lunge := 0.0
var _enemy_lunge := 0.0
var _forced_hit := false
var _pending_attack := false
var _mouse_prev := false
var _prev_keys := {}
var log_lines: Array = []
var popups: Array = []

func _ready() -> void:
	Audio.stop_loop("ambience")
	Audio.start_loop("ambience")
	var ctx = Game.battle_context if Game.battle_context != null else {}
	zone = str(ctx.get("region", "Denver Ruins"))
	palette = Data.zone_palette(zone)
	kid = Game.kid.duplicate(true) if Game.kid != null and typeof(Game.kid) == TYPE_DICTIONARY and Game.kid.has("current_hp") else Data.starting_kid()
	var enemy_id = str(ctx.get("enemy_id", Data.pick_species(zone)))
	enemy = Data.enemy_for(enemy_id, int(kid.get("level", 1)))
	_timer = 0.5
	_add_log("A wild " + enemy["name"] + " appeared!")

func debug_scene_name() -> String: return "battle"
func debug_state() -> String:
	return "battle state=%s enemy=%s hp=%d/%d kid=%d/%d" % [state, enemy["name"], enemy["hp"], enemy["max_hp"], kid["current_hp"], kid["max_hp"]]
func debug_kill_enemy() -> void: enemy["hp"] = 1
func debug_force_attack() -> void:
	_forced_hit = true
	_pending_attack = true

func _enter_choose() -> void:
	state = "choose"
	if _pending_attack:
		_pending_attack = false
		_confirm(0)

func _confirm(cmd: int) -> void:
	if state != "choose": return
	_chosen = cmd
	state = "resolve"
	_resolve_elapsed = 0.0
	_resolved_kid = false
	_resolved_enemy = false
	_escaped = false

func _add_log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 3: log_lines.pop_front()

func _popup(text: String, x: float, y: float, color: Color, ttl := 0.8) -> void:
	popups.append({"text": text, "x": x, "y": y, "color": color, "ttl": ttl, "max": ttl})

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh := cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh

func _physics_process(delta: float) -> void:
	time += delta
	_kid_lunge = max(0.0, _kid_lunge - delta)
	_enemy_lunge = max(0.0, _enemy_lunge - delta)
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["ttl"] -= delta
		popups[i]["y"] -= 14.0 * delta
		if popups[i]["ttl"] <= 0.0: popups.remove_at(i)
	match state:
		"intro":
			_timer -= delta
			if _timer <= 0.0: _enter_choose()
		"choose":
			_handle_choice_input()
		"resolve":
			_handle_resolve(delta)
		"return":
			_timer -= delta
			if _timer <= 0.0: _return_to_overworld()
		"lost":
			_timer -= delta
			if _timer <= 0.0: _confirm_death()
	queue_redraw()


func _handle_choice_input() -> void:
	if _just_key(KEY_UP) or _just_key(KEY_W):
		_sel = (_sel + MENU_LABELS.size() - 1) % MENU_LABELS.size()
	elif _just_key(KEY_DOWN) or _just_key(KEY_S):
		_sel = (_sel + 1) % MENU_LABELS.size()
	if _just_key(KEY_ENTER) or _just_key(KEY_SPACE):
		_confirm(_sel)
	elif _just_key(KEY_ESCAPE):
		_confirm(3)
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var m := get_viewport().get_mouse_position()
	_hover = -1
	for i in MENU_LABELS.size():
		var ry = 110 + i * 14
		if m.x >= 198 and m.x <= 314 and m.y >= ry and m.y < ry + 13:
			_hover = i
	if left and not _mouse_prev:
		if _hover >= 0:
			_sel = _hover
			_confirm(_hover)
	_mouse_prev = left

func _handle_resolve(delta: float) -> void:
	_resolve_elapsed += delta
	if not _resolved_kid and _resolve_elapsed >= 0.18:
		_resolved_kid = true
		_apply_kid_effect()
	if not _resolved_enemy and _resolve_elapsed >= 0.58 and enemy["hp"] > 0 and not _escaped:
		_resolved_enemy = true
		_apply_enemy_effect()
	if _resolve_elapsed >= 0.85:
		_finish_resolve()

func _finish_resolve() -> void:
	kid["hold"] = false
	if _escaped:
		_enter_return()
		return
	if enemy["hp"] <= 0:
		_add_log("Enemy defeated!")
		_enter_return()
		return
	if kid["current_hp"] <= 0:
		state = "lost"
		_timer = 1.35
		return
	state = "choose"

func _apply_kid_effect() -> void:
	match _chosen:
		0:
			var w: Dictionary = Data.weapons()[kid["active_weapon"]]
			_add_log("Kid uses " + w["name"] + "!")
			_kid_lunge = 0.35
			var rg := randi() / 2147483647.0
			var hit: bool = _forced_hit or rg < w["accuracy"]
			_forced_hit = false
			if hit:
				var lv: float = float(kid["level"]) / max(1.0, float(enemy["level"]))
				var base: float = float(w["power"]) * (0.7 + 0.3 * lv)
				var mult: float = Data.type_mult(w["type"], enemy)
				var crit := randi() % 100 < 8
				var dmg := int(base * mult * (1.5 if crit else 1.0))
				dmg = max(1, dmg)
				enemy["hp"] = max(0, enemy["hp"] - dmg)
				_popup(("CRIT " if crit else "") + str(dmg), 100.0, 30.0, Color("#ffd94d"))
				_add_log(str(dmg) + " damage" + (" — critical!" if crit else "!"))
			else:
				_add_log("Miss!")
		1:
			var item := ""
			if int(kid["items"].get("stim", 0)) > 0: item = "stim"
			elif int(kid["items"].get("medkit", 0)) > 0: item = "medkit"
			if item != "":
				kid["items"][item] = int(kid["items"][item]) - 1
				var heal: int = Data.items()[item]["heal"]
				kid["current_hp"] = min(kid["max_hp"], kid["current_hp"] + heal)
				_popup("+" + str(heal), 40.0, 60.0, Color("#7de08a"))
				_add_log("Kid uses " + Data.items()[item]["name"] + " — +" + str(heal) + " HP!")
			else:
				_add_log("No items left!")
		2:
			kid["hold"] = true
			_add_log("Kid holds steady!")
		3:
			_add_log("Kid tries to escape!")
			if randi() / 2147483647.0 < 0.6:
				_escaped = true
				_add_log("Kid got away!")
			else:
				_add_log("Can't escape!")

func _apply_enemy_effect() -> void:
	if enemy["hp"] <= 0: return
	_add_log(enemy["name"] + " attacks!")
	_enemy_lunge = 0.35
	var rg := randi() / 2147483647.0
	if rg < enemy["accuracy"]:
		var lv: float = float(enemy["level"]) / max(1.0, float(kid["level"]))
		var dmg: int = int(float(enemy["power"]) * (0.7 + 0.3 * lv))
		if kid["hold"]:
			dmg = int(dmg * 0.5)
			kid["hold"] = false
		dmg = max(1, dmg)
		kid["current_hp"] = max(0, kid["current_hp"] - dmg)
		_popup("-" + str(dmg), 34.0, 62.0, Color("#ff6b4a"))
		_add_log(str(dmg) + " damage to kid!")
	else:
		_add_log("Miss!")

func _enter_return() -> void:
	state = "return"
	_timer = 0.55

func _return_to_overworld() -> void:
	kid["hold"] = false
	Game.kid = kid
	Game.scene_change_to("overworld")

func _confirm_death() -> void:
	Game.carry["deaths"] = int(Game.carry.get("deaths", 0)) + 1
	var kept_weapons: Array = kid.get("weapons", []).duplicate()
	var kept_level: int = int(kid.get("level", 1))
	var kept_exp: int = int(kid.get("exp", 0))
	Game.kid = Data.starting_kid()
	Game.kid["weapons"] = kept_weapons
	Game.kid["level"] = kept_level
	Game.kid["exp"] = kept_exp
	Game.battle_origin = {}
	Game.scene_change_to("overworld")

func _border(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, 1), color)
	draw_rect(Rect2(x, y + h - 1, w, 1), color)
	draw_rect(Rect2(x, y, 1, h), color)
	draw_rect(Rect2(x + w - 1, y, 1, h), color)

func _poly(center: Vector2, pts: Array, color: Color) -> void:
	var out = PackedVector2Array()
	for p in pts:
		out.append(center + Vector2(float(p[0]), float(p[1])))
	draw_polygon(out, PackedColorArray([color]))

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), palette.get("bg", Color("#1c1410")))
	draw_rect(Rect2(0, 0, VIEW_W, 56), palette.get("back", Color("#241a12")))
	draw_rect(Rect2(0, 56, VIEW_W, 46), palette.get("ground", Color("#33241a")))
	draw_rect(Rect2(0, 56, VIEW_W, 2), palette.get("panel_line", Color("#4a3a24")))
	_draw_enemy()
	_draw_kid()
	_draw_kid_hp()
	_draw_panel()
	_draw_bottom_band()
	_draw_popups()
	if state == "return":
		var f: float = clamp(1.0 - _timer / 0.55, 0.0, 1.0)
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.023, 0.015, 0.007, f))
	if state == "lost":
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.20, 0.055, 0.03, 0.82))
		draw_centered("YOU DIED", VIEW_W / 2, 88, 14, Color("#d96a3a"))
		draw_centered("back to the last safe tile...", VIEW_W / 2, 108, 7, Color("#c8a08a"))

func _draw_kid() -> void:
	var bob := int(sin(time * 2.0) * 1.0)
	var lunge_x := int(_kid_lunge * 22.0)
	draw_rect(Rect2(23, 88, 21, 3), Color(0, 0, 0, 0.35))
	Kid.draw(self, 20 + lunge_x, 48 + bob, "side", 1, 0, -1, 1.5)

func _draw_kid_hp() -> void:
	var frac: float = float(kid["current_hp"]) / max(1.0, float(kid["max_hp"]))
	var qc := Color("#5fae5a")
	if frac < 0.3: qc = Color("#e0522a")
	elif frac < 0.6: qc = Color("#e0b23a")
	_draw_hp_bar(2, 92, 96, 6, frac, qc)
	draw_left("HP " + str(kid["current_hp"]) + "/" + str(kid["max_hp"]), 104, 98, 6, Color("#c8d4a0"))

func _draw_hp_bar(x: float, y: float, w: float, h: float, frac: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), Color("#16120c"))
	draw_rect(Rect2(x, y, w * clamp(frac, 0.0, 1.0), h), color)

func _draw_panel() -> void:
	var p: Dictionary = palette
	draw_rect(Rect2(208, 4, 106, 94), p.get("panel", Color("#160f0a")))
	_border(208, 4, 106, 94, p.get("panel_line", Color("#4a3a24")))
	draw_left("ENEMY", 214, 15, 6, p.get("accent", Color("#c9782a")))
	draw_left(enemy["name"], 214, 27, 8, p.get("text", Color("#e6dcc0")))
	draw_left("Lv " + str(enemy["level"]), 214, 38, 6, Color("#8a7d63"))
	var frac: float = float(enemy["hp"]) / max(1.0, float(enemy["max_hp"]))
	var qc := Color("#5fae5a")
	if frac < 0.3: qc = Color("#e0522a")
	elif frac < 0.6: qc = Color("#e0b23a")
	_draw_hp_bar(214, 44, 94, 7, frac, qc)
	draw_left("HP " + str(enemy["hp"]) + "/" + str(enemy["max_hp"]), 214, 62, 6, Color("#c8d4a0"))
	var type_tag := String(enemy["types"][0]).to_upper()
	draw_left(type_tag, 214, 76, 6, p.get("accent", Color("#c9782a")))
	draw_left("W: " + enemy["weak"].to_upper(), 214, 90, 6, Color("#8a7d63"))

func _draw_bottom_band() -> void:
	var p: Dictionary = palette
	draw_rect(Rect2(0, 104, VIEW_W, 2), p.get("panel_line", Color("#4a3a24")))
	draw_rect(Rect2(4, 106, 186, 64), p.get("panel", Color("#160f0a")))
	_border(4, 106, 186, 64, p.get("panel_line", Color("#4a3a24")))
	var n := log_lines.size()
	var start := maxi(0, n - 2)
	var y := 122
	for i in range(start, n):
		if i == n - 1:
			draw_left(">", 10, y, 7, p.get("accent", Color("#c9782a")))
			draw_left(log_lines[i], 22, y, 6, p.get("text", Color("#e6dcc0")))
		else:
			draw_left(log_lines[i], 11, y, 6, Color(0.72, 0.60, 0.46, 1.0))
		y += 17
	# menu
	draw_rect(Rect2(198, 106, 114, 64), p.get("panel", Color("#160f0a")))
	_border(198, 106, 114, 64, p.get("panel_line", Color("#4a3a24")))
	for i in MENU_LABELS.size():
		var ry := 110 + i * 14
		var sel_row := (i == _sel) or (i == _hover)
		if sel_row:
			draw_rect(Rect2(201, ry, 108, 12), p.get("accent", Color("#c9782a")))
			draw_left(MENU_LABELS[i], 208, ry + 10, 7, Color("#0b0806"))
		else:
			draw_left(MENU_LABELS[i], 208, ry + 10, 7, p.get("text", Color("#e6dcc0")))

func _draw_popups() -> void:
	for p in popups:
		var c: Color = p["color"]
		c.a = clamp(float(p["ttl"]) / 0.5, 0.0, 1.0)
		draw_left(p["text"], float(p["x"]), float(p["y"]), 8, c)

func draw_left(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_enemy() -> void:
	var bob := int(sin(time * 2.2) * 2.0)
	var lunge := int(_enemy_lunge * 26.0)
	var x := 118 - lunge
	var y := 40 + bob
	draw_rect(Rect2(x - 18, y + 16, 36, 3), Color(0, 0, 0, 0.35))
	match enemy["id"]:
		"rustjaw": _draw_rustjaw(x, y)
		"silt_pup": _draw_silt_pup(x, y)
		"smoke_wasp": _draw_smoke_wasp(x, y)

func _poly_scaled(center: Vector2, pts: Array, scale: float, color: Color) -> void:
	var out = PackedVector2Array()
	for p in pts:
		out.append(center + Vector2(float(p[0]) * scale, float(p[1]) * scale))
	draw_polygon(out, PackedColorArray([color]))

func _draw_rustjaw(x: float, y: float) -> void:
	# back spines
	_poly(Vector2(x, y), [[-10, -9], [-7, -19], [-3, -10]], Color("#241610"))
	_poly(Vector2(x, y), [[-1, -10], [3, -20], [7, -10]], Color("#241610"))
	_poly(Vector2(x, y), [[8, -8], [11, -16], [13, -7]], Color("#241610"))
	# tail stub (right)
	_poly(Vector2(x, y), [[13, -2], [24, 1], [22, 5], [13, 4]], Color("#241610"))
	_poly(Vector2(x, y), [[13, -1], [23, 1], [21, 4], [13, 3]], Color("#3a2414"))
	# body outline + fill
	_poly_scaled(Vector2(x, y), [[-14, 2], [-12, -10], [4, -13], [14, -9], [15, 0], [12, 8], [-10, 9]], 1.12, Color("#241610"))
	_poly(Vector2(x, y), [[-14, 2], [-12, -10], [4, -13], [14, -9], [15, 0], [12, 8], [-10, 9]], Color("#5e3a24"))
	# top highlight + belly shade
	_poly(Vector2(x, y), [[-11, -6], [0, -11], [10, -8], [11, -4], [0, -7], [-10, -3]], Color("#7a4c2c"))
	_poly(Vector2(x, y), [[-10, 5], [11, 5], [10, 8], [-9, 8]], Color("#3a2414"))
	# open jaw (head at left)
	_poly(Vector2(x, y), [[-13, 1], [-27, 3], [-26, 10], [-13, 8]], Color("#241610"))
	_poly(Vector2(x, y), [[-13, 2], [-25, 4], [-24, 8], [-12, 7]], Color("#3a2414"))
	_poly(Vector2(x, y), [[-13, 3], [-24, 5], [-23, 7], [-13, 6]], Color("#12090a"))
	_poly(Vector2(x, y), [[-19, 4], [-17, 4], [-18, 7]], Color("#e8e0cc"))
	_poly(Vector2(x, y), [[-15, 4], [-13, 4], [-14, 7]], Color("#e8e0cc"))
	# legs
	draw_rect(Rect2(x - 11, y + 8, 5, 7), Color("#241610"))
	draw_rect(Rect2(x - 1, y + 8, 5, 7), Color("#241610"))
	draw_rect(Rect2(x + 8, y + 8, 5, 7), Color("#241610"))
	# eye (head at left)
	draw_rect(Rect2(x - 10, y - 6, 4, 4), Color("#ffe27a"))
	draw_rect(Rect2(x - 10, y - 6, 1, 3), Color("#1a130d"))
	draw_rect(Rect2(x - 9, y - 5, 1, 1), Color("#fff2c4"))

func _draw_silt_pup(x: float, y: float) -> void:
	# tail (right, upright)
	_poly(Vector2(x, y), [[11, 1], [22, -6], [21, 1], [12, 4]], Color("#241a12"))
	_poly(Vector2(x, y), [[12, 1], [21, -4], [20, 0], [12, 3]], Color("#5d4f32"))
	# ear (left, on head)
	_poly(Vector2(x, y), [[-9, -7], [-7, -15], [-3, -8]], Color("#241a12"))
	_poly(Vector2(x, y), [[-8, -7], [-6.5, -12], [-4, -8]], Color("#6b5c3e"))
	# body outline + fill
	_poly_scaled(Vector2(x, y), [[-13, 2], [-10, -7], [6, -9], [13, -5], [14, 2], [11, 7], [-9, 8]], 1.12, Color("#241a12"))
	_poly(Vector2(x, y), [[-13, 2], [-10, -7], [6, -9], [13, -5], [14, 2], [11, 7], [-9, 8]], Color("#6b5c3e"))
	# belly shade + top highlight
	_poly(Vector2(x, y), [[-9, 4], [11, 4], [10, 7], [-9, 7]], Color("#4d4028"))
	_poly(Vector2(x, y), [[-8, -5], [4, -7], [11, -4], [0, -5], [-7, -3]], Color("#7d6b48"))
	# snout (head at left)
	_poly(Vector2(x, y), [[-13, 0], [-23, 2], [-22, 5], [-13, 5]], Color("#241a12"))
	_poly(Vector2(x, y), [[-13, 1], [-22, 2], [-21, 4], [-13, 4]], Color("#5d4f32"))
	draw_rect(Rect2(x - 22, y + 1, 2, 2), Color("#17100c"))
	# legs
	draw_rect(Rect2(x - 10, y + 7, 4, 6), Color("#241a12"))
	draw_rect(Rect2(x - 1, y + 7, 4, 6), Color("#241a12"))
	draw_rect(Rect2(x + 8, y + 7, 4, 6), Color("#241a12"))
	# eye (left head)
	draw_rect(Rect2(x - 9, y - 3, 3, 3), Color("#f4e9d4"))
	draw_rect(Rect2(x - 9, y - 3, 1, 2), Color("#241a12"))

func _draw_smoke_wasp(x: float, y: float) -> void:
	# wings (behind body)
	draw_polygon(PackedVector2Array([Vector2(x - 6, y - 6), Vector2(x - 16, y - 22), Vector2(x + 4, y - 10)]), PackedColorArray([Color(0.83, 0.81, 0.71, 0.45)]))
	draw_polygon(PackedVector2Array([Vector2(x + 4, y - 5), Vector2(x + 16, y - 18), Vector2(x + 14, y - 6)]), PackedColorArray([Color(0.83, 0.81, 0.71, 0.35)]))
	# stinger (right)
	_poly(Vector2(x, y), [[11, -1], [19, 2], [11, 4]], Color("#171420"))
	# body outline + fill
	_poly_scaled(Vector2(x, y), [[-12, 0], [-5, -8], [5, -8], [11, -3], [11, 3], [5, 7], [-5, 7], [-12, 3]], 1.14, Color("#171420"))
	_poly(Vector2(x, y), [[-12, 0], [-5, -8], [5, -8], [11, -3], [11, 3], [5, 7], [-5, 7], [-12, 3]], Color("#4a4160"))
	# top highlight
	_poly(Vector2(x, y), [[-7, -5], [4, -6], [10, -3], [0, -4]], Color("#5d5480"))
	# belly stripes
	for i in 3:
		var bx = x - 7 + i * 5
		draw_rect(Rect2(bx, y + 2, 2, 5), Color("#2c2740"))
	# head (left)
	_poly(Vector2(x, y), [[-12, -3], [-20, -1], [-20, 4], [-12, 5]], Color("#171420"))
	_poly(Vector2(x, y), [[-12, -2], [-19, -1], [-19, 3], [-12, 4]], Color("#342b44"))
	# eye (head at left)
	draw_rect(Rect2(x - 19, y - 1, 3, 3), Color("#ffcf6e"))
	draw_rect(Rect2(x - 19, y - 1, 1, 2), Color("#171420"))
	draw_rect(Rect2(x - 18, y - 2, 1, 1), Color("#fff2c4"))
	# legs
	draw_rect(Rect2(x - 5, y + 7, 3, 5), Color("#171420"))
	draw_rect(Rect2(x + 5, y + 7, 3, 5), Color("#171420"))
