class_name Note
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var static_body: StaticBody2D = $StaticBody2D

var target_beat: float = 0.0

@export var note_type: NoteData.NoteType = NoteData.NoteType.CROCHE
@export var is_inverted: bool = false

var required_action: GameActions.Type

@export var texture_noire: Texture2D
@export var texture_croche: Texture2D
@export var texture_double: Texture2D

var original_position: Vector2
var is_bumping = false

const BEAM_OFFSET_UP_STEM: float = -145.0
const BEAM_OFFSET_DOWN_STEM: float = 130.0

func _ready():
	original_position = sprite.position
	
	required_action = NoteData.get_required_action_for_type(note_type)

	match note_type:
		NoteData.NoteType.NOIRE:
			sprite.texture = texture_noire
		NoteData.NoteType.CROCHE:
			sprite.texture = texture_croche
		NoteData.NoteType.DOUBLE:
			sprite.texture = texture_double
		_:
			printerr("Note type not recognized or texture not set: ", NoteData.NoteType.keys()[note_type])
			sprite.texture = texture_croche

	sprite.flip_v = is_inverted

func get_beam_connection_point() -> Vector2:
	var stem_offset_y: float
	if is_inverted:
		stem_offset_y = BEAM_OFFSET_DOWN_STEM
	else:
		stem_offset_y = BEAM_OFFSET_UP_STEM
	return global_position + Vector2(0, stem_offset_y)


func bump():
	if is_bumping:
		return
	is_bumping = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "position", original_position + Vector2(0, 8), 0.1)
	tween.tween_property(sprite, "position", original_position, 0.2)
	tween.tween_callback(func(): is_bumping = false)

func on_player_jump():
	bump()
