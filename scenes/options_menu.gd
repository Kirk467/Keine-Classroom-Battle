extends CanvasLayer

@onready var return_to_main_menu: Button = $ColorRect/CenterContainer/MarginContainer/VBoxContainer/ReturnToMainMenu

func update_menu_buttons(phase: int) -> void:
	return_to_main_menu.visible = (
		phase != GameManager.GamePhase.QUESTION
	)

func _on_return_to_game_pressed():
	GameManager.toggle_options_menu()

func _on_return_to_main_menu_pressed() -> void:
	GameManager.toggle_options_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
