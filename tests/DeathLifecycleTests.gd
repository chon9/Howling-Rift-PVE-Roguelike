extends Node
var game
var checks=0
var failures=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL DEATH: "+message)
func _ready() -> void:
 game=get_node("Main")
 game.set_process(false)
 await get_tree().process_frame
 Progression.persistent=false;Progression.levels.clear();Progression.difficulty=1
 check(get_tree().root.has_node("ItemHover"),"real main scene startup creates exactly one hover manager safely")
 var first=true
 for hero in ChampionData.CHAMPIONS:
  if not first:
   remove_child(game);game.queue_free();await get_tree().process_frame
   GameState.reset();game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
  first=false
  game._start_game(hero);game.set_process(false)
  for c in GameState.champions:c.is_bot=false;c.stop_actions()
  var p=GameState.player;var enemy=GameState.champions[3]
  p.global_position=Vector2(1300,270);enemy.global_position=Vector2(1450,270)
  var material=p.material
  p.skill_cds=[5.,5.,5.,5.];p.summoner_cds=[10.,10.]
  game.deal_damage(enemy,p,p.hp+p.shield+10000,"exec")
  check(p.dead and p.hp==0 and p.deaths==1 and not p.visible,"lethal damage enters death state: "+hero)
  var corpses=game.world_root.get_children().filter(func(n):return n is AnimatedCorpse)
  check(not corpses.is_empty() and corpses.back().material!=material,"corpse uses separate material: "+hero)
  game.hud.get_node("HudRoot").refresh(.1);BrushVision.update_presentation()
  p.inventory[0]="long_sword"
  var ui=game.hud.get_node("HudRoot");ui.refresh(0)
  await get_tree().process_frame
  ui.inv_slots[0].panel.mouse_entered.emit()
  check(is_instance_valid(get_tree().root.get_node("ItemHover").panel),"item hover remains usable while dead: "+hero)
  ui.inv_slots[0].panel.mouse_exited.emit()
  # Render every death-animation frame, while exercising the actual update loop.
  for frame in range(6):
   for corpse in corpses:corpse.elapsed=frame*.13;corpse.queue_redraw()
   game._process(.02)
   await get_tree().process_frame
  check(p.skill_cds[0]<5 and p.summoner_cds[0]<10,"death continues cooldowns: "+hero)
  GameState.time=p.respawn_at+.1;game._process(.02)
  check(not p.dead and p.hp==p.hp_max and p.is_targetable,"actual update loop respawns hero: "+hero)
  game.deal_damage(p,enemy,enemy.hp+enemy.shield+10000,"exec")
  check(enemy.dead and enemy.deaths==1,"enemy death updates without interrupting match: "+hero)
  game.hud.get_node("HudRoot").refresh(.1)
  for subkind in ["melee","caster","siege","super","tibbers"]:
   var m=game.MinionS.new();game.world_root.add_child(m);m.setup(1,subkind,Vector2(1400,270));GameState.minions.append(m)
   game.deal_damage(p,m,m.hp+10000,"exec")
   check(m.dead and m.corpse_spawned,"minion death renders safely: "+subkind+" with "+hero)
  game._process(.02)
  await get_tree().process_frame
  await get_tree().process_frame
 print("DEATH LIFECYCLE: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
