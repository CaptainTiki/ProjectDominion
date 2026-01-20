#mainmenu.gd
extends Control
class_name MainMenu

signal request_new_game
signal request_settings
signal request_exit

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	new_game_button.pressed.connect(func(): request_new_game.emit())
	settings_button.pressed.connect(func(): request_settings.emit())
	exit_button.pressed.connect(func(): request_exit.emit())
