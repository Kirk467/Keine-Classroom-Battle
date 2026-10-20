extends HSlider


@export var bus_name: String
var bus_index: int

func _ready():
	bus_index = AudioServer.get_bus_index(bus_name)
	
	if bus_index == -1:
		print("Audio bus not found")
		return
	
	var current_db = AudioServer.get_bus_volume_db(bus_index)
	value = db_to_linear(current_db)
	
	if AudioServer.is_bus_mute(bus_index):
		value = 0.0
	
	value_changed.connect(_on_value_changed)
	
func _on_value_changed(new_value: float):
	if bus_index == -1:
		return
	
	if new_value <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		
		if bus_name == "Master":
			SoundManager.set_master_volume(new_value)
		elif bus_name == "MUSIC":
			SoundManager.set_music_volume(new_value)
		elif bus_name == "SFX":
			SoundManager.set_sfx_volume(new_value)
