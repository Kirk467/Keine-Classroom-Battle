extends CanvasLayer

func _ready() -> void:
	$Rect.material.set_shader_parameter("progress", 20.0)
	$Rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(target: String, transition_image: Texture2D = null) -> void:
	# Change the transition image if one is provided
	if transition_image != null:
		$Rect.texture = transition_image

	# Invisible → Visible
	$AnimationPlayer.play("transition")
	await $AnimationPlayer.animation_finished

	# Change scene
	var error = get_tree().change_scene_to_file(target)

	if error != OK:
		push_error("Failed to change scene: " + target)
		return

	await get_tree().process_frame

	# Visible → Invisible
	$AnimationPlayer.play("RESET")
	await $AnimationPlayer.animation_finished
