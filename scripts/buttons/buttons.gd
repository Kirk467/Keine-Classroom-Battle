class_name ButtonsExample extends Control

var tween_old: Tween
var tween_new: Tween

@onready var old_btn: Button = $ActionBtns/OldBtn
@onready var new_btn: Button = $ActionBtns/NewBtn
@onready var btn_container_old: VBoxContainer = %BtnContainerOld
@onready var btn_container_new: VBoxContainer = %BtnContainerNew

func _ready() -> void:
	old_btn.toggled.connect(old_tween)
	new_btn.toggled.connect(new_tween)
		
	for btn: Button in btn_container_new.get_children():
		btn.offset_transform_enabled = true
		btn.offset_transform_scale = Vector2.ZERO
		
	await get_tree().process_frame # if we don't wait a frame, the scale is overriden by the container
	for btn: Button in btn_container_old.get_children():
		btn.scale = Vector2.ZERO
		#btn.modulate.a = 0.0 # If we don't want to wait a frame, we can make the buttons invisible.

func old_tween(state: bool) -> void:
	if state:
		old_btn.text = "disappear"
	else:
		old_btn.text = "appear"
	
	if tween_old and tween_old.is_running():
		tween_old.kill()
		
	if state:
		tween_old = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween_old = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
	tween_old.set_parallel(true)
	
	var idx: int = 0
	for btn: Button in btn_container_old.get_children():
		if state:
			tween_old.tween_property(btn, "scale", Vector2.ONE, 0.15).set_delay(idx * 0.05)
			tween_old.tween_property(btn, "modulate:a", 1.0, 0.05).set_delay(idx * 0.05) # We need to tween modulate if we hid it in ready
		else:
			tween_old.tween_property(btn, "scale", Vector2.ZERO, 0.15).set_delay(idx * 0.05)
		idx += 1
	
func new_tween(state: bool) -> void:
	if state:
		new_btn.text = "disappear"
	else:
		new_btn.text = "appear"
	
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
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ONE, 0.15).set_delay(idx * 0.05)
		else:
			tween_new.tween_property(btn, "offset_transform_scale", Vector2.ZERO, 0.15).set_delay(idx * 0.05)
		idx += 1
