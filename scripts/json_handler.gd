extends Node

@onready var file_dialog: FileDialog = $SplitContainer/Stage/LobbyUI/FileDialog
@onready var find_file_button: Button = $SplitContainer/Stage/LobbyUI/FindFileButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_button_pressed():
	file_dialog.popup()
	
