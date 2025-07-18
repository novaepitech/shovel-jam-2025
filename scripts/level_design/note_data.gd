@tool
class_name NoteData
extends Marker2D

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

# Cette fonction associe un type de note à l'action requise pour la valider.
static func get_required_action_for_type(note_type: NoteType) -> GameActions.Type:
	match note_type:
		# Selon le GDD et le code existant:
		# - NOIRE (utilisé comme une blanche) -> Grand saut
		# - CROCHE (utilisé comme une noire) -> Pas normal
		# - DOUBLE (utilisé comme une croche) -> Petit pas
		NoteType.NOIRE:
			return GameActions.Type.SAUT
		NoteType.CROCHE:
			return GameActions.Type.PAS
		NoteData.NoteType.DOUBLE:
			return GameActions.Type.PETIT_PAS
		_:
			# Par défaut, on peut retourner une action simple ou une erreur.
			# Pour l'instant, on considère que les autres types utilisent un 'PAS'.
			return GameActions.Type.PAS

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
