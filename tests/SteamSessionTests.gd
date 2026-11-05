extends Node
var failures=0
var checks=0
class FakeSteam extends RefCounted:
 var left=[]
 var joins=[]
 var requests=[]
 var metadata={}
 var owner=222
 func getSteamID():return 111
 func getPersonaName():return "Test Host"
 func leaveLobby(id):left.append(id)
 func joinLobby(id):joins.append(id)
 func createLobby(privacy,limit):requests.append([privacy,limit])
 func getLobbyData(_id,key):return metadata.get(key,"")
 func getLobbyOwner(_id):return owner
func check(value: bool, message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL: "+message)
func _ready() -> void:
 await get_tree().process_frame
 SteamSession.set_process(false)
 check(load("res://tests/SteamPeerTests.gd")!=null,"two-PC Steam test compiles with project autoloads")
 check(SteamSession.join_game("garbage")==ERR_INVALID_PARAMETER,"reject non-numeric lobby code")
 check(SteamSession.join_game("0")==ERR_INVALID_PARAMETER,"reject zero lobby ID")
 check(SteamSession.host_game()==ERR_UNAVAILABLE,"offline host gives recoverable unavailable result")
 var api=FakeSteam.new()
 SteamSession.api=api;SteamSession.available=true
 var valid={"game":SteamSession.GAME_KEY,"protocol":SteamSession.PROTOCOL,"version":str(ProjectSettings.get_setting("application/config/version")),"host":"222","started":"0"}
 check(SteamSession.compatible(valid),"matching build and protocol accepted")
 for key in ["game","protocol","version"]:
  var wrong=valid.duplicate();wrong[key]="another"
  check(not SteamSession.compatible(wrong),"reject mismatched "+key)
 check(SteamSession.join_game(" 123 ")==OK and api.joins==[123],"trim and submit lobby code")
 check(SteamSession.host_game()==ERR_BUSY,"prevent competing host while join pending")
 LanSession.leave()
 SteamSession._joined(123,0,false,1)
 check(SteamSession.lobby_id==0 and not LanSession.active and api.left.has(123),"late cancelled join leaves orphan Steam lobby")
 check(SteamSession.host_game()==OK and api.requests==[[1,3]],"host requests friends-only three-member lobby")
 LanSession.leave()
 check(SteamSession.host_game()==ERR_BUSY,"wait for old creation callback before requesting another lobby")
 SteamSession._created(1,456)
 check(api.left.has(456) and not SteamSession.creating,"cancelled creation leaves lobby and clears busy state")
 check(SteamSession.join_game("789")==OK,"join permitted after cancelled create completes")
 api.metadata={"game":"another-game"}
 SteamSession._joined(789,0,false,1)
 check(not LanSession.active and api.left.has(789) and SteamSession.status.contains("matching"),"Spacewar lobby belonging to another game is rejected")
 check(SteamSession.join_game("790")==OK,"join again after validation failure")
 api.metadata=valid.duplicate();api.metadata.started="1"
 SteamSession._joined(790,0,false,1)
 check(api.left.has(790) and SteamSession.status.contains("already started"),"reject matches already in progress")
 SteamSession.join_game("791");api.metadata=valid.duplicate();api.owner=333
 SteamSession._joined(791,0,false,1)
 check(api.left.has(791) and SteamSession.status.contains("changed"),"reject lobby where original host left")
 SteamSession.join_game("792");SteamSession._joined(792,0,false,4)
 check(not LanSession.active and SteamSession.status.contains("full"),"full lobby errors leave game playable")
 GameState.started=true
 check(SteamSession.host_game()==ERR_ALREADY_IN_USE,"cannot replace running match with Steam host")
 SteamSession._invite(999,222)
 check(not api.joins.has(999),"invite never silently replaces active match")
 GameState.started=false
 SteamSession.leave();SteamSession.available=false;SteamSession.api=null
 print("STEAM SESSION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
