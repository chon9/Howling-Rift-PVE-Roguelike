extends Node
var failures = 0
var checks = 0
var game
func check(value: bool,text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func reset(hero: String):
 if is_instance_valid(game):
  remove_child(game); game.queue_free()
 GameState.reset()
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game(hero)
 var p = GameState.player
 for c in GameState.champions:
  c.is_bot = false
  c.global_position = Constants.FOUNT_B if c.team == 0 else Constants.FOUNT_R
 p.global_position = Vector2(1300,270)
 var enemy = GameState.champions[3]
 enemy.global_position = Vector2(1420,270)
 enemy.hp = 10000; enemy.hp_max = 10000
 return p
func missiles() -> void:
 for frame in range(20):
  for p in GameState.projectiles.duplicate():
   if is_instance_valid(p): p.update_frame(0.02)
func _ready() -> void:
 await get_tree().process_frame
 var p = reset("yasuo")
 var enemy = GameState.champions[3]
 for thrust in range(3):
  p.skill_cds[0] = 0
  check(p.try_cast_skill(0,enemy.world_pos()),"wind thrust cast "+str(thrust))
  missiles()
 check(enemy.stun > 0 and p.buffs.tempest.stacks == 0,"third wind thrust lifts target and resets stacks")
 p.skill_ranks[3] = 1
 check(p.try_cast_skill(3,enemy.world_pos()),"Skybreaker follows a stunned target")
 p.global_position = Vector2(1300,270)
 p.try_cast_skill(1,Vector2(1400,270))
 enemy.global_position = Vector2(1430,270)
 game.spawn_projectile(enemy,Vector2(1400,270),Vector2.LEFT,{"dmg":100,"speed":500,"life":1,"size":5,"damage_type":"auto"})
 var before = p.hp
 missiles()
 check(p.hp == before and GameState.projectiles.is_empty(),"wind wall blocks hostile missile")
 p = reset("leesin")
 enemy = GameState.champions[3]
 p.try_cast_skill(0,enemy.world_pos())
 missiles()
 check(p.sonic_target == enemy and enemy.buffs.has("sonic_mark"),"sonic projectile marks first enemy")
 var mp = p.mp
 check(p.try_cast_skill(0,enemy.world_pos()) and p.is_dashing and p.sonic_target == null and p.mp == mp,"Q recast dashes without restarting cooldown or charging mana twice")
 p = reset("leesin")
 var ally_minion = game.MinionS.new()
 game.world_root.add_child(ally_minion)
 ally_minion.setup(p.team,"melee",p.world_pos()+Vector2(220,0))
 GameState.minions.append(ally_minion)
 check(p.try_cast_skill(1,ally_minion.world_pos()) and p.is_dashing and p.dash_target == ally_minion.world_pos(),"Safeguard targets an allied minion")
 check(p.shield > 0 and p.buffs.has("iron_will"),"minion Safeguard shields the caster and grants lifesteal")
 for frame in range(30): p.update_frame(0.02)
 check(p.world_pos().distance_to(ally_minion.world_pos()) < UnitCollision.contact_distance(p,ally_minion)+2,"Safeguard reaches the allied minion")
 var ally_hero = GameState.champions[1]
 ally_hero.global_position = p.world_pos()+Vector2(180,0)
 p.skill_cds[1] = 0
 check(p.try_cast_skill(1,ally_hero.world_pos()) and p.dash_target == ally_hero.world_pos() and ally_hero.shield > 0,"Safeguard still dashes to and shields allied heroes")
 p.stop_actions()
 ally_minion.global_position = p.world_pos()+Vector2(220,0)
 for invalid_target in ["enemy","dead","untargetable","out_of_range"]:
  ally_minion.team = 1-p.team if invalid_target == "enemy" else p.team
  ally_minion.dead = invalid_target == "dead"
  ally_minion.is_targetable = invalid_target != "untargetable"
  ally_minion.global_position = p.world_pos()+Vector2(450 if invalid_target == "out_of_range" else 220,0)
  ally_hero.global_position = Constants.FOUNT_B
  p.skill_cds[1] = 0
  p.mp = p.mp_max
  p.is_dashing = false
  check(p.try_cast_skill(1,ally_minion.world_pos()) and not p.is_dashing,"Safeguard excludes "+invalid_target+" minions and falls back to self protection")
 p = reset("zed")
 enemy = GameState.champions[3]
 var origin = p.world_pos()
 p.try_cast_skill(1,origin+Vector2(200,0))
 check(p.world_pos() == origin and p.buffs.shadow.point == origin+Vector2(200,0),"shadow placement does not move hero")
 check(p.try_cast_skill(1,origin+Vector2(200,0)) and p.world_pos() == origin+Vector2(200,0),"W recast swaps places with shadow")
 p.skill_ranks[3] = 1
 p.try_cast_skill(3,enemy.world_pos())
 game.deal_damage(p,enemy,100,"auto")
 var hp = enemy.hp
 enemy.update_frame(3.01)
 check(enemy.hp < hp-100 and not enemy.buffs.has("death_mark"),"death mark detonates stored damage")
 p = reset("jinx")
 enemy = GameState.champions[3]
 var creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",enemy.world_pos()+Vector2(20,0))
 GameState.minions.append(creep)
 p.try_cast_skill(0,p.world_pos())
 check(p.effective_attack_range() == p.atk_range+100,"rocket stance increases effective attack range")
 var creep_hp = creep.hp
 game.deal_damage(p,enemy,100,"auto")
 check(creep.hp < creep_hp,"rocket autos splash neighboring targets")
 p.try_cast_skill(2,enemy.world_pos())
 for a in GameState.aoes.duplicate(): a.update_frame(0.02)
 check(enemy.stun > 0,"chompers stun enemies entering their area")
 p = reset("kayle")
 enemy = GameState.champions[3]
 p.skill_ranks[3] = 1
 p.try_cast_skill(3,p.world_pos())
 var protected_hp = p.hp
 game.deal_damage(enemy,p,500,"auto")
 check(p.hp == protected_hp,"Divine Intervention prevents incoming damage")
 var target_hp = enemy.hp
 p.update_frame(2.01)
 for a in GameState.aoes.duplicate(): a.update_frame(0.02)
 check(enemy.hp < target_hp and not p.buffs.has("divine"),"protection ends with an offensive sword burst")
 print("HERO MECHANICS: %d checks, %d failures" % [checks,failures])
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
