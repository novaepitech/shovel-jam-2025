class_name GameActions
extends Object

# Cet enum représente formellement toutes les actions de gameplay possibles.
enum Type {
	# Note: On ajoute NONE pour représenter l'absence d'action.
	NONE,
	SAUT,      # Correspond au "Clic" du GDD
	PAS,       # Correspond à "Alterner Pas"
	PETIT_PAS, # Correspond à "Alterner Petits Pas"
	BALANCIER  # Correspond à "Maintenir" (prévu pour le futur)
}
