extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL UPDATE/NETWORK: "+message)
func _ready() -> void:
 await get_tree().process_frame
 check(GameUpdates.newer("v0.4.4","0.4.3"),"patch upgrade detected")
 check(GameUpdates.newer("1.0.0","0.99.99"),"major upgrade compares numerically")
 check(not GameUpdates.newer("0.4.4","0.4.4") and not GameUpdates.newer("0.4.2","0.4.4"),"no same-version update or downgrade")
 for bad in ["v0.4.4-beta","0.4.4/evil","../../1.0.0","unknown"]:check(GameUpdates.version_parts(bad).is_empty(),"invalid version rejected")
 var prefix="https://github.com/"+GameUpdates.REPO+"/releases/download/v0.7.2/"
 var name="Howling-Rift-v0.7.2-Spacewar.zip"
 var manifest={"tag_name":"v0.7.2","draft":false,"prerelease":false,"assets":[{"name":name,"browser_download_url":prefix+name},{"name":name+".sha256","browser_download_url":prefix+name+".sha256"}]}
 check(GameUpdates.parse_release(manifest).version=="0.7.2","complete official release accepted")
 var legacy=manifest.duplicate(true)
 for asset in legacy.assets:asset.browser_download_url=asset.browser_download_url.replace(GameUpdates.REPO,GameUpdates.LEGACY_REPO)
 check(GameUpdates.parse_release(legacy).version=="0.7.2","original repository release links remain accepted")
 var unsafe=manifest.duplicate(true);unsafe.assets[0].browser_download_url="https://evil.example/update.zip"
 check(GameUpdates.parse_release(unsafe).is_empty(),"untrusted download rejected")
 unsafe=manifest.duplicate(true);unsafe.assets.pop_back()
 check(GameUpdates.parse_release(unsafe).is_empty(),"checksum is required")
 unsafe=manifest.duplicate(true);unsafe.prerelease=true
 check(GameUpdates.parse_release(unsafe).is_empty(),"prerelease does not replace stable installation")
 GameUpdates.auto_download=false;GameUpdates._checked(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(manifest).to_utf8_buffer())
 check(GameUpdates.phase=="available" and GameUpdates.latest=="0.7.2","main menu can show latest version")
 GameUpdates._checked(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
 check(GameUpdates.phase=="error" and GameUpdates.status.contains("still play"),"offline failure remains playable")
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 check(game.menu.find_child("UpdateAction",true,false)!=null,"main menu exposes update action")
 game._start_game("vayne")
 var player=GameState.player
 check(is_equal_approx(LanSession.SNAPSHOT_INTERVAL,1./30.),"world update cadence is thirty Hz")
 check(LanSession.assemble_state(1,1,2,PackedByteArray([3,4])).is_empty(),"partial snapshot never applies")
 check(LanSession.assemble_state(1,0,2,PackedByteArray([1,2]))==PackedByteArray([1,2,3,4]),"out-of-order chunks reassemble correctly")
 LanSession.assemble_state(2,0,2,PackedByteArray([9]))
 check(LanSession.assemble_state(3,0,1,PackedByteArray([7]))==PackedByteArray([7]),"missing old chunk never blocks newer snapshot")
 check(LanSession.assemble_state(4,3,2,PackedByteArray([1])).is_empty(),"invalid chunk index rejected")
 LanSession.last_state_time=1.;LanSession.record_position(player,Vector2(1400,270));player.global_position=Vector2(1400,270)
 LanSession.last_state_time=1.05;LanSession.record_position(player,Vector2(1417.5,270))
 check(LanSession.motion_samples[player].velocity.is_equal_approx(Vector2(350,0)),"motion samples recover authoritative velocity")
 LanSession.snapshot_received_at=Time.get_ticks_usec()/1000000.-.1
 LanSession.smooth_positions(.05)
 check(player.global_position.x>1417.5 and player.global_position.x<1446.,"bounded extrapolation reduces visible movement delay")
 LanSession.record_position(player,Vector2(2000,270))
 check(player.global_position.x==2000. and LanSession.motion_samples[player].velocity==Vector2.ZERO,"teleports snap without stale velocity")
 var packet=LanSnapshot.encode();packet.sequence=10;packet.time=3.
 LanSession.last_state_time=-1.;LanSession.last_snapshot_sequence=-1
 check(LanSession.apply_snapshot(packet),"independent full state applies")
 check(not LanSession.apply_snapshot(packet),"duplicate state rejected")
 packet.sequence=9;packet.time=4.
 check(not LanSession.apply_snapshot(packet),"late packet cannot overwrite newer sequence")
 packet.sequence=12;packet.time=5.
 check(LanSession.apply_snapshot(packet),"dropped sequence does not block next full state")
 LanSession.leave();check(LanSession.motion_samples.is_empty() and LanSession.last_snapshot_sequence==-1,"new match clears motion and sequence history")
 game._return_to_main_menu()
 if DisplayServer.get_name()!="headless":
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/update-menu-v044.png")
 print("UPDATE/NETWORK: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
