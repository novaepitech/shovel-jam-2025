extends CanvasLayer

@onready var hearts: Array[Sprite2D] = [$LivesContainer/Heart1, $LivesContainer/Heart2, $LivesContainer/Heart3]

func _ready():
	update_lives_display(GameState.get_current_lives())

	GameState.lives_changed.connect(update_lives_display)

func update_lives_display(current_lives: int):
	for i in range(hearts.size()):
		hearts[i].visible = (i < current_lives)
