# NPC sprite drawing — small humanoids for the childhood town scenes.
const PixelArt = preload("res://scripts/pixel_art.gd")

const OUTLINE := Color("#0c0906")
const SKIN := Color("#e8d3a8")

# shared palette pieces
const HAIR := Color("#241a10")

static func _pal(kind: String) -> Dictionary:
	match kind:
		"mother":
			return {"O": OUTLINE, "H": HAIR, "F": SKIN, "E": Color("#10100c"), "J": Color("#4c6b3c"), "L": Color("#2c2117"), "W": Color("#14100a")}
		"father":
			return {"O": OUTLINE, "H": HAIR, "F": SKIN, "E": Color("#10100c"), "B": Color("#33241a"), "J": Color("#57412a"), "L": Color("#241b12"), "W": Color("#14100a")}
		"guard":
			return {"O": OUTLINE, "H": Color("#1d1812"), "V": Color("#0c0a08"), "J": Color("#3a3226"), "L": Color("#221d16"), "W": Color("#14100a")}
		"kid":
			return {"O": OUTLINE, "H": Color("#2b1d12"), "F": Color("#ecd9b4"), "E": Color("#10100c"), "J": Color("#e0a04a"), "L": Color("#2c2117"), "W": Color("#14100a")}
	return {}

# mother — dark bobbed hair, olive jacket, wider skirt
const MOTHER := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	"OHHHHHHHHO.",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHFFFO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJJJJJJO..",
	"OJJJJJJJJO.",
	".LL..LL....",
	".WW..WW....",
]

# father — dark hair, rust jacket, beard
const FATHER := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHBBFFO...",
	"..OBBBO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJJJJJJO..",
	"OJJJJJJJO..",
	".LL..LL....",
	".WW..WW....",
]

# guard — helmet, visor, bronze armor
const GUARD := [
	"....OOO....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHVVVHO...",
	".OHVVVHO...",
	".OHHHHHHO..",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJJJJJJO..",
	"OJJJJJJJO..",
	"OOOOOOO....",
	".LL..LL....",
	".WW..WW....",
]

# kid friend — messy dark hair, bright orange jacket
const FRIEND := [
	"...OOO.....",
	"..OHHHHO...",
	".OHHHHHHO..",
	".OHFFFFO...",
	".OHFFEFO...",
	".OHFFFO....",
	"..OOOOO....",
	".OJJJJJO...",
	"OJJJJJJO...",
	"OJJJJJJO...",
	".OOOOOOO...",
	".LL..LL....",
	".WW..WW....",
]

static func _map(kind: String) -> Array:
	match kind:
		"mother":
			return MOTHER
		"father":
			return FATHER
		"guard":
			return GUARD
		"kid":
			return FRIEND
	return MOTHER

static func draw(canvas: Node2D, x: float, y: float, face: int, kind: String, bob := 0) -> void:
	PixelArt.draw_map(canvas, _map(kind), _pal(kind), x, y, face, bob)
	if kind == "guard":
		# side baton
		var baton_x := x + (11.5 if face > 0 else -3.5)
		canvas.draw_rect(Rect2(baton_x, y + 7 + bob, 2, 5), Color("#241a10"))
