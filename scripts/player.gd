extends CharacterBody2D

@export var jump_height: float
@export var jump_time_to_peak: float
@export var jump_time_to_descent: float

var jump_velocity: float
var jump_gravity: float
var fall_gravity: float

# Variable to store a reference to the body we are standing on
var current_floor_collider = null
# State to track if the player has made their first jump
var has_jumped_once: bool = false

func _ready():
    jump_velocity = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
    jump_gravity = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
    fall_gravity = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

func _physics_process(delta):
    velocity.y += get_custom_gravity() * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        var is_on_a_note = false
        var note_node = null

        # Check if the floor collider belongs to a note
        if current_floor_collider:
            var floor_parent = current_floor_collider.get_parent()
            if floor_parent and floor_parent.is_in_group("notes"):
                is_on_a_note = true
                note_node = floor_parent

        # --- NEW JUMP LOGIC ---
        if not has_jumped_once:
            # The first jump is always allowed, regardless of what's below.
            if is_on_a_note:
                note_node.on_player_jump()
            jump()
            has_jumped_once = true
        else:
            # For all subsequent jumps, the player MUST be on a note.
            if is_on_a_note:
                # Successful jump on a note
                note_node.on_player_jump()
                jump()
            else:
                # Failed jump (not on a note), switch to game over screen.
                get_tree().change_scene_to_file("res://scenes/game_over_screen.tscn")

    move_and_slide()

    # After moving, update our reference to the current floor for the *next* frame.
    # This is the reliable Godot 4 way to get the floor collider.
    update_floor_collider_reference()


func update_floor_collider_reference():
    # Loop through all collisions that happened in the last move_and_slide() call
    for i in range(get_slide_collision_count()):
        var collision = get_slide_collision(i)

        # get_floor_normal() is a built-in helper that gives us the floor's normal vector.
        # We check if the collision's normal matches it. This correctly identifies the floor.
        if collision.get_normal().is_equal_approx(get_floor_normal()):
            current_floor_collider = collision.get_collider()
            return # Exit the loop once we've found the floor

    # If no floor collision was found (e.g., we are in the air), clear the reference.
    current_floor_collider = null


func get_custom_gravity() -> float:
    return jump_gravity if velocity.y < 0.0 else fall_gravity

func jump():
    velocity.y = jump_velocity
