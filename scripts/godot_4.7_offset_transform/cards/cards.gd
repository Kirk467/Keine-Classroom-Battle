class_name CardsExample extends Control

@export var card_scene = preload("uid://cbet0tqjycopk")
@export var card_overlap_scene = preload("uid://cfe1p2qnaebxk")

@onready var cards_container: HBoxContainer = $CardsContainer
@onready var cards_overlap_container: HBoxContainer = $CardsOverlapContainer

func _ready() -> void:
	pass

func add_card() -> void:
	var instance: Control = card_overlap_scene.instantiate()
	cards_overlap_container.add_child(instance)

func remove_card() -> void:
	if cards_overlap_container.get_child_count() == 0: return
	cards_overlap_container.get_children().back().destroy()

func _on_minus_btn_pressed() -> void:
	remove_card()

func _on_plus_btn_pressed() -> void:
	add_card()
