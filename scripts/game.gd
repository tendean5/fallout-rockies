# Global game state — carry flags, checkpoint, scene switching, save, smoke mode.
class_name GameState
extends Node

var carry := {}
var checkpoint := {}
var holder: Node2D = null

# virtual input (used by smoke tests; keeps the scenes input-agnostic)
var virtual_left := false
var virtual_right := false
var virtual_up := false
var virtual_down := false

# checkpoint autonsave interval — shortened in smoke mode
var checkpoint_interval := 1.5

# ---- smoke mode ----
var smoke := false
var smoke_stage := -1
var smoke_timer := 0.0
var smoke_frames := 0
var results := []
var _bunkers_instance: Node2D = null

func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	smoke = "--smoke" in user_args
	if smoke:
		smoke_stage = 0
		smoke_timer = 0.0
		smoke_frames = 0
		results = []
		checkpoint_interval = 0.15

func register_holder(node: Node2D) -> void:
	holder = node

func current_scene() -> Node2D:
	if holder == null:
		return null
	var kids := holder.get_children()
	if kids.is_empty():
		return null
	return kids[0]

func scene_change_to(name: String) -> void:
	if holder == null:
		push_error("Game: holder not registered; cannot load scene " + name)
		return
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var script = load("res://scripts/%s.gd" % name)
	if script == null:
		push_error("Game: missing scene script for " + name)
		return
	var instance = script.new()
	holder.add_child(instance)

func new_game() -> void:
	carry = {"artifact": "locket", "flag": null, "age": 6, "deaths": 0}
	checkpoint = {}
	FalloutSave.clear()
	scene_change_to("bunkers")

func load_game_run() -> void:
	_load_checkpoint_and_carry()
	scene_change_to("overworld")

func _load_checkpoint_and_carry() -> void:
	var data := FalloutSave.load_game()
	var c = data.get("carry", {})
	var cp = data.get("checkpoint", {})
	carry = c if typeof(c) == TYPE_DICTIONARY else {"artifact": "locket", "flag": null, "age": 6, "deaths": 0}
	checkpoint = cp if typeof(cp) == TYPE_DICTIONARY else {}
	if typeof(carry.get("age", 6)) != TYPE_INT:
		carry["age"] = 6

func save_game(extra: Dictionary = {}) -> Dictionary:
	if typeof(carry) != TYPE_DICTIONARY:
		carry = {"artifact": "locket", "flag": null, "age": 6, "deaths": 0}
	var payload := {
		"age": carry.get("age", 6),
		"checkpoint": checkpoint,
		"carry": {
			"artifact": carry.get("artifact", "locket"),
			"flag": carry.get("flag", null),
			"age": carry.get("age", 6),
			"deaths": carry.get("deaths", 0),
		},
	}
	for k in extra:
		payload[k] = extra[k]
	return FalloutSave.write_game(payload)

func _physics_process(delta: float) -> void:
	if not smoke:
		return
	smoke_frames += 1
	smoke_timer += delta
	match smoke_stage:
		0:
			if smoke_frames >= 4:
				var scene := current_scene()
				if scene != null and scene.has_method("debug_scene_name"):
					scene._force_draw()
					success("title scene instantiated (%s)" % scene.debug_scene_name())
					smoke_stage = 1
					smoke_timer = 0.0
					scene_change_to("bunkers")
				else:
					fail("title scene missing or not running")
					smoke_stage = 99
		1:
			if smoke_timer >= 0.2:
				var scene := current_scene()
				if scene != null and scene.has_method("debug_teleport_to_end"):
					_bunkers_instance = scene
					scene.debug_teleport_to_end()
					smoke_stage = 2
					smoke_timer = 0.0
				else:
					fail("bunkers scene missing")
					smoke_stage = 99
		2:
			var scene2 := current_scene()
			if scene2 != null and scene2 != _bunkers_instance:
				var saved := FalloutSave.load_game()
				if typeof(saved) == TYPE_DICTIONARY and saved.get("carry") != null:
					success("bunker prologue → save → overworld")
				else:
					fail("save missing after bunkers")
				smoke_stage = 3
				smoke_timer = 0.0
			elif smoke_timer > 6.0:
				fail("bunkers never finished (no transition)")
				smoke_stage = 99
		3:
			var scene3 := current_scene()
			if scene3 != null:
				scene3._force_draw()
				if smoke_timer >= 0.4:
					success("overworld drew without error")
					smoke_stage = 4
					smoke_timer = 0.0
		4:
			virtual_right = true
			if smoke_timer >= 0.6:
				virtual_right = false
				var saved := FalloutSave.load_game()
				var ckpt = saved.get("checkpoint", {}) if saved != null else {}
				if typeof(ckpt) == TYPE_DICTIONARY and int(ckpt.get("x", 0)) > 6:
					success("walked and checkpointed (x=%d)" % int(ckpt["x"]))
				else:
					fail("no checkpoint advance after walking (x=%s)" % str(ckpt.get("x", "?")))
				smoke_stage = 5
				smoke_timer = 0.0
		5:
			var scene5 := current_scene()
			if scene5 != null and scene5.has_method("debug_teleport_to_water"):
				scene5.debug_teleport_to_water()
				smoke_stage = 6
				smoke_timer = 0.0
			elif smoke_timer > 2.0:
				fail("overworld scene lost")
				smoke_stage = 99
		6:
			var scene6 := current_scene()
			if scene6 != null:
				scene6._force_draw()
				if scene6.debug_deaths() > 0 and not scene6.debug_is_dead():
					success("drown → death → reset (deaths=%d)" % scene6.debug_deaths())
					smoke_stage = 7
				elif smoke_timer > 6.0:
					fail("drown-death never happened")
					smoke_stage = 7
		7:
			print_results_and_quit()
			smoke_stage = 99
		99:
			print_results_and_quit()

func success(msg: String) -> void:
	results.append("PASS: " + msg)
	print("SMOKE PASS: " + msg)

func fail(msg: String) -> void:
	results.append("FAIL: " + msg)
	print("SMOKE FAIL: " + msg)

func print_results_and_quit() -> void:
	var fails := 0
	for r in results:
		if r.begins_with("FAIL"):
			fails += 1
	var status := "PASS" if fails == 0 else "FAIL"
	print("SMOKE RESULT: %s (%d failures)" % [status, fails])
	get_tree().quit(fails)
