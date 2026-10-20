extends Button

@onready var multiplayer_button: Button = $"."

var tween: Tween

func _ready() -> void:
	mouse_entered.connect(hover)
	mouse_exited.connect(unhover)
	
	pivot_offset_ratio = Vector2(0.5, 0.5)

func hover() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "scale:x", 1.2, 0.1)
	#tween.tween_property(self, "transform_offset_scale:x", 1.2, 0.1) # We can use offset_transform_scale now if we want
	tween.tween_property(self, "scale:y", 0.75, 0.13)
	#tween.tween_property(self, "transform_offset_scale:y", 0.75, 0.13) # We can use offset_transform_scale now if we want
	tween.tween_property(self, "rotation_degrees", randf_range(3.0, 5.0) * [-1.0, 1.0].pick_random(), 0.1)
	tween.chain().tween_property(self, "scale:x", 1.1, 0.15)
	#tween.tween_property(self, "transform_offset_scale:x", 1.1, 0.15) # We can use offset_transform_scale now if we want
	tween.tween_property(self, "scale:y", 1.1, 0.15)
	#tween.tween_property(self, "transform_offset_scale:y", 1.1, 0.15) # We can use offset_transform_scale now if we want
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)
	
func unhover() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.15)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_pressed():
	Transtest.change_scene("res://scenes/main_game.tscn")
