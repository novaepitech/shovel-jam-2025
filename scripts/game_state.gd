extends Node

signal lives_changed(new_lives: int)

const MAX_LIVES: int = 3
var current_lives: int

func _enter_tree():
	# This is called once when the autoload is first loaded at game start.
	# We initialize the lives here.
	current_lives = MAX_LIVES

func decrease_life():
	current_lives -= 1
	lives_changed.emit(current_lives)

func get_current_lives() -> int:
	return current_lives

func reset_lives():
	current_lives = MAX_LIVES
	lives_changed.emit(current_lives)
