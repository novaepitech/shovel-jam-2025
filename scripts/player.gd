class_name Player
extends CharacterBody2D

enum State { IDLE_ON_NOTE, MOVING_TO_NOTE, WAITING_FOR_FIRST_INPUT }
#const RHYTHM_WINDOW_BEATS = 0.0625
const RHYTHM_WINDOW_BEATS = 1.5

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.WAITING_FOR_FIRST_INPUT
var _move_tween: Tween
var _landing_offset: Vector2 = Vector2.ZERO

@export var run_speed: float = 150.0
var jump_height: float = 160.0
var jump_time_to_peak: float = 0.4
var jump_time_to_descent: float = 0.3
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float

func _ready():
	jump_velocity = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
	jump_gravity = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
	fall_gravity = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
	
	# --- CALCUL DE L'OFFSET D'ATTERRISSAGE ---
	# On calcule dynamiquement la distance entre le centre du joueur et ses pieds.
	var collision_shape = $CollisionShape2D
	# S'assurer que la shape est bien un rectangle
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# La hauteur du joueur est la taille Y de sa collision shape.
		# L'offset vertical est la moitié de cette hauteur, en négatif (pour monter).
		var player_height = collision_shape.shape.size.y
		_landing_offset.y = -player_height / 2.0
		# On peut aussi ajouter un petit offset X si on veut que le joueur
		# atterrisse légèrement à gauche de la tête de la note.
		_landing_offset.x = -60.0
		_landing_offset.y = -55.0
	else:
		printerr("Player's collision shape not found or not a RectangleShape2D. Landing will be off.")

func _physics_process(delta):
	match _state:
		State.WAITING_FOR_FIRST_INPUT:
			velocity.x = run_speed
			velocity.y += get_custom_gravity() * delta
			move_and_slide()
			
			if Input.is_action_just_pressed("jump"):
				velocity.x = 0
				_attempt_rhythmic_action("jump")

		State.IDLE_ON_NOTE:
			if Input.is_action_just_pressed("jump"):
				_attempt_rhythmic_action("jump")
			elif Input.is_action_just_pressed("pas"):
				_attempt_rhythmic_action("pas")

		State.MOVING_TO_NOTE:
			pass

func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	if not _note_sequence.is_empty():
		_current_note_index = -1
	else:
		print("Level is empty.")

func _attempt_rhythmic_action(action_type: String):
	# --- LOGIQUE DE CALIBRATION ---
	# Si le joueur est sur la plateforme de départ, cette action va CALIBRER l'horloge.
	# Elle ne sera pas jugée sur le rythme, elle le définit.
	if _state == State.WAITING_FOR_FIRST_INPUT:
		RhythmConductor.calibrate()
		_initiate_move_to_next_note(action_type)
		return

	# Pour toutes les actions suivantes, on utilise le système de validation.
	if _state == State.IDLE_ON_NOTE:
		var input_beat = RhythmConductor.song_position_in_beats
		var current_note = _note_sequence[_current_note_index]
		
		# On récupère le temps cible CALIBRÉ.
		var target_beat = RhythmConductor.get_calibrated_target_beat(current_note.target_beat)

		var offset = abs(input_beat - target_beat)
		
		print("Input at beat: %f | Calibrated Target: %f | Offset: %f" % [input_beat, target_beat, offset])

		if offset <= RHYTHM_WINDOW_BEATS:
			print(" -> SUCCESS!")
			_initiate_move_to_next_note(action_type)
		else:
			print(" -> FAILURE!")
			get_tree().change_scene_to_file("res://scenes/game_over_screen.tscn")

# Cette fonction est maintenant appelée uniquement après une validation réussie.
func _initiate_move_to_next_note(action_type: String):
	var next_note_index: int
	if _state == State.WAITING_FOR_FIRST_INPUT:
		next_note_index = 0
	else:
		next_note_index = _current_note_index + 1

	if next_note_index >= _note_sequence.size():
		print("End of the level!")
		return

	var previous_state_snapshot = _state
	_state = State.MOVING_TO_NOTE
	
	var start_pos: Vector2
	if previous_state_snapshot == State.WAITING_FOR_FIRST_INPUT:
		start_pos = global_position
	else:
		start_pos = _note_sequence[_current_note_index].global_position + _landing_offset

	# We calculate the final destination *with the offset* before starting the tween.
	var target_note_pos = _note_sequence[next_note_index].global_position
	var end_pos: Vector2 = target_note_pos + _landing_offset

	_execute_tween_movement(start_pos, end_pos, action_type, previous_state_snapshot)

func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: String, previous_state: State):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	var time_per_beat = 60.0 / RhythmConductor._bpm
	
	# La durée du mouvement doit correspondre à la durée de la note actuelle
	var move_duration = time_per_beat # Par défaut 1 beat
	if previous_state == State.IDLE_ON_NOTE:
		var current_note_data = _note_sequence[_current_note_index]
		var note_duration_in_beats = get_parent().get_note_duration_in_beats(current_note_data.note_type)
		move_duration = note_duration_in_beats * time_per_beat
	
	var control_point_1: Vector2
	var mid_point = start_pos.lerp(end_pos, 0.5)
	var delta_y = end_pos.y - start_pos.y

	match action_type:
		"jump":
			control_point_1 = mid_point + Vector2(0, -250 - (delta_y * 0.5))
		"pas":
			control_point_1 = mid_point + Vector2(0, -50 - (delta_y * 0.5))
		_:
			control_point_1 = mid_point

	_move_tween.tween_method(
		_update_position_along_curve.bind(start_pos, control_point_1, end_pos),
		0.0, 1.0, move_duration
	).set_trans(Tween.TRANS_LINEAR)

	_move_tween.tween_callback(_on_movement_finished.bind(previous_state))


func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	var curve_pos = start.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t)
	global_position = curve_pos


func _on_movement_finished(previous_state: State):
	print("Movement finished.")
	
	if previous_state == State.WAITING_FOR_FIRST_INPUT:
		print("First move complete. Disabling starting floor.")
		var floor_node = get_parent().get_node_or_null("Floor")
		if floor_node:
			floor_node.get_node("CollisionShape2D").disabled = true
		else:
			printerr("Could not find 'Floor' node to disable it.")
	
	if _current_note_index < 0:
		_current_note_index = 0
	else:
		_current_note_index += 1
	
	_state = State.IDLE_ON_NOTE
	
	var target_note_pos = _note_sequence[_current_note_index].global_position
	# On applique l'offset calculé pour que les pieds du joueur soient au bon endroit.
	global_position = target_note_pos + _landing_offset
	
	_note_sequence[_current_note_index].bump()


func get_custom_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity
