extends Node
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL MOBILE AUDIO: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 var s=game.sound_fx
 for key in s.SUPPLIED_CLIPS:
  var stream=s.announcer_clips[key]
  check(stream is AudioStreamWAV and stream.get_length()>.3,"supplied clip decodes: "+key)
  check(stream.resource_path.ends_with(s.SUPPLIED_CLIPS[key]+".wav"),"event selects correct recording: "+key)
  s.announcer_voice.stop();s.announce(key)
  check(s.announcer_voice.stream==stream and s.announcement_counts.get(key,0)>0,"announcer dispatches supplied recording: "+key)
 s.announcer_voice.stop()
 game._start_game("yasuo");game.set_process(false)
 for unit in GameState.champions:unit.is_bot=false;unit.stop_actions()
 var p=GameState.player;var victim=GameState.champions[3]
 var expected=["first_blood","slain","killing_spree","mega_kill","unstoppable","monster_kill","godlike","legendary","legendary"]
 for i in range(expected.size()):
  s.announcer_voice.stop();game._respawn_champion(victim)
  GameState.time=i*9.
  game.deal_damage(p,victim,victim.hp+victim.shield+1000.,"exec")
  check(game.kill_announcer.events.back()==expected[i],"consecutive no-death kills select "+expected[i])
  check(game.hud.get_node("HudRoot").announcement_title.text==game.kill_announcer.TITLES[expected[i]] if expected[i]!="slain" else game.hud.get_node("HudRoot").announcement_title.text=="ENEMY SLAIN","spree HUD matches event")
 game._respawn_champion(victim);GameState.time+=9.
 game.deal_damage(victim,p,p.hp+p.shield+1000.,"exec")
 check(game.kill_announcer.streaks[p.get_instance_id()].streak==0,"death resets uninterrupted spree")
 game._respawn_champion(p);game.kill_announcer.streaks.clear();game.kill_announcer.events.clear()
 for i in range(5):
  s.announcer_voice.stop();game._respawn_champion(victim)
  GameState.time=200.+i
  game.deal_damage(p,victim,victim.hp+victim.shield+1000.,"exec")
  var event=["slain","double_kill","triple_kill","quadra_kill","penta_kill"][i]
  check(game.kill_announcer.events.back()==event,"rapid kill count selects correct event")
  if i>=3:
   check(game.hud.get_node("HudRoot").kill_celebration.headline==("MANIAC" if i==3 else "SAVAGE"),"Mobile Legends multikill title")
   check(s.announcer_voice.stream.resource_path.ends_with(("maniac" if i==3 else "savage")+".wav"),"Mobile Legends multikill recording")
 s.announcer_voice.stop()
 game.announce_kill("slain",p.team,p.hero.name,p)
 check(s.announcer_voice.stream.resource_path.ends_with("mobile-announcer-v1/enemy_slain.wav"),"personal kill uses supplied You Have Slain recording")
 s.announcer_voice.stop()
 game.announce_kill("slain",p.team,GameState.champions[1].hero.name,GameState.champions[1])
 check(not s.announcer_voice.playing and not s.announcer_clips.has("team_enemy_slain"),"teammate kill has no TTS fallback")
 for key in ["ally_slain","shutdown","victory_voice","defeat_voice"]:
  s.announce(key)
  check(not s.announcer_clips.has(key) and not s.announcer_voice.playing,"missing supplied callout stays silent: "+key)
 var music=game.music
 check(music.players.battle.stream is AudioStreamMP3 and music.TRACKS.battle.ends_with("battle-theme-v1.mp3") and music.players.battle.stream.loop,"supplied battle theme loops during match")
 music.refresh(3.)
 check(music.mode=="battle" and music.gains.battle==1.,"match selects supplied battle music")
 print("MOBILE AUDIO: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
