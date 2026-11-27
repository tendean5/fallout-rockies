# NPC sprite drawing — pxl-generated PNGs (childhood cast: friend, mumma, pap, guard).
# 4 directions: "front", "back", "side" (facing right; face == -1 mirrors).
const TEX_PERRY = preload("res://assets/sprites/sprites/perry.png")
const TEX_PERRY_BACK = preload("res://assets/sprites/sprites/perry_back.png")
const TEX_PERRY_SIDE = preload("res://assets/sprites/sprites/perry_side.png")
const TEX_MUMMA = preload("res://assets/sprites/sprites/mumma.png")
const TEX_MUMMA_BACK = preload("res://assets/sprites/sprites/mumma_back.png")
const TEX_MUMMA_SIDE = preload("res://assets/sprites/sprites/mumma_side.png")
const TEX_PAP = preload("res://assets/sprites/sprites/pap.png")
const TEX_PAP_BACK = preload("res://assets/sprites/sprites/pap_back.png")
const TEX_PAP_SIDE = preload("res://assets/sprites/sprites/pap_side.png")
const TEX_GUARD = preload("res://assets/sprites/sprites/guard.png")
const TEX_GUARD_BACK = preload("res://assets/sprites/sprites/guard_back.png")
const TEX_GUARD_SIDE = preload("res://assets/sprites/sprites/guard_side.png")

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

static func _tex(kind: String, facing: String) -> Texture2D:
	match kind:
		"kid":
			if facing == "back": return TEX_PERRY_BACK
			if facing == "side": return TEX_PERRY_SIDE
			return TEX_PERRY
		"mother":
			if facing == "back": return TEX_MUMMA_BACK
			if facing == "side": return TEX_MUMMA_SIDE
			return TEX_MUMMA
		"father":
			if facing == "back": return TEX_PAP_BACK
			if facing == "side": return TEX_PAP_SIDE
			return TEX_PAP
		"guard":
			if facing == "back": return TEX_GUARD_BACK
			if facing == "side": return TEX_GUARD_SIDE
			return TEX_GUARD
	return TEX_PERRY

static func draw(canvas: Node2D, x: float, y: float, facing: String, face: int, kind: String, bob := 0) -> void:
	_ensure_defaults()
	var tex := _tex(kind, facing)
	if facing == "side" and face < 0:
		tex = _flip_tex(tex)
	canvas.draw_texture(tex, Vector2(x, y + bob))
