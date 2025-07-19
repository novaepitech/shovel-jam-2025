class_name Player
extends CharacterBody2D

enum State {
	INITIAL_RUN,
	IDLE_ON_NOTE,
	MOVING_TO_NOTE,
	FINISHED,
	FAILED
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var initial_walk_timer: Timer = $InitialWalkTimer

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.INITIAL_RUN

var _is_current_move_validated: bool = false

var _move_tween: Tween
var _landing_offset: Vector2 = Vector2(-15.0, -90.0)
const INITIAL_RUN_SPEED = 600.0

#-----------------------------------------------------------------------------
# INITIALISATION
#-----------------------------------------------------------------------------

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	animated_sprite.play("default")

	initial_walk_timer.timeout.connect(_on_initial_walk_timer_timeout)


func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	if _note_sequence.is_empty():
		_state = State.FINISHED
		return

	# On récupère le Main node pour accéder au BPM et au lead_in_beats
	var main_node = get_tree().get_root().get_node("Main")
	var lead_in_duration_seconds = main_node.lead_in_beats * (60.0 / main_node.bpm)

	print("Durée de la course initiale calculée : %.2f secondes" % lead_in_duration_seconds)

	# On règle le Timer avec cette durée calculée avant de le démarrer
	initial_walk_timer.wait_time = lead_in_duration_seconds
	initial_walk_timer.start()

#-----------------------------------------------------------------------------
# BOUCLE DE JEU PRINCIPALE (_physics_process)
#-----------------------------------------------------------------------------

func _physics_process(_delta: float):
	match _state:
		State.INITIAL_RUN:
			_process_state_initial_run()
		State.IDLE_ON_NOTE:
			_process_state_idle_on_note()
		State.MOVING_TO_NOTE:
			_process_state_moving_to_note()
		State.FAILED:
			pass

func _process_state_initial_run():
	# Pendant la course initiale, on avance simplement.
	# La condition de position est supprimée car le Timer s'en charge maintenant.
	velocity = Vector2(INITIAL_RUN_SPEED, 0)
	move_and_slide()

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
# LOGIQUE DE MOUVEMENT (DÉCLENCHEMENT AUTOMATIQUE)
#-----------------------------------------------------------------------------

func _on_initial_walk_timer_timeout():
	# Sécurité : on s'assure qu'on est bien dans l'état de course initiale.
	if _state != State.INITIAL_RUN:
		return

	print("Course initiale de 3s terminée. Déclenchement du mouvement vers la première note.")

	# On arrête la course en avant.
	velocity = Vector2.ZERO

	# On déclenche manuellement le premier mouvement.
	_start_automatic_move_to_next_note()


func _start_automatic_move_to_next_note():
	var next_note_index = _current_note_index + 1

	if next_note_index >= _note_sequence.size():
		print("Level finished!")
		_state = State.FINISHED
		return

	_state = State.MOVING_TO_NOTE
	_is_current_move_validated = false
	animated_sprite.play("default")

	# --- MODIFICATION CLÉ POUR GÉRER LE PREMIER SAUT ---
	var move_action_type: GameActions.Type
	var move_duration_beats: float
	var start_pos: Vector2

	if _current_note_index == -1:
		# Cas spécial : le tout premier mouvement part de la position actuelle du joueur.
		start_pos = global_position
		# On peut définir une action et une durée par défaut pour ce premier saut.
		# Par exemple, un "PAS" (noire) qui dure 1 temps.
		move_action_type = GameActions.Type.PAS
		move_duration_beats = 1.0
	else:
		# Cas normal : le mouvement part de la note précédente.
		var current_note = _note_sequence[_current_note_index]
		start_pos = current_note.global_position + _landing_offset
		move_action_type = current_note.required_action
		move_duration_beats = get_parent().get_note_duration_in_beats(current_note.rhythmic_value)

	# Le reste de la fonction est inchangé, mais utilisera nos variables `start_pos`, etc.
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

#-----------------------------------------------------------------------------
# Le reste du fichier est inchangé...
#-----------------------------------------------------------------------------

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
	_state = State.FAILED
	animated_sprite.stop()

func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	var p1 = start.lerp(ctrl, t)
	var p2 = ctrl.lerp(end, t)
	global_position = p1.lerp(p2, t)
