# Title screen — menu with New Game / Load, keyboard + mouse.
extends Node2D

const FalloutSave = preload("res://scripts/save.gd")

const VIEW_W := 320
const VIEW_H := 176

const BTN_W := 130
const BTN_H := 18
const BTN_X := 95
const BTN_Y := [100, 126]

var t := 0.0
var selection := 0
var blink := true
var mouse_pos := Vector2(-1, -1)
var mouse_btn_pos := Vector2(-1, -1)

# edge-detect state for keyboard/mouse (mirrors the old just-pressed semantics)
var _prev_keys: Dictionary = {}
var _mouse_prev_left := false

func _ready() -> void:
	t = 0.0

func debug_scene_name() -> String:
	return "title"

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color("#0b0806"))
	draw_centered("FALLOUT", 160, 40, 26, Color("#e8c55a"))
	draw_centered("ROCKIES", 160, 66, 26, Color("#e8c55a"))
	draw_centered("an original game", 160, 86, 7, Color("#7d7058"))

	var btns := _buttons()
	for i in btns.size():
		var b = btns[i]
		var hovered := _mouse_over(b)
		var lit := (i == selection) or hovered
		draw_rect(Rect2(b["x"] - 2, b["y"] - 2, b["w"] + 4, b["h"] + 4), Color("#e8c55a") if lit else Color("#2a2015"))
		draw_rect(Rect2(b["x"], b["y"], b["w"], b["h"]), Color("#1c150c") if lit else Color("#16100a"))
		var label_color := Color("#4a4032")
		if b["enabled"]:
			label_color = Color("#e8c55a") if lit else Color("#8a7d63")
		draw_centered(b["label"], b["x"] + b["w"] / 2, b["y"] + b["h"] / 2 + 3, 9, label_color)
		if not b["enabled"] and i == 1:
			draw_centered("no saves yet", b["x"] + b["w"] / 2, b["y"] + b["h"] + 9, 6, Color("#5a5040"))

	if blink:
		draw_centered("Arrows to choose \u00b7 Enter to confirm \u00b7 click works too", 160, 165, 6, Color("#5a5040"))

func _physics_process(delta: float) -> void:
	t += delta
	blink = int(t * 2) % 2 == 0

	var btns := _buttons()

	if _just_key(KEY_UP) or _just_key(KEY_W):
		selection = (selection + btns.size() - 1) % btns.size()
	if _just_key(KEY_DOWN) or _just_key(KEY_S):
		selection = (selection + 1) % btns.size()
	if _just_key(KEY_ENTER) or _just_key(KEY_SPACE):
		_confirm()

	# mouse click: select + confirm on clicked button
	var cur_left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if cur_left and not _mouse_prev_left:
		mouse_btn_pos = get_viewport().get_mouse_position()
		for i in btns.size():
			var b = btns[i]
			if _mouse_over(b):
				selection = i
				_confirm()
				break
	_mouse_prev_left = cur_left

func _buttons() -> Array:
	var has_save := not FalloutSave.load_game().is_empty()
	return [
		{"id": "new", "label": "NEW GAME", "x": BTN_X, "w": BTN_W, "y": BTN_Y[0], "h": BTN_H, "enabled": true},
		{"id": "load", "label": "LOAD", "x": BTN_X, "w": BTN_W, "y": BTN_Y[1], "h": BTN_H, "enabled": has_save},
	]

func _mouse_over(b: Dictionary) -> bool:
	var m := get_viewport().get_mouse_position()
	return m.x >= b["x"] and m.x <= b["x"] + b["w"] and m.y >= b["y"] and m.y <= b["y"] + b["h"]

func _confirm() -> void:
	var btns := _buttons()
	var b = btns[selection]
	if not b["enabled"]:
		return
	if b["id"] == "new":
		Game.new_game()
	elif b["id"] == "load":
		Game.load_game_run()

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh: bool = cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)

