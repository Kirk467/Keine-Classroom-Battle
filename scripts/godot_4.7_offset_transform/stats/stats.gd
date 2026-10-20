class_name StatsExample extends Control

var tween: Tween

@onready var appear_btn: Button = $ActionBtns/AppearBtn
@onready var stats: VBoxContainer = $Stats

func _ready() -> void:
	appear_btn.toggled.connect(toggle_appear)
		
	for c: Control in stats.get_children():
		c.offset_transform_enabled = true
		c.offset_transform_scale = Vector2.ZERO
		
func toggle_appear(state: bool) -> void:
	if state:
		appear_btn.text = "Disappear"
	else:
		appear_btn.text = "Appear"
	
	if tween and tween.is_running():
		tween.kill()
		
	if state:
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
	tween.set_parallel(true)
	
	var idx: int = 0
	for c: Control in stats.get_children():
		if state:
			tween.tween_property(c, "offset_transform_scale", Vector2.ONE, 0.05).set_delay(idx * 0.05)
			#tween.tween_property(c, "offset_transform_position_ratio:x", 0.0, 0.25).from(-1.0).set_delay(idx * 0.05) # Straigth
			tween.tween_property(c, "offset_transform_position_ratio:x", randf_range(-0.1, 0.1), 0.25).from(-1.0).set_delay(idx * 0.05) # Random offset
		else:
			tween.tween_property(c, "offset_transform_scale", Vector2.ZERO, 0.15).set_delay(idx * 0.05)
		idx += 1
