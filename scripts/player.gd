# res://scripts/player.gd

class_name Player
extends CharacterBody2D

# --- Machine d'état ---
enum State {
	IDLE_ON_NOTE,
	MOVING_TO_NOTE,
	WAITING_FOR_FIRST_INPUT
}

# --- Variables ---
var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.WAITING_FOR_FIRST_INPUT
var _move_tween: Tween

# --- Variables de physique pour l'état de départ ---
@export var run_speed: float = 150.0 # Vitesse pour la course de départ
@export var jump_height: float = 160.0
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.3
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float


func _ready():
	jump_velocity = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
	jump_gravity = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
	fall_gravity = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0


func _physics_process(delta):
	match _state:
		State.WAITING_FOR_FIRST_INPUT:
			# Le joueur court vers la droite sur la plateforme de départ.
			velocity.x = run_speed
			
			# On applique la gravité pour le maintenir au sol.
			velocity.y += get_custom_gravity() * delta
			move_and_slide()

			# On écoute l'input pour le premier saut.
			if Input.is_action_just_pressed("jump"):
				# On arrête le mouvement de course pour que le tween prenne le contrôle proprement.
				velocity.x = 0
				print("First input detected. Switching to rhythmic movement system.")
				_start_move_to_next_note("jump")

		State.IDLE_ON_NOTE:
			# Le joueur attend sur une note, sans bouger.
			if Input.is_action_just_pressed("jump"):
				_start_move_to_next_note("jump")
			elif Input.is_action_just_pressed("pas"):
				_start_move_to_next_note("pas")

		State.MOVING_TO_NOTE:
			# Le Tween gère le mouvement, donc on ne fait rien ici.
			pass


func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	print("Player received the level partition with %d notes." % _note_sequence.size())

	if not _note_sequence.is_empty():
		_current_note_index = -1
		print("Player is on the starting platform. Ready for first input.")
	else:
		print("Level is empty, player is waiting on platform.")


func _start_move_to_next_note(action_type: String):
	var next_note_index: int
	
	if _state == State.WAITING_FOR_FIRST_INPUT:
		next_note_index = 0
	else:
		next_note_index = _current_note_index + 1

	if next_note_index >= _note_sequence.size():
		print("End of the level!")
		return

	var previous_state = _state
	_state = State.MOVING_TO_NOTE
	
	var start_pos: Vector2
	if previous_state == State.WAITING_FOR_FIRST_INPUT:
		start_pos = global_position
	else:
		start_pos = _note_sequence[_current_note_index].global_position

	var end_pos: Vector2 = _note_sequence[next_note_index].global_position

	_execute_tween_movement(start_pos, end_pos, action_type, previous_state)


func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: String, previous_state: State):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	var beat_duration = 60.0 / RhythmConductor._bpm
	var move_duration = beat_duration

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
	global_position = target_note_pos
	
	_note_sequence[_current_note_index].bump()


func get_custom_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity
