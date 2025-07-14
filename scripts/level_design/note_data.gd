@tool
class_name NoteData
extends Marker2D

# --- CHANGE 1: Preload the MusicTheory script ---
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

# --- CHANGE 2: Refer to the enum via the preloaded script ---
# Instead of MusicTheory.Pitch, we use our constant: MusicTheory.Pitch
@export var pitch: MusicTheory.Pitch = MusicTheory.Pitch.SOL_LINE2:
    set = _set_pitch

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
