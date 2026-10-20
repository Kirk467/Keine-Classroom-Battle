class_name Home extends Control

@export var buttons_scene = preload("uid://d2o0aygquit55")
@export var stats_scene = preload("uid://da3rdotuyisxl")
@export var cards_scene = preload("uid://bhlusn1ccigiy")
@export var animation_scene = preload("uid://bbxpd225sox54")

func _on_btns_btn_pressed() -> void:
	get_tree().change_scene_to_packed(buttons_scene)

func _on_stats_btn_pressed() -> void:
	get_tree().change_scene_to_packed(stats_scene)

func _on_cards_btn_pressed() -> void:
	get_tree().change_scene_to_packed(cards_scene)

func _on_animation_btn_pressed() -> void:
	get_tree().change_scene_to_packed(animation_scene)
