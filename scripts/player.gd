class_name Player
extends CharacterBody2D

enum State { IDLE_ON_NOTE, MOVING_TO_NOTE, WAITING_FOR_FIRST_INPUT }

const RHYTHM_WINDOW_BEATS = 2.5 # Fenêtre de tolérance (ajustez si besoin)

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.WAITING_FOR_FIRST_INPUT
var _move_tween: Tween
var _landing_offset: Vector2 = Vector2.ZERO

@export var run_speed: float = 150.0
# ... (les autres variables de saut sont inchangées)
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
	
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		_landing_offset.x = -60.0
		_landing_offset.y = -55.0
	else:
		printerr("Player's collision shape not found or not a RectangleShape2D. Landing will be off.")

func _physics_process(delta):
	# La logique de déplacement initial est inchangée
	if _state == State.WAITING_FOR_FIRST_INPUT:
		velocity.x = run_speed
		velocity.y += get_custom_gravity() * delta
		move_and_slide()
	
	# --- REFACTORING DE LA GESTION D'ENTRÉE ---
	var performed_action: GameActions.Type = _get_player_rhythmic_input()
	if performed_action != GameActions.Type.NONE:
		# Quel que soit l'état, si une action rythmique est tentée, on la valide.
		_attempt_rhythmic_action(performed_action)

# --- NOUVELLE FONCTION ---
# Exigence 1 & 2: Détecte une entrée et la mappe à une action de jeu.
# Pour l'instant, on utilise une détection simple "is_action_just_pressed" comme demandé.
func _get_player_rhythmic_input() -> GameActions.Type:
	if Input.is_action_just_pressed("saut"):
		return GameActions.Type.SAUT
	if Input.is_action_just_pressed("pas"):
		return GameActions.Type.PAS
	if Input.is_action_just_pressed("petit_pas"):
		return GameActions.Type.PETIT_PAS
	
	return GameActions.Type.NONE


func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	if not _note_sequence.is_empty():
		_current_note_index = -1
	else:
		print("Level is empty.")


# --- FONCTION ENTIÈREMENT REFACTORISÉE ---
# Exigence 4: Logique de validation complète (Timing + Type d'action).
func _attempt_rhythmic_action(performed_action: GameActions.Type):
	# Pour la toute première action, on ne valide rien, on calibre et on démarre.
	if _state == State.WAITING_FOR_FIRST_INPUT:
		RhythmConductor.calibrate()
		# On utilise l'action effectuée pour le premier mouvement.
		_initiate_move_to_next_note(performed_action)
		return

	# On ne peut agir que si on est en attente sur une note.
	if _state != State.IDLE_ON_NOTE:
		return

	# --- 1. VALIDATION TEMPORELLE (RYTHME) ---
	var input_beat = RhythmConductor.song_position_in_beats
	var current_note = _note_sequence[_current_note_index]
	var target_beat = RhythmConductor.get_calibrated_target_beat(current_note.target_beat)
	var offset = abs(input_beat - target_beat)
	var is_on_time = offset <= RHYTHM_WINDOW_BEATS

	# --- 2. VALIDATION DU TYPE D'ACTION ---
	var required_action = current_note.required_action
	var is_correct_action = (performed_action == required_action)

	print("Input: %s | Required: %s | On Time: %s" % [GameActions.Type.keys()[performed_action], GameActions.Type.keys()[required_action], is_on_time])

	# --- 3. CONCLUSION (SUCCÈS OU ÉCHEC) ---
	if is_on_time and is_correct_action:
		print(" -> SUCCESS!")
		_initiate_move_to_next_note(performed_action)
	else:
		print(" -> FAILURE! (Reason: %s, %s)" % ["Incorrect Action" if not is_correct_action else "On Time", "Off-beat" if not is_on_time else "Correct Timing"])
		# Pour l'instant on ne fait rien en cas d'échec, comme demandé.
		# Plus tard, on ajoutera ici la perte de vie, etc.
		# get_tree().change_scene_to_file("res://scenes/game_over_screen.tscn")


# Le paramètre est maintenant un GameActions.Type
func _initiate_move_to_next_note(action_type: GameActions.Type):
	var next_note_index: int = _current_note_index + 1

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

	var target_note_pos = _note_sequence[next_note_index].global_position
	var end_pos: Vector2 = target_note_pos + _landing_offset

	_execute_tween_movement(start_pos, end_pos, action_type, previous_state_snapshot)

# Le paramètre est maintenant un GameActions.Type
func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: GameActions.Type, previous_state: State):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	var time_per_beat = 60.0 / RhythmConductor._bpm
	
	var move_duration = time_per_beat
	if previous_state == State.IDLE_ON_NOTE:
		var current_note_data = _note_sequence[_current_note_index]
		var note_duration_in_beats = get_parent().get_note_duration_in_beats(current_note_data.note_type)
		move_duration = note_duration_in_beats * time_per_beat
	
	var control_point_1: Vector2
	var mid_point = start_pos.lerp(end_pos, 0.5)
	var delta_y = end_pos.y - start_pos.y

	# On utilise notre enum pour choisir la trajectoire (contexte du GDD)
	match action_type:
		GameActions.Type.SAUT:
			# Grand saut
			control_point_1 = mid_point + Vector2(0, -250 - (delta_y * 0.5))
		GameActions.Type.PAS:
			# Saut léger
			control_point_1 = mid_point + Vector2(0, -100 - (delta_y * 0.5))
		GameActions.Type.PETIT_PAS:
			# Quasi pas de saut
			control_point_1 = mid_point + Vector2(0, -20 - (delta_y * 0.5))
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
	global_position = target_note_pos + _landing_offset
	
	_note_sequence[_current_note_index].bump()

func get_custom_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity
