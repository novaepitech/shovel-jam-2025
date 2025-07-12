extends Node2D

# Fait glisser la scène de la note depuis l'explorateur de fichiers ici
@export var note_scene: PackedScene
# Les positions Y de chaque ligne de la portée. À ajuster dans l'inspecteur.
@export var staff_line_positions: Array[float] = [200.0, 300.0, 400.0, 500.0]

@onready var player = $Player
@onready var spawn_point = $SpawnPoint
@onready var note_spawn_timer = $NoteSpawnTimer

func _ready():
    # Connecte le signal 'timeout' du timer à notre fonction de spawn
    note_spawn_timer.connect("timeout", _on_note_spawn_timer_timeout)
    note_spawn_timer.start()

func _on_note_spawn_timer_timeout():
    # Crée une nouvelle instance de la note
    var new_note = note_scene.instantiate()

    # Choisit une ligne de portée au hasard pour faire apparaître la note
    var random_line_index = randi() % staff_line_positions.size()
    var spawn_y = staff_line_positions[random_line_index]

    # Positionne la note au point de spawn
    new_note.global_position = Vector2(spawn_point.global_position.x, spawn_y)

    # Ajoute la note à la scène
    add_child(new_note)
