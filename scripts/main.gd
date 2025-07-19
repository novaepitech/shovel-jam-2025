extends Node2D

@export var note_scene: PackedScene
@export var beam_scene: PackedScene
@export var level_data_scene: PackedScene
@export var bpm: float = 120.0
@export var initial_scroll_speed: float = 400.0

# NOUVELLE VARIABLE: Définit le temps de "compte à rebours" avant la première note.
# 4.0 correspond à une mesure complète en 4/4.
@export var lead_in_beats: float = 4.0

@onready var world_container: Node2D = $WorldContainer
@onready var staff_lines: TextureRect = $WorldContainer/StaffLines
@onready var player: Player = $Player

var level_notes: Array[Note] = []


func _ready() -> void:
	SignalManager.speed_change_requested.connect(_on_speed_change_requested)

	build_level_layout()

	RhythmConductor.start(bpm)

	# L'initialisation du joueur ne le place plus, elle lui donne juste les données.
	# Le joueur gère sa propre course initiale.
	if not level_notes.is_empty():
		player.initialize_rhythmic_movement(level_notes)
	else:
		printerr("Level build completed, but no notes were found in the level data.")


func _on_speed_change_requested(new_speed: float):
	print("Visual scroll speed changed to %f" % new_speed)


func build_level_layout():
	var level_data_node = level_data_scene.instantiate()
	var all_nodes = level_data_node.get_children()

	all_nodes.sort_custom(func(a, b): return a.position.x < b.position.x)

	# On place la première note un peu en avant du joueur pour lui laisser de la place pour courir.
	var last_spawn_x: float = 500.0
	var previous_note_instance: Note = null
	var previous_note_data: NoteData = null

	# CHANGEMENT CLÉ: La partition ne commence pas à 0, mais après le "lead-in".
	var current_beat: float = lead_in_beats

	for i in range(all_nodes.size()):
		var node_data = all_nodes[i]
		if node_data is NoteData:
			var note_instance = note_scene.instantiate()
			note_instance.rhythmic_value = node_data.type
			note_instance.is_inverted = node_data.inverted

			note_instance.target_beat = current_beat

			# CORRECTION PRINCIPALE: On calcule l'espacement en fonction de la note PRÉCÉDENTE
			# Si c'est la première note, on utilise une noire par défaut
			var spacing_duration: float
			if previous_note_data == null:
				spacing_duration = 1.0  # Première note: espacement d'une noire
			else:
				spacing_duration = get_note_duration_in_beats(previous_note_data.type)

			var time_interval = spacing_duration * (60.0 / bpm)
			var distance_to_add = initial_scroll_speed * time_interval
			var new_x_pos = last_spawn_x + distance_to_add
			var new_y_pos = MusicTheory.get_y_for_pitch(node_data.pitch)

			note_instance.position = Vector2(new_x_pos, new_y_pos)
			world_container.add_child(note_instance)
			level_notes.append(note_instance)

			print("Note created for beat: %.2f | Type: %s | Spacing based on: %s" % [
				note_instance.target_beat,
				NoteData.NoteRhythmicValue.keys()[node_data.type],
				NoteData.NoteRhythmicValue.keys()[previous_note_data.type] if previous_note_data else "default"
			])

			# CORRECTION BEAMING: Vérification plus stricte
			if previous_note_instance and beam_scene and previous_note_data:
				var is_prev_beamable = previous_note_data.type in [NoteData.NoteRhythmicValue.CROCHE, NoteData.NoteRhythmicValue.DOUBLE_CROCHE]
				var is_curr_beamable = node_data.type in [NoteData.NoteRhythmicValue.CROCHE, NoteData.NoteRhythmicValue.DOUBLE_CROCHE]

				# Les deux notes doivent être beamables pour créer une ligature
				if is_prev_beamable and is_curr_beamable and (previous_note_data.inverted == node_data.inverted):
					_create_beam(previous_note_instance, note_instance)

			# Mise à jour pour la prochaine itération
			var current_note_duration = get_note_duration_in_beats(node_data.type)
			current_beat += current_note_duration
			last_spawn_x = new_x_pos
			previous_note_instance = note_instance
			previous_note_data = node_data

		elif node_data is SpeedTrigger:
			node_data.get_parent().remove_child(node_data)
			world_container.add_child(node_data)
			node_data.position.x = last_spawn_x

	staff_lines.size.x = last_spawn_x + get_viewport().get_visible_rect().size.x
	level_data_node.queue_free()


func _create_beam(start_note: Note, end_note: Note):
	var start_point = start_note.get_beam_connection_point()
	var end_point = end_note.get_beam_connection_point()
	var beam_instance = beam_scene.instantiate()
	world_container.add_child(beam_instance)
	var beam_vector = end_point - start_point

	beam_instance.position = start_point
	beam_instance.rotation = beam_vector.angle()

	const BEAM_TEXTURE_WIDTH = 64.0
	beam_instance.scale.x = beam_vector.length() / BEAM_TEXTURE_WIDTH


func get_note_duration_in_beats(note_type: NoteData.NoteRhythmicValue) -> float:
	match note_type:
		NoteData.NoteRhythmicValue.BLANCHE: return 2.0
		NoteData.NoteRhythmicValue.NOIRE: return 1.0
		NoteData.NoteRhythmicValue.CROCHE: return 0.5
		NoteData.NoteRhythmicValue.DOUBLE_CROCHE: return 0.25
		NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES: return 1.0 / 3.0
		NoteData.NoteRhythmicValue.SILENCE: return 1.0
	return 1.0
