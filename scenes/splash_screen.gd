extends Control

func _ready() -> void:
	$AnimationPlayer.play("intro")
	await $AnimationPlayer.animation_finished

	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
