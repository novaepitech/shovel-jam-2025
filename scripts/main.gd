extends Node2D

@export var note_scene: PackedScene
@export var beam_scene: PackedScene
@export var level_data_scene: PackedScene
@export var bpm: float = 120.0
@export var initial_scroll_speed: float = 400.0

@onready var world_container: Node2D = $WorldContainer
@onready var staff_lines: TextureRect = $WorldContainer/StaffLines
@onready var player: Player = $Player

# Durée d'un beat en secondes (par exemple, 0.5s pour 120 BPM)
var time_per_beat: float
var current_scroll_speed: float
var level_notes: Array[Note] = []


func _ready() -> void:
	SignalManager.speed_change_requested.connect(_on_speed_change_requested)

	# Renommé 'beat_duration' en 'time_per_beat' pour plus de clarté
	time_per_beat = 60.0 / bpm
	current_scroll_speed = initial_scroll_speed

	RhythmConductor.start(bpm)

	build_level_layout()

	if not level_notes.is_empty():
			player.initialize_rhythmic_movement(level_notes)
	else:
		printerr("Level build completed, but no notes were found in the level data.")


func _on_speed_change_requested(new_speed: float):
	print("Speed changed from %f to %f" % [current_scroll_speed, new_speed])
	current_scroll_speed = new_speed


func build_level_layout():
	var level_data_node = level_data_scene.instantiate()
	var all_nodes = level_data_node.get_children()

	all_nodes.sort_custom(func(a, b): return a.position.x < b.position.x)

	var last_spawn_x: float = get_viewport().get_visible_rect().size.x
	var temp_scroll_speed: float = initial_scroll_speed
	var previous_note_data: NoteData = null
	var previous_note_instance: Note = null

	var current_beat: float = 0.0

	for node_data in all_nodes:
		if node_data is NoteData:
			# La traduction n'est plus nécessaire. `node_data.type` est maintenant correct.
			var duration_in_beats = get_note_duration_in_beats(node_data.type)

			var note_instance = note_scene.instantiate()

			# On assigne directement la valeur correcte.
			note_instance.rhythmic_value = node_data.type
			note_instance.is_inverted = node_data.inverted
			note_instance.target_beat = current_beat

			var time_interval = duration_in_beats * time_per_beat
			var distance_to_add = temp_scroll_speed * time_interval
			var new_x_pos = last_spawn_x + distance_to_add
			var new_y_pos = MusicTheory.get_y_for_pitch(node_data.pitch)

			note_instance.position = Vector2(new_x_pos, new_y_pos)
			world_container.add_child(note_instance)
			level_notes.append(note_instance)

			print("Note created at beat: ", note_instance.target_beat, " | Type: ", NoteData.NoteRhythmicValue.keys()[node_data.type], " | Duration (beats): ", duration_in_beats)

			current_beat += duration_in_beats

			if previous_note_data and beam_scene:
				# On utilise directement les types des données de note.
				var is_prev_beamable = previous_note_data.type in [NoteData.NoteRhythmicValue.CROCHE, NoteData.NoteRhythmicValue.DOUBLE_CROCHE, NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES]
				var is_curr_beamable = node_data.type in [NoteData.NoteRhythmicValue.CROCHE, NoteData.NoteRhythmicValue.DOUBLE_CROCHE, NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES]
				var have_same_orientation = (previous_note_data.inverted == node_data.inverted)

				if is_prev_beamable and is_curr_beamable and have_same_orientation:
					var start_point = previous_note_instance.get_beam_connection_point()
					var end_point = note_instance.get_beam_connection_point()
					var beam_instance = beam_scene.instantiate()
					world_container.add_child(beam_instance)
					var beam_vector = end_point - start_point
					var beam_length = beam_vector.length()
					var beam_angle = beam_vector.angle()
					beam_instance.position = start_point
					beam_instance.rotation = beam_angle
					const BEAM_TEXTURE_WIDTH = 64.0
					beam_instance.scale.x = beam_length / BEAM_TEXTURE_WIDTH
					beam_instance.scale.y = 1.0
					beam_instance.z_index = 0

			last_spawn_x = new_x_pos
			previous_note_data = node_data
			previous_note_instance = note_instance

		elif node_data is SpeedTrigger:
			node_data.get_parent().remove_child(node_data)
			world_container.add_child(node_data)
			node_data.position.x = last_spawn_x
			node_data.position.y = 0
			temp_scroll_speed = node_data.new_speed
			print("Simulated speed change to ", temp_scroll_speed, " at X position: ", last_spawn_x)
			previous_note_data = null
			previous_note_instance = null

	staff_lines.size.x = last_spawn_x + get_viewport().get_visible_rect().size.x
	print("Level built. Total length of staff lines: ", staff_lines.size.x)

	level_data_node.queue_free()


# La fonction `calculate_wait_time_for_note` a été supprimée.
# Elle est remplacée par cette unique fonction de référence.
func get_note_duration_in_beats(note_type: NoteData.NoteRhythmicValue) -> float:
	match note_type:
		NoteData.NoteRhythmicValue.BLANCHE:
			return 2.0
		NoteData.NoteRhythmicValue.NOIRE:
			return 1.0
		NoteData.NoteRhythmicValue.CROCHE:
			return 0.5
		NoteData.NoteRhythmicValue.DOUBLE_CROCHE:
			return 0.25 # La voici !
		NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES:
			return 1.0 / 3.0
		NoteData.NoteRhythmicValue.SILENCE:
			return 1.0
	return 1.0
