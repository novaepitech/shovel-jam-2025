# res://scripts/player.gd

class_name Player
extends CharacterBody2D

# --- Machine d'état (Exigence 3.2) ---
enum State {
	# En attente d'une action sur une note. Les inputs sont écoutés.
	IDLE_ON_NOTE,
	# En déplacement vers la note suivante. Les inputs sont ignorés.
	MOVING_TO_NOTE,
	# État initial avant le premier saut. Utilise encore la physique.
	WAITING_FOR_FIRST_INPUT
}

# La liste des notes et la progression du joueur (de la Partie 2)
var _note_sequence: Array[Note] = []
var _current_note_index: int = -1

# Variable pour stocker notre machine d'état
var _state: State = State.WAITING_FOR_FIRST_INPUT

# Référence à notre tween pour le mouvement scripté
var _move_tween: Tween


# --- Ancien système de physique (pour la phase d'attente) ---
@export var jump_height: float
@export var jump_time_to_peak: float
@export var jump_time_to_descent: float
var jump_velocity: float
var jump_gravity: float
var fall_gravity: float
# --- Fin de l'ancien système ---


func _ready():
	# On calcule les variables de saut pour la phase d'attente initiale
	jump_velocity = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
	jump_gravity = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
	fall_gravity = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0


func _physics_process(delta):
	# On gère le comportement en fonction de notre état actuel
	match _state:
		State.WAITING_FOR_FIRST_INPUT:
			# Comportement initial : on utilise encore la physique
			# pour permettre au joueur de se tenir sur le sol de départ.
			# Nous n'avons pas besoin de faire bouger le joueur horizontalement.
			velocity.y += get_custom_gravity() * delta
			move_and_slide()

			# Détection de l'input pour la première note
			if Input.is_action_just_pressed("jump"):
				# Pour l'instant, on ne vérifie pas la proximité de la note.
				# On suppose que le premier saut est pour la première note.
				# Une fois le premier input donné, on passe au système rythmique.
				print("First input detected. Switching to rhythmic movement system.")
				_start_move_to_next_note("jump")


		State.IDLE_ON_NOTE:
			# Le joueur est sur une note et attend.
			# Il ne bouge pas, il ne tombe pas (Exigence 3.1 : découplage de la physique)
			# On écoute les entrées pour déclencher le prochain mouvement.
			if Input.is_action_just_pressed("jump"):
				_start_move_to_next_note("jump")
			elif Input.is_action_just_pressed("pas"): # On prépare une nouvelle action "pas"
				_start_move_to_next_note("pas")

		State.MOVING_TO_NOTE:
			# Le joueur est en mouvement, on n'écoute aucune entrée.
			# Le Tween gère tout le déplacement.
			pass


# Reçoit la "partition" depuis main.gd (inchangée)
func initialize_rhythmic_movement(notes: Array[Note]) -> void:
	_note_sequence = notes
	print("Player received the level partition with %d notes." % _note_sequence.size())

	if not _note_sequence.is_empty():
		_current_note_index = 0
		print("Player is ready. Targetting first note.")
	else:
		_state = State.IDLE_ON_NOTE # S'il n'y a pas de notes, on ne fait rien.


# La fonction qui orchestre le début d'un mouvement
func _start_move_to_next_note(action_type: String):
	# Sécurité : on vérifie qu'il y a bien une note suivante
	var next_note_index = _current_note_index + 1
	if _state == State.WAITING_FOR_FIRST_INPUT:
		next_note_index = 0

	if next_note_index >= _note_sequence.size():
		print("End of the level!")
		return

	# On passe à l'état de mouvement pour ignorer les autres inputs (Exigence 3.3)
	_state = State.MOVING_TO_NOTE
	
	# On définit les points de départ et d'arrivée (Exigence 3.4)
	var start_pos: Vector2
	# Correction pour le premier mouvement: il faut utiliser la position actuelle du joueur.
	if _state == State.WAITING_FOR_FIRST_INPUT or _current_note_index < 0:
		start_pos = global_position
	else:
		# Mouvements suivants : on part de la note précédente
		start_pos = _note_sequence[_current_note_index].global_position

	var end_pos: Vector2 = _note_sequence[next_note_index].global_position

	# On déclenche le mouvement scripté via un Tween
	_execute_tween_movement(start_pos, end_pos, action_type)

func _execute_tween_movement(start_pos: Vector2, end_pos: Vector2, action_type: String):
	# Si un ancien tween est toujours en cours, on le tue
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	# La durée du mouvement sera liée au rythme. Pour l'instant, une valeur fixe suffit.
	# Par exemple, la durée d'une croche.
	var beat_duration = 60.0 / RhythmConductor._bpm
	var move_duration = beat_duration # Durée d'un "pas" ou "saut"

	# --- VARIATION DE TRAJECTOIRE (Exigence 3.5) ---
	# C'est ici que la magie opère. On utilise une trajectoire en courbe.
	# Pour cela, on définit un ou deux points de contrôle (style courbe de Bézier).
	var control_point_1: Vector2
	var control_point_2: Vector2

	var mid_point = start_pos.lerp(end_pos, 0.5)
	var delta_y = end_pos.y - start_pos.y

	match action_type:
		"jump":
			# Pour un SAUT, on crée une arche haute.
			# Le point de contrôle est bien au-dessus du point médian.
			control_point_1 = mid_point + Vector2(0, -250 - (delta_y * 0.5))
		"pas":
			# Pour un PAS, on crée une arche très plate.
			# Le point de contrôle est juste un peu au-dessus, et s'adapte à la hauteur de la note suivante.
			# Un "pas" montant aura une arche légèrement plus haute qu'un "pas" descendant.
			control_point_1 = mid_point + Vector2(0, -50 - (delta_y * 0.5))
		_: # Fallback pour toute autre action
			control_point_1 = mid_point

	# On anime la propriété `global_position` en utilisant une méthode custom
	_move_tween.tween_method(
		_update_position_along_curve.bind(start_pos, control_point_1, end_pos),
		0.0, # from
		1.0, # to
		move_duration # duration
	).set_trans(Tween.TRANS_LINEAR) # La courbe gère l'easing, donc le tween est linéaire

	# À la fin du tween, on appelle la fonction de complétion (Exigence 3.6)
	_move_tween.tween_callback(_on_movement_finished)


func _update_position_along_curve(t: float, start: Vector2, ctrl: Vector2, end: Vector2):
	# `t` is a value from 0.0 to 1.0 provided by the tween.
	# We calculate the Y position using the Bezier curve.
	var curve_pos = start.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t)
	
	# CRITICAL CHANGE: We ONLY apply the Y part of the movement.
	# The X position remains fixed relative to the screen.
	global_position.y = curve_pos.y


# Appelée quand le joueur atteint sa destination (Exigence 3.6)
func _on_movement_finished():
	print("Movement finished. Landed on a new note.")
	
	if _state == State.WAITING_FOR_FIRST_INPUT:
		# C'était le premier mouvement, on peut maintenant désactiver le sol de départ.
		# Note : cette ligne ne fonctionnera que si le floor est bien un StaticBody2D
		get_parent().get_node("Floor").get_node("CollisionShape2D").disabled = true
	
	# On met à jour notre progression dans la partition
	if _current_note_index < _note_sequence.size() - 1:
		_current_note_index += 1
	else:
		# Cas particulier du premier saut
		if _state == State.WAITING_FOR_FIRST_INPUT:
			_current_note_index = 0

	# On repasse en état d'attente sur la nouvelle note
	_state = State.IDLE_ON_NOTE
	
	# On s'assure d'être parfaitement sur la note pour éviter les décalages
	var target_note_pos = _note_sequence[_current_note_index].global_position
	global_position.y = target_note_pos.y
	
	# On peut faire "bumper" la note sur laquelle on atterrit
	var current_note = _note_sequence[_current_note_index]
	current_note.bump()

# Fonctions de l'ancien système de physique, gardées pour l'état initial
func get_custom_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity

func jump(): # Cette fonction n'est plus utilisée pour le mouvement rythmique
	velocity.y = jump_velocity
