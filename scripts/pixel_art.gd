# Chunky pixel-art renderer — deterministic, hard-outlined, 1px grid.
# A sprite is an Array[String], one string per row; each character maps to a Color.
# face == -1 mirrors the sprite horizontally. bob offsets the whole sprite vertically.

static func draw_map(canvas: Node2D, map: Array, palette: Dictionary, x: float, y: float, face: int, bob := 0) -> void:
	var flip := face < 0
	var w := 0
	for row in map:
		if row.length() > w:
			w = row.length()
	for r in range(map.size()):
		var row: String = map[r]
		if row.length() < w:
			row += ".".repeat(w - row.length())
		var src := row
		if flip:
			var rev := ""
			for i in range(row.length()):
				rev += row[row.length() - 1 - i]
			src = rev
		for c in range(src.length()):
			var ch := src[c]
			if ch == ".":
				continue
			var col = palette.get(ch, null)
			if col == null:
				continue
			canvas.draw_rect(Rect2(x + c, y + r + bob, 1, 1), col)
