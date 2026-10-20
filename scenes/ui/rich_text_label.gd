extends RichTextLabel

var original_y: float
var time_passed: float = 1
var amp: float = 8
var speed: float = 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	original_y = position.y


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time_passed += delta
	position.y = original_y + sin(time_passed * speed) * amp
