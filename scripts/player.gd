class_name Player
extends CharacterBody2D

signal player_failed

enum State {
	INITIAL_RUN,
	IDLE_ON_NOTE,
	MOVING_TO_NOTE,
	FINISHED,
	FAILED
}

@onready var fail_sound_player: AudioStreamPlayer = $FailSoundPlayer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var initial_walk_timer: Timer = $InitialWalkTimer

@export var fail_sound: AudioStream

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.INITIAL_RUN

var _is_current_move_validated: bool = false

var _move_tween: Tween
var _landing_offset: Vector2 = Vector2(-15.0, -90.0)
const INITIAL_RUN_SPEED = 600.0
const GRAVITY = 2000.0

#-----------------------------------------------------------------------------
# INITIALISATION
#-----------------------------------------------------------------------------

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	animated_sprite.play("default")

	if fail_sound:
		fail_sound_player.stream = fail_sound

	initial_walk_timer.timeout.connect(_on_initial_walk_timer_timeout)


func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	if _note_sequence.is_empty():
		_state = State.FINISHED
		return

	var main_node = get_tree().get_root().get_node("Main")
	var lead_in_duration_seconds = main_node.lead_in_beats * (60.0 / main_node.bpm)

	initial_walk_timer.wait_time = lead_in_duration_seconds
	initial_walk_timer.start()

#-----------------------------------------------------------------------------
# BOUCLE DE JEU PRINCIPALE (_physics_process)
#-----------------------------------------------------------------------------

func _physics_process(delta: float):
	match _state:
		State.INITIAL_RUN:
			_process_state_initial_run()
		State.IDLE_ON_NOTE:
			_process_state_idle_on_note()
		State.MOVING_TO_NOTE:
			_process_state_moving_to_note()
		State.FAILED:
			velocity.y += GRAVITY * delta
			move_and_slide()

func _process_state_initial_run():
	if not _move_tween or not _move_tween.is_running():
		_move_tween = create_tween()
		var target_pos = global_position + Vector2(INITIAL_RUN_SPEED * initial_walk_timer.wait_time, 0)  # Calculate distance based on timer
		_move_tween.tween_property(self, "global_position", target_pos, initial_walk_timer.wait_time)
		_move_tween.tween_callback(func(): velocity = Vector2.ZERO)

func _process_state_idle_on_note():
	var current_note = _note_sequence[_current_note_index]

	if RhythmConductor.song_position_in_beats >= current_note.target_beat:
		_start_automatic_move_to_next_note()

func _process_state_moving_to_note():
	if _is_current_move_validated:
		return

	var performed_action = _get_player_rhythmic_input()
	if performed_action != GameActions.Type.NONE:
		_validate_player_input(performed_action)

#-----------------------------------------------------------------------------
# LOGIQUE D'ÉCHEC
#-----------------------------------------------------------------------------

func _on_initial_walk_timer_timeout():
	if _state != State.INITIAL_RUN:
		return

	print("Course initiale terminée. Déclenchement du mouvement vers la première note.")
	velocity = Vector2.ZERO
	_start_automatic_move_to_next_note()

func _on_movement_finished():
	if _is_current_move_validated:
		_land_successfully()
	else:
		_fail_movement()

func _land_successfully():
	_current_note_index += 1
	var target_note = _note_sequence[_current_note_index]

	global_position = target_note.global_position + _landing_offset
	target_note.bump()

	print("Landed successfully on note %d." % _current_note_index)

	_state = State.IDLE_ON_NOTE
	animated_sprite.stop()

func _fail_movement():
	print("!!! MOVEMENT FAILED !!! Player did not provide correct input.")

	# Module 3: Gestion de l'état interne
	_state = State.FAILED

	# On remet la vélocité à zéro pour que le joueur tombe verticalement
	# sans conserver d'élan horizontal du tween précédent.
	velocity = Vector2.ZERO

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	# Module 2: Séquence visuelle et sonore
	animated_sprite.stop()
	# - On ne joue plus l'animation qui cause le problème.
	# animation_player.play("fall")
	fail_sound_player.play()

	# Module 4 & 5 & 6 (partie 1) : Communication
	player_failed.emit()

func _start_automatic_move_to_next_note():
	var next_note_index = _current_note_index + 1

	if next_note_index >= _note_sequence.size():
		print("Level finished!")
		_state = State.FINISHED
		return

	_state = State.MOVING_TO_NOTE
	_is_current_move_validated = false
	animated_sprite.play("default")

	var move_action_type: GameActions.Type
	var move_duration_beats: float
	var start_pos: Vector2

	if _current_note_index == -1:
		start_pos = global_position
		move_action_type = GameActions.Type.PAS
		move_duration_beats = 1.0
	else:
		var current_note = _note_sequence[_current_note_index]
		start_pos = current_note.global_position + _landing_offset
		move_action_type = current_note.required_action
		move_duration_beats = get_parent().get_note_duration_in_beats(current_note.rhythmic_value)

	var next_note = _note_sequence[next_note_index]
	var move_duration_seconds = move_duration_beats * RhythmConductor.time_per_beat

	print("Début du mouvement de l'index %d vers %d. Durée: %.2fs. Trajectoire: %s" % [_current_note_index, next_note_index, move_duration_seconds, GameActions.Type.keys()[move_action_type]])

	_execute_tween_movement(start_pos, next_note.global_position + _landing_offset, move_action_type, move_duration_seconds)


func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: GameActions.Type, duration: float):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween().set_parallel(false)

	const SAUT_FACTOR = 0.3
	const PAS_FACTOR = 0.15
	const PETIT_PAS_FACTOR = 0.05

	var distance_x = abs(end_pos.x - start_pos.x)
	var arc_height = 0.0

	match action_type:
		GameActions.Type.SAUT:
			arc_height = distance_x * SAUT_FACTOR
		GameActions.Type.PAS:
			arc_height = distance_x * PAS_FACTOR
		GameActions.Type.PETIT_PAS:
			arc_height = distance_x * PETIT_PAS_FACTOR

	arc_height = max(arc_height, 20.0)

	var mid_point = start_pos.lerp(end_pos, 0.5)
	var control_point = mid_point - Vector2(0, arc_height)

	_move_tween.tween_method(
		_update_position_along_curve.bind(start_pos, control_point, end_pos),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_LINEAR)

	_move_tween.tween_callback(_on_movement_finished)

func _get_player_rhythmic_input() -> GameActions.Type:
	if Input.is_action_just_pressed("saut"): return GameActions.Type.SAUT
	if Input.is_action_just_pressed("pas"): return GameActions.Type.PAS
	if Input.is_action_just_pressed("petit_pas"): return GameActions.Type.PETIT_PAS
	return GameActions.Type.NONE

func _validate_player_input(performed_action: GameActions.Type):
	var target_note_index = _current_note_index + 1
	if target_note_index >= _note_sequence.size(): return

	var target_note = _note_sequence[target_note_index]
	var required_action = target_note.required_action

	if performed_action == required_action:
		print("  > Input '%s' CORRECT!" % GameActions.Type.keys()[performed_action])
		_is_current_move_validated = true
	else:
		print("  > Input '%s' WRONG! (Required: %s)" % [GameActions.Type.keys()[performed_action], GameActions.Type.keys()[required_action]])

func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	var p1 = start.lerp(ctrl, t)
	var p2 = ctrl.lerp(end, t)
	global_position = p1.lerp(p2, t)
