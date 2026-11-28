# Kid sprite drawing — pxl-generated PNGs (chunky Fallout 1 pixels, hard outline).
# Shared by every scene (bunker + overworld + battle).
# 4 directions: "front" (facing the camera), "back" (facing away), "side" (facing left/right).
# side sprites are drawn facing right; face == -1 mirrors horizontally.
const TEX_IDLE = preload("res://assets/sprites/sprites/kid_idle.png")
const TEX_WALK_A = preload("res://assets/sprites/sprites/kid_walk_a.png")
const TEX_WALK_B = preload("res://assets/sprites/sprites/kid_walk_b.png")
const TEX_BACK_IDLE = preload("res://assets/sprites/sprites/kid_back_idle.png")
const TEX_BACK_WALK_A = preload("res://assets/sprites/sprites/kid_back_walk_a.png")
const TEX_BACK_WALK_B = preload("res://assets/sprites/sprites/kid_back_walk_b.png")
const TEX_SIDE_IDLE = preload("res://assets/sprites/sprites/kid_side_idle.png")
const TEX_SIDE_WALK_A = preload("res://assets/sprites/sprites/kid_side_walk_a.png")
const TEX_SIDE_WALK_B = preload("res://assets/sprites/sprites/kid_side_walk_b.png")

const SPRITE_W := 20
const SPRITE_H := 28

static var _filters_set := false
static var _flipped: Dictionary = {}

static func _ensure_defaults() -> void:
	if _filters_set:
		return
	_filters_set = true

static func _flip_tex(tex: Texture2D) -> Texture2D:
	var key: String = tex.resource_path
	if _flipped.has(key):
		return _flipped[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, img.get_format())
	for y in h:
		for x in w:
			out.set_pixel(w - 1 - x, y, img.get_pixel(x, y))
	var t := ImageTexture.create_from_image(out)
	_flipped[key] = t
	return t

static func _pick(facing: String, step: int) -> Texture2D:
	match facing:
		"back":
			if step == 0: return TEX_BACK_WALK_A
			if step == 1: return TEX_BACK_WALK_B
			return TEX_BACK_IDLE
		"side":
			if step == 0: return TEX_SIDE_WALK_A
			if step == 1: return TEX_SIDE_WALK_B
			return TEX_SIDE_IDLE
		_:
			if step == 0: return TEX_WALK_A
			if step == 1: return TEX_WALK_B
			return TEX_IDLE

# Eyes are at row 8 of the front/side art. Blinking draws a thin ink line across them.
static func _blink_eyes(canvas: Node2D, x: float, y: float, facing: String, face: int, scale: float) -> void:
	if facing != "front" and facing != "side":
		return
	var ink := Color("#241a12")
	if facing == "front":
		canvas.draw_rect(Rect2(x + 5.0 * scale, y + 8.0 * scale, 2.0 * scale, 1.0 * scale), ink)
		canvas.draw_rect(Rect2(x + 12.0 * scale, y + 8.0 * scale, 2.0 * scale, 1.0 * scale), ink)
	elif facing == "side":
		var ex := 13.0
		if face < 0:
			ex = SPRITE_W - ex - 2.0
		canvas.draw_rect(Rect2(x + ex * scale, y + 8.0 * scale, 2.0 * scale, 1.0 * scale), ink)

static func draw(canvas: Node2D, x: float, y: float, facing: String = "front", face: int = 1, bob := 0.0, step := -1, scale := 1.0, blink := false) -> void:
	_ensure_defaults()
	var tex := _pick(facing, step)
	if facing == "side" and face < 0:
		tex = _flip_tex(tex)
	if scale == 1.0:
		canvas.draw_texture(tex, Vector2(x, y + bob))
		if blink:
			_blink_eyes(canvas, x, y, facing, face, 1.0)
	else:
		canvas.draw_texture_rect(tex, Rect2(x, y + bob, float(SPRITE_W) * scale, float(SPRITE_H) * scale), false, Color.WHITE)
		if blink:
			_blink_eyes(canvas, x, y, facing, face, scale)
