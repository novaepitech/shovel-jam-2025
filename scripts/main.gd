# res://scripts/main.gd
extends Node2D

@export var note_scene: PackedScene
@export var level_data_scene: PackedScene
@export var bpm: float = 120.0
@export var initial_scroll_speed: float = 400.0

# The note spawning Timer is no longer needed.
@onready var world_container: Node2D = $WorldContainer
@onready var staff_lines: TextureRect = $WorldContainer/StaffLines

var beat_duration: float
var current_scroll_speed: float


func _ready() -> void:
	SignalManager.speed_change_requested.connect(_on_speed_change_requested)

	beat_duration = 60.0 / bpm
	current_scroll_speed = initial_scroll_speed

	# We directly call our new function that builds the entire level at once.
	build_level_layout()


func _process(delta: float) -> void:
	# The _process function is now very simple, it only scrolls the world.
	world_container.position.x -= current_scroll_speed * delta


func _on_speed_change_requested(new_speed: float):
	print("Speed changed from %f to %f" % [current_scroll_speed, new_speed])
	current_scroll_speed = new_speed


# The _on_note_spawn_timer_timeout function is completely removed as there is no timer anymore.

# This single function replaces the old logic.
# It pre-calculates and places all level objects at once.
func build_level_layout():
	var level_data_node = level_data_scene.instantiate()
	var all_nodes = level_data_node.get_children()

	# Sorting nodes by their X position in the editor is crucial for processing order.
	all_nodes.sort_custom(func(a, b): return a.position.x < b.position.x)

	# --- Variables for our level construction simulation ---
	# Starts just to the right of the visible screen
	var last_spawn_x: float = get_viewport().get_visible_rect().size.x
	# "Simulated" speed that will change along the way
	var temp_scroll_speed: float = initial_scroll_speed

	# Iterate through each element defined in the level data scene
	for node_data in all_nodes:
		# CASE 1: The element is a note
		if node_data is NoteData:
			var note_instance = note_scene.instantiate()

			note_instance.note_type = node_data.type
			note_instance.is_inverted = node_data.inverted

			# Calculates the time this note represents
			var time_interval = calculate_wait_time_for_note(node_data.type)
			# Calculates the distance to add based on the CURRENT simulation speed
			var distance_to_add = temp_scroll_speed * time_interval

			# Calculates the final X position of the note
			var new_x_pos = last_spawn_x + distance_to_add
			var new_y_pos = MusicTheory.get_y_for_pitch(node_data.pitch)

			note_instance.position = Vector2(new_x_pos, new_y_pos)
			world_container.add_child(note_instance)

			# Updates the X position for the next object
			last_spawn_x = new_x_pos

		# CASE 2: The element is a speed trigger
		elif node_data is SpeedTrigger:
			# We need to move the trigger from the data scene to our game world
			node_data.get_parent().remove_child(node_data)
			world_container.add_child(node_data)

			# Place it at the current X position, without adding distance
			node_data.position.x = last_spawn_x
			# It can be vertically centered for better visibility
			node_data.position.y = 0

			# CRUCIAL UPDATE: we change the speed for the next calculations!
			temp_scroll_speed = node_data.new_speed
			print("Simulated speed change to ", temp_scroll_speed, " at X position: ", last_spawn_x)

	# Update the size of the staff lines to cover the entire level
	staff_lines.size.x = last_spawn_x + get_viewport().get_visible_rect().size.x
	print("Level built. Total length of staff lines: ", staff_lines.size.x)

	# Le noeud de données et ses enfants (les modèles NoteData) ne sont plus nécessaires
	level_data_node.queue_free()


func calculate_wait_time_for_note(note_type: NoteData.NoteType) -> float:
	match note_type:
		NoteData.NoteType.CROCHE: return beat_duration
		NoteData.NoteType.DOUBLE: return beat_duration / 2.0
		NoteData.NoteType.TRIOLET: return beat_duration / 3.0
		NoteData.NoteType.NOIRE: return beat_duration * 2.0
		NoteData.NoteType.SILENCE: return beat_duration
	return beat_duration
