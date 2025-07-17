extends Node

## L'horloge musicale centrale du jeu. Représente la position
## temporelle actuelle dans la chanson, en "beats" (temps musicaux).
## C'est la variable clé qui répond aux exigences 1 et 3.
var song_position_in_beats: float = 0.0

# BPM (Beats Per Minute) du niveau actuel.
var _bpm: float = 120.0
# Variable pour savoir si le conducteur est actif.
var _is_running: bool = false


## Démarre le conducteur avec un BPM spécifique.
## Cette fonction sera appelée par la scène principale (main.gd).
func start(level_bpm: float) -> void:
	_bpm = level_bpm
	song_position_in_beats = 0.0
	_is_running = true
	print("RhythmConductor started with BPM: ", _bpm)


## Arrête le conducteur.
func stop() -> void:
	_is_running = false


## La fonction _process est le moteur de notre horloge.
## Elle s'assure que le temps musical progresse de manière continue.
## Ceci répond à l'exigence 2.
func _process(delta: float) -> void:
	if not _is_running:
		return

	# Le calcul pour incrémenter notre horloge :
	# 1. On calcule combien de beats il y a par seconde (BPM / 60).
	# 2. On multiplie ce ratio par le temps écoulé depuis la dernière frame (delta).
	# 3. On ajoute le résultat à notre position actuelle.
	song_position_in_beats += (_bpm / 60.0) * delta
