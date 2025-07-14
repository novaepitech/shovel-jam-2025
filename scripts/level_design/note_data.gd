class_name NoteData
extends Marker2D

# On utilise un Enum pour que ce soit clair et facile dans l'inspecteur.
enum NoteType {
    SILENCE,    # Un temps de silence
    CROCHE,     # Rythme de base (1x)
    DOUBLE,     # Double-croche (2x plus rapide)
    TRIOLET,    # Triolet (3x plus rapide)
    NOIRE,      # Noire (2x plus lent)
}

@export var type: NoteType = NoteType.CROCHE
