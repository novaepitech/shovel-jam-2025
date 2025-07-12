extends CharacterBody2D

@export var jump_velocity = -500.0 # Your standard jump velocity
@export var note_jump_range = 400.0 # Max X distance to consider a note for jumping
@export var note_jump_apex_height = 200.0 # How high the note jump apex is (pixels above start/end)
@export var note_jump_duration = 0.5 # Duration of the cool jump in seconds

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_jumping_to_note = false # State to prevent multiple note jumps
var current_tween: Tween = null # Reference to the active tween

@onready var level_1: Node2D = get_parent().get_node("Level1") # Assuming Player and Level1 are siblings under main.gd

func _physics_process(delta):
    # If currently performing a special note jump, skip regular physics
    if is_jumping_to_note:
        return

    # Add the gravity.
    if not is_on_floor():
        velocity.y += gravity * delta

    # Handle standard Jump.
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    move_and_slide()

func _input(event: InputEvent) -> void:
    # Use _input for action detection to ensure it's captured immediately
    if event.is_action_pressed("jump") and not is_jumping_to_note:
        var next_note_fall_point_pos = find_next_note_fall_point()
        if next_note_fall_point_pos != Vector2.ZERO: # Check if a valid fall point was found
            start_note_jump(next_note_fall_point_pos)
        elif is_on_floor(): # If no note jump possible, perform regular jump if on floor
            velocity.y = jump_velocity
            # Note: move_and_slide() will be called in _physics_process

func find_next_note_fall_point() -> Vector2:
    var closest_note_fall_point: Vector2 = Vector2.ZERO
    var min_dist_x = INF # Initialize with infinity

    for node in level_1.get_children():
        # Check if the node is part of the "notes" group
        if node.is_in_group("notes"):
            var fall_point_marker = node.find_child("FallPoint")
            if fall_point_marker:
                var fall_point_global_pos = fall_point_marker.global_position

                # Check if the fall point is ahead of the player
                if fall_point_global_pos.x > global_position.x:
                    var dist_x = fall_point_global_pos.x - global_position.x

                    # Check if it's within the horizontal range for a jump
                    if dist_x < note_jump_range:
                        if dist_x < min_dist_x:
                            min_dist_x = dist_x
                            closest_note_fall_point = fall_point_global_pos
                            # Consider vertical alignment too, if needed, but horizontal is primary for "next"
                            # For example, if abs(fall_point_global_pos.y - global_position.y) > some_threshold, maybe skip?

    return closest_note_fall_point

func start_note_jump(target_fall_point_global_pos: Vector2):
    is_jumping_to_note = true
    # Stop any current velocity and temporarily disable regular physics processing
    velocity = Vector2.ZERO
    set_physics_process(false) # Player won't be affected by gravity or normal movement

    var start_pos = global_position
    var end_pos = target_fall_point_global_pos

    # Calculate a control point for a quadratic Bezier curve
    # The control point defines the arc's peak
    var mid_x = (start_pos.x + end_pos.x) / 2
    var apex_y = min(start_pos.y, end_pos.y) - note_jump_apex_height # Apex is above the higher point
    var control_pos = Vector2(mid_x, apex_y)

    # Create and start the Tween
    if current_tween:
        current_tween.kill() # Stop any previous tween if it's still running (unlikely due to is_jumping_to_note)
    current_tween = get_tree().create_tween()
    current_tween.set_trans(Tween.TRANS_SINE) # Smooth transition
    current_tween.set_ease(Tween.EASE_IN_OUT) # Smooth in and out of the arc

    # Use tween_method to animate the global_position along the Bezier curve
    # The _tween_bezier_position method will be called repeatedly with 't' from 0.0 to 1.0
    current_tween.tween_method(Callable(self, "_tween_bezier_position").bind(start_pos, control_pos, end_pos), 0.0, 1.0, note_jump_duration)

    # After the position tween, call a cleanup function
    current_tween.chain().tween_callback(Callable(self, "_on_note_jump_finished"))

func _tween_bezier_position(t: float, p0: Vector2, p1: Vector2, p2: Vector2):
    # Quadratic Bezier curve formula: P(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
    global_position = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2

func _on_note_jump_finished():
    is_jumping_to_note = false
    set_physics_process(true) # Re-enable regular physics processing
    current_tween = null # Clear tween reference

    # Apply a small downward velocity to ensure the player settles on the floor
    # and `is_on_floor()` can become true if the target is a platform.
    velocity.y = 100 # Adjust as needed
    # move_and_slide() will be called in the next _physics_process frame.
