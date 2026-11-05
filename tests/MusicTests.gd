extends Node
var failures = 0
var checks = 0
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 var original_volume = Progression.music_volume
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 var music = game.music
 music.refresh(3)
 check(music.mode == "menu" and music.gains.menu == 1,"title menu selects the calm theme")
 check(music.players.menu.stream.get_length()>=179 and music.players.battle.stream.get_length()>210 and music.players.battle.stream is AudioStreamMP3,"supplied battle theme plays over the match")
 check(game.sound_fx.announcer_clips.values().all(func(clip):return clip.resource_path.begins_with("res://assets/audio/mobile-announcer-v1/")),"announcer uses only supplied recordings")
 for player in music.players.values():
  check(player.stream.loop and player.stream.get_length()>=179,"valid long looping soundtrack")
 if DisplayServer.get_name() != "headless":
  check(music.players.menu.playing,"menu music actually plays on native audio")
  var position = music.players.menu.get_playback_position()
  await get_tree().create_timer(0.15).timeout
  check(music.players.menu.get_playback_position()>position,"native playback advances")
 game._start_game("ashe")
 music.refresh(0.9)
 check(music.mode == "battle" and music.gains.menu>0 and music.gains.battle>0,"starting a match crossfades both tracks")
 music.refresh(3)
 check(music.gains.battle == 1 and music.gains.menu == 0,"crossfade finishes without overlapping full-volume tracks")
 var battle_volume = music.players.battle.volume_db
 GameState.paused = true
 music.refresh(3)
 check(music.paused_mix and music.players.battle.volume_db<battle_volume-4,"pause menu reduces music volume")
 GameState.paused = false
 music.refresh(3)
 game.sound_fx.announce("double_kill")
 music.refresh(0.1)
 if DisplayServer.get_name() != "headless": check(music.ducked,"spoken announcement ducks background music")
 music.set_volume(0)
 music.refresh(3)
 check(not music.players.menu.playing and not music.players.battle.playing,"zero volume stops music playback")
 music.set_volume(0.35)
 music.refresh(3)
 game.sound_fx.set_enabled(false)
 check(music.user_volume == 0.35 and music.players.battle.volume_db>-80,"music volume is independent of sound effects")
 var original_path = Progression.save_path
 Progression.save_path = "res://tests/music-profile-test.cfg"
 Progression.persistent = true
 music.set_volume(0.27)
 Progression.music_volume = 0.9
 Progression.load_profile()
 check(is_equal_approx(Progression.music_volume,0.27),"music preference survives profile save/load")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Progression.save_path))
 Progression.save_path = original_path
 Progression.persistent = false
 music.set_volume(0.45)
 game._end_game(Constants.BLUE)
 music.refresh(3)
 check(music.mode == "menu" and music.gains.menu == 1,"match results return to the calm theme")
 game._return_to_main_menu()
 music = game.music
 music.refresh(3)
 check(music.mode == "menu" and music.user_volume == 0.45,"returning to main menu keeps the music setting")
 game._show_start_upgrades()
 await get_tree().process_frame
 var slider = game.menu.find_child("MusicVolume",true,false)
 check(slider != null,"settings exposes the music volume slider")
 if slider != null:
  slider.value = 28
  check(is_equal_approx(music.user_volume,0.28),"settings slider changes the actual music volume")
  var rect = slider.get_global_rect()
  check(rect.position.x>=0 and rect.end.x<=get_viewport().get_visible_rect().size.x and rect.end.y<=get_viewport().get_visible_rect().size.y,"music control stays inside the screen")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/49-music-settings.png")
 Progression.music_volume = original_volume
 print("MUSIC: %d checks, %d failures" % [checks,failures])
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
