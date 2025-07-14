extends Node2D

@onready var sprite = $Sprite2D
@onready var static_body = $StaticBody2D

var original_position: Vector2
var is_bumping = false

func _ready():
    original_position = sprite.position

func bump():
    if is_bumping:
        return
    
    is_bumping = true
    
    # Create a tween for the bump effect
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_BACK)
    
    # Bump down
    tween.tween_property(sprite, "position", original_position + Vector2(0, 8), 0.1)
    # Bump back up
    tween.tween_property(sprite, "position", original_position, 0.2)
    
    # Reset bumping state when done
    tween.tween_callback(func(): is_bumping = false)

# Call this when player successfully jumps off the note
func on_player_jump():
    bump()


#func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    #queue_free()
