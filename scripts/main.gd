# Arpeggio/scripts/main.gd
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
			# --- CORRECTION ET REFACTORING ---
			# 1. On récupère la durée en "beats" de la note une seule fois.
			var duration_in_beats = get_note_duration_in_beats(node_data.type)
			
			var note_instance = note_scene.instantiate()
			note_instance.note_type = node_data.type
			note_instance.is_inverted = node_data.inverted
			
			# 2. On assigne le temps cible à la note.
			note_instance.target_beat = current_beat

			# 3. On calcule l'intervalle spatial en utilisant la durée en beats.
			var time_interval = duration_in_beats * time_per_beat
			var distance_to_add = temp_scroll_speed * time_interval
			var new_x_pos = last_spawn_x + distance_to_add
			var new_y_pos = MusicTheory.get_y_for_pitch(node_data.pitch)

			note_instance.position = Vector2(new_x_pos, new_y_pos)
			world_container.add_child(note_instance)
			
			level_notes.append(note_instance)
			
			print("Note created at beat: ", note_instance.target_beat, " | Type: ", NoteData.NoteType.keys()[note_instance.note_type], " | Duration (beats): ", duration_in_beats)
			
			# 4. On avance notre horloge musicale pour la note suivante.
			# Cette ligne est maintenant correctement placée et la logique est saine.
			current_beat += duration_in_beats
			
			# (La logique de création des ligatures reste inchangée)
			if previous_note_data and beam_scene:
				var is_prev_beamable = (previous_note_data.type == NoteData.NoteType.CROCHE or \
										previous_note_data.type == NoteData.NoteType.DOUBLE)
				var is_curr_beamable = (node_data.type == NoteData.NoteType.CROCHE or \
										node_data.type == NoteData.NoteType.DOUBLE)
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
	
	if not level_notes.is_empty():
		player.initialize_rhythmic_movement(level_notes)
	else:
		printerr("Level build completed, but no notes were found in the level data.")


# La fonction `calculate_wait_time_for_note` a été supprimée.
# Elle est remplacée par cette unique fonction de référence.
func get_note_duration_in_beats(note_type: NoteData.NoteType) -> float:
	# La valeur de base est la noire (quarter note), qui vaut 1 beat.
	# NOTE: Les noms de l'enum peuvent prêter à confusion. On se base sur leur
	# utilisation dans le code original pour déduire leur valeur rythmique.
	# - NoteType.CROCHE dans le code se comporte comme une NOIRE (1 beat)
	# - NoteType.DOUBLE se comporte comme une CROCHE (0.5 beat)
	# - NoteType.NOIRE se comporte comme une BLANCHE (2 beats)
	match note_type:
		NoteData.NoteType.CROCHE:
			return 1.0 # 1 beat (équivalent Noire)
		NoteData.NoteType.DOUBLE:
			return 0.5 # 0.5 beat (équivalent Croche)
		NoteData.NoteType.TRIOLET:
			return 1.0 / 3.0 # 1/3 beat (Triolet de doubles-croches)
		NoteData.NoteType.NOIRE:
			return 2.0 # 2 beats (équivalent Blanche)
		NoteData.NoteType.SILENCE:
			return 1.0 # 1 beat (équivalent Soupir)
	return 1.0 # Valeur par défaut
