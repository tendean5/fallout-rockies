# Kid placeholder sprite drawing (shared by every scene).
class_name Kid

const BODY_COLOR := Color("#c9a03a")
const HEAD_COLOR := Color("#e6d3a8")
const FACE_COLOR := Color("#2a1d14")
const HOOD_COLOR := Color("#322317")
const PACK_COLOR := Color("#4a3520")
const LEG_COLOR := Color("#2c2117")
const STRAP_COLOR := Color("#6b4f30")

# step: -1 idle, 0 left leg up, 1 right leg up (walk animation)
static func draw(canvas: Node2D, x: float, y: float, face: int, bob := 0, step := -1) -> void:
	y += bob
	# legs (planted legs show alternately)
	var left_lift := (step == 0)
	var right_lift := (step == 1)
	canvas.draw_rect(Rect2(x + 2, y + 10 - (1 if left_lift else 0), 2, 3), LEG_COLOR)
	canvas.draw_rect(Rect2(x + 6, y + 10 - (1 if right_lift else 0), 2, 3), LEG_COLOR)
	# backpack on the back (opposite of face)
	if face > 0:
		canvas.draw_rect(Rect2(x, y + 5, 2, 5), PACK_COLOR)
	elif face < 0:
		canvas.draw_rect(Rect2(x + 9, y + 5, 2, 5), PACK_COLOR)
	# body — jacket + strap
	canvas.draw_rect(Rect2(x, y + 5, 11, 6), BODY_COLOR)
	canvas.draw_rect(Rect2(x, y + 7, 11, 1), STRAP_COLOR)
	# hood
	canvas.draw_rect(Rect2(x + 1, y, 9, 3), HOOD_COLOR)
	# head — pale, peeking out of the hood
	canvas.draw_rect(Rect2(x + 2, y + 2, 7, 5), HEAD_COLOR)
	# eyes — look toward the face direction
	if face > 0:
		canvas.draw_rect(Rect2(x + 6, y + 4, 1, 1), FACE_COLOR)
		canvas.draw_rect(Rect2(x + 7, y + 4, 1, 1), FACE_COLOR)
	elif face < 0:
		canvas.draw_rect(Rect2(x + 2, y + 4, 1, 1), FACE_COLOR)
		canvas.draw_rect(Rect2(x + 3, y + 4, 1, 1), FACE_COLOR)
	else:
		canvas.draw_rect(Rect2(x + 4, y + 4, 1, 1), FACE_COLOR)
		canvas.draw_rect(Rect2(x + 6, y + 4, 1, 1), FACE_COLOR)
