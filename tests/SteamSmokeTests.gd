extends Node
var failures=0
var checks=0
func check(value: bool, message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL: "+message)
func _ready() -> void:
 await get_tree().process_frame
 check(SteamSession.available,"Spacewar initializes with signed-in Steam account")
 if not SteamSession.available:
  print(SteamSession.status);get_tree().quit(1);return
 var game=load("res://scripts/Main.gd").new();add_child(game)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/steam-main-menu.png")
 check(SteamSession.host_game()==OK,"request real friends-only Steam lobby")
 var finish=Time.get_ticks_msec()+27000
 while SteamSession.operation=="host" and Time.get_ticks_msec()<finish:await get_tree().process_frame
 check(LanSession.is_host() and SteamSession.lobby_id>0,"native Steam host transport attaches")
 if not LanSession.is_host():
  print(SteamSession.status);get_tree().quit(1);return
 var id=SteamSession.lobby_id
 var api=SteamSession.api
 check(api.getLobbyMemberLimit(id)==3,"lobby limits coop to three people")
 check(SteamSession.compatible(SteamSession.lobby_metadata(id)),"lobby carries game, version and protocol metadata")
 check(api.getLobbyOwner(id)==api.getSteamID(),"local account owns real lobby")
 check(LanSession.multiplayer.get_unique_id()==1,"Steam host matches existing RPC authority ID")
 check(game.menu_page=="lobby","creation opens actual hero-ready lobby")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/steam-host-lobby.png")
 var peer=LanSession.multiplayer.multiplayer_peer
 peer.transfer_channel=2
 check(peer.transfer_channel==2,"native Steam peer supports effects channel")
 peer.transfer_channel=1
 check(peer.transfer_channel==1,"native Steam peer supports command channel")
 peer.transfer_channel=0
 check(SteamSession.join_game(str(id))==OK,"rejoining leaves previous session safely")
 # The owner has already left and this old lobby cannot attach to a new host.
 LanSession.leave()
 var wait_until=Time.get_ticks_msec()+3000
 while Time.get_ticks_msec()<wait_until:await get_tree().process_frame
 check(not LanSession.active and SteamSession.lobby_id==0,"cancelled join cannot resurrect lobby")
 SteamLobbyMenu.show_browser(game)
 check(game.menu_page=="steam","friend browser opens after leaving lobby")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/steam-friend-browser.png")
 check(SteamSession.host_game()==OK,"Steam hosting can restart after leave")
 finish=Time.get_ticks_msec()+27000
 while SteamSession.operation=="host" and Time.get_ticks_msec()<finish:await get_tree().process_frame
 check(LanSession.is_host(),"new native listen socket works after previous host closes")
 if LanSession.is_host():
  LanSession.ready_player("yasuo",["flash","heal"],Progression.bonuses())
  LanSession.start_match()
  check(GameState.started,"existing ARAM starts through Steam-backed authority")
  check(api.getLobbyData(SteamSession.lobby_id,"started")=="1","match closes Steam lobby to late joins")
 LanSession.leave()
 check(not LanSession.active and SteamSession.lobby_id==0,"Steam leave detaches peer and clears lobby")
 game._return_to_main_menu()
 check(SteamSession.host_game("pvp",3,true)==OK,"request real Steam PvP room")
 finish=Time.get_ticks_msec()+27000
 while SteamSession.operation=="host" and Time.get_ticks_msec()<finish:await get_tree().process_frame
 check(LanSession.is_host() and LanSession.is_pvp(),"native Steam attaches PvP rules")
 if LanSession.is_host():
  id=SteamSession.lobby_id
  var metadata=SteamSession.lobby_metadata(id)
  check(api.getLobbyMemberLimit(id)==6 and metadata.mode=="pvp" and metadata.team_size=="3","real Steam lobby advertises six-player PvP")
  check(LanSession.set_pvp_rules(1,false),"host changes to human-only duel")
  check(api.getLobbyMemberLimit(id)==2 and api.getLobbyData(id,"team_size")=="1" and api.getLobbyData(id,"fill_bots")=="0","Steam metadata and member limit update together")
  LanSession.ready_player("ashe",["heal","ghost"],profile_bonuses())
  check(not LanSession.can_start(),"PvP requires an opposing human")
  check(game.menu.find_child("PvpTeam",true,false)!=null,"real Steam displays PvP team controls")
 LanSession.leave()
 game.queue_free();await get_tree().process_frame
 print("STEAM LIVE SMOKE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)

func profile_bonuses() -> Dictionary:return Progression.bonuses()
