# NPC sprite drawing — small humanoids for the town scenes.
# kind: "mother", "father", "guard", "kid"
class_name NPC

const SKIN := Color("#e8d3a8")
const DARK := Color("#241a10")

static func draw(canvas: Node2D, x: float, y: float, face: int, kind: String, bob := 0) -> void:
	y += bob
	if kind == "mother":
		# dark hair, teal jacket
		canvas.draw_rect(Rect2(x + 1, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x + 7, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x, y + 5, 11, 6), Color("#4c6b3c"))
		canvas.draw_rect(Rect2(x, y + 7, 11, 1), Color("#2c4526"))
		canvas.draw_rect(Rect2(x + 2, y, 7, 3), Color("#2a1d14"))
		canvas.draw_rect(Rect2(x + 2, y + 2, 7, 4), SKIN)
		canvas.draw_rect(Rect2(x + 5 if face >= 0 else x + 1, y + 4, 1, 1), DARK)
		canvas.draw_rect(Rect2(x + 8 if face >= 0 else x + 4, y + 4, 1, 1), DARK)
	elif kind == "father":
		# denim jacket, beard
		canvas.draw_rect(Rect2(x + 1, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x + 7, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x, y + 5, 11, 6), Color("#57412a"))
		canvas.draw_rect(Rect2(x, y + 7, 11, 1), Color("#332619"))
		canvas.draw_rect(Rect2(x + 2, y, 7, 3), Color("#241a10"))
		canvas.draw_rect(Rect2(x + 2, y + 2, 7, 5), SKIN)
		canvas.draw_rect(Rect2(x + 2, y + 5, 7, 3), Color("#33241a"))
		canvas.draw_rect(Rect2(x + 5 if face >= 0 else x + 1, y + 4, 1, 1), DARK)
		canvas.draw_rect(Rect2(x + 8 if face >= 0 else x + 4, y + 4, 1, 1), DARK)
	elif kind == "guard":
		# armor, helmet — the Enclave sentry
		canvas.draw_rect(Rect2(x + 1, y + 10, 2, 3), Color("#221d16"))
		canvas.draw_rect(Rect2(x + 7, y + 10, 2, 3), Color("#221d16"))
		canvas.draw_rect(Rect2(x - 1, y + 5, 13, 6), Color("#3a3226"))
		canvas.draw_rect(Rect2(x - 1, y + 7, 13, 1), Color("#2a251c"))
		canvas.draw_rect(Rect2(x + 1, y, 9, 3), Color("#2a251c"))
		canvas.draw_rect(Rect2(x + 1, y + 2, 9, 2), Color("#1d1812"))
		canvas.draw_rect(Rect2(x + 3, y + 5, 5, 2), Color("#0c0a08"))
		# baton
		var baton_x := x + (12 if face > 0 else -2)
		canvas.draw_rect(Rect2(baton_x, y + 8, 2, 5), Color("#241a10"))
	elif kind == "kid":
		# small childhood friend — bright jacket, round face
		canvas.draw_rect(Rect2(x + 1, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x + 7, y + 10, 2, 3), Color("#2c2117"))
		canvas.draw_rect(Rect2(x, y + 5, 11, 6), Color("#e0a04a"))
		canvas.draw_rect(Rect2(x + 1, y, 9, 3), Color("#ecd9b4"))
		canvas.draw_rect(Rect2(x + 2, y, 7, 4), SKIN)
		canvas.draw_rect(Rect2(x + 5 if face >= 0 else x + 1, y + 3, 1, 1), DARK)
		canvas.draw_rect(Rect2(x + 8 if face >= 0 else x + 4, y + 3, 1, 1), DARK)
