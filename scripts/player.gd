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
@export var time_window_in_beats: float = 0.25  # Marge d'erreur avant/après le target_beat (en beats)

# Existing landing offset (shared for X and base Y)
@export var landing_offset: Vector2 = Vector2(-15.0, -90.0)

# Adjustment to lower the final landing Y for inverted notes only.
# Positive values move the landing position down (further down the screen).
# Tune this in the Godot editor (e.g., 20-50 pixels) to grab the tail "a bit lower".
@export var inverted_landing_y_adjustment: float = 30.0

var _note_sequence: Array[Note] = []
var _current_note_index: int = -1
var _state: State = State.INITIAL_RUN

var _move_tween: Tween
const INITIAL_RUN_SPEED = 600.0
const GRAVITY = 2000.0

var pending_notes: Array[Dictionary] = []

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

	# Check for missed windows in all relevant states
	if _state in [State.INITIAL_RUN, State.MOVING_TO_NOTE, State.IDLE_ON_NOTE]:
		for p in pending_notes:
			if RhythmConductor.song_position_in_beats > p.upper_bound:
				print("!!! MOVEMENT FAILED !!! Missed input window for note at beat %.2f" % p.target_beat)
				_fail_movement()
				break

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
	pass  # Input handling is now in _input, no need for per-frame checks here

#-----------------------------------------------------------------------------
# INPUT HANDLING (decoupled from states)
#-----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var performed_action = GameActions.Type.NONE
	if event.is_action_pressed("saut"): performed_action = GameActions.Type.SAUT
	elif event.is_action_pressed("pas"): performed_action = GameActions.Type.PAS
	elif event.is_action_pressed("petit_pas"): performed_action = GameActions.Type.PETIT_PAS
	# Add other actions if needed (e.g., BALANCIER)

	if performed_action != GameActions.Type.NONE:
		var current_beat = RhythmConductor.song_position_in_beats
		var candidates: Array[Dictionary] = []
		var any_in_window: bool = false

		for p in pending_notes:
			if current_beat >= p.lower_bound and current_beat <= p.upper_bound:
				any_in_window = true
				if performed_action == p.required_action:
					candidates.append(p)

		if not candidates.is_empty():
			# Select the closest by target_beat
			var closest = candidates[0]
			var min_diff = abs(candidates[0].target_beat - current_beat)
			for c in candidates.slice(1):
				var diff = abs(c.target_beat - current_beat)
				if diff < min_diff:
					min_diff = diff
					closest = c

			# Validate
			print("  > Input '%s' CORRECT et SYNCHRONISÉ! (Beat actuel: %.2f, Fenêtre: [%.2f, %.2f])" % [GameActions.Type.keys()[performed_action], current_beat, closest.lower_bound, closest.upper_bound])
			pending_notes.erase(closest)
		else:
			if any_in_window:
				print("  > Input '%s' WRONG or Timing INCORRECT!" % GameActions.Type.keys()[performed_action])
				_fail_movement()
			# Else, input outside any window, ignore

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
	_land_successfully()

func _land_successfully():
	_current_note_index += 1
	var target_note = _note_sequence[_current_note_index]

	# Compute landing offset with inverted adjustment (only affects Y)
	var final_offset = landing_offset
	if target_note.is_inverted:
		final_offset.y += inverted_landing_y_adjustment

	global_position = target_note.global_position + final_offset
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

	# Add the target note to pending validations BEFORE starting the movement
	var target_note = _note_sequence[next_note_index]
	var lower_bound = target_note.target_beat - time_window_in_beats
	var upper_bound = target_note.target_beat + time_window_in_beats
	pending_notes.append({
		"note": target_note,
		"target_beat": target_note.target_beat,
		"lower_bound": lower_bound,
		"upper_bound": upper_bound,
		"required_action": target_note.required_action
	})

	_state = State.MOVING_TO_NOTE

	# Check if the target note is inverted to decide which animation to play
	if target_note.is_inverted:
		animated_sprite.play("swing")  # Play swing animation for inverted notes
	else:
		animated_sprite.play("default")  # Default animation for regular notes

	var move_action_type: GameActions.Type
	var move_duration_beats: float
	var start_pos: Vector2

	if _current_note_index == -1:
		start_pos = global_position
		move_action_type = GameActions.Type.PAS
		move_duration_beats = 1.0
	else:
		var current_note = _note_sequence[_current_note_index]

		# NEW: Compute start offset with inverted adjustment if the CURRENT note (starting point) is inverted
		var start_offset = landing_offset
		if current_note.is_inverted:
			start_offset.y += inverted_landing_y_adjustment

		start_pos = current_note.global_position + start_offset
		move_action_type = current_note.required_action
		move_duration_beats = get_parent().get_note_duration_in_beats(current_note.rhythmic_value)

	var next_note = _note_sequence[next_note_index]
	var move_duration_seconds = move_duration_beats * RhythmConductor.time_per_beat

	print("Début du mouvement de l'index %d vers %d. Durée: %.2fs. Trajectoire: %s, Inverted: %s" % [_current_note_index, next_note_index, move_duration_seconds, GameActions.Type.keys()[move_action_type], "Yes" if target_note.is_inverted else "No"])

	# Compute landing offset with inverted adjustment (only affects Y) for the END position
	var final_offset = landing_offset
	if target_note.is_inverted:
		final_offset.y += inverted_landing_y_adjustment

	# Pass the inverted status to the movement function
	_execute_tween_movement(start_pos, next_note.global_position + final_offset, move_action_type, move_duration_seconds, target_note.is_inverted)


func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: GameActions.Type, duration: float, is_inverted: bool = false):
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween().set_parallel(false)

	const SAUT_FACTOR = 0.3
	const PAS_FACTOR = 0.15
	const PETIT_PAS_FACTOR = 0.05
	const SWING_FACTOR = 0.2  # Factor for swing arc height (adjust as needed)

	var distance_x = abs(end_pos.x - start_pos.x)
	var arc_height = 0.0

	if is_inverted:
		# For inverted notes, create a swinging motion by adjusting the control point
		arc_height = distance_x * SWING_FACTOR
		# Swing motion: control point is positioned to simulate grabbing and swinging from the tail
		var mid_point = start_pos.lerp(end_pos, 0.5)
		# Adjust control point to be higher or lower depending on note orientation (inverted notes may have tail upwards)
		var control_point = mid_point + Vector2(0, arc_height)  # Adjust to swing "up" or "down" as needed
		_move_tween.tween_method(
			_update_position_along_curve.bind(start_pos, control_point, end_pos),
			0.0, 1.0, duration
		).set_trans(Tween.TRANS_SINE)  # Use sine transition for smoother swing
	else:
		# Default jumping motion for non-inverted notes
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

func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	var p1 = start.lerp(ctrl, t)
	var p2 = ctrl.lerp(end, t)
	global_position = p1.lerp(p2, t)
