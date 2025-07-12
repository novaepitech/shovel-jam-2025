extends Node2D

@onready var level_1: Node2D = $Level1

var speed = 650.0 # Vitesse de défilement en pixels/seconde

func _process(delta: float) -> void:
    level_1.position.x -= speed * delta
