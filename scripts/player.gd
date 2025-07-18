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

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.INITIAL_RUN

var _is_current_move_validated: bool = false

var _move_tween: Tween
var _landing_offset: Vector2 = Vector2(-15.0, -90.0)
const INITIAL_RUN_SPEED = 300.0

#-----------------------------------------------------------------------------
# INITIALISATION
#-----------------------------------------------------------------------------

func _ready():
	var camera = Camera2D.new()
	camera.offset = Vector2(350, 0)
	camera.position_smoothing_enabled = true
	add_child(camera)
	motion_mode = MOTION_MODE_FLOATING
	animated_sprite.play("default") # L'animation de course joue dès le début

func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	if _note_sequence.is_empty():
		_state = State.FINISHED

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
	if _note_sequence.is_empty():
		return
		
	velocity = Vector2(INITIAL_RUN_SPEED, 0)
	move_and_slide()
	
	var first_note_pos = _note_sequence[0].global_position
	if global_position.x >= first_note_pos.x:
		print("Initial run complete. Reached first note.")
		global_position = first_note_pos + _landing_offset
		_note_sequence[0].bump()
		_current_note_index = 0
		_state = State.IDLE_ON_NOTE
		velocity = Vector2.ZERO
		animated_sprite.stop() # On arrête l'animation en attendant sur la note

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

func _start_automatic_move_to_next_note():
	var next_note_index = _current_note_index + 1

	if next_note_index >= _note_sequence.size():
		print("Level finished!")
		_state = State.FINISHED
		return

	_state = State.MOVING_TO_NOTE
	_is_current_move_validated = false

	# CORRECTION 1 : Lancer l'animation dès le début du mouvement !
	animated_sprite.play("default")

	var current_note = _note_sequence[_current_note_index]
	var next_note = _note_sequence[next_note_index]
	
	var move_action_type = current_note.required_action
	
	var move_duration_beats = get_parent().get_note_duration_in_beats(current_note.rhythmic_value)
	var move_duration_seconds = move_duration_beats * RhythmConductor.time_per_beat
	
	print("Starting move from note %d to %d. Duration: %.2fs. Trajectory: %s" % [_current_note_index, next_note_index, move_duration_seconds, GameActions.Type.keys()[move_action_type]])
	
	_execute_tween_movement(global_position, next_note.global_position + _landing_offset, move_action_type, move_duration_seconds)

func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: GameActions.Type, duration: float):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween().set_parallel(false)

	# --- NOUVELLE LOGIQUE DYNAMIQUE ---
	# 1. On définit des "facteurs de hauteur" pour chaque type de mouvement.
	#    Ces valeurs sont des pourcentages de la distance du saut.
	const SAUT_FACTOR = 0.3      # L'arc fera 30% de la hauteur de la distance horizontale
	const PAS_FACTOR = 0.15      # L'arc fera 15%...
	const PETIT_PAS_FACTOR = 0.05  # L'arc fera 5%...

	# 2. On calcule la distance horizontale du saut.
	var distance_x = abs(end_pos.x - start_pos.x)
	var arc_height = 0.0

	# 3. On choisit le bon facteur et on calcule la hauteur de l'arc.
	match action_type:
		GameActions.Type.SAUT:
			arc_height = distance_x * SAUT_FACTOR
		GameActions.Type.PAS:
			arc_height = distance_x * PAS_FACTOR
		GameActions.Type.PETIT_PAS:
			arc_height = distance_x * PETIT_PAS_FACTOR

	# 4. On s'assure que même les sauts verticaux ont un petit arc pour le style.
	arc_height = max(arc_height, 20.0)

	var mid_point = start_pos.lerp(end_pos, 0.5)
	# Le point de contrôle est maintenant dynamiquement calculé.
	var control_point = mid_point - Vector2(0, arc_height)
	# ------------------------------------

	_move_tween.tween_method(
		_update_position_along_curve.bind(start_pos, control_point, end_pos),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_LINEAR)

	_move_tween.tween_callback(_on_movement_finished)

#-----------------------------------------------------------------------------
# LOGIQUE DE VALIDATION DE L'INPUT
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

#-----------------------------------------------------------------------------
# FIN DU MOUVEMENT (ATTERRISSAGE)
#-----------------------------------------------------------------------------

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
	animated_sprite.stop() # On arrête l'animation quand on attend

func _fail_movement():
	print("!!! MOVEMENT FAILED !!! Player did not provide correct input.")
	_state = State.FAILED
	animated_sprite.stop()

#-----------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
#-----------------------------------------------------------------------------

# CORRECTION 2 : Utiliser la bonne formule pour une courbe de saut (Bézier quadratique)
func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	# Cette formule crée un arc parfait entre start et end, en passant par le point de contrôle ctrl.
	var p1 = start.lerp(ctrl, t)
	var p2 = ctrl.lerp(end, t)
	global_position = p1.lerp(p2, t)
