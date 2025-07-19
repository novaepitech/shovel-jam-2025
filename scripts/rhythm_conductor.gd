extends Node

var song_position_in_beats: float = 0.0
var time_per_beat: float = 0.5 # Durée d'un temps en secondes

var _bpm: float = 120.0
var _is_running: bool = false


func start(level_bpm: float) -> void:
	if level_bpm <= 0:
		printerr("BPM must be positive.")
		return

	_bpm = level_bpm
	time_per_beat = 60.0 / _bpm
	song_position_in_beats = 0.0
	_is_running = true
	print("RhythmConductor started. BPM: %d, Time per beat: %.3fs" % [_bpm, time_per_beat])


func stop() -> void:
	_is_running = false


func _process(delta: float) -> void:
	if not _is_running:
		return
	# Avance la position dans la chanson en fonction du temps écoulé
	song_position_in_beats += delta / time_per_beat
