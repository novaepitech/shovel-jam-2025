extends Area2D

var speed = 200.0 # Vitesse de défilement en pixels/seconde

func _process(delta):
    # Fait bouger la note vers la gauche
    global_position.x -= speed * delta
    
    # Détruit la note si elle sort de l'écran (à gauche)
    if global_position.x < -50:
        queue_free()
