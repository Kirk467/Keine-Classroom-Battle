class_name ButtonsExample extends Control

var tween_new: Tween

@onready var btn_container_new: VBoxContainer = $Panel/MarginContainer/btn_container_new

func _ready() -> void:
	for btn: Button in btn_container_new.get_children():
		btn.offset_transform_enabled = true
		btn.offset_transform_scale = Vector2.ZERO
	
	get_tree().create_timer(1.0).timeout.connect(func(): new_tween(true))
	SoundManager.play_music(preload("res://audio/Touhou Project - Nostalgic Blood of the East ~ Old World (Calm Night Remix).mp3"))
	
	
func new_tween(state: bool) -> void:
	if tween_new and tween_new.is_running():
		tween_new.kill()
		
	if state:
		tween_new = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween_new = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
	tween_new.set_parallel(true)
	
	var idx: int = 0
	for btn: Button in btn_container_new.get_children():
		if state:
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ONE, 0.15).set_delay(idx * 0.3)
		else:
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ZERO, 0.15).set_delay(idx * 0.1)
		idx += 1


func _on_singleplayer_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	

func _on_options_button_pressed() -> void:
	GameManager.toggle_options_menu()
	
	
func _on_exit_button_pressed() -> void:
	get_tree().quit()
