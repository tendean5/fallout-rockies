# NPC sprite drawing — pxl-generated PNGs (childhood cast: friend, mumma, pap, guard).
const TEX_PERRY = preload("res://assets/sprites/sprites/perry.png")
const TEX_MUMMA = preload("res://assets/sprites/sprites/mumma.png")
const TEX_PAP = preload("res://assets/sprites/sprites/pap.png")
const TEX_GUARD = preload("res://assets/sprites/sprites/guard.png")

const SPRITE_W := 11
const SPRITE_H := 13

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

static func _tex(kind: String) -> Texture2D:
	match kind:
		"kid":
			return TEX_PERRY
		"mother":
			return TEX_MUMMA
		"father":
			return TEX_PAP
		"guard":
			return TEX_GUARD
	return TEX_PERRY

static func draw(canvas: Node2D, x: float, y: float, face: int, kind: String, bob := 0) -> void:
	_ensure_defaults()
	var tex := _tex(kind)
	if face < 0:
		tex = _flip_tex(tex)
	canvas.draw_texture(tex, Vector2(x, y + bob))
