extends Node

#DEBUG
signal log_updated(message)
var connected_to_steam: bool = false

signal connected_to_server
signal disconnected_from_server
signal lobby_list_updated(lobbies)

var peer = null
var current_lobby_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	OS.set_environment("SteamAppId", "480")
	OS.set_environment("SteamGameId", "480")

	# 1. Check FIRST if Steam is running before doing anything else!
	if not Steam.isSteamRunning():
		printerr("Steam is not running. Multiplayer features will be disabled.")
		send_log("Steam is NOT running! Running in offline mode.")
		connected_to_steam = false
		return  # STOPS executing here so it never hits steamInit() and never crashes!

	# 2. Safe to initialize now
	var _init_dict = Steam.steamInit()
	# Note: depending on your GodotSteam version, steamInit() can return a dictionary or bool. 
	# If it initialized successfully, we proceed:
	
	connected_to_steam = true
	send_log("Steam is running! User: " + Steam.getPersonaName())

	# 3. Create the peer safely now that we know Steam is active
	peer = SteamMultiplayerPeer.new()

	# Connect callbacks to know when connected
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	
	# Multiplayer callbacks
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	check_command_line()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if connected_to_steam:
		Steam.run_callbacks()

func host_game():
	if not connected_to_steam or not peer:
		send_log("Cannot host: Steam is not active.")
		return
		
	send_log("Attempting to host...")
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 50)
	
func _on_lobby_created(connect_result, lobby_id):
	if connect_result == 1:
		send_log("Created Lobby: " + str(lobby_id))	
		Steam.setLobbyData(lobby_id, "name", str(Steam.getPersonaName()) + "'s Lobby")
		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setRichPresence("connect","+connect_lobby " + str(lobby_id))

func _on_lobby_match_list(lobbies: Array):
	send_log("Found " + str(lobbies.size()) + " lobbies.")
	lobby_list_updated.emit(lobbies)
	
func _on_lobby_joined(lobby_id, _permissions, _locked, response):
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		current_lobby_id = lobby_id
		send_log("Joined Lobby!")
		
		var host_id = Steam.getLobbyOwner(lobby_id)
		if host_id != Steam.getSteamID():
			send_log("Connecting P2P to Host: " + str(host_id))
			peer.create_client(host_id)
			multiplayer.multiplayer_peer = peer
		connected_to_server.emit()
	else:
		send_log("Join Failed. Code: " + str(response))
		
func refresh_lobby_list():
	if not connected_to_steam: return
	send_log("Requesting Lobby List...")
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
		
func _on_join_requested(lobby_id, _friend_id):
	send_log("Friend Invite received! Joining...")
	if current_lobby_id != 0:
		disconnect_from_server()
		await get_tree().create_timer(0.2).timeout
	join_game(lobby_id)
		
func join_game(lobby_id):
	if not connected_to_steam: return
	send_log("Joining Lobby ID: " + str(lobby_id))
	current_lobby_id = lobby_id
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		
	Steam.joinLobby(lobby_id)
	
func check_command_line():
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg == "+connect_lobby" and args.size() > 1:
			var lobby_id_index = args.find(arg) + 1
			if lobby_id_index < args.size():
				var lobby_id = int(args[lobby_id_index])
				send_log("Found launch invite! Joining " + str(lobby_id))
				await get_tree().create_timer(1.0).timeout
				join_game(lobby_id)
				
func disconnect_from_server():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	if current_lobby_id != 0 and connected_to_steam:
		Steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0
	
	disconnected_from_server.emit()
	
func _on_peer_connected(id):
	send_log("P2P Connection Established: " + str(id))	
	
func _on_peer_disconnected(id):
	send_log("Peer Disconnected: " + str(id))	
	
func _on_server_disconnected():
	send_log("Host Left. Disconnecting...")
	disconnect_from_server()
	
func set_lobby_lock(locked: bool):
	if current_lobby_id == 0 or not connected_to_steam:
		return 
	Steam.setLobbyJoinable(current_lobby_id, !locked)
	send_log("Lobby Locked: " + str(locked))

#region Debug
func send_log(msg):
	print(msg)
	log_updated.emit(msg)
#endregion
