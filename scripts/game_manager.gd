extends Node


enum GamePhase { LOBBY, QUESTION, RESULTS }

signal phase_changed(new_phase)
signal player_list_updated
signal question_received(q_text, answers)

const OPTIONS_MENU_SCENE = preload("res://scenes/options_menu.tscn")


const PLAYER_COLORS = [
	Color("FF5D5D"),
	Color("5DFF89"),
	Color("5D9BFF"),
	Color("FFD95D"),
	Color("FF5DFF"),
	Color("5DFFFF"),
	Color("FF9B5D"),
	Color("B65DFF")
]

var options_menu_instance: CanvasLayer
var current_phase: GamePhase = GamePhase.LOBBY:
	set(value):
		current_phase = value
		phase_changed.emit(current_phase)
		print("Phase changed to: ", GamePhase.keys()[current_phase])
var players = {}
var current_question_index = 0
var question_db = []
var scores = {} #Format: {peer_id, score}
var players_answered = []
var round_selections = {} #Format: {peer_id: selected_option}

func _ready():
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	options_menu_instance = OPTIONS_MENU_SCENE.instantiate()
	add_child(options_menu_instance)
	options_menu_instance.visible = false
	
func load_json_files(path: String):
	if not FileAccess.file_exists(path):
		NetworkManager.send_log("File Does Not Exist!")
		return[]
		
	#accesses json file	
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text() 
	file.close()
	
	#parses json file
	var parsed_text = JSON.parse_string(json_text)
	question_db = parsed_text
	return parsed_text
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_options_menu()

func toggle_options_menu():
	
	if options_menu_instance.visible:
		options_menu_instance.visible = false
	else:
		options_menu_instance.visible = true

#join and tell server who i am
@rpc("any_peer", "call_local", "reliable")
func register_player(new_player_info):
	
	#if i am the server, i process the registration
	var sender_id = multiplayer.get_remote_sender_id()
	
	if multiplayer.is_server():
		var info_with_color = new_player_info
		
		#assign color logic if not already there
		if not players.has(sender_id):
			var color_index = players.size() % PLAYER_COLORS.size()
			info_with_color["color"] = PLAYER_COLORS[color_index]
			info_with_color["score"] = 0
			info_with_color["seat"] = color_index
			players[sender_id] = info_with_color
			
		#sync new list to everyone
		sync_player_list.rpc(players)

#the server tells everyone the new list
@rpc("authority", "call_local", "reliable")
func sync_player_list(updated_players):
	players = updated_players
	player_list_updated.emit()
	
	
#let everyone know the current phase
@rpc("authority", "call_local", "reliable")
func change_phase(new_phase_id):
	current_phase = new_phase_id
	
	options_menu_instance.update_menu_buttons(current_phase)

   # If we just started the question phase, send the data
	if current_phase == GamePhase.QUESTION:
		
		#clear the previous players answers
		players_answered.clear()
		round_selections.clear()
		
		if multiplayer.is_server():
			#pick the next question
			var q_data = question_db[current_question_index]
			#send to everyone
			sync_question.rpc(q_data["question"], q_data["options"], current_question_index)

#Make sure everyone has the right question
@rpc("authority", "call_local", "reliable")
func sync_question(q_text, answers, q_index):
	#update local index for the clients
	current_question_index = q_index
	#exit signal so ui can update
	question_received.emit(q_text, answers)


#any_peer allows clients to call this on the server
@rpc("any_peer", "call_local", "reliable")
func submit_answer(selected_option, remaining_time_score):
	#for security, only the server should access the score
	if multiplayer.is_server():
		var player_id = multiplayer.get_remote_sender_id()
		
		#prevent duplicates if they spam the button somehow
		if player_id in players_answered:
			return
			
		#mark the player as answered
		players_answered.append(player_id)	
		round_selections[player_id] = selected_option
		
		var correct_option = question_db[current_question_index]["answer"]
		print("SERVER CHECK - User selected: '", str(selected_option), "' | Correct JSON answer: '", str(correct_option), "'")

		if str(selected_option) == correct_option:
			NetworkManager.send_log("Player " + str(player_id) + " got it right!")
			print("+1")
			if not scores.has(player_id):
				scores[player_id] = 0.0
			scores[player_id] += (1.0 + remaining_time_score/1000.0)
			
		
		#wait for everyone to answer
		if players_answered.size() == players.size():
			end_round()	

	
			
@rpc("authority", "call_local", "reliable")
func sync_results(selections, current_scores):
	round_selections = selections
	scores = current_scores			
		
	

func end_round():
	#send the results data to everyone
	sync_results.rpc(round_selections, scores)
	#move to results
	change_phase.rpc(GamePhase.RESULTS)
	


func start_game_rpc():
	#only the host can call this
	if multiplayer.is_server():
		NetworkManager.set_lobby_lock(true) #<-lock the lobby
		change_phase.rpc(GamePhase.QUESTION)
		


func _on_peer_disconnected(id):
	#only the server handles this
	if multiplayer.is_server():
		if players.has(id):
			players.erase(id)
			#sync the new shorter list to everyone
			sync_player_list(players)
			
			
func reset_player_data():
	players.clear()
	players_answered.clear()
	player_list_updated.emit()
	

func reset_game():
	current_question_index += 1
	
	#check to see if we reached the end of the question index
	if current_question_index >= question_db.size():
		#game over
		current_question_index = 0
		
		#reset the scores when at the end
		scores.clear()
		
		#unlock the lobby
		if multiplayer.is_server():
			NetworkManager.set_lobby_lock(false)
		change_phase.rpc(GamePhase.LOBBY)
	else:
		#next round
		change_phase.rpc(GamePhase.QUESTION)
