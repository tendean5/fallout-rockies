# Root scene — registers the holder and kicks off the title scene.
extends Node2D

const BattleData = preload("res://scripts/battle_data.gd")

var holder: Node2D = null
var _shot_target := ""
var _shot_timer := 0.0
var _capture_time := 0.6
var _walk := false
var _talk := false
var _advance_timer := 0.0

func _ready() -> void:
	holder = Node2D.new()
	holder.name = "Holder"
	add_child(holder)
	Game.register_holder(holder)

	var args := OS.get_cmdline_user_args()
	var start_scene := "title"
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			_shot_target = args[i + 1]
		elif args[i].begins_with("--start="):
			start_scene = args[i].substr(8)
		elif args[i] == "--walk":
			_walk = true
		elif args[i] == "--talk":
			_talk = true
		elif args[i].begins_with("--time="):
			_capture_time = max(0.1, float(args[i].substr(7)))
	if start_scene == "battle":
		Game.kid = Game.kid if Game.kid != null and typeof(Game.kid) == TYPE_DICTIONARY and Game.kid.has("current_hp") else BattleData.starting_kid()
		Game.battle_context = {"region": "Denver Ruins"}
	Game.scene_change_to(start_scene)

func _process(delta: float) -> void:
	if _shot_target.is_empty():
		return
	if _walk:
		Game.virtual_right = true
	if _talk:
		_advance_timer += delta
		if _advance_timer >= 0.4:
			_advance_timer = 0.0
			var ws := Game.current_scene()
			if ws != null and ws.has_method("debug_advance_dialogue"):
				ws.debug_advance_dialogue()
	_shot_timer += delta
	if _shot_timer >= _capture_time:
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(_shot_target)
			print("SHOT_SAVED: " + _shot_target + " (%dx%d)" % [img.get_width(), img.get_height()])
			_analyze(img)
		var cur := Game.current_scene()
		if cur != null and cur.has_method("debug_state"):
			print("STATE: " + cur.debug_state())
		Game.virtual_right = false
		get_tree().quit()

func _analyze(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var total := 0
	var counts := {}
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			total += 1
			var hex := c.to_html()
			counts[hex] = counts.get(hex, 0) + 1
	var pairs := []
	for k in counts:
		pairs.append({"hex": k, "n": counts[k]})
	pairs.sort_custom(func(a, b): return a["n"] > b["n"])
	print("SHOT_COLORS (top):")
	for i in range(mini(12, pairs.size())):
		print("  %s x%d (%.0f%%)" % [pairs[i]["hex"], pairs[i]["n"], 100.0 * pairs[i]["n"] / total])

func _close(a: Color, b: Color) -> bool:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return (dr * dr + dg * dg + db * db) < 0.02
