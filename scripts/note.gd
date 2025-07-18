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
@export var texture_double_croche: Texture2D # La nouvelle texture pour la double-croche.

# Variables pour les animations visuelles.
var original_position: Vector2
var is_bumping = false

# Constantes pour le positionnement des ligatures (beams).
const BEAM_OFFSET_UP_STEM: float = -145.0
const BEAM_OFFSET_DOWN_STEM: float = 130.0


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
		_:
			# Fallback en cas d'erreur ou de type non reconnu.
			printerr("Note type not recognized or texture not set: ", NoteData.NoteRhythmicValue.keys()[rhythmic_value])
			sprite.texture = texture_noire

	# On applique l'inversion de la texture si nécessaire.
	sprite.flip_v = is_inverted


## Retourne la position globale du point de connexion pour une ligature.
func get_beam_connection_point() -> Vector2:
	var stem_offset_y: float
	if is_inverted:
		stem_offset_y = BEAM_OFFSET_DOWN_STEM
	else:
		stem_offset_y = BEAM_OFFSET_UP_STEM
	return global_position + Vector2(0, stem_offset_y)


## Déclenche une petite animation de "saut" de la note.
func bump():
	if is_bumping:
		return
	is_bumping = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "position", original_position + Vector2(0, 8), 0.1)
	tween.tween_property(sprite, "position", original_position, 0.2)
	tween.tween_callback(func(): is_bumping = false)


## Fonction appelée par le joueur lorsqu'il saute sur cette note.
func on_player_jump():
	bump()
