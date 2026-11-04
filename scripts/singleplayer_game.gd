extends Control

# VARIABLES

var remaining_time_score: float = 0.0
var user_time_set: float = 30.0

# RESOURCES

const LOBBY_MUSIC = preload(
	"res://audio/ULiL Character Select Theme Gensokyo Mystery Discovery.mp3"
)

const PLAYER_ROW_SCENE = preload(
	"res://scenes/ui/player_list_row.tscn"
)


# NODE REFERENCES
@onready var debug_label: Label = $DebugLabel

@onready var lobby_ui: Control = $SplitContainer/Stage/LobbyUI
@onready var question_ui: Control = $SplitContainer/Stage/QuestionUI
@onready var results_ui: Control = $SplitContainer/Stage/ResultsUI

@onready var disconnect_button: Button = $SplitContainer/Stage/LobbyUI/DisconnectButton

@onready var find_file_button: Button = $SplitContainer/Stage/LobbyUI/FindFileButton

@onready var start_game_button: Button = $SplitContainer/Stage/LobbyUI/StartGameButton

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

@onready var answer_buttons: Array = $SplitContainer/Desk/MarginContainer/GridContainer.get_children()

@onready var result_buttons: Array = $SplitContainer/Stage/ResultsUI/VBoxContainer/GridContainer.get_children()

# INITIALIZATION

func _ready() -> void:

	print("SINGLE PLAYER SCENE LOADED")

	# Activate offline mode.
	GameManager.is_single_player = true

	# Clear previous player data.
	GameManager.reset_player_data()

	# Reset the game phase.
	GameManager.current_phase = GameManager.GamePhase.LOBBY

	# Connect debug output.
	if not NetworkManager.log_updated.is_connected(_on_log_updated):
		NetworkManager.log_updated.connect(_on_log_updated)

	# Connect GameManager signals.
	if not GameManager.phase_changed.is_connected(_on_phase_changed):
		GameManager.phase_changed.connect(_on_phase_changed)

	if not GameManager.question_received.is_connected(_on_question_received):
		GameManager.question_received.connect(_on_question_received)

	# Connect timer.
	if not round_timer.timeout.is_connected(_on_timer_timeout):
		round_timer.timeout.connect(_on_timer_timeout)

	# Connect answer buttons.
	for button in answer_buttons:

		var answer_callable := _on_answer_pressed.bind(button)

		if not button.pressed.is_connected(answer_callable):
			button.pressed.connect(answer_callable)

	# Connect question file button.
	if not find_file_button.pressed.is_connected(_on_file_button_pressed):
		find_file_button.pressed.connect(_on_file_button_pressed)

	# Connect FileDialog.
	if not file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.connect(_on_file_selected)

	# Connect Start Game.
	if not start_game_button.pressed.is_connected(_on_start_game_pressed):
		start_game_button.pressed.connect(_on_start_game_pressed)

	# Connect Next Question.
	var old_next_callable := Callable(GameManager, "reset_game")

	if next_round_button.pressed.is_connected(old_next_callable):
		next_round_button.pressed.disconnect(old_next_callable)

	if not next_round_button.pressed.is_connected(_on_singleplayer_next_pressed):
		next_round_button.pressed.connect(_on_singleplayer_next_pressed)

	# Connect Exit Game.
	var old_exit_callable := Callable(self, "_on_disconnect_button_pressed")

	if disconnect_button.pressed.is_connected(old_exit_callable):
		disconnect_button.pressed.disconnect(old_exit_callable)

	if not disconnect_button.pressed.is_connected(_on_singleplayer_exit_pressed):
		disconnect_button.pressed.connect(_on_singleplayer_exit_pressed)

	disconnect_button.text = "EXIT GAME"

	# Connect timer settings.
	if not custom_timer_editor.value_changed.is_connected(_on_timer_value_changed):
		custom_timer_editor.value_changed.connect(_on_timer_value_changed)

	var timer_line_edit: LineEdit = custom_timer_editor.get_line_edit()

	if not timer_line_edit.text_submitted.is_connected(_on_timer_set):
		timer_line_edit.text_submitted.connect(_on_timer_set)

	# Initialize timer.
	if custom_timer_editor.value <= 0:
		custom_timer_editor.value = 30.0

	user_time_set = float(custom_timer_editor.value)

	# Hide multiplayer-only controls.
	hide_multiplayer_controls()

	# Initial interface.
	lobby_ui.show()

	question_ui.hide()
	results_ui.hide()

	desk.hide()
	desk_grid_container.hide()

	find_file_button.show()
	start_game_button.hide()

	disconnect_button.show()

	next_round_button.hide()

	SoundManager.play_music(LOBBY_MUSIC, -15.0)

# HIDE MULTIPLAYER CONTROLS

func hide_multiplayer_controls() -> void:

	# These nodes can be deleted from the SinglePlayerGame scene.
	# get_node_or_null() prevents errors if they no longer exist.

	var multiplayer_nodes: Array[NodePath] = [

		"SplitContainer/Stage/LobbyUI/HostButton",

		"SplitContainer/Stage/LobbyUI/LobbyContainer",

		"SplitContainer/Stage/LobbyUI/PlayerListContainer"
	]

	for node_path in multiplayer_nodes:

		var control = get_node_or_null(node_path)

		if control != null and control is CanvasItem:
			control.hide()

# PROCESS

func _process(_delta: float) -> void:

	if not round_timer.is_stopped():

		timer_bar.max_value = round_timer.wait_time

		timer_bar.value = round_timer.time_left

		remaining_time_score = timer_bar.value


# GAME PHASES

func _on_phase_changed(phase) -> void:

	lobby_ui.hide()

	question_ui.hide()

	results_ui.hide()

	desk.hide()

	desk_grid_container.hide()

	round_timer.stop()

	match phase:

		# -------------------------------------------------
		# LOBBY / QUESTION SELECTION
		# -------------------------------------------------

		GameManager.GamePhase.LOBBY:

			lobby_ui.show()

			find_file_button.show()

			start_game_button.visible = (
				not GameManager.question_db.is_empty()
			)

			disconnect_button.show()

			next_round_button.hide()

			SoundManager.play_music(LOBBY_MUSIC, -15.0)


		GameManager.GamePhase.QUESTION:

			question_ui.show()

			desk.show()

			desk_grid_container.show()

			find_file_button.hide()

			start_game_button.hide()

			timer_bar.max_value = user_time_set

			timer_bar.value = user_time_set

			remaining_time_score = user_time_set

			round_timer.start(user_time_set)

			SoundManager.stop_music()
			

		GameManager.GamePhase.RESULTS:

			results_ui.show()

			desk.hide()

			desk_grid_container.hide()

			find_file_button.hide()

			start_game_button.hide()

			round_timer.stop()

			display_results()

			next_round_button.show()

			# Use remaining pools instead of question indexes.
			# Question indexes are randomized and no longer sequential.

			if GameManager.has_remaining_single_player_questions():

				next_round_button.text = "NEXT QUESTION"

			else:

				next_round_button.text = "RETURN TO MENU"


# QUESTION FILE SELECTION


func _on_file_button_pressed() -> void:

	# No Steam or multiplayer checks are needed.
	file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:

	NetworkManager.send_log("Loading question file...")

	var loaded: bool = GameManager.load_json_files(path)

	if not loaded:

		NetworkManager.send_log("Failed to load question file.")

		start_game_button.hide()

		return

	NetworkManager.send_log(
		"Successfully loaded " +
		str(GameManager.question_db.size()) +
		" questions."
	)

	# Wait for the player to press Start Game.
	start_game_button.show()



# START GAME


func _on_start_game_pressed() -> void:

	if GameManager.question_db.is_empty():

		NetworkManager.send_log("No questions loaded.")

		return

	if user_time_set <= 0:
		user_time_set = 30.0

	# Hide selection controls.
	find_file_button.hide()

	start_game_button.hide()

	# Begin the offline quiz.
	GameManager.start_single_player_game(user_time_set)



# TIMER SETTINGS


func _on_timer_value_changed(new_value: float) -> void:

	user_time_set = maxf(new_value, 1.0)


func _on_timer_set(new_time: String) -> void:

	var float_value: float = float(new_time)

	if float_value <= 0:
		float_value = 30.0

	user_time_set = float_value

	custom_timer_editor.value = float_value

	custom_timer_editor.get_line_edit().release_focus()

	NetworkManager.send_log(
		"Round timer set to: " +
		str(user_time_set) +
		" seconds."
	)




# QUESTION UI


func _on_question_received(
	q_text: String,
	answers: Array,
	duration: float
) -> void:

	question_label.text = q_text

	user_time_set = maxf(duration, 1.0)

	remaining_time_score = user_time_set

	timer_bar.max_value = user_time_set

	timer_bar.value = user_time_set

	# Update and randomize answer button presentation.
	# The GameManager has already shuffled these options.

	for i in range(answer_buttons.size()):

		var button: Button = answer_buttons[i]

		if i < answers.size():

			button.text = str(answers[i])

			button.show()

			button.disabled = false

		else:

			button.hide()

	question_ui.show()

	desk.show()

	desk_grid_container.show()



# ANSWER SUBMISSION


func _on_answer_pressed(pressed_button: Button) -> void:

	# Prevent multiple answers.
	for button in answer_buttons:
		button.disabled = true

	# Submit the answer locally.
	GameManager.submit_single_player_answer(
		pressed_button.text,
		remaining_time_score
	)


func _on_timer_timeout() -> void:

	# Disable answers when the timer expires.
	for button in answer_buttons:
		button.disabled = true

	# Count the unanswered question as incorrect.
	GameManager.end_single_player_round()



# NEXT QUESTION


func _on_singleplayer_next_pressed() -> void:

	var advanced: bool = GameManager.advance_single_player_round()

	if not advanced:

		return_to_main_menu()



# EXIT GAME


func _on_singleplayer_exit_pressed() -> void:

	return_to_main_menu()


# Compatibility with an older editor signal connection.
func _on_disconnect_button_pressed() -> void:

	return_to_main_menu()


func return_to_main_menu() -> void:

	round_timer.stop()

	GameManager.is_single_player = false

	GameManager.reset_player_data()

	GameManager.current_question_index = 0

	GameManager.total_question_count = 0

	GameManager.current_question_options.clear()

	GameManager.current_correct_answer = ""

	GameManager.question_db.clear()

	GameManager.single_player_question_pools = {
		1: [],
		2: [],
		3: []
	}

	GameManager.single_player_category_results.clear()

	GameManager.current_phase = GameManager.GamePhase.LOBBY

	SoundManager.stop_music()

	get_tree().change_scene_to_file(
		"res://scenes/main_menu.tscn"
	)



# RESULTS DISPLAY


func display_results() -> void:

	var options: Array = GameManager.current_question_options

	var correct_answer: String = GameManager.current_correct_answer

	# Reset result buttons.
	for i in range(result_buttons.size()):

		var button: Button = result_buttons[i]

		# Remove previous avatars.
		for child in button.get_children():

			if child is TextureRect:
				child.queue_free()

		# Reset previous color.
		button.self_modulate = Color.WHITE

		if i < options.size():

			button.text = str(options[i])

			button.show()

			# Highlight the correct answer.
			if button.text == correct_answer:

				button.self_modulate = Color.GREEN

			else:

				button.self_modulate = Color.RED

		else:

			button.hide()

	# Display the player's selected answer.
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

	# Update question or final results.
	update_score_ui()



# PLAYER AVATAR


func create_avatar_on_button(
	button: Button,
	player_id: int
) -> void:

	if not GameManager.players.has(player_id):
		return

	var data: Dictionary = GameManager.players[player_id]

	# Obtain the existing avatar texture.
	var row = PLAYER_ROW_SCENE.instantiate()

	var avatar_texture: Texture2D = (
		row.get_node("TextureRect").texture
	)

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

	# Center avatar vertically.
	icon.position = Vector2(
		10,
		maxf((button.size.y - 30.0) / 2.0, 0.0)
	)



# SINGLE-PLAYER RESULTS


func update_score_ui() -> void:

	var output: String = ""

	var correct: int = GameManager.single_player_correct_answers

	var answered: int = GameManager.single_player_questions_answered

	var total: int = GameManager.total_question_count

	var quiz_finished: bool = (
		not GameManager.has_remaining_single_player_questions()
	)
	
	# INTERMEDIATE QUESTION RESULTS

	if not quiz_finished:

		output = "QUIZ PROGRESS\n\n"

		output += (
			"Correct Answers: " +
			str(correct) + "\n"
		)

		output += (
			"Questions Answered: " +
			str(answered) + "/" + str(total) + "\n"
		)

		output += (
			"Current Difficulty: " +
			str(GameManager.single_player_current_difficulty)
		)

		score_label.text = output

		winner_label.text = "QUESTION RESULTS"

		return

	# FINAL RESULTS

	output = "FINAL RESULTS\n\n"

	output += (
		"Correct Answers: " +
		str(correct) + "/" + str(total) + "\n"
	)

	var incorrect: int = answered - correct

	output += (
		"Incorrect Answers: " +
		str(incorrect) + "\n"
	)

	var accuracy: float = 0.0

	if answered > 0:

		accuracy = (
			float(correct) / float(answered)
		) * 100.0

	output += (
		"Accuracy: " +
		("%.1f" % accuracy) +
		"%\n"
	)

	# CATEGORY BREAKDOWN

	if not GameManager.single_player_category_results.is_empty():

		output += "\n--------------------\n"

		output += "CATEGORY BREAKDOWN\n\n"

		var categories: Array = (
			GameManager.single_player_category_results.keys()
		)

		categories.sort()

		for category in categories:

			var stats: Dictionary = (
				GameManager.single_player_category_results[category]
			)

			var category_correct: int = int(stats["correct"])

			var category_total: int = int(stats["total"])

			var category_accuracy: float = 0.0

			if category_total > 0:

				category_accuracy = (
					float(category_correct) /
					float(category_total)
				) * 100.0

			output += str(category) + "\n"

			output += (
				"  Correct: " +
				str(category_correct) +
				"/" + str(category_total) + "\n"
			)

			output += (
				"  Accuracy: " +
				("%.1f" % category_accuracy) +
				"%\n\n"
			)

	else:

		output += "\nNo category information was provided."

	score_label.text = output

	winner_label.text = "QUIZ COMPLETE!"


# DEBUG OUTPUT

func _on_log_updated(msg: String) -> void:

	debug_label.text += "\n" + str(msg)

	var lines: PackedStringArray = debug_label.text.split("\n")

	# Keep the latest eight debug messages.
	if lines.size() > 8:

		debug_label.text = "\n".join(
			lines.slice(-8)
		)
