extends Node


var playback: AudioStreamPlaybackPolyphonic
var music_player: AudioStreamPlayer

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "MUSIC"
	
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	
	var stream = AudioStreamPolyphonic.new()
	stream.polyphony = 32
	player.stream = stream
	player.play()
	player.bus = "SFX"
	
	playback = player.get_stream_playback()
	
	get_tree().node_added.connect(_on_node_added)
	
	connect_buttons(get_tree().root)

func _on_node_added(node: Node):
	if node is Button:
		_setup_button_signals(node)

func connect_buttons(root_node: Node):
	for child in root_node.get_children():
		if child is Button:
			_setup_button_signals(child)
		connect_buttons(child)

func _setup_button_signals(button: Button):
	button.mouse_entered.connect(_play_hover)
	button.pressed.connect(_play_pressed)

func _play_hover():
	if playback:
		playback.play_stream(preload('res://audio/47313572-ui-sounds-pack-3-15-359713.mp3'), 0, 0, randf_range(0.8, 1.2))

func _play_pressed():
	if playback:
		playback.play_stream(preload('res://audio/47313572-ui-sounds-pack-4-12-359738.mp3'), 0, 0, randf_range(0.8, 1.2))
		
#----------------------------------------------------------------

func play_music(track: AudioStream, volume_db: float = 0.0) -> void:

	music_player.volume_db = volume_db

	var bus_index = AudioServer.get_bus_index("MUSIC")

	print("========== MUSIC DEBUG ==========")
	print("Track: ", track.resource_path)
	print("Player Volume: ", music_player.volume_db)
	print("Music Bus Volume: ", AudioServer.get_bus_volume_db(bus_index))
	print("Master Volume: ", AudioServer.get_bus_volume_db(0))

	if music_player.stream == track and music_player.playing:
		return

	music_player.stream = track
	music_player.play()
	
func stop_music():
	music_player.stop()

#----------------------------------------------------------------

func set_master_volume(value: float):
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func set_music_volume(value: float):
	var bus_index = AudioServer.get_bus_index("MUSIC")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	
func set_sfx_volume(value: float):
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	
