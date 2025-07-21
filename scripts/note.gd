class_name Note
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

# Propriétés rythmiques et de positionnement de la note.
var target_beat: float = 0.0

# Utilise la nouvelle énumération sémantiquement correcte et complète.
# Le type de note par défaut est une Noire.
@export var rhythmic_value: NoteData.NoteRhythmicValue = NoteData.NoteRhythmicValue.NOIRE

# Détermine si la hampe de la note est vers le haut ou vers le bas.
@export var is_inverted: bool = false

# L'action de jeu requise pour valider cette note (ex: SAUT, PAS).
# Sera déterminée dans _ready().
var required_action: GameActions.Type

# -- Textures exportées --
# Assurez-vous de les assigner dans l'inspecteur de Godot pour la scène Note.tscn.
@export var texture_blanche: Texture2D
@export var texture_noire: Texture2D
@export var texture_croche: Texture2D
@export var texture_double_croche: Texture2D
@export var texture_silence: Texture2D
@export var texture_demi_silence: Texture2D

# Variables pour les animations visuelles.
var original_position: Vector2
var is_bumping = false

# Constant for the Y offset adjustment when inverting notes
const INVERT_Y_OFFSET: float = 340.0


func _ready():
	# On sauvegarde la position initiale du sprite pour l'animation "bump".
	original_position = sprite.position

	# On demande à notre classe statique NoteData quelle action est nécessaire pour cette valeur rythmique.
	# La logique est maintenant centralisée et claire.
	required_action = NoteData.get_required_action_for_type(rhythmic_value)

	# On sélectionne la bonne texture en fonction de la valeur rythmique de la note.
	match rhythmic_value:
		NoteData.NoteRhythmicValue.BLANCHE:
			sprite.texture = texture_blanche
		NoteData.NoteRhythmicValue.NOIRE:
			sprite.texture = texture_noire
		NoteData.NoteRhythmicValue.CROCHE:
			sprite.texture = texture_croche
		NoteData.NoteRhythmicValue.DOUBLE_CROCHE:
			sprite.texture = texture_double_croche # Utilisation de la nouvelle texture.
		NoteData.NoteRhythmicValue.TRIOLET_DE_CROCHES:
			# Pour l'instant, un triolet ressemble visuellement à une croche.
			sprite.texture = texture_croche
		NoteData.NoteRhythmicValue.SILENCE:
			sprite.texture = texture_silence
		NoteData.NoteRhythmicValue.DEMI_SILENCE:
			sprite.texture = texture_demi_silence
		_:
			# Fallback en cas d'erreur ou de type non reconnu.
			printerr("Note type not recognized or texture not set: ", NoteData.NoteRhythmicValue.keys()[rhythmic_value])
			sprite.texture = texture_noire

	# On applique l'inversion de la texture si nécessaire.
	if is_inverted:
		sprite.flip_v = true
		# Adjust the note's position to compensate for the visual flip
		# Move the note down so the head appears at the same level as non-inverted notes
		position.y += INVERT_Y_OFFSET


## Déclenche l'animation appropriée en fonction du type de note.
func bump():
	if is_bumping:
		return
	is_bumping = true

	if rhythmic_value in [NoteData.NoteRhythmicValue.SILENCE, NoteData.NoteRhythmicValue.DEMI_SILENCE]:
		# Pour SILENCE et DEMI_SILENCE: Animation de fondu (fade-out) au lieu du bump.
		# L'opacité passe de 1.0 à 0.0 sur 0.3s pour un effet subtil et "silencieux".
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): is_bumping = false)
	else:
		# Animation bump standard pour les autres notes.
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(sprite, "position", original_position + Vector2(0, 8), 0.1)
		tween.tween_property(sprite, "position", original_position, 0.2)
		tween.tween_callback(func(): is_bumping = false)


## Fonction appelée par le joueur lorsqu'il saute sur cette note.
func on_player_jump():
	bump()
