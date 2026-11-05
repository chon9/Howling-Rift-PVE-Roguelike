extends Node
# Host runs all combat and validates commands; guests display replicated state.
const SNAPSHOT_INTERVAL = 1.0/30.0
const MAX_EXTRAPOLATION = 0.08
const STATE_CHUNK_BYTES = 1000
const PORT = 24567
var network_port: int = PORT
var active: bool = false
var transport: String = "lan"
var main = null
var status: String = ""
var players: Dictionary = {}
var draft_states: Dictionary = {}
var replica_minions: Dictionary = {}
var replica_projectiles: Dictionary = {}
var replica_aoes: Dictionary = {}
var positions: Dictionary = {}
var motion_samples: Dictionary = {}
var incoming_frames: Dictionary = {}
var snapshot_sequence: int = 0
var last_snapshot_sequence: int = -1
var snapshot_received_at: float = 0.0
var state_timer: float = 0.0
var last_state_time: float = -1.0
var loading_match: bool = false
var loaded_peers: Dictionary = {}
var loading_deadline: float = 0.
var pending_finish: Dictionary = {}
var match_started: bool = false
var last_commands: Dictionary = {}
var pending_player: Dictionary = {}
var rules: Dictionary={"mode":"pve","team_size":3,"fill_bots":true}
var match_config: Dictionary={}
var join_address: String=""
var resume_token: String=""
var reconnect_info: Dictionary={}
var peer_tokens: Dictionary={}
var disconnected: Dictionary={}
var resume_requested: bool=false
const RECONNECT_SECONDS=60.
func build_version() -> String:return str(ProjectSettings.get_setting("application/config/version",""))
func is_pvp() -> bool:return rules.mode==MatchRules.PVP
func max_players() -> int:return MatchRules.capacity(rules)
func local_config() -> Dictionary:return players.get(multiplayer.get_unique_id(),{})
func broadcast_lobby() -> void:
 _lobby.rpc(players,rules)
 refresh_lobby()

func _ready() -> void:
 var args = OS.get_cmdline_user_args()
 var override_index = args.find("--test-lan-port")
 if override_index >= 0 and override_index+1 < args.size(): network_port = clampi(args[override_index+1].to_int(),1024,65535)
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(_failed)
 multiplayer.server_disconnected.connect(_server_left)
 multiplayer.peer_connected.connect(_peer_connected)
func is_host() -> bool: return active and multiplayer.is_server()
func is_client() -> bool: return active and not multiplayer.is_server()
func is_local(c) -> bool: return is_client() and c == GameState.player
func leave(forget_reconnect: bool=true) -> void:
 active = false
 var previous_peer = multiplayer.multiplayer_peer
 var was_steam = transport == "steam"
 # Replacing the transport releases it after SceneMultiplayer detaches.
 # Explicit ENet close can resend queued packets to already disconnected peers.
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 multiplayer.server_relay=true
 # Steam listen sockets must close even when another object retains the peer.
 if was_steam: previous_peer.close()
 SteamSession.leave()
 transport = "lan"
 ClientMovement.clear()
 players.clear(); draft_states.clear(); positions.clear()
 replica_minions.clear(); replica_projectiles.clear(); replica_aoes.clear()
 motion_samples.clear(); incoming_frames.clear(); snapshot_sequence=0; last_snapshot_sequence=-1; snapshot_received_at=0.
 match_started = false;loading_match=false;loaded_peers.clear();loading_deadline=0.;pending_finish.clear()
 state_timer = 0; last_state_time = -1
 pending_player.clear()
 last_commands.clear()
 rules=MatchRules.settings();match_config.clear();peer_tokens.clear();disconnected.clear();resume_requested=false;resume_token=""
 if forget_reconnect:reconnect_info.clear()
func attach_steam(peer: MultiplayerPeer, host: bool,settings: Dictionary={}) -> void:
 rules=MatchRules.settings(str(settings.get("mode","pve")),int(settings.get("team_size",3)),bool(settings.get("fill_bots",true)))
 transport = "steam"
 multiplayer.server_relay=not is_pvp()
 multiplayer.multiplayer_peer = peer
 active = true
 if host:
  players[1] = {"peer":1,"name":str(SteamSession.api.getPersonaName()).left(40),"hero":"ashe","spells":["flash","ignite"],"bonuses":{} if is_pvp() else Progression.bonuses(),"ready":false,"team":0}
func _peer_connected(peer: int) -> void:
 if not is_host():return
 if transport=="steam" and (not SteamSession.peer_allowed(peer) or (not match_started and players.size()>=max_players())):
  multiplayer.multiplayer_peer.disconnect_peer(peer);return
 var timer=get_tree().create_timer(5.)
 timer.timeout.connect(func():
  if is_host() and multiplayer.get_peers().has(peer) and not players.has(peer):multiplayer.multiplayer_peer.disconnect_peer(peer))
func host_game(mode: String="pve",size: int=3,bots: bool=true) -> Error:
 leave()
 rules=MatchRules.settings(mode,size,bots)
 var peer=ENetMultiplayerPeer.new()
 var error=peer.create_server(network_port,5 if is_pvp() else 2,3)
 if error!=OK:return error
 multiplayer.server_relay=not is_pvp()
 multiplayer.multiplayer_peer=peer;active=true
 players[1]={"peer":1,"name":"Host","hero":"ashe","spells":["flash","ignite"],"bonuses":{} if is_pvp() else Progression.bonuses(),"ready":false,"team":0}
 var addresses: PackedStringArray=[]
 for address in IP.get_local_addresses():
  if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):addresses.append(address)
 status="HOST • UDP %d\nLAN IP: %s\nChoose a team and hero, then press Ready." % [network_port,", ".join(addresses) if not addresses.is_empty() else "127.0.0.1"]
 return OK
func join_game(address: String) -> Error:
 if address.is_empty() or not address.is_valid_ip_address(): return ERR_INVALID_PARAMETER
 leave()
 join_address=address
 var peer = ENetMultiplayerPeer.new()
 var error = peer.create_client(address,network_port,3)
 if error != OK: return error
 multiplayer.multiplayer_peer = peer
 active = true
 status = "Connecting to %s..." % address
 return OK
func _connected() -> void:
 if not active: return
 if transport == "steam": SteamSession.connected()
 status = "Connected • choose a hero and press Ready."
 if resume_requested:
  _resume_player.rpc_id(1,resume_token,build_version());return
 if pending_player.is_empty():_submit_player.rpc_id(1,"ashe",["flash","ignite"],Progression.bonuses(),false,build_version())
 else:_submit_player.rpc_id(1,pending_player.hero,pending_player.spells,pending_player.bonuses,pending_player.ready,build_version())
 refresh_lobby()
func _failed() -> void:
 if not active: return
 var steam = transport == "steam"
 var saved=reconnect_info.duplicate(true) if resume_requested else {}
 leave()
 reconnect_info=saved
 status = "Steam connection failed. Check Steam is online and ask the host to create a new lobby." if steam else "Connection failed. Check the host's IP and that both PCs are on the same LAN."
 if is_instance_valid(main): main._show_main_menu()
func _server_left() -> void:
 if not active: return
 var reconnect=reconnect_info.duplicate(true) if resume_requested else {}
 if is_pvp() and match_started and GameState.running and not resume_token.is_empty():
  reconnect={"transport":transport,"address":join_address,"lobby":SteamSession.lobby_id,"token":resume_token,"expires":Time.get_ticks_msec()/1000.+RECONNECT_SECONDS}
 leave()
 status = "Connection lost. Reconnect to PvP within 60 seconds." if not reconnect.is_empty() else "Host disconnected. The multiplayer session ended."
 if is_instance_valid(main): main._return_to_main_menu()
 reconnect_info=reconnect
 if is_instance_valid(main) and not reconnect.is_empty():main._show_main_menu()
func _peer_left(peer: int) -> void:
 if not is_host():return
 var config=players.get(peer,{}).duplicate(true)
 players.erase(peer)
 if GameState.started:
  for c in GameState.champions:
   if c.owner_peer!=peer:continue
   c.owner_peer=0;c.stop_actions()
   if is_pvp():
    var token=str(peer_tokens.get(peer,""))
    if GameState.running and not token.is_empty():
     disconnected[token]={"config":config,"slot":GameState.champions.find(c),"expires":Time.get_ticks_msec()/1000.+RECONNECT_SECONDS,"draft":draft_states.get(peer,{}).duplicate(true),"steam_id":int(config.get("steam_id",0))}
    c.is_bot=bool(rules.fill_bots)
    c.char_name=config.get("name","Player")+(" (AI)" if c.is_bot else " (Disconnected)")
   else:
    c.is_bot=true
    if not GameState.allied_bots:c.disable_roster_slot()
    c.char_name+=" (AI)" if GameState.allied_bots else " (Disconnected)"
   c.name_label.text=c.char_name
 draft_states.erase(peer);peer_tokens.erase(peer);loaded_peers.erase(peer)
 _release_if_loaded()
 if not GameState.started:broadcast_lobby()
 refresh_lobby()
func sanitize_bonuses(bonuses: Dictionary) -> Dictionary:
 var result = {}
 for field in GearLoot.STAT_NAMES:
  var value = float(bonuses.get(field,0))
  if is_finite(value): result[field] = clampf(value,0,0.615 if field == "bonus_ms" else 5 if field == "bonus_as" else 0.4 if field == "bonus_cdr" else 1.0 if field in ["bonus_crit","bonus_lifesteal"] else 10000)
 return result
@rpc("any_peer","call_remote","reliable",1)
func _submit_player(hero: String, spells: Array, bonuses: Dictionary, ready: bool,version: String="") -> void:
 if not is_host():return
 var incoming=multiplayer.get_remote_sender_id()
 if match_started or version!=build_version():
  multiplayer.multiplayer_peer.disconnect_peer(incoming);return
 if not ChampionData.CHAMPIONS.has(hero):return
 var peer = multiplayer.get_remote_sender_id()
 if peer <= 1 or not multiplayer.get_peers().has(peer): return
 if transport == "steam" and not SteamSession.peer_allowed(peer): return
 if not players.has(peer) and players.size() >= max_players(): multiplayer.multiplayer_peer.disconnect_peer(peer); return
 if not valid_spells(spells): return
 var team=int(players.get(peer,{}).get("team",MatchRules.open_team(players,rules)))
 if team<0:multiplayer.multiplayer_peer.disconnect_peer(peer);return
 players[peer]={"peer":peer,"name":players.get(peer,{}).get("name","Player %d" % (players.size()+1)),"hero":hero,"spells":spells.duplicate(),"bonuses":{} if is_pvp() else sanitize_bonuses(bonuses),"ready":ready,"team":team}
 if transport=="steam":
  players[peer].name=SteamSession.peer_name(peer)
  players[peer].steam_id=multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer)
 if not peer_tokens.has(peer):peer_tokens[peer]=Crypto.new().generate_random_bytes(24).hex_encode()
 _welcome.rpc_id(peer,peer_tokens[peer])
 broadcast_lobby()
@rpc("authority","call_remote","reliable",1)
func _welcome(token: String) -> void:
 resume_token=token

func valid_spells(spells: Array) -> bool:
 return spells.size() == 2 and spells[0] != spells[1] and SummonerData.SPELLS.has(spells[0]) and SummonerData.SPELLS.has(spells[1])
func ready_player(hero: String, spells: Array, bonuses: Dictionary, ready: bool = true) -> void:
 if not active or match_started:return
 pending_player = {"hero":hero,"spells":spells.duplicate(),"bonuses":bonuses.duplicate(),"ready":ready}
 if not ChampionData.CHAMPIONS.has(hero) or not valid_spells(spells): return
 if is_host():
  players[1].hero = hero
  players[1].spells = spells.duplicate()
  players[1].bonuses = {} if is_pvp() else bonuses.duplicate()
  players[1].ready = ready
  broadcast_lobby()
 elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
  _submit_player.rpc_id(1,hero,spells,bonuses,ready,build_version())
func start_error() -> String:
 if match_started:return "This match has already started."
 return MatchRules.start_error(players,rules)
func can_start() -> bool:
 return is_host() and start_error().is_empty()
func change_team(team: int) -> void:
 if not active or match_started or not is_pvp():return
 if is_host():_assign_team(1,team)
 else:_request_team.rpc_id(1,team)
@rpc("any_peer","call_remote","reliable",1)
func _request_team(team: int) -> void:
 if is_host() and not match_started:_assign_team(multiplayer.get_remote_sender_id(),team)
func _assign_team(peer: int,team: int) -> bool:
 if match_started or not players.has(peer) or not is_pvp() or team not in [0,1]:return false
 if MatchRules.count_team(players,team,peer)>=int(rules.team_size):
  if peer!=1:_lobby_error.rpc_id(peer,"That team is full. Choose the other team.")
  else:status="That team is full. Choose the other team.";refresh_lobby()
  return false
 if players[peer].team!=team:players[peer].team=team;players[peer].ready=false
 broadcast_lobby();return true
func set_pvp_rules(size: int,bots: bool) -> bool:
 if not is_host() or match_started or not is_pvp() or size not in [1,2,3]:return false
 if MatchRules.count_team(players,0)>size or MatchRules.count_team(players,1)>size:
  status="Move players to fit the smaller team size first.";refresh_lobby();return false
 rules=MatchRules.settings("pvp",size,bots)
 for entry in players.values():entry.ready=false
 if transport=="steam":SteamSession.update_rules(rules)
 broadcast_lobby();return true
@rpc("authority","call_remote","reliable",1)
func _lobby_error(message: String) -> void:
 status=message;refresh_lobby()
@rpc("authority","call_remote","reliable",1)
func _lobby(configs: Dictionary,settings: Dictionary={}) -> void:
 players=configs.duplicate(true)
 var old_mode=rules.mode
 if not settings.is_empty():rules=MatchRules.settings(str(settings.mode),int(settings.team_size),bool(settings.fill_bots))
 if old_mode!=rules.mode and is_instance_valid(main) and main.menu_page=="lobby":main._show_lobby()
 refresh_lobby()
func refresh_lobby() -> void:
 if is_instance_valid(main):main._refresh_lobby()
func start_match() -> void:
 if not can_start():return
 var config=MatchRules.build_config(players,rules,Progression.difficulty,Progression.allied_bots)
 for entry in config.players:players[entry.peer]=entry.duplicate(true)
 BuildStealer.assign(config)
 config["loading_id"]=Time.get_ticks_msec()
 match_config=config.duplicate(true)
 match_started=true
 multiplayer.multiplayer_peer.refuse_new_connections=not is_pvp()
 if transport=="steam":SteamSession.lock_match()
 _begin_match.rpc(config)
@rpc("authority","call_local","reliable",1)
func _begin_match(config: Dictionary) -> void:
 match_started=true;match_config=config.duplicate(true)
 pending_finish.clear()
 loading_match=not bool(config.get("resuming",false));loaded_peers.clear();loading_deadline=Time.get_ticks_msec()/1000.+180.
 rules=MatchRules.settings(str(config.get("mode","pve")),int(config.get("team_size",3)),bool(config.get("fill_bots",true)))
 draft_states.clear();last_state_time=-1
 motion_samples.clear();incoming_frames.clear();snapshot_sequence=0;last_snapshot_sequence=-1
 resume_requested=false;reconnect_info.clear()
 if is_instance_valid(main):main._start_network_match(config)
func mark_match_loaded() -> void:
 if not active:return
 if not loading_match:
  if is_instance_valid(main):main._finish_match_loading()
  _apply_pending_finish()
  return
 var id=int(match_config.get("loading_id",0))
 if is_host():loaded_peers[1]=true;_release_if_loaded()
 else:_client_loaded.rpc_id(1,id)
@rpc("any_peer","call_remote","reliable",1)
func _client_loaded(id: int) -> void:
 if not is_host() or not loading_match or id!=int(match_config.get("loading_id",0)):return
 var peer=multiplayer.get_remote_sender_id()
 if not players.has(peer):return
 loaded_peers[peer]=true;_release_if_loaded()
func _release_if_loaded() -> void:
 if not is_host() or not loading_match or not GameState.started:return
 for peer in players:
  if not loaded_peers.has(peer):return
 _release_match.rpc(int(match_config.get("loading_id",0)))
@rpc("authority","call_local","reliable",1)
func _release_match(id: int) -> void:
 if not loading_match or id!=int(match_config.get("loading_id",0)) or not GameState.started:return
 loading_match=false
 if is_instance_valid(main):main._finish_match_loading()
 _apply_pending_finish()

func _apply_pending_finish() -> void:
 if pending_finish.is_empty():return
 var outcome=pending_finish;pending_finish={}
 _finish(int(outcome.winner),outcome.packet)

func send_command(kind: String, data: Dictionary = {}) -> void:
 if not is_client() or not GameState.started: return
 _command.rpc_id(1,kind,data)
@rpc("any_peer","call_remote","reliable",1)
func _command(kind: String, data: Dictionary) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 if kind not in ["order","skill","summoner","rank","recall","stop","buy","sell","draft","permanent"]:return
 var sender = multiplayer.get_remote_sender_id()
 var c = null
 for hero in GameState.champions:
  if hero.owner_peer == sender and sender > 1: c = hero; break
 if c == null: return
 var now = Time.get_ticks_msec()
 var stamp = str(sender)+kind
 if kind!="order" and now-int(last_commands.get(stamp,0)) < 15: return
 last_commands[stamp] = now
 execute(c,kind,data)
func execute(c, kind: String, data: Dictionary) -> void:
 var raw_point = data.get("point",c.world_pos())
 if not raw_point is Vector2: return
 var point: Vector2 = raw_point
 if not point.is_finite(): return
 var index = int(data.get("index",-1))
 match kind:
  "order":
   if data.get("type") in ["smart","amove"]: main._issue_champion_order(c,{"type":data.type,"point":point,"sequence":clampi(int(data.get("sequence",0)),0,2147483647)})
  "skill":
   if index >= 0 and index < 4: c.try_cast_skill(index,point)
  "summoner":
   if index >= 0 and index < 2:
    var previous = main.mouse_world
    main.mouse_world = point
    main.cast_summoner(c,index)
    main.mouse_world = previous
  "rank":
   if index >= 0 and index < 4: c.try_level_skill(index)
  "recall": c.start_recall()
  "stop": c.stop_actions()
  "buy": c.try_buy_item(str(data.get("id","")))
  "sell": c.try_sell_item(index)
  "draft": choose_draft(c,index)
  "permanent": return # Starting bonuses are captured by lobby configuration.
func award_draft(c) -> void:
 if not main.lane_augments.MILESTONES.has(c.level): return
 if not draft_states.has(c.owner_peer): draft_states[c.owner_peer] = {"pending":[],"choices":[],"picked":[],"awarded":[],"offers":{}}
 var draft = draft_states[c.owner_peer]
 if draft.awarded.has(c.level): return
 draft.awarded.append(c.level)
 draft.pending.append(c.level)
 fill_choices(draft,c)
func fill_choices(draft: Dictionary,c) -> void:
 if draft.pending.is_empty() or not draft.choices.is_empty(): return
 draft.choices = main.lane_augments.roll_choices(c)
 draft.offers = {}
 for index in draft.choices:draft.offers[index]=main.lane_augments.roll_offer(index,int(draft.pending[0]))
func choose_draft(c,index: int) -> void:
 var draft = draft_states.get(c.owner_peer,{})
 if draft.is_empty() or draft.pending.is_empty() or not draft.choices.has(index): return
 main.lane_augments.apply_augment(c,index,draft.offers.get(index,{}),int(draft.pending[0]))
 draft.picked.append(main.lane_augments.AUGMENTS[index].name)
 draft.pending.pop_front()
 draft.choices.clear()
 fill_choices(draft,c)
func registered_peers() -> Array:
 var peers=[]
 for peer in multiplayer.get_peers():
  if not players.has(peer):continue
  if transport=="lan" and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
   var packet_peer=multiplayer.multiplayer_peer.get_peer(peer)
   if packet_peer==null or packet_peer.get_state()!=ENetPacketPeer.STATE_CONNECTED or packet_peer.get_channels()<3:continue
  peers.append(peer)
 return peers
func replicate(delta: float) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 state_timer += delta
 if state_timer < SNAPSHOT_INTERVAL: return
 state_timer = fmod(state_timer,SNAPSHOT_INTERVAL)
 snapshot_sequence+=1
 var packet = LanSnapshot.encode()
 packet.sequence=snapshot_sequence
 for peer in registered_peers():
  var state = packet.duplicate()
  state.draft = draft_states.get(peer,{"pending":[],"choices":[],"picked":[]})
  var compressed=var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
  var count=ceili(float(compressed.size())/STATE_CHUNK_BYTES)
  for part in range(count):
   _state.rpc_id(peer,snapshot_sequence,part,count,compressed.slice(part*STATE_CHUNK_BYTES,mini((part+1)*STATE_CHUNK_BYTES,compressed.size())))
@rpc("authority","call_remote","unreliable",0)
func _state(sequence: int,part: int,count: int,chunk: PackedByteArray) -> void:
 if not is_client() or not GameState.started:return
 var compressed=assemble_state(sequence,part,count,chunk)
 if compressed.is_empty():return
 var packet=bytes_to_var(compressed.decompress_dynamic(4*1024*1024,FileAccess.COMPRESSION_DEFLATE))
 if packet is Dictionary and int(packet.get("sequence",-1))==sequence:apply_snapshot(packet)
func assemble_state(sequence: int,part: int,count: int,chunk: PackedByteArray) -> PackedByteArray:
 if sequence<=last_snapshot_sequence or count<1 or count>256 or part<0 or part>=count or chunk.is_empty() or chunk.size()>STATE_CHUNK_BYTES:return PackedByteArray()
 var now=Time.get_ticks_usec()/1000000.
 for old in incoming_frames.keys():
  if old<=last_snapshot_sequence or now-incoming_frames[old].started>.25:incoming_frames.erase(old)
 if not incoming_frames.has(sequence):
  if incoming_frames.size()>=4:
   var oldest=incoming_frames.keys().min()
   if sequence<oldest:return PackedByteArray()
   incoming_frames.erase(oldest)
  incoming_frames[sequence]={"started":now,"count":count,"parts":{}}
 var frame=incoming_frames[sequence]
 if frame.count!=count:return PackedByteArray()
 frame.parts[part]=chunk
 if frame.parts.size()!=count:return PackedByteArray()
 var result=PackedByteArray()
 for index in range(count):result.append_array(frame.parts[index])
 incoming_frames.erase(sequence)
 return result
func apply_snapshot(packet: Variant) -> bool:
 if not packet is Dictionary or not packet.has("time") or packet.time<=last_state_time:return false
 var sequence=int(packet.get("sequence",last_snapshot_sequence+1))
 if sequence<=last_snapshot_sequence:return false
 last_state_time=packet.time;last_snapshot_sequence=sequence
 snapshot_received_at=Time.get_ticks_usec()/1000000.0
 LanSnapshot.apply(packet,self)
 return true
func record_position(node,point: Vector2) -> void:
 var previous=motion_samples.get(node,{})
 var velocity=Vector2.ZERO
 var teleported=node.global_position.distance_to(point)>140.
 if not previous.is_empty():
  var elapsed=last_state_time-previous.time
  if elapsed>0.001 and elapsed<.25 and not teleported:
   velocity=(point-previous.point)/elapsed
   if velocity.length()>1600.:velocity=Vector2.ZERO
 if teleported:node.global_position=point
 motion_samples[node]={"point":point,"time":last_state_time,"velocity":velocity}
 positions[node]=point
func smooth_positions(delta: float) -> void:
 var age=clampf(Time.get_ticks_usec()/1000000.0-snapshot_received_at,0.,MAX_EXTRAPOLATION)
 for node in positions.keys():
  if not is_instance_valid(node):positions.erase(node);motion_samples.erase(node);continue
  var sample=motion_samples.get(node,{})
  if node is Champion and (node.dead or node.stun>0):sample={}
  var target=positions[node]+sample.get("velocity",Vector2.ZERO)*age
  if node is Champion or node is Minion:target=GameState.clamp_walkable(target)
  if node==GameState.player and ClientMovement.tick(node,delta,target):continue
  var rate=45. if node==GameState.player else 32.
  node.global_position=node.global_position.lerp(target,1.-exp(-delta*rate))
func _process(delta: float) -> void:
 if is_host():
  var now=Time.get_ticks_msec()/1000.
  if loading_match and now>loading_deadline:
   for peer in players.keys():
    if peer!=1 and not loaded_peers.has(peer):multiplayer.multiplayer_peer.disconnect_peer(peer)
  for token in disconnected.keys():
   if now>disconnected[token].expires:disconnected.erase(token)
 if not is_client() or not GameState.started: return
 for c in GameState.champions:
  if c.hit_flash>0:
   c.hit_flash=maxf(0.,c.hit_flash-delta);c.queue_redraw()
 smooth_positions(delta)
 BrushVision.update_presentation()
func send_effect(kind: String, actor, point: Vector2, data: Dictionary = {}) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 for peer in registered_peers():
  if data.has("audience") and not data.audience.is_empty() and not data.audience.has(peer):continue
  _effect.rpc_id(peer,kind,GameState.champions.find(actor),point,data)
@rpc("authority","call_remote","unreliable",2)
func _effect(kind: String, actor_index: int, point: Vector2, data: Dictionary) -> void:
 if not is_client() or not GameState.started or not is_instance_valid(main): return
 var actor = GameState.champions[actor_index] if actor_index >= 0 and actor_index < GameState.champions.size() else null
 match kind:
  "announce": main.announce_kill(data.event,int(data.team),str(data.hero),actor)
  "sound": main.play_sfx(data.event,actor)
  "melee":
   if actor != null: main.spawn_melee_strike(actor,point,data.get("light_hit",false))
  "burst":
   if actor != null: main.spawn_spell_burst(actor,point,data.radius)
  "beam":
   if actor != null: main.spawn_beam(actor,data.direction,data.length,data.width,0,data.color)
  "minion_hit": main.spawn_minion_hit(point)
  "impact": main.spawn_impact(point,data.color,data.size)
  "hero_impact": main.spawn_hero_impact(point,int(data.row),float(data.radius),float(data.angle),actor)
  "text": main.floating_text(point,data.text,data.color,data.big)
  "kill":
   var victim = GameState.champions[data.victim]
   main.hud.get_node("HudRoot").log_kill(actor,victim)
func finish(winner: int) -> void:
 if is_host():
  disconnected.clear()
  for peer in registered_peers():
   var packet=LanSnapshot.encode();packet["archive_report"]=main.archive_report
   _finish.rpc_id(peer,winner,packet)
@rpc("authority","call_remote","reliable",1)
func _finish(winner: int, packet: Dictionary) -> void:
 if not is_client():return
 if not GameState.started or (is_instance_valid(main) and is_instance_valid(main.match_loader) and main.match_loader.pending):
  pending_finish={"winner":winner,"packet":packet.duplicate(true)};return
 last_state_time = packet.time
 LanSnapshot.apply(packet,self)
 main.archive_report=str(packet.get("archive_report",""))
 main._end_game(winner)

func can_reconnect() -> bool:
 return not active and not reconnect_info.is_empty() and Time.get_ticks_msec()/1000.<reconnect_info.expires
func reconnect_game() -> Error:
 if not can_reconnect():return ERR_UNAVAILABLE
 var saved=reconnect_info.duplicate(true)
 var error=SteamSession.join_game(str(saved.lobby),true) if saved.transport=="steam" else join_game(saved.address)
 if error==OK:
  reconnect_info=saved;resume_token=saved.token;resume_requested=true
  status="Reconnecting to your PvP hero…"
 return error
@rpc("any_peer","call_remote","reliable",1)
func _resume_player(token: String,version: String) -> void:
 if not is_host():return
 var peer=multiplayer.get_remote_sender_id()
 if peer<=1 or players.has(peer) or not multiplayer.get_peers().has(peer):return
 if not is_pvp() or not GameState.running or version!=build_version() or not disconnected.has(token):
  multiplayer.multiplayer_peer.disconnect_peer(peer);return
 var entry=disconnected[token]
 if Time.get_ticks_msec()/1000.>entry.expires:
  disconnected.erase(token);multiplayer.multiplayer_peer.disconnect_peer(peer);return
 if transport=="steam" and (not SteamSession.peer_allowed(peer) or int(multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer))!=entry.steam_id):
  multiplayer.multiplayer_peer.disconnect_peer(peer);return
 var c=GameState.champions[entry.slot]
 var config=entry.config.duplicate(true);config.peer=peer;config.ready=true
 players[peer]=config;peer_tokens[peer]=token
 draft_states[peer]=entry.draft.duplicate(true)
 c.owner_peer=peer;c.is_bot=false;c.char_name=config.name;c.name_label.text=c.char_name;c.stop_actions()
 disconnected.erase(token)
 var start=match_config.duplicate(true);start.players=players.values().duplicate(true);start.resuming=true
 _welcome.rpc_id(peer,token);_lobby.rpc_id(peer,players,rules);_begin_match.rpc_id(peer,start)
 state_timer=SNAPSHOT_INTERVAL
