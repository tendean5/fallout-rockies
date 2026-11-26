# Kid placeholder sprite drawing (shared by every scene).
class_name Kid

const BODY_COLOR := Color("#e8c55a")
const HEAD_COLOR := Color("#f2e3b6")
const FACE_COLOR := Color("#2a1d14")

static func draw(canvas: Node2D, x: float, y: float, face: int) -> void:
	canvas.draw_rect(Rect2(x, y + 4, 11, 9), BODY_COLOR)
	canvas.draw_rect(Rect2(x + 2, y, 7, 6), HEAD_COLOR)
	canvas.draw_rect(Rect2(x + (7 if face > 0 else 2), y + 2, 3, 2), FACE_COLOR)
