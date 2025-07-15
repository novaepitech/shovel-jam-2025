class_name Note
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var static_body: StaticBody2D = $StaticBody2D # Corrected _Body to Body

# Export variables to hold the configuration, replacing the initialize() function.
# These will be set by main.gd before the node is added to the scene.
@export var note_type: NoteData.NoteType = NoteData.NoteType.CROCHE
@export var is_inverted: bool = false

# Export variables to hold the different textures.
# We will assign these in the Godot Editor Inspector.
@export var texture_noire: Texture2D
@export var texture_croche: Texture2D # Corrected Texture22 to Texture2D
@export var texture_double: Texture2D

var original_position: Vector2
var is_bumping = false

# These offsets are relative to the Note's Node2D position (center of the note head).
# They determine where the beam should connect to the stem.
# These values are based on the typical visual structure of musical note sprites
# where the note head is at the bottom and the stem extends upwards.
# Adjust these values by trial and error if your sprites have a different layout
# or if the beam doesn't visually align well.
const BEAM_OFFSET_UP_STEM: float = -145.0 # For notes with upward stems (y is negative for 'up')
const BEAM_OFFSET_DOWN_STEM: float = 130.0 # For notes with downward stems (y is positive for 'down')

func _ready():
	original_position = sprite.position

	# 1. Set the correct texture based on the note type
	match note_type:
		NoteData.NoteType.NOIRE:
			sprite.texture = texture_noire
		NoteData.NoteType.CROCHE:
			sprite.texture = texture_croche
		NoteData.NoteType.DOUBLE:
			sprite.texture = texture_double
		_:
			# Fallback to a default texture if the type is unknown
			printerr("Note type not recognized or texture not set: ", NoteData.NoteType.keys()[note_type])
			sprite.texture = texture_croche # Default to croche

	# 2. Apply the flip properties if the note is inverted
	sprite.flip_v = is_inverted

## Returns the global position where a beam should connect to this note's stem.
func get_beam_connection_point() -> Vector2:
	var stem_offset_y: float
	if is_inverted:
		# Stem goes down, so beam connects to the 'bottom' end of the sprite's stem.
		stem_offset_y = BEAM_OFFSET_DOWN_STEM
	else:
		# Stem goes up, so beam connects to the 'top' end of the sprite's stem.
		stem_offset_y = BEAM_OFFSET_UP_STEM

	# The Note's Node2D position is its local origin.
	# The sprite is a child, and its local position is (0,0) relative to the Note.
	# So, we just add the determined Y offset to the Note's global position.
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

#func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	#queue_free()
