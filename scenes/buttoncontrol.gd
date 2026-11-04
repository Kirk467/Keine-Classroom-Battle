class_name ButtonsExample extends Control

var tween_new: Tween

@onready var v_box_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer


func new_tween(state: bool) -> void:
	if tween_new and tween_new.is_running():
		tween_new.kill()
		
	if state:
		tween_new = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween_new = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
	tween_new.set_parallel(true)
	
	var idx: int = 0
	for btn: Button in v_box_container.get_children():
		if state:
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ONE, 0.15).set_delay(idx * 0.05)
		else:
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ZERO, 0.15).set_delay(idx * 0.05)
		idx += 1
