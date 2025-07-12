extends CharacterBody2D

@export var jump_velocity = -900.0
@export var rise_gravity_multiplier = 1.8
@export var fall_gravity_multiplier = 4.2

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_platform = null  # Track the last platform we were on

func _physics_process(delta):
    # Add the gravity with appropriate multiplier
    if not is_on_floor():
        if velocity.y > 0:  # When falling
            velocity.y += gravity * fall_gravity_multiplier * delta
        else:  # When rising
            velocity.y += gravity * rise_gravity_multiplier * delta

    # Handle Jump.
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

        # Check if we're jumping off a note
        if last_platform and last_platform.get_parent().is_in_group("notes"):
            var note = last_platform.get_parent()
            if note.has_method("on_player_jump"):
                note.on_player_jump()

    # Track current platform
    if is_on_floor():
        var collision = get_slide_collision(get_slide_collision_count() - 1) if get_slide_collision_count() > 0 else null
        if collision:
            last_platform = collision.get_collider()
    else:
        # Clear last platform when not on floor (to prevent multiple triggers)
        if velocity.y < 0:  # Only clear when jumping up
            last_platform = null

    move_and_slide()
