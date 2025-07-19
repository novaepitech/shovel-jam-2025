@tool
class_name NoteData
extends Marker2D

# Voici notre NOUVELLE énumération, propre, correcte et complète.
# L'ordre est maintenant logique.
enum NoteRhythmicValue {
	SILENCE,
	BLANCHE,       # 2 temps
	NOIRE,         # 1 temps
	CROCHE,        # 0.5 temps
	DOUBLE_CROCHE, # 0.25 temps
	TRIOLET_DE_CROCHES
}

# La variable exportée utilise la nouvelle énumération. Les nouvelles notes
# que vous placerez utiliseront ce nouveau système directement.
@export var type: NoteRhythmicValue = NoteRhythmicValue.NOIRE

@export var pitch: MusicTheory.Pitch = MusicTheory.Pitch.SOL_LINE2:
	set = _set_pitch

@export var inverted: bool = false

# La logique des actions requises est mise à jour en se basant sur le GDD.
# Croche -> Pas
# Double-croche -> Petit pas
static func get_required_action_for_type(note_type: NoteRhythmicValue) -> GameActions.Type:
	match note_type:
		NoteRhythmicValue.BLANCHE:
			return GameActions.Type.SAUT
		NoteRhythmicValue.NOIRE:
			return GameActions.Type.PAS
		NoteRhythmicValue.CROCHE:
			# D'après le GDD, "Alterner Petits Pas" est pour les double-croches.
			# Nous assignons donc "Pas" à la croche.
			return GameActions.Type.PAS
		NoteRhythmicValue.DOUBLE_CROCHE:
			# Et "Petit Pas" à la double-croche, comme sur la diapo 3.
			return GameActions.Type.PETIT_PAS
		_:
			return GameActions.Type.PAS


func _ready():
	if Engine.is_editor_hint():
		_update_position_from_pitch()

func _set_pitch(new_pitch_value: MusicTheory.Pitch):
	pitch = new_pitch_value
	if Engine.is_editor_hint():
		property_list_changed.emit()
		_update_position_from_pitch()

func _update_position_from_pitch():
	var new_y = MusicTheory.get_y_for_pitch(pitch)
	position.y = new_y
