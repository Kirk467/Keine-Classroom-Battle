class_name Card extends Panel

@export var angle_min: float = -15.0
@export var angle_max: float = 15.0

var tween: Tween
var default_rot: float = 0.0

@onready var border: Panel = $Border

func _ready() -> void:
	get_parent().child_entered_tree.connect(angle_card)
	get_parent().child_exiting_tree.connect(
		func(node: Node) -> void:
			if not is_inside_tree() or not node.is_inside_tree(): return
			await get_tree().process_frame
			angle_card()
	)
	
	mouse_entered.connect(hover)
	mouse_exited.connect(unhover)
	
	border.self_modulate.a = 0.0
	pivot_offset_ratio = Vector2(0.5, 0.5)

	angle_card()
	
func angle_card(_unused: Node = null) -> void:
	var child_count: int = get_parent().get_child_count()
	offset_transform_rotation = deg_to_rad(lerp(angle_min, angle_max, float(get_index())/float(child_count)))
	default_rot = offset_transform_rotation 

func hover() -> void:
	z_index = 1
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE * 1.2, 0.1)
	tween.tween_property(self, "offset_transform_rotation", 0.0, 0.1)
	tween.tween_property(self, "offset_transform_position_ratio:y", -0.25, 0.15)
	tween.tween_property(border, "self_modulate:a", 1.0, 0.1)
	
func unhover() -> void:
	z_index = 0
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.2)
	tween.tween_property(self, "offset_transform_rotation", default_rot, 0.2)
	tween.tween_property(self, "offset_transform_position_ratio:y", 0.0, 0.25)
	tween.tween_property(border, "self_modulate:a", 0.0, 0.1)
