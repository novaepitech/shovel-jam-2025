# res://scripts/main.gd
extends Node2D

@export var note_scene: PackedScene
@export var beam_scene: PackedScene
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

	# Variables to keep track of the previous note for beaming logic
	var previous_note_data: NoteData = null
	var previous_note_instance: Note = null

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

			# --- Beam Creation Logic ---
			# Beams are typically used for eighth (CROCHE) and sixteenth (DOUBLE) notes.
			# This simple logic connects consecutive beamable notes with a single bar.
			if previous_note_data and beam_scene: # Ensure previous note exists and beam scene is set
				var is_prev_beamable = (previous_note_data.type == NoteData.NoteType.CROCHE or \
										previous_note_data.type == NoteData.NoteType.DOUBLE)
				var is_curr_beamable = (node_data.type == NoteData.NoteType.CROCHE or \
										node_data.type == NoteData.NoteType.DOUBLE)
				
				# MODIFICATION: A beam can only form if both notes have the same orientation (both regular or both inverted).
				var have_same_orientation = (previous_note_data.inverted == node_data.inverted)

				if is_prev_beamable and is_curr_beamable and have_same_orientation:
					# Get the global positions for the stem connection points
					var start_point = previous_note_instance.get_beam_connection_point()
					var end_point = note_instance.get_beam_connection_point()

					var beam_instance = beam_scene.instantiate()
					world_container.add_child(beam_instance)

					# Calculate the vector from the start to the end point
					var beam_vector = end_point - start_point
					var beam_length = beam_vector.length()
					var beam_angle = beam_vector.angle() # Angle in radians

					# Position the beam at the start point (since its Sprite2D has centered=false)
					beam_instance.position = start_point
					beam_instance.rotation = beam_angle

					# Scale the beam horizontally to match the length
					# Assuming beam.png has an original width of 64 pixels (adjust if yours is different)
					const BEAM_TEXTURE_WIDTH = 64.0
					beam_instance.scale.x = beam_length / BEAM_TEXTURE_WIDTH

					# Set beam thickness (vertical scale). 1.0 means original texture height.
					# Adjust this to make the beam thinner/thicker if needed.
					beam_instance.scale.y = 1.0 # If beam.png is 16px high, this makes it 16px. Use 0.5 for 8px.

					# Set beam Z index to ensure it's behind notes if desired (notes are Z=1)
					beam_instance.z_index = 0 # Example: place behind notes

			# Updates the X position for the next object
			last_spawn_x = new_x_pos

			# Store this note's data and instance for the next iteration's beam check
			previous_note_data = node_data
			previous_note_instance = note_instance

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

			# Reset previous note data after a non-note element to prevent beaming across triggers
			previous_note_data = null
			previous_note_instance = null

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
