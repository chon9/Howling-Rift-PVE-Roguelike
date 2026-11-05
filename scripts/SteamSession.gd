extends Node
# Spacewar is a development identity. Only our protocol's lobbies are accepted.
signal changed
signal friends_changed
const APP_ID = 480
const GAME_KEY = "howling-rift-aram"
const PROTOCOL = "13"
const REQUEST_TIMEOUT = 25.0
var api = null
var available = false
var status = "Steam unavailable. Solo and LAN are available."
var lobby_id: int = 0
var host_steam_id: int = 0
var operation = ""
var target_lobby: int = 0
var deadline: float = 0
var creating = false
var requested_rules: Dictionary=MatchRules.settings()
var resume_join: bool=false
var joining: Dictionary = {}
var friends: Array = []
var friend_candidates: Dictionary = {}

func _ready() -> void:
 if OS.get_cmdline_user_args().has("--no-steam"): return
 if DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--steam-test"): return
 initialize()
 call_deferred("_startup_invite")

func initialize() -> bool:
 if available: return true
 if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
  set_status("Steam extension unavailable. Solo and LAN are available."); return false
 api = Engine.get_singleton("Steam")
 var result: Dictionary = api.steamInitEx(APP_ID,false)
 if int(result.get("status",-1)) != 0:
  set_status("Open Steam and restart the game to use Steam co-op."); return false
 available = bool(api.loggedOn())
 if not available:
  set_status("Sign into Steam and restart the game to use Steam co-op."); return false
 api.lobby_created.connect(_created)
 api.lobby_joined.connect(_joined)
 api.join_requested.connect(_invite)
 api.lobby_chat_update.connect(_membership_changed)
 api.lobby_data_update.connect(_lobby_data)
 api.initRelayNetworkAccess()
 set_status("Steam connected • "+str(api.getPersonaName()))
 return true

func set_status(value: String) -> void:
 status = value
 changed.emit()

func _process(_delta: float) -> void:
 if not available: return
 api.run_callbacks()
 if deadline > 0 and Time.get_ticks_msec()/1000.0 > deadline:
  if operation == "connecting": fail("Steam connection timed out. Ask the host to create a new lobby.")
  else:
   operation = ""; target_lobby = 0; deadline = 0
   set_status("Steam request timed out. Check your connection and try again.")

func host_game(mode: String="pve",size: int=3,bots: bool=true) -> Error:
 if not available: return ERR_UNAVAILABLE
 if creating or not operation.is_empty(): return ERR_BUSY
 if GameState.started: return ERR_ALREADY_IN_USE
 LanSession.leave()
 requested_rules=MatchRules.settings(mode,size,bots)
 operation = "host"; creating = true
 deadline = Time.get_ticks_msec()/1000.0+REQUEST_TIMEOUT
 set_status("Creating Steam lobby…")
 api.createLobby(1,6 if mode=="pvp" else 3) # Friends-only custom rooms.
 return OK

func join_game(code: String,resuming: bool=false) -> Error:
 var clean = code.strip_edges()
 if not clean.is_valid_int() or clean.to_int() <= 0: return ERR_INVALID_PARAMETER
 if not available: return ERR_UNAVAILABLE
 if creating or not operation.is_empty(): return ERR_BUSY
 if GameState.started: return ERR_ALREADY_IN_USE
 var id = clean.to_int()
 if joining.has(id): return ERR_BUSY
 LanSession.leave()
 resume_join=resuming
 operation = "join"; target_lobby = id; joining[id] = true
 deadline = Time.get_ticks_msec()/1000.0+REQUEST_TIMEOUT
 set_status("Joining Steam lobby…")
 api.joinLobby(id)
 return OK

func _created(result: int, id: int) -> void:
 creating = false
 if operation != "host":
  if result == 1: api.leaveLobby(id)
  return
 if result != 1: fail("Could not create Steam lobby (code %d)." % result); return
 lobby_id = id; host_steam_id = int(api.getSteamID())
 api.setLobbyData(id,"game",GAME_KEY)
 api.setLobbyData(id,"protocol",PROTOCOL)
 api.setLobbyData(id,"version",str(ProjectSettings.get_setting("application/config/version","0.1.0")))
 api.setLobbyData(id,"host",str(host_steam_id))
 api.setLobbyData(id,"name",str(api.getPersonaName()).left(40)+"'s Howling Rift")
 api.setLobbyData(id,"started","0")
 var peer = ClassDB.instantiate("SteamMultiplayerPeer")
 peer.set_no_nagle(true)
 var error: Error = peer.host_with_lobby(id)
 if error != OK: fail("Steam transport could not start: "+error_string(error)); return
 LanSession.attach_steam(peer,true,requested_rules)
 update_rules(requested_rules)
 operation = ""; deadline = 0
 LanSession.status = "STEAM %s • Lobby %d\nInvite friends, choose teams and heroes, then press Ready." % ["PVP" if requested_rules.mode=="pvp" else "CO-OP",id]
 set_status(LanSession.status)
 if is_instance_valid(LanSession.main): LanSession.main._show_lobby()

func compatible(data: Dictionary) -> bool:
 return data.get("game","") == GAME_KEY and data.get("protocol","") == PROTOCOL and data.get("version","") == str(ProjectSettings.get_setting("application/config/version","0.1.0"))

func lobby_metadata(id: int) -> Dictionary:
 var data = {}
 for key in ["game","protocol","version","host","started","name","mode","team_size","fill_bots"]: data[key] = api.getLobbyData(id,key)
 return data

func _joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
 # Steam also emits lobby_joined for the host's own newly created lobby.
 if operation == "host" and not joining.has(id): return
 if id == lobby_id and host_steam_id == int(api.getSteamID()): return
 joining.erase(id)
 if operation != "join" or id != target_lobby:
  if response == 1 and id != lobby_id: api.leaveLobby(id)
  return
 if response != 1: fail("Could not join. The lobby may be full, closed, or friends only (code %d)." % response); return
 lobby_id = id
 var data = lobby_metadata(id)
 if not compatible(data): fail("This lobby is not a matching Howling Rift build."); return
 if data.started != "0" and not (resume_join and data.mode=="pvp"): fail("This match has already started. Ask your friend to host a new lobby."); return
 host_steam_id = int(api.getLobbyOwner(id))
 if host_steam_id <= 0 or str(host_steam_id) != data.host or host_steam_id == int(api.getSteamID()):
  fail("The lobby host has changed. Ask your friend to create a new lobby."); return
 var peer = ClassDB.instantiate("SteamMultiplayerPeer")
 peer.set_no_nagle(true)
 var error: Error = peer.connect_to_lobby(id)
 if error != OK: fail("Steam connection failed: "+error_string(error)); return
 var saved_token=LanSession.resume_token;var saved_reconnect=LanSession.reconnect_info.duplicate(true)
 var settings=MatchRules.settings(data.get("mode","pve"),int(data.get("team_size",3)),data.get("fill_bots","1")=="1")
 LanSession.attach_steam(peer,false,settings)
 if resume_join:LanSession.resume_token=saved_token;LanSession.resume_requested=true;LanSession.reconnect_info=saved_reconnect
 operation = "connecting"; deadline = Time.get_ticks_msec()/1000.0+REQUEST_TIMEOUT
 LanSession.status = "Connecting to Steam host…"
 set_status(LanSession.status)
 if is_instance_valid(LanSession.main): LanSession.main._show_lobby()

func connected() -> void:
 operation = ""; deadline = 0
 set_status("Steam connected • choose a hero and press Ready.")

func leave() -> void:
 var old_id = lobby_id
 lobby_id = 0; host_steam_id = 0; operation = ""; target_lobby = 0; deadline = 0
 if available and old_id > 0: api.leaveLobby(old_id)
 if available: set_status("Steam connected • "+str(api.getPersonaName()))

func fail(reason: String) -> void:
 var reconnect=LanSession.reconnect_info.duplicate(true) if resume_join else {}
 LanSession.leave()
 LanSession.reconnect_info=reconnect
 LanSession.status = reason
 set_status(reason)
 if is_instance_valid(LanSession.main):
  if GameState.started: LanSession.main._return_to_main_menu()
  else: LanSession.main._show_main_menu()

func invite_friends() -> void:
 if available and lobby_id > 0: api.activateGameOverlayInviteDialog(lobby_id)

func lock_match() -> void:
 if available and lobby_id > 0 and LanSession.is_host():
  api.setLobbyData(lobby_id,"started","1")
  api.setLobbyJoinable(lobby_id,LanSession.is_pvp())

func peer_allowed(peer_id: int) -> bool:
 if not available or lobby_id <= 0: return false
 var remote = LanSession.multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
 for i in range(api.getNumLobbyMembers(lobby_id)):
  if int(api.getLobbyMemberByIndex(lobby_id,i)) == int(remote): return true
 return false

func peer_name(peer_id: int) -> String:
 var remote = LanSession.multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
 return str(api.getFriendPersonaName(remote)).left(40)

func _membership_changed(id: int, _changed: int, _actor: int, _state: int) -> void:
 if id != lobby_id or lobby_id == 0: return
 if int(api.getLobbyOwner(id)) != host_steam_id:
  fail("Steam host left. The multiplayer session ended.")

func _invite(id: int, _friend: int) -> void:
 if GameState.started or LanSession.active or not operation.is_empty():
  set_status("Steam invite received. Leave your current session before joining."); return
 var error = join_game(str(id))
 if error != OK: set_status("Could not join invite: "+error_string(error))

func _startup_invite() -> void:
 var args = OS.get_cmdline_args()+OS.get_cmdline_user_args()
 var index = args.find("+connect_lobby")
 if available and index >= 0 and index+1 < args.size(): _invite(args[index+1].to_int(),0)

func refresh_friends() -> void:
 friends.clear(); friend_candidates.clear()
 if available:
  for i in range(api.getFriendCount(4)):
   var friend = api.getFriendByIndex(i,4)
   var playing: Dictionary = api.getFriendGamePlayed(friend)
   var id = int(playing.get("lobby",0))
   if int(playing.get("id",0)) == APP_ID and id > 0:
    friend_candidates[id] = str(api.getFriendPersonaName(friend)).left(40)
    api.requestLobbyData(id)
 friends_changed.emit()

func _lobby_data(success: int, id: int, member_id: int) -> void:
 if success != 1 or id != member_id or not friend_candidates.has(id): return
 var data = lobby_metadata(id)
 if not compatible(data) or data.started != "0": return
 for entry in friends:
  if entry.id == id: return
 friends.append({"id":id,"name":friend_candidates[id],"members":api.getNumLobbyMembers(id),"mode":data.get("mode","pve"),"capacity":int(data.get("team_size","3"))*2 if data.get("mode","pve")=="pvp" else 3})
 friends_changed.emit()

func _exit_tree() -> void:
 if available: leave()

func update_rules(rules: Dictionary) -> void:
 if not available or lobby_id<=0:return
 api.setLobbyData(lobby_id,"mode",rules.mode)
 api.setLobbyData(lobby_id,"team_size",str(rules.team_size))
 api.setLobbyData(lobby_id,"fill_bots","1" if rules.fill_bots else "0")
 if api.has_method("setLobbyMemberLimit"):api.setLobbyMemberLimit(lobby_id,MatchRules.capacity(rules))
