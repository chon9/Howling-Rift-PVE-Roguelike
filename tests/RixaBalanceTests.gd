extends Node
var checks = 0
var failures = 0
var game
var p
var enemy
var neighbor
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func clear_attacks() -> void:
 for node in GameState.projectiles+GameState.aoes: node.queue_free()
 GameState.projectiles.clear(); GameState.aoes.clear()
 for c in [enemy,neighbor]:
  c.hp_max = 10000; c.hp = 10000; c.bonus_armor = 0; c.shield = 0; c.buffs.clear(); c.dead = false; c.stun = 0
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("jinx")
 p = GameState.player
 enemy = GameState.champions[3]
 neighbor = GameState.champions[4]
 for c in GameState.champions:
  c.is_bot = false; c.stop_actions(); c.global_position = Vector2(100,100)
 p.global_position = Vector2(1200,270)
 enemy.global_position = Vector2(1350,270)
 neighbor.global_position = enemy.world_pos()+Vector2(40,0)
 p.buffs.rockets = {"time":6.0}
 for scale in [1.0,2.0,4.0,Progression.scaling(99).damage]:
  clear_attacks()
  p.difficulty_stats.damage = scale
  game.deal_damage(p,enemy,100,"auto")
  var primary = 10000-enemy.hp
  var splash = 10000-neighbor.hp
  print("ROCKET AUDIT: scale %.1f, direct %.0f, splash %.0f, expected %.0f" % [scale,primary,splash,floor(100*0.35*scale)])
  check(splash == floor(100*0.35*scale),"rocket splash applies difficulty once at ×%.1f" % scale)
 p.difficulty_stats.damage = 1.0
 clear_attacks()
 enemy.shield = 1000
 game.deal_damage(p,enemy,100,"auto")
 check(enemy.hp == 10000 and neighbor.hp == 9965,"primary shield does not erase the nearby rocket explosion")
 clear_attacks()
 neighbor.bonus_armor = 100
 game.deal_damage(p,enemy,100,"auto")
 check(neighbor.hp == 9983,"secondary armor applies once to its own splash damage")
 clear_attacks()
 enemy.bonus_armor = 100
 game.deal_damage(p,enemy,100,"auto")
 check(enemy.hp == 9950 and neighbor.hp == 9965,"primary armor does not reduce splash against an unarmored neighbor")
 clear_attacks()
 p.buffs.clear()
 p.skill_ranks = [1,1,2,1]
 # Two overlapping trap circles currently hit a standing champion twice.
 enemy.global_position = Vector2(1350,270)
 neighbor.global_position = Vector2(1600,270)
 p._dispatch_cast("jinx_e",enemy.world_pos()-Vector2(25,0))
 for area in GameState.aoes.duplicate(): area.update_frame(0.7)
 var trap_damage = 10000-enemy.hp
 print("TRAP AUDIT: %.0f damage, expected 85" % trap_damage)
 check(trap_damage == 85,"one trap cast can damage the same champion only once")
 # Standing in the same cast does not repeat damage or refresh its stun.
 enemy.stun = 0.4
 for area in GameState.aoes.duplicate(): area.update_frame(0.1)
 check(enemy.hp == 10000-trap_damage and is_equal_approx(enemy.stun,0.4),"standing inside sibling traps cannot repeat damage or stun")
 p._dispatch_cast("jinx_e",enemy.world_pos())
 for area in GameState.aoes.duplicate(): area.update_frame(0.1)
 check(enemy.hp == 10000-trap_damage-85,"a new trap cast has its own hit history")
 clear_attacks()
 enemy.global_position = Vector2(1350,270)
 neighbor.global_position = enemy.world_pos()+Vector2(60,0)
 p._dispatch_cast("jinx_r",enemy.world_pos())
 var rocket = GameState.projectiles.back()
 var raw = rocket.dmg
 rocket.global_position = enemy.world_pos()-Vector2(1,0)
 rocket.update_frame(0.001)
 for area in GameState.aoes.duplicate(): area.update_frame(0.01)
 var rocket_damage = 10000-enemy.hp
 print("ULT AUDIT: %.0f direct damage, expected %.0f" % [rocket_damage,floor(raw)])
 check(rocket_damage == floor(raw),"ultimate primary target does not take the explosion damage a second time")
 check(10000-neighbor.hp == floor(raw*0.65),"ultimate still splashes neighboring champions")
 clear_attacks()
 p.bonus_ap = 20
 p._dispatch_cast("jinx_r",enemy.world_pos())
 rocket = GameState.projectiles.back()
 raw = rocket.dmg
 rocket.global_position = enemy.world_pos()-Vector2(1,0)
 rocket.update_frame(0.001)
 for area in GameState.aoes.duplicate(): area.update_frame(0.01)
 check(10000-enemy.hp == floor(raw+20) and 10000-neighbor.hp == floor(raw*0.65+20),"AP is added once per ultimate victim and remains item-scaled")
 check(ChampionData.skill_description("jinx",2,p).contains("once per trap cast"),"trap tooltip explains the shared hit limit")
 check(ChampionData.skill_description("jinx",3,p).contains("direct target is excluded"),"ultimate tooltip matches single-hit behavior")
 print("RIXA BALANCE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
