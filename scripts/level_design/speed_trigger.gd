# res://scripts/level_design/SpeedTrigger.gd
class_name SpeedTrigger
extends Area2D

## The new scroll speed (in pixels/second) to apply
## when the player touches this trigger.
@export var new_speed: float = 600.0

func _ready():
    # Connect the Area2D signal to our own function.
    # This is cleaner than doing it via the editor for a reusable scene.
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
    # Check if the entered body is indeed the player.
    # Using groups is perfect for this.
    # (Make sure your Player is in the "player" group).
    if body.is_in_group("player"):
        # "Post" our message on the global billboard.
        # We say: "Hey everyone, someone requested a speed change!"
        # and attach the new value.
        SignalManager.speed_change_requested.emit(new_speed)

        # Disable collision to prevent being triggered again.
        # queue_free() also works, but disabling collision is safer
        # if something else depends on this node during the frame.
        $CollisionShape2D.disabled = true
