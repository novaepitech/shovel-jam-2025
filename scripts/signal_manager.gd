# res://scripts/SignalManager.gd
# Ce script n'a pas besoin d'hériter de Node.
# C'est juste un conteneur pour nos signaux globaux.
extends Node

# On déclare le signal. Il pourra transporter une valeur (la nouvelle vitesse).
signal speed_change_requested(new_speed: float)
