@tool
class_name NoteData
extends Marker2D

# We need to explicitly load the script resource for the tool to find it.
#const MusicTheory = preload("res://scripts/music_theory.gd")


# This enum is unchanged
enum NoteType {
	SILENCE,
	CROCHE,
	DOUBLE,
	TRIOLET,
	NOIRE,
}

@export var type: NoteType = NoteType.CROCHE

# Refer to the enum via the preloaded script
@export var pitch: MusicTheory.Pitch = MusicTheory.Pitch.SOL_LINE2:
	set = _set_pitch

# This will show up as a checkbox in the Inspector.
@export var inverted: bool = false

func _ready():
	if Engine.is_editor_hint():
		_update_position_from_pitch()

func _set_pitch(new_pitch_value: MusicTheory.Pitch):
	pitch = new_pitch_value

	if Engine.is_editor_hint():
		# This property is used by the editor to know that something has changed
		# and the scene needs to be marked as "unsaved". It's good practice.
		property_list_changed.emit()
		_update_position_from_pitch()

func _update_position_from_pitch():
	# This call will now work correctly because we are using our preloaded constant.
	var new_y = MusicTheory.get_y_for_pitch(pitch)
	position.y = new_y
