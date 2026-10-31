extends Node

var cues: Dictionary = {}
var effects: AudioStreamPlayer
var music: AudioStreamPlayer
var muted = false
var last_wave = 0
var last_result = ""

func _ready() -> void:
	for key in ["select", "order", "build", "wave", "victory", "defeat"]:
		cues[key] = load("res://assets/audio/%s.wav" % key)
	effects = AudioStreamPlayer.new()
	effects.max_polyphony = 6
	effects.volume_db = -13
	add_child(effects)
	music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/embers.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	music.stream = stream
	music.volume_db = -24
	add_child(music)
	music.play()

func toggle() -> void:
	muted = not muted
	music.volume_db = -80 if muted else -24
	effects.volume_db = -80 if muted else -13

func _exit_tree() -> void:
	if is_instance_valid(effects):
		effects.stop()
		effects.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	cues.clear()

func cue(key: String) -> void:
	if not muted and cues.has(key):
		effects.stream = cues[key]
		effects.play()

func _process(_delta: float) -> void:
	if Session.sim.wave > last_wave:
		cue("wave")
	last_wave = Session.sim.wave
	if Session.sim.result != "" and Session.sim.result != last_result:
		cue(Session.sim.result)
	last_result = Session.sim.result
