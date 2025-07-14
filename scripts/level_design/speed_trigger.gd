# res://scripts/level_design/SpeedTrigger.gd
class_name SpeedTrigger
extends Area2D

## La nouvelle vitesse de défilement (en pixels/seconde) à appliquer
## quand le joueur touche ce déclencheur.
@export var new_speed: float = 600.0

func _ready():
    # On connecte le signal de l'Area2D à notre propre fonction.
    # C'est plus propre que de le faire via l'éditeur pour une scène réutilisable.
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
    # On vérifie si le corps qui est entré est bien le joueur.
    # L'utilisation des groupes est parfaite pour ça.
    # (Assure-toi que ton Player est dans le groupe "player").
    if body.is_in_group("player"):
        # On "poste" notre message sur le panneau d'affichage global.
        # On dit : "Hé tout le monde, quelqu'un a demandé un changement de vitesse !"
        # et on joint la nouvelle valeur.
        SignalManager.speed_change_requested.emit(new_speed)
        
        # On désactive la collision pour ne pas être déclenché à nouveau.
        # queue_free() fonctionne aussi, mais désactiver la collision est plus sûr
        # si quelque chose d'autre dépend de ce nœud pendant la frame.
        $CollisionShape2D.disabled = true
