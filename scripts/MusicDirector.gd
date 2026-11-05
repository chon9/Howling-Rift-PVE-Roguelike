extends Node
# Local soundtrack: crossfaded loops, independent volume and announcer ducking.
const TRACKS = {"menu":"res://assets/audio/music/oath-of-the-rift.ogg","battle":"res://assets/audio/music/battle-theme-v1.mp3"}
var main
var players: Dictionary = {}
var gains: Dictionary = {"menu":0.0,"battle":0.0}
var mode: String = "menu"
var user_volume: float = 0.28
var ducked: bool = false
var paused_mix: bool = false
func _ready() -> void:
 user_volume = Progression.music_volume
 for key in TRACKS:
  var player = AudioStreamPlayer.new()
  player.name = key.capitalize()+"Music"
  var stream = load(TRACKS[key]).duplicate()
  stream.loop = true
  player.stream = stream
  player.volume_db = -80
  add_child(player)
  players[key] = player
 refresh(0)
func set_volume(value: float) -> void:
 user_volume = clampf(value,0,1)
 Progression.music_volume = user_volume
 Progression.save_profile()
 if user_volume<=0:
  for player in players.values(): player.stop()
func refresh(delta: float) -> void:
 mode = "battle" if GameState.started and GameState.running else "menu"
 ducked = is_instance_valid(main) and is_instance_valid(main.sound_fx) and main.sound_fx.announcer_voice.playing
 paused_mix = GameState.started and GameState.paused
 for key in players:
  var player = players[key]
  var desired = 1.0 if key == mode and user_volume>0 else 0.0
  gains[key] = move_toward(gains[key],desired,delta/2.4)
  if user_volume<=0:
   player.stop()
   player.volume_db = -80
   continue
  if desired>0 and not player.playing and DisplayServer.get_name() != "headless": player.play()
  var base_mix = -11.0 if key == "menu" else -14.0
  var attenuation = (6.0 if ducked else 0.0)+(5.0 if paused_mix else 0.0)
  var target_db = base_mix+linear_to_db(maxf(0.0001,user_volume*gains[key]))-attenuation
  player.volume_db = lerpf(player.volume_db,target_db,1-exp(-delta*6)) if gains[key]>0.001 else -80
  if desired==0 and gains[key]<=0.001: player.stop()
func _process(delta: float) -> void:
 refresh(delta)
func _exit_tree() -> void:
 for player in players.values():
  player.stop()
  player.stream = null
