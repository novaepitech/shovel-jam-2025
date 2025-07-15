extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var subtitle_label = $VBoxContainer/SubtitleLabel
@onready var restart_button = $VBoxContainer/ButtonsBox/RestartButton
@onready var quit_button = $VBoxContainer/ButtonsBox/QuitButton
@onready var animation_player = $AnimationPlayer

func _ready():
	# Connect button signals to our functions.
	restart_button.pressed.connect(_on_restart_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	# Hide elements initially to animate their appearance.
	title_label.modulate.a = 0
	subtitle_label.modulate.a = 0
	restart_button.modulate.a = 0
	quit_button.modulate.a = 0

	# Play the "fade_in" animation.
	animation_player.play("fade_in")

# Function called when the "Restart" button is pressed.
func _on_restart_button_pressed():
	# Reset game state via GameManager before restarting the scene.
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Function called when the "Quit" button is pressed.
func _on_quit_button_pressed():
	get_tree().quit()
