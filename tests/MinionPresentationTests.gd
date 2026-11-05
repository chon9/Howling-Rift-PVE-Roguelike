extends Node
var game
var failures = 0
var checks = 0
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func effects(path: String) -> int:
 return game.world_root.get_children().filter(func(node): return node.get_script() != null and node.get_script().resource_path == path).size()
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("ahri")
 var p = GameState.player
 p.global_position = Vector2(1300,400)
 game.camera.global_position = p.world_pos()
 for c in GameState.champions:
  c.is_bot = false
  c.stop_actions()
  if c != p: c.visible = false
 var types = ["melee","caster","siege","super","tibbers"]
 var units = []
 for team in [Constants.BLUE,Constants.RED]:
  for i in range(types.size()):
   var m = game.MinionS.new()
   game.world_root.add_child(m)
   m.setup(team,types[i],Vector2(1100+i*115,210+team*115))
   GameState.minions.append(m)
   units.append(m)
   check(m.unit_texture.resource_path.ends_with(types[i]+"-actions-v1.png"),"painted sprite for "+types[i])
   check(m.material.get_shader_parameter("red_team") == (team == Constants.RED),"correct team cloth for "+types[i])
   m.animator.moving = true
   m.animator.phase = 0
   var first = m.animation_frame()
   m.animator.phase = 0.25
   check(m.animation_frame() != first,"walk animation advances for "+types[i])
   m.stun = 1
   check(m.animator.pose().action == "hit","stun stops walk frames for "+types[i])
   m.stun = 0
 check(units[0].unit_texture.get_image().detect_alpha() != Image.ALPHA_NONE,"sprite sheet preserves alpha")
 var target = units[5]
 var spark_count = effects("res://scripts/MinionHit.gd")
 var text_count = effects("res://scripts/FloatingText.gd")
 game.deal_damage(units[0],target,12,"auto")
 check(effects("res://scripts/MinionHit.gd") == spark_count and effects("res://scripts/FloatingText.gd") == text_count,"minion trading creates no impact burst or floating damage spam")
 check(target.flash_t == 0,"automated minion trading does not flash the sprite")
 var hp = target.hp
 game.deal_damage(p,target,30,"skill")
 check(target.hp<hp and effects("res://scripts/MinionHit.gd") == spark_count+1,"champion skill contact deals damage and shows one small spark")
 check(effects("res://scripts/SpellBurst.gd") == 0,"minion hits do not receive hero-sized spell bursts")
 check(effects("res://scripts/FloatingText.gd") == text_count+1,"human farming damage number remains visible")
 check(target.flash_t>0 and target.flash_t<1,"champion hit flash is restrained")
 game.deal_damage(p,target,5,"skill")
 check(effects("res://scripts/MinionHit.gd") == spark_count+1 and effects("res://scripts/FloatingText.gd") == text_count+1,"rapid repeat hits throttle visual feedback")
 game.sound_fx.last_played.clear()
 var impacts = game.sound_fx.counts.get("impact",0)
 game.sound_fx.play("minion_impact",target)
 game.sound_fx.play("minion_impact",units[6])
 check(game.sound_fx.counts.get("impact",0) == impacts,"minion hit audio is silent for host and guests")
 GameState.time = 1
 var projectile_count = effects("res://scripts/MinionHit.gd")
 game.spawn_projectile(p,target.world_pos()-Vector2(1,0),Vector2.RIGHT,{"dmg":10,"speed":10,"size":4,"life":1,"damage_type":"skill"})
 GameState.projectiles.back().update_frame(0.001)
 check(effects("res://scripts/MinionHit.gd") == projectile_count+1,"projectile contact creates a single restrained hit effect")
 check(effects("res://scripts/SpellBurst.gd") == 0,"projectile hits retain quiet minion presentation")
 var packet = LanSnapshot.encode()
 check(packet.minions[0].has("facing_sign") and packet.minions[0].has("attack_anim"),"LAN retains facing and attack animation")
 var click = GameState.target_click_rect(target)
 check(click.has_point(target.world_pos()+target.art_rect().get_center()),"click targeting follows painted sprite bounds")
 game._update_camera(1)
 game.hud.get_node("HudRoot").refresh(0)
 await get_tree().process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/47-painted-minion-roster.png")
 var gold = p.gold
 var cs = p.cs
 target.hp = 1
 game.deal_damage(p,target,10,"auto")
 check(target.dead and p.cs == cs+1 and p.gold == gold+target.gold_val,"last hits still award CS and gold")
 print("MINION PRESENTATION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
