extends Control
var remaining_time_score = 0.0
var user_time_set = 30.0

#DEBUG
@onready var debug_label: Label = $DebugLabel

#UI
@onready var lobby_ui: TextureRect = $SplitContainer/Stage/LobbyUI
@onready var question_ui: TextureRect = $SplitContainer/Stage/QuestionUI
@onready var results_ui: TextureRect = $SplitContainer/Stage/ResultsUI
@onready var host_button: Button = $SplitContainer/Stage/LobbyUI/HostButton
@onready var disconnect_button: Button = $SplitContainer/Stage/LobbyUI/DisconnectButton
@onready var refresh_button: Button = $SplitContainer/Stage/LobbyUI/LobbyContainer/RefreshButton
@onready var player_list_container: VBoxContainer = $SplitContainer/Stage/LobbyUI/PlayerListContainer
@onready var start_game_button: Button = $SplitContainer/Stage/LobbyUI/StartGameButton
@onready var question_label: Label = $SplitContainer/Stage/QuestionUI/VBoxContainer/Label
@onready var next_round_button: Button = $SplitContainer/Stage/ResultsUI/NextRoundButton
@onready var timer_bar: ProgressBar = $SplitContainer/Stage/QuestionUI/ProgressBar
@onready var round_timer: Timer = $RoundTimer
@onready var winner_label: Label = $SplitContainer/Stage/ResultsUI/VBoxContainer/WinnerLabel
@onready var score_label: Label = $SplitContainer/Stage/ResultsUI/VBoxContainer/ScoreListLabel
@onready var file_dialog: FileDialog = $SplitContainer/Stage/LobbyUI/FileDialog
@onready var find_file_button: Button = $SplitContainer/Stage/LobbyUI/FindFileButton
@onready var custom_timer_editor: SpinBox = $SplitContainer/Stage/LobbyUI/CustomTimerEditor
var spinBoxLineEdit



#LISTS AND CONTAINERS
@onready var desk: PanelContainer = $SplitContainer/Desk
@onready var desk_grid_container: GridContainer = $SplitContainer/Desk/MarginContainer/GridContainer
@onready var lobby_list: VBoxContainer = $SplitContainer/Stage/LobbyUI/LobbyContainer/ScrollContainer/LobbyList
@onready var lobby_container: VBoxContainer = $SplitContainer/Stage/LobbyUI/LobbyContainer
@onready var answer_buttons: Array = $SplitContainer/Desk/MarginContainer/GridContainer.get_children()
@onready var result_buttons: Array = $SplitContainer/Stage/ResultsUI/VBoxContainer/GridContainer.get_children()


var player_row_scene = preload("res://scenes/ui/player_list_row.tscn")


func _ready():
	#DEBUG
	NetworkManager.log_updated.connect(_on_log_updated)
	
	if not NetworkManager.connected_to_steam:
		NetworkManager.send_log("Steam is NOT running! Is your Steam client open?")
	else:
		NetworkManager.send_log("Steam is running! User: " + Steam.getPersonaName())
	
	#GAME MANAGER
	GameManager.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(GameManager.current_phase)
	GameManager.player_list_updated.connect(update_lobby_list)
	GameManager.question_received.connect(_on_question_received)
	
	#NETWORK MANAGER
	NetworkManager.lobby_list_updated.connect(_on_lobby_list_updated)
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
	
	#UI
	round_timer.timeout.connect(_on_timer_timeout)
	
	#BUTTON CONNECTIONS	
	host_button.pressed.connect(_on_host_button_pressed)
	find_file_button.pressed.connect(_on_file_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	disconnect_button.pressed.connect(_on_disconnect_button_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	for i in range(answer_buttons.size()):
	# Bind the entire button node to the function
		answer_buttons[i].pressed.connect(_on_answer_pressed.bind(answer_buttons[i]))
	next_round_button.pressed.connect(func(): GameManager.reset_game())
	file_dialog.file_selected.connect(_on_file_selected)
	spinBoxLineEdit = custom_timer_editor.get_line_edit()
	spinBoxLineEdit.text_submitted.connect(_on_timer_set)

	multiplayer.peer_connected.connect(_on_peer_connected)
	
	
func _process(_delta):
	if !round_timer.is_stopped():
		timer_bar.max_value = round_timer.wait_time
		timer_bar.value = round_timer.time_left	
		remaining_time_score = timer_bar.value
		

func _on_phase_changed(phase):
	lobby_ui.hide()
	question_ui.hide()
	results_ui.hide()
	desk_grid_container.hide()
	find_file_button.hide()
	
	match phase:
		GameManager.GamePhase.LOBBY:
			lobby_ui.show()
			desk_grid_container.hide()
			desk.hide()
			find_file_button.hide()
			var lobby_music = preload("res://audio/ULiL Character Select Theme Gensokyo Mystery Discovery.mp3")
			SoundManager.play_music(lobby_music)
		GameManager.GamePhase.QUESTION:	
			question_ui.show()
			desk_grid_container.show()
			desk.show()
			round_timer.start(user_time_set)
			SoundManager.stop_music()
		GameManager.GamePhase.RESULTS:
			results_ui.show()
			round_timer.stop()
			
			#update visuals
			display_results()
			
			#makes sure only the host sees the next_round button
			if multiplayer.is_server():
				next_round_button.show()
			else:
				next_round_button.hide()
				
			if GameManager.current_question_index + 1 >= GameManager.question_db.size():
				next_round_button.text = "RETURN TO LOBBY"
			else:
				next_round_button.text = "NEXT ROUND"	
				
func _on_file_button_pressed(): 
	file_dialog.popup()

func _on_file_selected(path: String):
	GameManager.load_json_files(path)
	start_game_button.show()
	
func _on_timer_set(_new_time: String):
	var float_value: float = float(_new_time)
	user_time_set = float_value
	custom_timer_editor.get_line_edit().release_focus()
	print(float_value)
	


func _on_host_button_pressed():
	if not NetworkManager.connected_to_steam:
		NetworkManager.send_log("Cannot host: Steam is offline.")
		host_button.disabled = false  # Keeps the button clickable!
		return
		
	host_button.disabled = true
	NetworkManager.host_game()

func _on_start_game_pressed():
	#calls the GameManager to start the loop
	GameManager.start_game_rpc()
	

func _on_lobby_list_updated(lobbies):
	refresh_button.disabled = false
	
	#clear any old buttons
	for child in lobby_list.get_children():
		child.queue_free()
	
	#create new buttons
	for lobby_id in lobbies:
		var lobby_name = Steam.getLobbyData(lobby_id, "name")
		var member_count = Steam.getNumLobbyMembers(lobby_id)
		var btn = Button.new()
		btn.text = str(lobby_name) + " (" + str(member_count) + " Players)"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		#connect the button to join the specific id
		btn.pressed.connect(func(): NetworkManager.join_game(lobby_id))
		
		lobby_list.add_child(btn)


func update_lobby_list():
	#clear old list
	for child in player_list_container.get_children():
		child.queue_free()
		
	#rebuild from GameManager data
	for id in GameManager.players:
		var p_data = GameManager.players[id]
		var row = player_row_scene.instantiate()
		row.get_node("Label").text = p_data["name"]
		row.get_node("TextureRect").self_modulate = p_data["color"]
		player_list_container.add_child(row)


func _on_connected_to_server():
	#hide the menu, show the disconnect button
	host_button.hide()
	lobby_container.hide()
	disconnect_button.show()
	find_file_button.hide()
	
	#only the server host sees the start button
	if multiplayer.is_server():
		find_file_button.show()
	
		
	#host registers immediately
	if multiplayer.is_server():
		var my_name = Steam.getPersonaName()
		var my_id = multiplayer.get_unique_id()
		GameManager.register_player.rpc({"name": my_name, "id": my_id})

func _on_disconnected_from_server():
	#force the ui back to the lobby
	lobby_ui.show()
	question_ui.hide()
	results_ui.hide()
	find_file_button.hide()
	
	#reset menu buttons
	host_button.show()
	host_button.disabled = false
	lobby_container.show()
	disconnect_button.hide()
	start_game_button.hide()
	find_file_button.hide()
	
	#clear local data so we dont see any old players
	GameManager.reset_player_data()
	
	#clear the list so old buttons dont linger
	for child in lobby_list.get_children():
		child.queue_free()

func _on_refresh_button_pressed():
	NetworkManager.refresh_lobby_list()

func _on_disconnect_button_pressed():
	NetworkManager.disconnect_from_server()

func _on_peer_connected(id):
	#id 1 is the server. if we see them connect. we are ready to talk
	if id == 1 and not multiplayer.is_server():
		#small delay to ensure the connection is fully open
		await get_tree().create_timer(0.1).timeout
		
		var my_name = Steam.getPersonaName()
		var my_id = multiplayer.get_unique_id()
		GameManager.register_player.rpc({ "name": my_name, "id": my_id})
		

func _on_question_received(q_text, answers):
	question_label.text = q_text
	for i in range(answer_buttons.size()):
		answer_buttons[i].text = answers[i]
		#reset button state
		answer_buttons[i].disabled = false


func _on_answer_pressed(pressed_button: Button):
	#disable keys to prevent double input
	for btn in answer_buttons:
		btn.disabled = true
	#send choice to the server
	GameManager.submit_answer.rpc(pressed_button.text, remaining_time_score)


func _on_timer_timeout():
	if multiplayer.is_server():
		#force round to end even if people havent answered
		GameManager.end_round()


func display_results():
	#grabs the correct answer index
	var question_data = GameManager.question_db[GameManager.current_question_index]
	var correct_answer = question_data["answer"]
	

	#reset buttons (clear old data like avatars and resets colors)
	for i in range(result_buttons.size()):
		var btn = result_buttons[i]
		btn.text = question_data["options"][i]
		
		#remove old avatars
		for child in btn.get_children():
			child.queue_free()
			
		#color logic
		if btn.text == correct_answer:
			btn.self_modulate = Color.GREEN
		else:
			btn.self_modulate = Color.RED
			
	#place player avatars
	for player_id in GameManager.round_selections:
		var submitted_text = GameManager.round_selections[player_id]
		
		#safety check in case index is out of bounds
		var target_btn: Button = null
		for btn in result_buttons:
			if btn.text == submitted_text:
				target_btn = btn
				break
		
		if target_btn != null:
			create_avatar_on_button(target_btn, player_id)
		
	#show scores
	update_score_ui()
	

func create_avatar_on_button(btn, player_id):
	var p_data = GameManager.players.get(player_id)
	if !p_data:
		return
		
	var icon = TextureRect.new()
	icon.texture = player_row_scene.instantiate().get_node("TextureRect").texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(30,30)
	icon.self_modulate = p_data["color"]
	btn.add_child(icon)
	
	#fixed player avatar locations
	#define 8 slots, 2 rows of 4
	var slots = [
		Vector2(10,10), Vector2(50,10), Vector2(90,10), Vector2(130,10),
		Vector2(10,50), Vector2(50,50), Vector2(90,50), Vector2(130,50)
	]
	
	#get the player's assigned seat (default to 0 if missing)
	var seat_index = p_data.get("seat", 0)
	
	#if we somehow have more than 8 players, loop back around
	if seat_index >= slots.size():
		seat_index = 0
		
	icon.position = slots[seat_index]


func update_score_ui():
	var text = "SCORES:\n"
	var highest_score = -1
	var winners = [] #list to hold all winners
	
	#calculate scores and find the highest score
	for id in GameManager.players:
		var p_data = GameManager.players[id]
		var final_score = GameManager.scores.get(id, 0.0)
		if final_score >= 1.0:
			NetworkManager.send_log(str(final_score) + " " + str(remaining_time_score))
		text += p_data["name"] + ": " + str(final_score) + "\n"
		
		
		if final_score > highest_score:
			highest_score = final_score
			winners = [p_data["name"]] #new high score, reset list
		elif final_score == highest_score:
			winners.append(p_data["name"]) #tie found, add to list
			
	score_label.text = text
	
	
	#display winner or tie
	if GameManager.current_question_index + 1 >= GameManager.question_db.size():
		if winners.size() > 1:
			winner_label.text = "Tie: " + " & ".join(winners)
		else:
			winner_label.text = "Winner: " + winners[0]
	else:
		winner_label.text = ""


#region Debug

func _on_log_updated(msg):
	debug_label.text += "\n" + str(msg)
	var lines = debug_label.text.split("\n")
	if lines.size() > 8:
		debug_label.text = "\n".join(lines.slice(-8))

#endregion
