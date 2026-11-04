extends Node

# GAME PHASES

enum GamePhase {
	LOBBY,
	QUESTION,
	RESULTS
}


# SIGNALS

signal phase_changed(new_phase)
signal player_list_updated
signal question_received(q_text, answers, duration)


# RESOURCES

const OPTIONS_MENU_SCENE = preload("res://scenes/options_menu.tscn")


# GENERAL VARIABLES

var options_menu_instance: CanvasLayer

var current_phase: GamePhase = GamePhase.LOBBY:
	set(value):
		if current_phase == value:
			return

		current_phase = value

		phase_changed.emit(current_phase)

		print("Phase changed to: ", GamePhase.keys()[current_phase])


var players: Dictionary = {}

var is_single_player: bool = false

var current_question_index: int = 0
var total_question_count: int = 0
var current_round_duration: float = 30.0

var question_db: Array = []

var scores: Dictionary = {}

var players_answered: Array = []
var round_selections: Dictionary = {}

var current_question_options: Array = []
var current_correct_answer: String = ""


# ADAPTIVE SINGLE-PLAYER VARIABLES

# Questions are grouped into three difficulty pools.
# Each pool contains indexes pointing to question_db.

var single_player_question_pools: Dictionary = {
	1: [],
	2: [],
	3: []
}


# Current difficulty selected by the adaptive system.
var single_player_current_difficulty: int = 1

# Difficulty of the question currently being answered.
var single_player_current_question_difficulty: int = 1


# Number of correct answers at each difficulty.
var single_player_correct_by_difficulty: Dictionary = {
	1: 0,
	2: 0,
	3: 0
}


# Overall single-player statistics.
var single_player_questions_answered: int = 0
var single_player_correct_answers: int = 0


# Category statistics.
# Format:
# {
#     "Programming": {
#         "correct": 3,
#         "total": 5
#     }
# }

var single_player_category_results: Dictionary = {}


# Prevents a question from being recorded twice.
var single_player_answer_recorded: bool = false


# INITIALIZATION

func _ready() -> void:

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	options_menu_instance = OPTIONS_MENU_SCENE.instantiate()

	add_child(options_menu_instance)

	options_menu_instance.visible = false


# QUESTION DIFFICULTY HELPER

func _get_question_difficulty(question: Dictionary) -> int:

	if question.has("difficulty_level"):
		return int(question["difficulty_level"])

	if question.has("difficulty level"):
		return int(question["difficulty level"])

	if question.has("difficulty"):
		return int(question["difficulty"])

	# Questions without a difficulty default to Level 1.
	return 1

# QUESTION FILE LOADING

func load_json_files(path: String) -> bool:

	# In multiplayer, only the host can load questions.
	# Single-player mode can load questions locally.
	if not is_single_player and not multiplayer.is_server():

		NetworkManager.send_log(
			"Only the host can load the question file."
		)

		return false

	if not FileAccess.file_exists(path):

		NetworkManager.send_log(
			"Question file does not exist: " + path
		)

		return false

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:

		NetworkManager.send_log(
			"Could not open question file."
		)

		return false

	var parsed_text = JSON.parse_string(file.get_as_text())

	file.close()

	if not parsed_text is Array:

		NetworkManager.send_log(
			"Invalid JSON: expected an array of questions."
		)

		return false

	if parsed_text.is_empty():

		NetworkManager.send_log(
			"Question file is empty."
		)

		return false

	# Validate every question.
	for i in range(parsed_text.size()):

		var item = parsed_text[i]

		if not item is Dictionary:

			NetworkManager.send_log(
				"Invalid question entry at index " + str(i)
			)

			return false

		# Validate question text.
		if not item.has("question"):

			NetworkManager.send_log(
				"Question entry " + str(i) + " is missing its question."
			)

			return false

		# Validate options.
		if not item.has("options") or not item["options"] is Array:

			NetworkManager.send_log(
				"Question entry " + str(i) + " has invalid options."
			)

			return false

		if item["options"].is_empty():

			NetworkManager.send_log(
				"Question " + str(i) + " has no options."
			)

			return false

		# Normalize answer options to strings.
		var normalized_options: Array[String] = []

		for option in item["options"]:
			normalized_options.append(str(option))

		item["options"] = normalized_options

		# Validate answer.
		if not item.has("answer"):

			NetworkManager.send_log(
				"Question entry " + str(i) + " is missing its answer."
			)

			return false

		item["answer"] = str(item["answer"])

		if item["answer"] not in normalized_options:

			NetworkManager.send_log(
				"The answer for question " + str(i) +
				" is not present in its options."
			)

			return false

		item["question"] = str(item["question"])

		# Validate difficulty.
		var difficulty_value = item.get(
			"difficulty_level",
			item.get("difficulty level", item.get("difficulty", 1))
		)

		var difficulty_type: int = typeof(difficulty_value)

		if difficulty_type != TYPE_INT and difficulty_type != TYPE_FLOAT:

			NetworkManager.send_log(
				"Invalid difficulty at question " + str(i) +
				". Use a number from 1 to 3."
			)

			return false

		var difficulty_number: float = float(difficulty_value)

		if not is_equal_approx(difficulty_number, roundf(difficulty_number)):

			NetworkManager.send_log(
				"Difficulty must be a whole number at question " + str(i)
			)

			return false

		var difficulty_level: int = int(difficulty_number)

		if difficulty_level < 1 or difficulty_level > 3:

			NetworkManager.send_log(
				"Invalid difficulty at question " + str(i) +
				". Difficulty must be between 1 and 3."
			)

			return false

		# Store the normalized difficulty.
		item["difficulty_level"] = difficulty_level

		# Category is optional.
		if item.has("category"):
			item["category"] = str(item["category"]).strip_edges()

	# Save the validated questions.
	question_db = parsed_text

	total_question_count = question_db.size()

	current_question_index = 0

	NetworkManager.send_log(
		"Successfully loaded " + str(total_question_count) + " questions."
	)

	return true


# OPTIONS MENU

func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_cancel"):
		toggle_options_menu()


func toggle_options_menu() -> void:

	if options_menu_instance != null:
		options_menu_instance.visible = not options_menu_instance.visible



# MULTIPLAYER PLAYER REGISTRATION

@rpc("any_peer", "call_local", "reliable")
func register_player(new_player_info: Dictionary) -> void:

	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()

	# Register the host locally.
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	# Prevent duplicate registrations.
	if players.has(sender_id):
		return

	# Enforce the existing 50-player limit.
	if players.size() >= NetworkManager.MAX_LOBBY_MEMBERS:

		NetworkManager.send_log("Lobby is full!")

		return

	var info: Dictionary = new_player_info.duplicate(true)

	# Generate visually distinct colors for each player.
	var color_index: int = players.size()

	var hue: float = fposmod(
		float(color_index) * 0.61803398875,
		1.0
	)

	info["id"] = sender_id

	info["color"] = Color.from_hsv(
		hue,
		0.8,
		0.95
	)

	info["score"] = 0
	info["seat"] = color_index

	players[sender_id] = info

	NetworkManager.send_log(
		"Registered player: " +
		str(info.get("name", "Player")) +
		" (" + str(sender_id) + "). Total: " +
		str(players.size()) + "/" +
		str(NetworkManager.MAX_LOBBY_MEMBERS)
	)

	# Synchronize the updated player list.
	sync_player_list.rpc(players)


@rpc("authority", "call_local", "reliable")
func sync_player_list(updated_players: Dictionary) -> void:

	players = updated_players.duplicate(true)

	player_list_updated.emit()
	

# QUESTION SYNCHRONIZATION
# MULTIPLAYER

@rpc("authority", "call_local", "reliable")
func begin_question(
	q_text: String,
	answers: Array,
	question_index: int,
	question_count: int,
	duration: float
) -> void:

	current_question_index = question_index

	total_question_count = question_count

	current_round_duration = maxf(duration, 1.0)

	current_question_options = answers.duplicate()

	current_correct_answer = ""

	players_answered.clear()

	round_selections.clear()

	# Update the question UI and timer.
	question_received.emit(
		q_text,
		current_question_options,
		current_round_duration
	)

	current_phase = GamePhase.QUESTION


@rpc("authority", "call_local", "reliable")
func change_phase(new_phase_id: int) -> void:

	current_phase = new_phase_id

# MULTIPLAYER ANSWER SUBMISSION

@rpc("any_peer", "call_local", "reliable")
func submit_answer(
	selected_option: String,
	remaining_time_score: float
) -> void:

	if not multiplayer.is_server():
		return

	if current_phase != GamePhase.QUESTION:
		return

	if current_question_index < 0:
		return

	if current_question_index >= question_db.size():
		return

	var player_id: int = multiplayer.get_remote_sender_id()

	# Handles answers submitted by the local host.
	if player_id == 0:
		player_id = multiplayer.get_unique_id()

	# Make sure this player exists.
	if not players.has(player_id):
		return

	# Prevent duplicate answers.
	if player_id in players_answered:
		return

	# Make sure the submitted option is valid.
	if selected_option not in current_question_options:
		return

	players_answered.append(player_id)

	round_selections[player_id] = selected_option

	var correct_answer: String = str(
		question_db[current_question_index]["answer"]
	)

	if selected_option == correct_answer:

		if not scores.has(player_id):
			scores[player_id] = 0.0

		var time_bonus: float = maxf(remaining_time_score, 0.0)

		scores[player_id] += 1.0 + (time_bonus / 1000.0)

		NetworkManager.send_log(
			"Player " + str(player_id) + " answered correctly."
		)

	else:

		NetworkManager.send_log(
			"Player " + str(player_id) + " answered incorrectly."
		)

	# End the round once everyone has answered.
	if players_answered.size() >= players.size():
		end_round()

# RESULTS SYNCHRONIZATION
# MULTIPLAYER

@rpc("authority", "call_local", "reliable")
func sync_results(
	selections: Dictionary,
	current_scores: Dictionary,
	options: Array,
	correct_answer: String
) -> void:

	round_selections = selections.duplicate(true)

	scores = current_scores.duplicate(true)

	current_question_options = options.duplicate()

	current_correct_answer = correct_answer


func end_round() -> void:

	if not multiplayer.is_server():
		return

	if is_single_player:
		return

	if current_phase != GamePhase.QUESTION:
		return

	if question_db.is_empty():

		NetworkManager.send_log(
			"Cannot end round: question database is empty."
		)

		return

	if current_question_index >= question_db.size():

		NetworkManager.send_log(
			"Cannot end round: question index is invalid."
		)

		return

	var q: Dictionary = question_db[current_question_index]

	# Synchronize selections, scores, options, and correct answer.
	sync_results.rpc(
		round_selections,
		scores,
		q["options"],
		str(q["answer"])
	)

	change_phase.rpc(GamePhase.RESULTS)

# START MULTIPLAYER GAME

func start_game_rpc(round_duration: float = 30.0) -> void:

	if is_single_player:
		return

	if not multiplayer.is_server():
		return

	if question_db.is_empty():

		NetworkManager.send_log(
			"Load a valid question file before starting."
		)

		return

	if players.is_empty():

		NetworkManager.send_log(
			"No players are registered."
		)

		return

	current_question_index = 0

	total_question_count = question_db.size()

	current_round_duration = maxf(round_duration, 1.0)

	scores.clear()

	players_answered.clear()

	round_selections.clear()

	# Clear previous results.
	sync_results.rpc({}, {}, [], "")

	NetworkManager.set_lobby_lock(true)

	var q: Dictionary = question_db[current_question_index]

	# Multiplayer retains its existing question sequence.
	begin_question.rpc(
		str(q["question"]),
		q["options"],
		current_question_index,
		total_question_count,
		current_round_duration
	)

# RESET MULTIPLAYER GAME

func reset_game() -> void:

	if is_single_player:
		return

	if not multiplayer.is_server():
		return

	if current_phase != GamePhase.RESULTS:
		return

	current_question_index += 1

	# Return to lobby if all questions are completed.
	if current_question_index >= question_db.size():

		current_question_index = 0

		scores.clear()

		players_answered.clear()

		round_selections.clear()

		sync_results.rpc({}, {}, [], "")

		NetworkManager.set_lobby_lock(false)

		change_phase.rpc(GamePhase.LOBBY)

		NetworkManager.send_log(
			"All questions completed. Returning to lobby."
		)

		return

	# Start the next multiplayer question.
	var q: Dictionary = question_db[current_question_index]

	begin_question.rpc(
		str(q["question"]),
		q["options"],
		current_question_index,
		total_question_count,
		current_round_duration
	)



# PLAYER DISCONNECTION
# MULTIPLAYER


func _on_peer_disconnected(id: int) -> void:

	if is_single_player:
		return

	if not multiplayer.is_server():
		return

	if not players.has(id):
		return

	NetworkManager.send_log(
		"Removing disconnected player: " + str(id)
	)

	players.erase(id)

	scores.erase(id)

	players_answered.erase(id)

	round_selections.erase(id)

	sync_player_list.rpc(players)

	# Check whether the remaining players have answered.
	if current_phase == GamePhase.QUESTION:

		if not players.is_empty():

			if players_answered.size() >= players.size():
				end_round()



# SINGLE-PLAYER: RESET ADAPTIVE DATA


func _reset_single_player_data() -> void:

	single_player_question_pools = {
		1: [],
		2: [],
		3: []
	}

	single_player_current_difficulty = 1

	single_player_current_question_difficulty = 1

	single_player_correct_by_difficulty = {
		1: 0,
		2: 0,
		3: 0
	}

	single_player_questions_answered = 0

	single_player_correct_answers = 0

	single_player_category_results.clear()

	single_player_answer_recorded = false



# SINGLE-PLAYER: START GAME


func start_single_player_game(round_duration: float = 30.0) -> void:

	if question_db.is_empty():

		NetworkManager.send_log("No questions loaded.")

		return

	is_single_player = true

	# Reset previous game data.
	players.clear()

	scores.clear()

	players_answered.clear()

	round_selections.clear()

	_reset_single_player_data()

	# Reset game information.
	current_question_index = 0

	total_question_count = question_db.size()

	current_round_duration = maxf(round_duration, 1.0)

	# Create the local player.
	var local_id: int = multiplayer.get_unique_id()

	players[local_id] = {
		"id": local_id,
		"name": "Player",
		"color": Color("FF5D5D"),
		"score": 0.0,
		"seat": 0
	}

	scores[local_id] = 0.0

	player_list_updated.emit()

	# Build the difficulty pools.
	for i in range(question_db.size()):

		var question: Dictionary = question_db[i]

		var difficulty: int = _get_question_difficulty(question)

		single_player_question_pools[difficulty].append(i)

	# Randomize the order within each difficulty.
	for difficulty in range(1, 4):

		var pool: Array = single_player_question_pools[difficulty]

		pool.shuffle()

		single_player_question_pools[difficulty] = pool

	NetworkManager.send_log(
		"Starting adaptive single-player quiz."
	)

	NetworkManager.send_log(
		"Starting at Difficulty 1."
	)

	start_single_player_question()



# SINGLE-PLAYER: CHECK REMAINING QUESTIONS


func has_remaining_single_player_questions() -> bool:

	for difficulty in range(1, 4):

		var pool: Array = single_player_question_pools[difficulty]

		if not pool.is_empty():
			return true

	return false



# SINGLE-PLAYER: FIND LOWER DIFFICULTY


func _find_available_lower_difficulty(
	from_difficulty: int
) -> int:

	# Find the nearest lower difficulty with unused questions.
	for difficulty in range(from_difficulty - 1, 0, -1):

		var pool: Array = single_player_question_pools[difficulty]

		if not pool.is_empty():
			return difficulty

	return 0



# SINGLE-PLAYER: SELECT NEXT QUESTION


func _take_next_single_player_question() -> int:

	var selected_difficulty: int = single_player_current_difficulty

	var current_pool: Array = single_player_question_pools[
		selected_difficulty
	]

	# Prefer the current difficulty.
	if current_pool.is_empty():

		selected_difficulty = 0

		# First, look for available higher difficulties.
		for difficulty in range(
			single_player_current_difficulty + 1,
			4
		):

			var pool: Array = single_player_question_pools[difficulty]

			if not pool.is_empty():

				selected_difficulty = difficulty

				break

		# If no higher difficulty remains, look lower.
		if selected_difficulty == 0:

			for difficulty in range(
				single_player_current_difficulty - 1,
				0,
				-1
			):

				var pool: Array = single_player_question_pools[difficulty]

				if not pool.is_empty():

					selected_difficulty = difficulty

					break

	# No questions remain.
	if selected_difficulty == 0:
		return -1

	# Update current difficulty.
	single_player_current_difficulty = selected_difficulty

	# Remove one question from its pool.
	var selected_pool: Array = single_player_question_pools[
		selected_difficulty
	]

	var question_index: int = int(selected_pool.pop_back())

	single_player_question_pools[selected_difficulty] = selected_pool

	return question_index



# SINGLE-PLAYER: START QUESTION


func start_single_player_question() -> bool:

	if not is_single_player:
		return false

	if not has_remaining_single_player_questions():
		return false

	var selected_index: int = _take_next_single_player_question()

	if selected_index < 0:
		return false

	current_question_index = selected_index

	var question: Dictionary = question_db[current_question_index]

	single_player_current_question_difficulty = (
		_get_question_difficulty(question)
	)

	single_player_answer_recorded = false

	# Randomize answer order without modifying the saved JSON.
	var shuffled_options: Array = question["options"].duplicate()

	shuffled_options.shuffle()

	NetworkManager.send_log(
		"Question Difficulty: " +
		str(single_player_current_question_difficulty)
	)

	# Start the question locally.
	begin_question(
		str(question["question"]),
		shuffled_options,
		current_question_index,
		total_question_count,
		current_round_duration
	)

	return true



# SINGLE-PLAYER: RECORD QUESTION RESULT


func _record_single_player_result(
	question: Dictionary,
	was_correct: bool
) -> void:

	if single_player_answer_recorded:
		return

	single_player_answer_recorded = true

	single_player_questions_answered += 1

	var played_difficulty: int = single_player_current_question_difficulty

	# -----------------------------------------------------
	# CATEGORY STATISTICS
	# -----------------------------------------------------

	var category_name: String = str(
		question.get("category", "")
	).strip_edges()

	# Questions without a category are excluded from the
	# category breakdown but still count overall.
	if not category_name.is_empty():

		if not single_player_category_results.has(category_name):

			single_player_category_results[category_name] = {
				"correct": 0,
				"total": 0
			}

		var category_stats: Dictionary = (
			single_player_category_results[category_name]
		)

		category_stats["total"] = (
			int(category_stats["total"]) + 1
		)

		if was_correct:

			category_stats["correct"] = (
				int(category_stats["correct"]) + 1
			)

		single_player_category_results[category_name] = category_stats

	# -----------------------------------------------------
	# ADAPTIVE DIFFICULTY
	# -----------------------------------------------------

	if was_correct:

		single_player_correct_answers += 1

		single_player_correct_by_difficulty[played_difficulty] = (
			int(single_player_correct_by_difficulty[played_difficulty]) + 1
		)

		# Three correct Level 1 answers -> Level 2.
		if played_difficulty == 1:

			if int(single_player_correct_by_difficulty[1]) >= 3:

				single_player_current_difficulty = 2

				NetworkManager.send_log(
					"Advanced to Difficulty 2!"
				)

		# Two correct Level 2 answers -> Level 3.
		elif played_difficulty == 2:

			if int(single_player_correct_by_difficulty[2]) >= 2:

				single_player_current_difficulty = 3

				NetworkManager.send_log(
					"Advanced to Difficulty 3!"
				)

	else:

		# Incorrect answer: find an available lower difficulty.
		var lower_difficulty: int = (
			_find_available_lower_difficulty(played_difficulty)
		)

		if lower_difficulty > 0:

			single_player_current_difficulty = lower_difficulty

			NetworkManager.send_log(
				"Incorrect answer. Falling back to Difficulty " +
				str(lower_difficulty) + "."
			)

		else:

			NetworkManager.send_log(
				"Incorrect answer. Continuing with the current difficulty."
			)



# SINGLE-PLAYER: SUBMIT ANSWER


func submit_single_player_answer(
	selected_option: String,
	remaining_time_score: float
) -> void:

	if not is_single_player:
		return

	if current_phase != GamePhase.QUESTION:
		return

	if current_question_index < 0:
		return

	if current_question_index >= question_db.size():
		return

	if single_player_answer_recorded:
		return

	# Reject invalid options.
	if selected_option not in current_question_options:
		return

	var player_id: int = multiplayer.get_unique_id()

	if not players.has(player_id):
		return

	var question: Dictionary = question_db[current_question_index]

	var correct_answer: String = str(question["answer"])

	var was_correct: bool = selected_option == correct_answer

	# Record the selected answer.
	round_selections[player_id] = selected_option

	if was_correct:

		var time_bonus: float = maxf(remaining_time_score, 0.0)

		scores[player_id] = float(
			scores.get(player_id, 0.0)
		) + (1.0 + (time_bonus / 1000.0))

		NetworkManager.send_log("Your answer was correct.")

	else:

		NetworkManager.send_log("Your answer was incorrect.")

	# Update adaptive difficulty and category statistics.
	_record_single_player_result(question, was_correct)

	# End the question.
	end_single_player_round()



# SINGLE-PLAYER: END ROUND


func end_single_player_round() -> void:

	if not is_single_player:
		return

	if current_phase != GamePhase.QUESTION:
		return

	if question_db.is_empty():
		return

	var question: Dictionary = question_db[current_question_index]

	# If the timer expires without an answer, count it as incorrect.
	if not single_player_answer_recorded:

		_record_single_player_result(question, false)

	# Synchronize results locally.
	sync_results(
		round_selections,
		scores,
		current_question_options,
		str(question["answer"])
	)

	change_phase(GamePhase.RESULTS)



# SINGLE-PLAYER: ADVANCE QUESTION


func advance_single_player_round() -> bool:

	if not is_single_player:
		return false

	if current_phase != GamePhase.RESULTS:
		return false

	if not has_remaining_single_player_questions():
		return false

	return start_single_player_question()



# RESET PLAYER DATA


func reset_player_data() -> void:

	players.clear()

	scores.clear()

	players_answered.clear()

	round_selections.clear()

	player_list_updated.emit()
