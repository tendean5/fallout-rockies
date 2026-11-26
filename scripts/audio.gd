# Audio — global ambience + one-shot sfx, built from chirp-generated WAV loops.
# Loops (ambience, torch crackle) persist across scenes; one-shots are intermittent.
extends Node

const AMB = preload("res://assets/audio/sfx/ambience.wav")
const CRACKLE = preload("res://assets/audio/sfx/torch_crackle.wav")
const BLIP = preload("res://assets/audio/sfx/dialogue_blip.wav")
const STEP = preload("res://assets/audio/sfx/walk_step.wav")
const CHIME = preload("res://assets/audio/sfx/chime.wav")

var _loops: Dictionary = {}  # name -> AudioStreamPlayer
var _pool: Array = []
var _master := 0.9

func _ready() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_master))
	for s in [AMB, CRACKLE]:
		if "loop_mode" in s:
			s.loop_mode = 1  # loop forward (smpl chunk import should already do this)

func start_loop(name: String) -> void:
	if name in _loops:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _loop_stream(name)
	player.bus = "Master"
	add_child(player)
	player.play()
	_loops[name] = player

func stop_loop(name: String) -> void:
	if not (name in _loops):
		return
	var p: AudioStreamPlayer = _loops[name]
	p.stop()
	p.queue_free()
	_loops.erase(name)

func stop_all_loops() -> void:
	for name in _loops.keys():
		stop_loop(name)

func play_sfx(name: String, vol := 1.0) -> void:
	var stream = _sfx_stream(name)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	player.stream = stream
	player.volume_db = linear_to_db(max(0.001, vol)) if vol > 0.001 else -60.0
	player.play()

func set_master_volume(vol: float) -> void:
	_master = vol
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(max(0.001, vol)))

func debug_state() -> String:
	var s := "loops=%s" % str(_loops.keys())
	var p = _loops.get("ambience", null)
	if p != null:
		var st = p.stream
		s += " ambience.loop_mode=%s" % (str(st.loop_mode) if "loop_mode" in st else "?")
	return s

func _loop_stream(name: String) -> AudioStream:
	match name:
		"ambience":
			return AMB
		"torch_crackle":
			return CRACKLE
	return null

func _sfx_stream(name: String) -> AudioStream:
	match name:
		"dialogue_blip":
			return BLIP
		"walk_step":
			return STEP
		"chime":
			return CHIME
	return null
