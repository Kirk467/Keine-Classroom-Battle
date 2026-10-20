class_name GoHome extends Node

@export var home_path: String = "res://home.tscn"


func _ready() -> void:
	get_parent().pressed.connect(
		func() -> void:
			get_tree().change_scene_to_file(home_path)
	)
