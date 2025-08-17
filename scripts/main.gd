extends Node2D

@export var note_scene: PackedScene
@export var level_data_scene: PackedScene
@export var bpm: float = 120.0
@export var initial_scroll_speed: float = 400.0
@export var lead_in_beats: float = 4.0

@onready var world_container: Node2D = $WorldContainer
@onready var staff_lines: TextureRect = $WorldContainer/StaffLines
@onready var player: Player = $Player
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var level_notes: Array[Note] = []


func _ready() -> void:
	SignalManager.speed_change_requested.connect(_on_speed_change_requested)
	player.player_failed.connect(_on_player_failed)
	player.level_finished.connect(_on_level_finished)

	build_level_layout()

	RhythmConductor.start(bpm)

	if not level_notes.is_empty():
		player.initialize_rhythmic_movement(level_notes)
	else:
		printerr("Level build completed, but no notes were found in the level data.")

func _on_player_failed():
	music_player.stop()

	GameState.decrease_life()
	var remaining_lives = GameState.get_current_lives()
	print("Player failed. Lives remaining: %d" % remaining_lives)

	if remaining_lives <= 0:
		print("GAME OVER. No lives left.")
		get_tree().change_scene_to_file("res://scenes/game_over_screen.tscn")
	else:
		await get_tree().create_timer(1.5).timeout
		get_tree().reload_current_scene()

func _on_level_finished():
	music_player.stop()
	print("LEVEL COMPLETE! Transitioning to win screen.")
	get_tree().change_scene_to_file("res://scenes/win_screen.tscn")

func _on_speed_change_requested(new_speed: float):
	print("Visual scroll speed changed to %f" % new_speed)


func build_level_layout():
	var level_data_node = level_data_scene.instantiate()
	var all_nodes = level_data_node.get_children()

	all_nodes.sort_custom(func(a, b): return a.position.x < b.position.x)

	var last_spawn_x: float = 500.0
	var previous_note_instance: Note = null
	var previous_note_data: NoteData = null

	var current_beat: float = lead_in_beats

	for i in range(all_nodes.size()):
		var node_data = all_nodes[i]
		if node_data is NoteData:
			var note_instance = note_scene.instantiate()
			note_instance.rhythmic_value = node_data.type
			note_instance.is_inverted = node_data.inverted

			var spacing_duration: float
			if previous_note_data == null:
				spacing_duration = 1.0
			else:
				spacing_duration = get_note_duration_in_beats(previous_note_data.type)

			var time_interval = spacing_duration * (60.0 / bpm)
			var distance_to_add = initial_scroll_speed * time_interval
			var new_x_pos = last_spawn_x + distance_to_add
			var new_y_pos = MusicTheory.get_y_for_pitch(node_data.pitch)

			current_beat += spacing_duration
			note_instance.target_beat = current_beat

			note_instance.position = Vector2(new_x_pos, new_y_pos)
			world_container.add_child(note_instance)
			level_notes.append(note_instance)

			last_spawn_x = new_x_pos
			previous_note_instance = note_instance
			previous_note_data = node_data

		elif node_data is SpeedTrigger:
			node_data.get_parent().remove_child(node_data)
			world_container.add_child(node_data)
			node_data.position.x = last_spawn_x

	staff_lines.size.x = last_spawn_x + get_viewport().get_visible_rect().size.x
	level_data_node.queue_free()


func get_note_duration_in_beats(note_type: NoteData.NoteRhythmicValue) -> float:
	match note_type:
		NoteData.NoteRhythmicValue.BLANCHE: return 2.0
		NoteData.NoteRhythmicValue.NOIRE: return 1.0
		NoteData.NoteRhythmicValue.CROCHE: return 0.5
		NoteData.NoteRhythmicValue.DOUBLE_CROCHE: return 0.25
		NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES: return 1.0 / 3.0
		NoteData.NoteRhythmicValue.SILENCE: return 1.0
		NoteData.NoteRhythmicValue.DEMI_SILENCE: return 0.5
	return 1.0
