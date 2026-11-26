# Loading screen — sits between the title and the first scene. Progress bar,
# dithered warm backdrop, and a wipe into the target scene.
extends Node2D

const VIEW_W := 320
const VIEW_H := 176

const TITLE_SIZE := 18
const TITLE_SUB := "an original game"

var t := 0.0
var progress := 0.0
var stage_index := 0
var done := false
var _fading := false
var _fade := 0.0
var _loaded := false
var _dither = null

var _prev_keys: Dictionary = {}

var _stages := []

func _ready() -> void:
	t = 0.0
	progress = 0.0
	stage_index = 0
	_fading = false
	_fade = 0.0
	_loaded = false
	var target := str(Game.load_target) if Game.load_target != null else "bunkers"
	_stages = [
		"SEEDING THE ROCKIES...",
		"CARVING THE ENCLAVE...",
		"TRACING THE LAST RADIATION...",
		"FILLING THE EMPTY EYES...",
	]
	if target == "overworld":
		_stages = [
		"SEEDING THE ROCKIES...",
		"TRACING THE LAST RADIATION...",
		"LOADING SAVED CHECKPOINT...",
		"FILLING THE EMPTY EYES...",
		]
	Audio.start_loop("ambience")

func debug_scene_name() -> String:
	return "loading"

func debug_state() -> String:
	return "loading target=%s progress=%.0f stage=%d fading=%s" % [str(Game.load_target), progress, stage_index, str(_fading)]

func _just_key(code: int) -> bool:
	var cur := Input.is_physical_key_pressed(code)
	var fresh := cur and not bool(_prev_keys.get(code, false))
	_prev_keys[code] = cur
	return fresh

func _physics_process(delta: float) -> void:
	t += delta

	var total := float(_stages.size()) + 1.0
	progress = min(100.0, (t / 2.4) * 100.0)
	stage_index = int(t / 0.6) if t >= 0.0 else 0
	if stage_index >= _stages.size():
		stage_index = _stages.size() - 1

	if _just_key(KEY_ENTER) or _just_key(KEY_SPACE):
		_finish()

	if progress >= 100.0 and not _fading:
		_fading = true
		Audio.play_sfx("chime", 0.55)

	if _fading:
		_fade = min(1.0, _fade + delta * 3.2)
		if _fade >= 1.0 and not _loaded:
			_loaded = true
			var target := str(Game.load_target) if Game.load_target != null else "bunkers"
			Game.scene_change_to(target)
		queue_redraw()
		return

	queue_redraw()

func _finish() -> void:
	if _fading or _loaded:
		return
	progress = 100.0
	_fading = true
	Audio.play_sfx("chime", 0.55)

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color("#0a0705"))
	_speckle()
	_vignette()

	var cx := VIEW_W / 2.0
	draw_centered("FALLOUT", cx, 36, TITLE_SIZE, Color("#e6dcc0"))
	draw_centered("ROCKIES", cx, 60, TITLE_SIZE, Color("#c99a44"))
	draw_centered(TITLE_SUB, cx, 74, 6, Color("#8a7a5e"))

	# progress bar
	var bar_x := cx - 85.0
	var bar_y := 102.0
	var bar_w := 170.0
	var bar_h := 7.0
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color("#241a0e"))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#18100a"))
	var fill := bar_w * progress / 100.0
	if fill > 0.0:
		var grad_color := Color(0.55, 0.36, 0.14) if progress < 60.0 else Color(0.83, 0.55, 0.16)
		draw_rect(Rect2(bar_x, bar_y, fill, bar_h), grad_color)
		for i in int(fill / 4.0):
			var dx := bar_x + 1.0 + float(i * 4) + (int(t * 8.0) % 2)
			draw_rect(Rect2(dx, bar_y + 1.0, 2.0, 1.0), Color(0.98, 0.75, 0.36, 0.7))
		draw_rect(Rect2(bar_x + 1.0, bar_y, max(0.0, fill - 1.0), 2), Color(0.98, 0.62, 0.16, 0.55))
	draw_centered("%d%%" % int(progress), cx, bar_y + bar_h + 12, 6, Color("#8a7a5e"))

	var stage: String = _stages[stage_index]
	var blink := int(t * 3.0) % 2 == 0
	draw_centered(("_" if blink else " ") + " " + stage + " " + ("_" if blink else " "), cx, 132, 7, Color("#c9b088"))
	draw_centered("a rocky aisle \u00b7 press ENTER to skip", cx, 162, 5, Color("#4a4032"))

	# fade to black on completion
	if _fade > 0.0:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.02, 0.012, 0.007, _fade))

func _vignette() -> void:
	var corners := Rect2(0, 0, VIEW_W, 40)
	draw_rect(corners, Color(0.02, 0.012, 0.007, 0.5))
	draw_rect(Rect2(0, VIEW_H - 40, VIEW_W, 40), Color(0.02, 0.012, 0.007, 0.6))

func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 0x7fffffff

func _speckle() -> void:
	if _dither == null:
		var img := Image.create(VIEW_W, VIEW_H, false, Image.FORMAT_RGBA8)
		for y in VIEW_H:
			for x in VIEW_W:
				var h := _hash(x, y)
				if h % 100 < 22:
					img.set_pixel(x, y, Color(0.10, 0.065, 0.038, 0.85) if h % 2 != 0 else Color(0.16, 0.12, 0.07, 0.85))
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		_dither = ImageTexture.create_from_image(img)
	draw_texture(_dither, Vector2(0, 0))

func draw_centered(text: String, x: float, baseline_y: float, size: int, color: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
