extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var static_body: StaticBody2D = $StaticBody2D

# --- NEW ---
# Export variables to hold the different textures.
# We will assign these in the Godot Editor Inspector.
@export var texture_noire: Texture2D
@export var texture_croche: Texture2D
@export var texture_double: Texture2D
# Note: We don't add Triolet yet, as requested.

var original_position: Vector2
var is_bumping = false

func _ready():
    original_position = sprite.position

# --- NEW ---
# This function will be called by main.gd to set the note's appearance.
func set_type(type: NoteData.NoteType):
    match type:
        NoteData.NoteType.NOIRE:
            sprite.texture = texture_noire
        NoteData.NoteType.CROCHE:
            sprite.texture = texture_croche
        NoteData.NoteType.DOUBLE:
            sprite.texture = texture_double
        _:
            # Fallback to a default texture if the type is unknown or not handled
            printerr("Note type not recognized or texture not set: ", NoteData.NoteType.keys()[type])
            sprite.texture = texture_croche # Default to croche

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
