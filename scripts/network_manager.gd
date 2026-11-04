extends Node

signal log_updated(message)
signal connected_to_server
signal disconnected_from_server
signal lobby_list_updated(lobbies)
signal session_failed(message)

var connected_to_steam: bool = false
var peer: SteamMultiplayerPeer = null
var current_lobby_id: int = 0
var is_host: bool = false
var is_disconnecting: bool = false

const MAX_LOBBY_MEMBERS: int = 50


func _ready() -> void:
	OS.set_environment("SteamAppId", "480")
	OS.set_environment("SteamGameId", "480")

	send_log("Initializing Steam...")

	if not Steam.isSteamRunning():
		send_log("Steam is NOT running. Multiplayer is disabled.")
		connected_to_steam = false
		return

	var init_result = Steam.steamInit()
	var initialization_successful := false

	if typeof(init_result) == TYPE_BOOL:
		initialization_successful = init_result

	elif typeof(init_result) == TYPE_DICTIONARY:
		initialization_successful = int(init_result.get("status", 0)) == 0

	else:
		initialization_successful = bool(init_result)

	if not initialization_successful:
		send_log("Steam initialization failed: " + str(init_result))
		connected_to_steam = false
		return

	connected_to_steam = true

	send_log("Steam is running! User: " + Steam.getPersonaName())

	# Steam lobby callbacks.
	if not Steam.lobby_created.is_connected(_on_lobby_created):
		Steam.lobby_created.connect(_on_lobby_created)

	if not Steam.lobby_match_list.is_connected(_on_lobby_match_list):
		Steam.lobby_match_list.connect(_on_lobby_match_list)

	if not Steam.lobby_joined.is_connected(_on_lobby_joined):
		Steam.lobby_joined.connect(_on_lobby_joined)

	if not Steam.join_requested.is_connected(_on_join_requested):
		Steam.join_requested.connect(_on_join_requested)

	# Godot multiplayer callbacks.
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not multiplayer.connected_to_server.is_connected(_on_multiplayer_connected_to_server):
		multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_multiplayer_connection_failed):
		multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	send_log("Steam initialization complete.")

	check_command_line()


func _process(_delta: float) -> void:
	if connected_to_steam:
		Steam.run_callbacks()


# =========================================================
# HOSTING
# =========================================================

func host_game() -> void:
	if not connected_to_steam:
		send_log("Cannot host: Steam is not active.")
		session_failed.emit("Steam is not active.")
		return

	send_log("Attempting to host...")

	# Clean up an existing session first.
	if current_lobby_id != 0 or peer != null:
		disconnect_from_server()

	is_host = true

	send_log("Requesting Steam lobby creation...")

	# Steam will call _on_lobby_created when the request finishes.
	# The multiplayer peer is created inside that callback.
	Steam.createLobby(
		Steam.LOBBY_TYPE_PUBLIC,
		MAX_LOBBY_MEMBERS
	)

	send_log("Steam lobby creation request sent.")


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	send_log("Lobby creation callback received.")

	if connect_result != 1:
		_fail_session(
			"Steam lobby creation failed. Result: " + str(connect_result)
		)
		return

	current_lobby_id = lobby_id

	send_log("Created Lobby: " + str(lobby_id))

	Steam.setLobbyData(
		lobby_id,
		"name",
		Steam.getPersonaName() + "'s Lobby"
	)

	Steam.setLobbyJoinable(lobby_id, true)

	Steam.setRichPresence(
		"connect",
		"+connect_lobby " + str(lobby_id)
	)

	send_log("Creating Steam multiplayer host...")

	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true

	var host_error: int = peer.create_host(0)

	if host_error != OK:
		_fail_session(
			"Failed to create multiplayer host. Error: " + str(host_error)
		)
		return

	multiplayer.multiplayer_peer = peer

	send_log("Multiplayer host created successfully.")
	send_log("Lobby is ready.")

	# The host is already connected locally.
	connected_to_server.emit()


# =========================================================
# JOINING
# =========================================================

func join_game(lobby_id: int) -> void:
	if not connected_to_steam:
		send_log("Cannot join: Steam is not active.")
		return

	if lobby_id == 0:
		send_log("Invalid lobby ID.")
		return

	send_log("Joining Lobby ID: " + str(lobby_id))

	# Leave an existing session first.
	if current_lobby_id != 0 or peer != null:
		disconnect_from_server()

	is_host = false

	send_log("Sending Steam join request...")

	Steam.joinLobby(lobby_id)


func _on_lobby_joined(
	lobby_id: int,
	_permissions: int,
	_locked: bool,
	response: int
) -> void:

	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		_fail_session(
			"Failed to join Steam lobby. Code: " + str(response)
		)
		return

	current_lobby_id = lobby_id

	send_log("Successfully joined Steam lobby.")

	var host_id: int = Steam.getLobbyOwner(lobby_id)

	send_log("Lobby owner Steam ID: " + str(host_id))

	# IMPORTANT:
	# The host already created its multiplayer peer.
	# Do not create another one when Steam reports
	# that the lobby owner joined their own lobby.
	if host_id == Steam.getSteamID():

		if is_host and peer != null and multiplayer.multiplayer_peer == peer:
			send_log("Host already initialized. Keeping existing connection.")
			return

		send_log("Local player owns this lobby, but no active host peer exists.")
		return

	# This section is only for actual clients.
	is_host = false

	send_log("Connecting to host through Steam P2P...")

	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true

	var client_error: int = peer.create_client(host_id, 0)

	if client_error != OK:
		_fail_session(
			"Failed to create multiplayer client. Error: " + str(client_error)
		)
		return

	multiplayer.multiplayer_peer = peer

	send_log("Multiplayer client initialized. Waiting for connection...")


func _on_multiplayer_connected_to_server() -> void:
	send_log("Connected to the multiplayer host.")
	connected_to_server.emit()


func _on_multiplayer_connection_failed() -> void:
	_fail_session("Multiplayer connection failed.")


func _on_server_disconnected() -> void:
	if is_disconnecting:
		return

	send_log("Host disconnected.")

	disconnect_from_server()


# =========================================================
# LOBBY BROWSER
# =========================================================

func refresh_lobby_list() -> void:
	if not connected_to_steam:
		send_log("Cannot refresh lobby list: Steam is offline.")
		return

	send_log("Requesting lobby list...")

	Steam.addRequestLobbyListDistanceFilter(
		Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE
	)

	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	send_log("Found " + str(lobbies.size()) + " lobbies.")

	lobby_list_updated.emit(lobbies)


# =========================================================
# STEAM INVITES
# =========================================================

func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	send_log("Friend invite received.")

	if current_lobby_id != 0 or peer != null:
		disconnect_from_server()
		await get_tree().create_timer(0.2).timeout

	join_game(lobby_id)


func check_command_line() -> void:
	var args := OS.get_cmdline_args()

	for i in range(args.size()):
		if args[i] == "+connect_lobby":
			if i + 1 < args.size():
				var lobby_id := int(args[i + 1])

				send_log("Found launch invite: " + str(lobby_id))

				await get_tree().create_timer(1.0).timeout

				join_game(lobby_id)
				return


# =========================================================
# DISCONNECTING
# =========================================================

func disconnect_from_server() -> void:
	if is_disconnecting:
		return

	var had_session := current_lobby_id != 0 or peer != null

	is_disconnecting = true

	send_log("Disconnecting...")

	if peer != null:
		peer.close()

		if multiplayer.multiplayer_peer == peer:
			multiplayer.multiplayer_peer = null

		peer = null

	if current_lobby_id != 0 and connected_to_steam:
		Steam.leaveLobby(current_lobby_id)

	current_lobby_id = 0
	is_host = false

	is_disconnecting = false

	if had_session:
		disconnected_from_server.emit()

	send_log("Disconnected.")


func _fail_session(message: String) -> void:
	send_log(message)

	if peer != null:
		peer.close()

		if multiplayer.multiplayer_peer == peer:
			multiplayer.multiplayer_peer = null

		peer = null

	if current_lobby_id != 0 and connected_to_steam:
		Steam.leaveLobby(current_lobby_id)

	current_lobby_id = 0
	is_host = false

	session_failed.emit(message)


# =========================================================
# MULTIPLAYER CALLBACKS
# =========================================================

func _on_peer_connected(id: int) -> void:
	send_log("P2P connection established: " + str(id))


func _on_peer_disconnected(id: int) -> void:
	send_log("Peer disconnected: " + str(id))


# =========================================================
# LOBBY SETTINGS
# =========================================================

func set_lobby_lock(locked: bool) -> void:
	if current_lobby_id == 0 or not connected_to_steam:
		return

	Steam.setLobbyJoinable(current_lobby_id, not locked)

	send_log("Lobby locked: " + str(locked))


# =========================================================
# DEBUG
# =========================================================

func send_log(msg: String) -> void:
	print(msg)
	log_updated.emit(msg)
