# Kid placeholder sprite drawing (shared by every scene).
const PixelArt = preload("res://scripts/pixel_art.gd")

const OUTLINE := Color("#0c0906")
const HOOD := Color("#33261a")
const SKIN := Color("#e2cfa8")
const EYE := Color("#10100c")
const JACKET := Color("#c9a03a")
const STRAP := Color("#6b4f30")
const LEG := Color("#241b12")
const SHOE := Color("#14100a")

const PAL := {
	"O": OUTLINE,
	"H": HOOD,
	"F": SKIN,
	"E": EYE,
	"J": JACKET,
	"S": STRAP,
	"L": LEG,
	"W": SHOE,
}

# idle sprite — 11 wide x 13 tall, rows top->bottom. Feet at row 12 (floor).
const IDLE := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHHHHHHO..",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHFFFO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJSJJJO...",
	"OJJJJJJJO..",
	".LL..LL....",
	".WW..WW....",
]

# walk frames — step 0: left foot planted, right foot back
const STEP_LEFT := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHHHHHHO..",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHFFFO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJSJJJO...",
	"OJJJJJJJO..",
	".LL...L....",
	".WW...WW...",
]

# step 1: right foot planted, left foot back
const STEP_RIGHT := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHHHHHHO..",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHFFFO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJSJJJO...",
	"OJJJJJJJO..",
	".L...LL....",
	".WW..WW....",
]

static func _pick(step: int) -> Array:
	if step == 0:
		return STEP_LEFT
	if step == 1:
		return STEP_RIGHT
	return IDLE

static func draw(canvas: Node2D, x: float, y: float, face: int, bob := 0, step := -1) -> void:
	var map := _pick(step)
	PixelArt.draw_map(canvas, map, PAL, x, y, face, bob)
