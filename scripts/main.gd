# res://scripts/main.gd
extends Node2D

@export var note_scene: PackedScene
@export var level_data_scene: PackedScene
@export var bpm: float = 120.0 
@export var initial_scroll_speed: float = 400.0

@onready var note_spawn_timer: Timer = $NoteSpawnTimer
# NOUVEAU : Référence vers notre conteneur
@onready var world_container: Node2D = $WorldContainer
@onready var staff_lines: TextureRect = $WorldContainer/StaffLines

var beat_duration: float
var current_scroll_speed: float
var note_queue: Array[Node] = []
var note_queue_index: int = 0
var last_note_spawn_x: float = 0.0

func _ready() -> void:
    # Ceci va maintenant fonctionner car SignalManager est un Node valide.
    SignalManager.speed_change_requested.connect(_on_speed_change_requested)
    
    beat_duration = 60.0 / bpm
    current_scroll_speed = initial_scroll_speed
    
    note_spawn_timer.timeout.connect(_on_note_spawn_timer_timeout)

    load_and_prepare_level()
    
    # Le point de départ pour le spawn est le bord droit de l'écran.
    last_note_spawn_x = get_viewport().get_visible_rect().size.x
    
    _on_note_spawn_timer_timeout()

func _process(delta: float) -> void:
    # Beaucoup plus performant ! On ne déplace qu'un seul nœud.
    world_container.position.x -= current_scroll_speed * delta

func _on_speed_change_requested(new_speed: float):
    print("Vitesse changée de %f à %f" % [current_scroll_speed, new_speed])
    current_scroll_speed = new_speed

func _on_note_spawn_timer_timeout():
    if note_queue_index >= note_queue.size():
        note_spawn_timer.stop()
        print("Niveau terminé.")
        return
        
    var node_to_spawn_data = note_queue[note_queue_index]
    
    var time_interval = 0.0
    
    if node_to_spawn_data is NoteData:
        time_interval = calculate_wait_time_for_note(node_to_spawn_data.type)
        # On ne place un silence que s'il a un temps, sinon on le saute.
        if node_to_spawn_data.type != NoteData.NoteType.SILENCE:
            var note_instance = note_scene.instantiate()
            
            world_container.add_child(note_instance)

            # Set the note's type so it can change its sprite
            note_instance.set_type(node_to_spawn_data.type)

            var new_x_pos = last_note_spawn_x + (current_scroll_speed * time_interval)
            note_instance.position = Vector2(new_x_pos, node_to_spawn_data.position.y)
            last_note_spawn_x = new_x_pos
    elif node_to_spawn_data is SpeedTrigger:
        # Un trigger ne prend pas de temps, il est placé à la même position
        # que la note précédente ou suivante. On peut le placer avec la note précédente.
        time_interval = 0.0 # On le fait apparaître en même temps que la note précédente.
        node_to_spawn_data.get_parent().remove_child(node_to_spawn_data)
        node_to_spawn_data.position = Vector2(last_note_spawn_x, -get_viewport().get_visible_rect().size.y / 2)
        world_container.add_child(node_to_spawn_data)
    
    note_queue_index += 1
    
    # Programme le prochain événement
    if time_interval > 0:
        note_spawn_timer.wait_time = time_interval
        note_spawn_timer.start()
    else:
        # Si l'intervalle est de 0 (comme pour un trigger), on déclenche
        # immédiatement le prochain tour pour ne pas attendre.
        _on_note_spawn_timer_timeout()

func load_and_prepare_level():
    var level_data_node = level_data_scene.instantiate()
    var all_nodes = level_data_node.get_children()
    
    all_nodes.sort_custom(func(a, b): return a.position.x < b.position.x)
    note_queue = all_nodes

    # --- NOUVELLE LOGIQUE ---
    # Après avoir chargé le niveau, on le "construit" une première fois en mémoire
    # pour calculer sa longueur totale sans encore rien afficher.
    var total_level_width: float = 0.0
    var temp_scroll_speed = initial_scroll_speed

    # On simule le placement de chaque note pour trouver la position de la dernière.
    for node_data in note_queue:
        if node_data is NoteData:
            var time_interval = calculate_wait_time_for_note(node_data.type)
            total_level_width += temp_scroll_speed * time_interval
        elif node_data is SpeedTrigger:
            # Si on rencontre un trigger, on met à jour la vitesse pour les calculs suivants.
            temp_scroll_speed = node_data.new_speed
    
    # On ajoute une marge à la fin pour que ça ne se coupe pas brutalement.
    total_level_width += get_viewport().get_visible_rect().size.x

    # Maintenant, on applique cette largeur à notre TextureRect.
    staff_lines.size.x = total_level_width
    print("Niveau préparé. Longueur totale des lignes de partition : ", total_level_width)

func calculate_wait_time_for_note(note_type: NoteData.NoteType) -> float:
    match note_type:
        NoteData.NoteType.CROCHE: return beat_duration
        NoteData.NoteType.DOUBLE: return beat_duration / 2.0
        NoteData.NoteType.TRIOLET: return beat_duration / 3.0
        NoteData.NoteType.NOIRE: return beat_duration * 2.0
        NoteData.NoteType.SILENCE: return beat_duration
    return beat_duration
