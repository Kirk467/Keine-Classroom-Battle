extends Control


var remaining_time_score: float = 0.0
var user_time_set: float = 30.0


const LOBBY_MUSIC = preload(
	"res://audio/ULiL Character Select Theme Gensokyo Mystery Discovery.mp3"
)

const PLAYER_ROW_SCENE = preload(
	"res://scenes/ui/player_list_row.tscn"
)


# =========================================================
# NODE REFERENCES
# =========================================================

@onready var debug_label: Label = $DebugLabel

@onready var lobby_ui: TextureRect = $SplitContainer/Stage/LobbyUI
@onready var question_ui: TextureRect = $SplitContainer/Stage/QuestionUI
@onready var results_ui: TextureRect = $SplitContainer/Stage/ResultsUI

@onready var host_button: Button = $SplitContainer/Stage/LobbyUI/HostButton
@onready var disconnect_button: Button = $SplitContainer/Stage/LobbyUI/DisconnectButton

@onready var refresh_button: Button = $SplitContainer/Stage/LobbyUI/LobbyContainer/RefreshButton

@onready var player_list_container: VBoxContainer = $SplitContainer/Stage/LobbyUI/PlayerListContainer

@onready var start_game_button: Button = $SplitContainer/Stage/LobbyUI/StartGameButton
@onready var find_file_button: Button = $SplitContainer/Stage/LobbyUI/FindFileButton

@onready var question_label: Label = $SplitContainer/Stage/QuestionUI/VBoxContainer/Label

@onready var next_round_button: Button = $SplitContainer/Stage/ResultsUI/NextRoundButton

@onready var timer_bar: ProgressBar = $SplitContainer/Stage/QuestionUI/ProgressBar
@onready var round_timer: Timer = $RoundTimer

@onready var winner_label: Label = $SplitContainer/Stage/ResultsUI/VBoxContainer/WinnerLabel
@onready var score_label: Label = $SplitContainer/Stage/ResultsUI/VBoxContainer/CenterContainer/ScrollContainer/ScoreListLabel

@onready var file_dialog: FileDialog = $SplitContainer/Stage/LobbyUI/FileDialog

@onready var custom_timer_editor: SpinBox = $SplitContainer/Stage/LobbyUI/CustomTimerEditor

@onready var desk: PanelContainer = $SplitContainer/Desk

@onready var desk_grid_container: GridContainer = $SplitContainer/Desk/MarginContainer/GridContainer

@onready var lobby_list: VBoxContainer = $SplitContainer/Stage/LobbyUI/LobbyContainer/ScrollContainer/LobbyList

@onready var lobby_container: VBoxContainer = $SplitContainer/Stage/LobbyUI/LobbyContainer

@onready var answer_buttons: Array = $SplitContainer/Desk/MarginContainer/GridContainer.get_children()

@onready var result_buttons: Array = $SplitContainer/Stage/ResultsUI/VBoxContainer/GridContainer.get_children()


# =========================================================
# INITIALIZATION
# =========================================================

func _ready() -> void:

	# Connect debug output.
	if not NetworkManager.log_updated.is_connected(_on_log_updated):
		NetworkManager.log_updated.connect(_on_log_updated)

	# Display Steam status.
	if not NetworkManager.connected_to_steam:
		NetworkManager.send_log(
			"Steam is NOT running! Is your Steam client open?"
		)
	else:
		NetworkManager.send_log(
			"Steam is running! User: " + Steam.getPersonaName()
		)

	# GameManager signals.
	if not GameManager.phase_changed.is_connected(_on_phase_changed):
		GameManager.phase_changed.connect(_on_phase_changed)

	if not GameManager.player_list_updated.is_connected(update_lobby_list):
		GameManager.player_list_updated.connect(update_lobby_list)

	if not GameManager.question_received.is_connected(_on_question_received):
		GameManager.question_received.connect(_on_question_received)

	# NetworkManager signals.
	if not NetworkManager.lobby_list_updated.is_connected(_on_lobby_list_updated):
		NetworkManager.lobby_list_updated.connect(_on_lobby_list_updated)

	if not NetworkManager.connected_to_server.is_connected(_on_connected_to_server):
		NetworkManager.connected_to_server.connect(_on_connected_to_server)

	if not NetworkManager.disconnected_from_server.is_connected(_on_disconnected_from_server):
		NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)

	if not NetworkManager.session_failed.is_connected(_on_session_failed):
		NetworkManager.session_failed.connect(_on_session_failed)

	# Timer.
	if not round_timer.timeout.is_connected(_on_timer_timeout):
		round_timer.timeout.connect(_on_timer_timeout)

	# Buttons.
	if not host_button.pressed.is_connected(_on_host_button_pressed):
		host_button.pressed.connect(_on_host_button_pressed)

	if not find_file_button.pressed.is_connected(_on_file_button_pressed):
		find_file_button.pressed.connect(_on_file_button_pressed)

	if not refresh_button.pressed.is_connected(_on_refresh_button_pressed):
		refresh_button.pressed.connect(_on_refresh_button_pressed)

	if not disconnect_button.pressed.is_connected(_on_disconnect_button_pressed):
		disconnect_button.pressed.connect(_on_disconnect_button_pressed)

	if not start_game_button.pressed.is_connected(_on_start_game_pressed):
		start_game_button.pressed.connect(_on_start_game_pressed)

	if not next_round_button.pressed.is_connected(GameManager.reset_game):
		next_round_button.pressed.connect(GameManager.reset_game)

	# Answer buttons.
	for button in answer_buttons:
		if not button.pressed.is_connected(_on_answer_pressed.bind(button)):
			button.pressed.connect(_on_answer_pressed.bind(button))

	# File dialog.
	if not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)

	# Timer editor.
	if not custom_timer_editor.get_line_edit().text_submitted.is_connected(_on_timer_set):
		custom_timer_editor.get_line_edit().text_submitted.connect(_on_timer_set)

	# Initialize timer using 30 seconds as the fallback.
	if custom_timer_editor.value <= 0:
		custom_timer_editor.value = 30.0

	user_time_set = float(custom_timer_editor.value)

	# Initial UI state.
	_on_phase_changed(GameManager.current_phase)

	host_button.show()
	host_button.disabled = false

	disconnect_button.hide()
	start_game_button.hide()
	find_file_button.hide()


# =========================================================
# PROCESS
# =========================================================

func _process(_delta: float) -> void:
	if not round_timer.is_stopped():

		timer_bar.max_value = round_timer.wait_time
		timer_bar.value = round_timer.time_left

		remaining_time_score = timer_bar.value


# =========================================================
# GAME PHASES
# =========================================================

func _on_phase_changed(phase) -> void:

	lobby_ui.hide()
	question_ui.hide()
	results_ui.hide()

	desk_grid_container.hide()
	find_file_button.hide()

	round_timer.stop()

	match phase:

		GameManager.GamePhase.LOBBY:

			lobby_ui.show()
			
			desk.hide()
			desk_grid_container.hide()
			
			# Only the host can load questions and start a game.
			find_file_button.visible = multiplayer.is_server()

			start_game_button.visible = (
				multiplayer.is_server()
				and not GameManager.question_db.is_empty()
			)

			SoundManager.play_music(LOBBY_MUSIC, -15.0)


		GameManager.GamePhase.QUESTION:

			question_ui.show()

			desk.show()
			desk_grid_container.show()
			
			timer_bar.max_value = user_time_set
			timer_bar.value = user_time_set

			remaining_time_score = user_time_set

			round_timer.start(user_time_set)

			SoundManager.stop_music()


		GameManager.GamePhase.RESULTS:

			desk.hide()
			desk_grid_container.hide()

			results_ui.show()

			round_timer.stop()

			display_results()

			if GameManager.current_question_index + 1 >= GameManager.total_question_count:
				next_round_button.text = "RETURN TO LOBBY"
			else:
				next_round_button.text = "NEXT ROUND"


# =========================================================
# HOSTING
# =========================================================

func _on_host_button_pressed() -> void:

	if not NetworkManager.connected_to_steam:
		NetworkManager.send_log(
			"Cannot host: Steam is offline."
		)

		host_button.show()
		host_button.disabled = false
		return

	host_button.hide()

	NetworkManager.send_log("Creating lobby...")

	NetworkManager.host_game()


# =========================================================
# SESSION CONNECTION
# =========================================================

func _on_connected_to_server() -> void:

	NetworkManager.send_log(
		"Connected to multiplayer session."
	)

	host_button.hide()
	lobby_container.hide()

	disconnect_button.show()

	# Only the host can load questions.
	if multiplayer.is_server():

		find_file_button.show()

		start_game_button.visible = not GameManager.question_db.is_empty()

	else:

		find_file_button.hide()
		start_game_button.hide()

	# Register this player with the host.
	var player_info = {
	"name": Steam.getPersonaName(),
	"id": multiplayer.get_unique_id()
	}

	if multiplayer.is_server():
		GameManager.register_player(player_info)
	else:
		GameManager.register_player.rpc_id(1, player_info)


func _on_disconnected_from_server() -> void:

	NetworkManager.send_log(
		"Returned to the lobby screen."
	)

	round_timer.stop()

	lobby_ui.show()

	question_ui.hide()
	results_ui.hide()

	find_file_button.hide()
	desk.hide()

	host_button.show()
	host_button.disabled = false

	lobby_container.show()

	disconnect_button.hide()
	start_game_button.hide()

	GameManager.reset_player_data()

	# Clear the lobby browser.
	for child in lobby_list.get_children():
		child.queue_free()

	# Clear the player list.
	for child in player_list_container.get_children():
		child.queue_free()


func _on_session_failed(message: String) -> void:

	NetworkManager.send_log(
		"Session setup failed: " + message
	)

	host_button.show()
	host_button.disabled = false

	disconnect_button.hide()

	refresh_button.disabled = false


func _on_disconnect_button_pressed() -> void:
	NetworkManager.disconnect_from_server()


# =========================================================
# LOBBY BROWSER
# =========================================================

func _on_refresh_button_pressed() -> void:

	if not NetworkManager.connected_to_steam:
		NetworkManager.send_log(
			"Cannot refresh: Steam is offline."
		)

		refresh_button.disabled = false
		return

	refresh_button.disabled = true

	NetworkManager.refresh_lobby_list()


func _on_lobby_list_updated(lobbies: Array) -> void:

	refresh_button.disabled = false

	# Remove old lobby buttons.
	for child in lobby_list.get_children():
		child.queue_free()

	# Create a button for every available lobby.
	for lobby_id in lobbies:

		var lobby_name: String = str(
			Steam.getLobbyData(lobby_id, "name")
		)

		if lobby_name.is_empty():
			lobby_name = "Unnamed Lobby"

		var player_count: int = Steam.getNumLobbyMembers(lobby_id)

		var button := Button.new()

		button.text = (
			lobby_name +
			" (" + str(player_count) + " Players)"
		)

		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		button.pressed.connect(
			_on_lobby_button_pressed.bind(int(lobby_id))
		)

		lobby_list.add_child(button)


func _on_lobby_button_pressed(lobby_id: int) -> void:
	NetworkManager.join_game(lobby_id)


# =========================================================
# QUESTION FILE
# =========================================================

func _on_file_button_pressed() -> void:

	if not multiplayer.is_server():
		return

	file_dialog.popup()


func _on_file_selected(path: String) -> void:

	if not multiplayer.is_server():
		return

	var loaded := GameManager.load_json_files(path)

	start_game_button.visible = loaded

	if loaded:
		NetworkManager.send_log(
			"Question file loaded successfully."
		)


# =========================================================
# TIMER SETTINGS
# =========================================================

func _on_timer_set(new_time: String) -> void:

	var float_value: float = float(new_time)

	if float_value <= 0:
		float_value = 30.0

	user_time_set = float_value
	custom_timer_editor.value = float_value

	custom_timer_editor.get_line_edit().release_focus()

	NetworkManager.send_log(
		"Round timer set to: " + str(user_time_set) + " seconds."
	)


# =========================================================
# START GAME
# =========================================================

func _on_start_game_pressed() -> void:

	if not multiplayer.is_server():
		return

	GameManager.start_game_rpc(user_time_set)


# =========================================================
# PLAYER LIST
# =========================================================

func update_lobby_list() -> void:

	for child in player_list_container.get_children():
		child.queue_free()

	for player_id in GameManager.players:

		var data: Dictionary = GameManager.players[player_id]

		var row = PLAYER_ROW_SCENE.instantiate()

		row.get_node("Label").text = str(
			data.get("name", "Player")
		)

		row.get_node("TextureRect").self_modulate = data.get(
			"color",
			Color.WHITE
		)

		player_list_container.add_child(row)


# =========================================================
# QUESTION UI
# =========================================================

func _on_question_received(
	q_text: String,
	answers: Array,
	duration: float
) -> void:

	question_label.text = q_text

	# The duration is received from the host.
	user_time_set = maxf(duration, 1.0)

	remaining_time_score = user_time_set

	timer_bar.max_value = user_time_set
	timer_bar.value = user_time_set

	# Update answer buttons.
	for i in range(answer_buttons.size()):

		var button: Button = answer_buttons[i]

		if i < answers.size():

			button.text = str(answers[i])

			button.show()
			button.disabled = false

		else:

			button.hide()


# =========================================================
# ANSWER SUBMISSION
# =========================================================

func _on_answer_pressed(pressed_button: Button) -> void:

	# Prevent the player from selecting multiple answers.
	for button in answer_buttons:
		button.disabled = true

	if multiplayer.is_server():
		GameManager.submit_answer(
		pressed_button.text,
		remaining_time_score
	)
	else:
		GameManager.submit_answer.rpc_id(
			1,
			pressed_button.text,
			remaining_time_score
	   )


func _on_timer_timeout() -> void:

	# Disable answers when the timer runs out.
	for button in answer_buttons:
		button.disabled = true

	# Only the host ends the round.
	if multiplayer.is_server():
		GameManager.end_round()


# =========================================================
# RESULTS DISPLAY
# =========================================================

func display_results() -> void:

	var options: Array = GameManager.current_question_options

	var correct_answer: String = GameManager.current_correct_answer

	# Reset result buttons.
	for i in range(result_buttons.size()):

		var button: Button = result_buttons[i]

		# Remove old player icons.
		for child in button.get_children():
			child.queue_free()

		if i < options.size():

			button.text = str(options[i])

			button.show()

			if button.text == correct_answer:
				button.self_modulate = Color.GREEN
			else:
				button.self_modulate = Color.RED

		else:

			button.hide()

	# Place player avatars beside their selected answers.
	for player_id in GameManager.round_selections:

		var selected_answer: String = str(
			GameManager.round_selections[player_id]
		)

		var target_button: Button = null

		for button in result_buttons:

			if button.visible and button.text == selected_answer:
				target_button = button
				break

		if target_button != null:
			create_avatar_on_button(target_button, player_id)

	update_score_ui()


func create_avatar_on_button(
	button: Button,
	player_id: int
) -> void:

	if not GameManager.players.has(player_id):
		return

	var data: Dictionary = GameManager.players[player_id]

	# Get the player row's texture.
	var row = PLAYER_ROW_SCENE.instantiate()

	var avatar_texture: Texture2D = row.get_node("TextureRect").texture

	row.queue_free()

	# Create the avatar icon.
	var icon := TextureRect.new()

	icon.texture = avatar_texture

	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	icon.custom_minimum_size = Vector2(30, 30)

	icon.size = Vector2(30, 30)

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	icon.self_modulate = data.get("color", Color.WHITE)

	button.add_child(icon)

	# Avatar positions for up to eight players.
	var slots = [
		Vector2(10, 10),
		Vector2(50, 10),
		Vector2(90, 10),
		Vector2(130, 10),

		Vector2(10, 50),
		Vector2(50, 50),
		Vector2(90, 50),
		Vector2(130, 50)
	]

	var seat: int = posmod(
		int(data.get("seat", 0)),
		slots.size()
	)

	icon.position = slots[seat]


# =========================================================
# SCORE DISPLAY
# =========================================================

func update_score_ui() -> void:

	# Collect all registered players and their scores.
	var ranked_players: Array = []

	for player_id in GameManager.players:

		var data: Dictionary = GameManager.players[player_id]

		var score: float = float(
			GameManager.scores.get(player_id, 0.0)
		)

		ranked_players.append({
			"id": player_id,
			"name": str(data.get("name", "Player")),
			"score": score
		})

	# Sort players from highest to lowest score.
	ranked_players.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if is_equal_approx(a["score"], b["score"]):
				return a["name"].to_lower() < b["name"].to_lower()

			return a["score"] > b["score"]
	)

	# Display the top 10 players.
	var output: String = "TOP 10 PLAYERS:\n"

	var displayed_count: int = mini(10, ranked_players.size())

	for i in range(displayed_count):

		var player = ranked_players[i]

		output += (
			str(i + 1) + ". " +
			player["name"] + ": " +
			str(player["score"]) + "\n"
		)

	# Display the local player's personal ranking.
	var local_player_id = multiplayer.get_unique_id()

	var personal_score_found := false

	for i in range(ranked_players.size()):

		var player = ranked_players[i]

		if player["id"] == local_player_id:

			output += "\n--------------------\n"
			output += "YOUR SCORE:\n"
			output += "Rank: #" + str(i + 1) + "\n"
			output += "Score: " + str(player["score"])

			personal_score_found = true
			break

	if not personal_score_found:
		output += "\nYour score is not available."

	# Update the leaderboard label.
	score_label.text = output

	# Determine the winner after the final question.
	if GameManager.total_question_count > 0:

		if GameManager.current_question_index + 1 >= GameManager.total_question_count:

			if ranked_players.is_empty():
				winner_label.text = "No players"
				return

			var highest_score: float = ranked_players[0]["score"]

			var winners: Array[String] = []

			for player in ranked_players:

				if is_equal_approx(player["score"], highest_score):
					winners.append(player["name"])
				else:
					break

			if winners.size() > 1:
				winner_label.text = "Tie: " + " & ".join(winners)
			else:
				winner_label.text = "Winner: " + winners[0]

		else:
			winner_label.text = ""


# =========================================================
# DEBUG OUTPUT
# =========================================================

func _on_log_updated(msg: String) -> void:

	debug_label.text += "\n" + str(msg)

	var lines: PackedStringArray = debug_label.text.split("\n")

	# Keep only the latest eight debug messages.
	if lines.size() > 8:

		debug_label.text = "\n".join(
			lines.slice(-8)
		)
