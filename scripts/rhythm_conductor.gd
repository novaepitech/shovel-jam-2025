# Arpeggio/scripts/rhythm_conductor.gd
extends Node

var song_position_in_beats: float = 0.0
var _bpm: float = 120.0
var _is_running: bool = false

# --- NOUVELLES VARIABLES POUR LA CALIBRATION ---
# L'offset qui décale la partition pour l'aligner sur l'action du joueur.
var _song_start_offset_beats: float = 0.0
# Un drapeau pour savoir si la calibration a déjà eu lieu.
var _is_calibrated: bool = false


func start(level_bpm: float) -> void:
	_bpm = level_bpm
	song_position_in_beats = 0.0
	_is_running = true
	# On réinitialise l'état de calibration à chaque démarrage de niveau.
	_song_start_offset_beats = 0.0
	_is_calibrated = false
	print("RhythmConductor started with BPM: ", _bpm)


func stop() -> void:
	_is_running = false


func _process(delta: float) -> void:
	if not _is_running:
		return
	song_position_in_beats += (_bpm / 60.0) * delta


# --- NOUVELLES FONCTIONS ---

## Calibre le début de la partition sur la première action du joueur.
## Ne doit être appelé qu'une seule fois par niveau.
func calibrate():
	if not _is_calibrated:
		_song_start_offset_beats = song_position_in_beats
		_is_calibrated = true
		print("RhythmConductor CALIBRATED! Offset is: ", _song_start_offset_beats)

## Retourne le temps cible réel pour une note, en tenant compte de l'offset.
func get_calibrated_target_beat(note_target_beat: float) -> float:
	return note_target_beat + _song_start_offset_beats
