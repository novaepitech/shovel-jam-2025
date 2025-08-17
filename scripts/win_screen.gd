extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var subtitle_label = $VBoxContainer/SubtitleLabel
@onready var play_again_button = $VBoxContainer/ButtonsBox/PlayAgainButton
@onready var quit_button = $VBoxContainer/ButtonsBox/QuitButton
@onready var animation_player = $AnimationPlayer

func _ready():
	# Connect button signals to our functions.
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# Hide elements initially to animate their appearance.
	title_label.modulate.a = 0
	subtitle_label.modulate.a = 0
	play_again_button.modulate.a = 0
	quit_button.modulate.a = 0

	# Play the "fade_in" animation.
	animation_player.play("fade_in")

# Function called when the "Play Again" button is pressed.
func _on_play_again_button_pressed():
	# Reset game state via GameState before restarting the scene.
	GameState.reset_lives()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Function called when the "Quit" button is pressed.
func _on_quit_button_pressed():
	get_tree().quit()
