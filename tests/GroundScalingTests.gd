extends Node
const Scaling = preload("res://scripts/SkillScaling.gd")
const Grounding = preload("res://scripts/SpriteGrounding.gd")
var checks = 0
var failures = 0
var game
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._start_game("ezreal")
 var p = GameState.player
 for c in GameState.champions:
  c.is_bot = false
  c.stop_actions()
 var target = GameState.champions[3]
 target.bonus_armor = 0
 target.base_mr = 0
 target.bonus_mr = 0
 target.shield = 0
 target.hp_max = 10000
 target.hp = 10000
 var before = Scaling.value("ezreal_q",p.rank(0),p.ad,p.bonus_ap)
 p.gold = 5000
 check(p.try_buy_item("long_sword") and p.try_buy_item("amp_tome"),"AD and AP components can be purchased")
 var after = Scaling.value("ezreal_q",p.rank(0),p.ad,p.bonus_ap)
 check(is_equal_approx(after-before,17),"Mystic Shot gains 11 from +10 AD and 6 from +20 AP")
 p._dispatch_cast("ezreal_q",p.world_pos()+Vector2(200,0))
 var shot = GameState.projectiles.back()
 check(is_equal_approx(shot.dmg+p.bonus_ap*Scaling.legacy_ap_ratio(p.hero_key),after),"tooltip formula matches actual cast and bounded combat AP scaling")
 var hp = target.hp
 game.deal_damage(p,target,shot.dmg,"skill")
 check(is_equal_approx(hp-target.hp,floor(after)),"displayed damage matches actual HP loss before armor")
 var ui = game.hud.get_node("HudRoot")
 ui.show_skill_description(0)
 ui.refresh(0)
 check(ui.tooltip_label.text.contains("110% AD") and ui.tooltip_label.text.contains("30% AP"),"hover shows real AD/AP coefficients")
 check(ui.tooltip_label.text.contains("%.1f" % after),"hover reflects equipped items immediately")
 p.try_sell_item(0)
 ui.refresh(0)
 check(ui.tooltip_label.text.contains("%.1f" % Scaling.value("ezreal_q",p.rank(0),p.ad,p.bonus_ap)),"selling an item updates live hover damage")
 for key in ChampionData.CHAMPIONS:
  for i in range(4):
   var desc = ChampionData.skill_description(key,i)
   check(desc.contains("AP") or desc.contains("AD"),"scaling documented for "+key+" "+str(i))
  var data = ActionSpriteArt.frame("hero_"+key,"idle",0)
  var rect = ActionSpriteArt.rect("hero_"+key,"idle",0,Constants.CHAMP_ART_HEIGHT)
  var scale = Constants.CHAMP_ART_HEIGHT/ActionSpriteArt.entry("hero_"+key).body_height
  check((rect.position+Vector2(data.pivot[0],data.pivot[1])*scale).length()<0.001,"hero feet align to world anchor: "+key)

 for structure in GameState.structures:
  var kind = "turret" if structure.type == "nexus_turret" else structure.type
  var foot = Grounding.foot("structure_%d_%s" % [structure.team,kind])
  check((structure.art_rect.position-Vector2(0,ViewMath.STRUCTURE_FOOTPRINT[structure.type].y*structure.art_rect.size.y)+foot*structure.art_rect.size).length()<0.001,"structure base aligns to ground")
 p.global_position = Vector2(1550,270)
 target.global_position = Vector2(1750,270)
 target.hp_max = 10000
 target.hp = 10000
 for i in range(5):
  var minion = game.MinionS.new()
  game.world_root.add_child(minion)
  minion.setup(Constants.BLUE,["melee","caster","siege","super","tibbers"][i],Vector2(1450+i*70,335))
  GameState.minions.append(minion)
  minion.animator.moving = true
  for frame in range(6):
   minion.animator.phase = (frame+0.1)/6.0
   var rect = minion.animator.draw_rect()
   var data = ActionSpriteArt.frame("minion_"+minion.subkind,"run",frame)
   var scale = minion.size*2.7/ActionSpriteArt.entry("minion_"+minion.subkind).body_height
   check((rect.position+Vector2(data.pivot[0],data.pivot[1])*scale).length()<0.001,"every minion walk frame is grounded")

 game.sound_fx.counts.clear()
 game.sound_fx.play("minion_impact")
 check(game.sound_fx.counts.is_empty(),"legacy or LAN minion impact events are silent")
 game._update_camera(1)
 game.hud.get_node("HudRoot").refresh(0)
 await get_tree().process_frame
 ui.show_skill_description(0)
 ui.refresh(0)
 check(ui.tooltip_panel.position.x>=0 and ui.tooltip_panel.position.y>=0,"skill tooltip is positioned inside the screen")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/48-grounded-units-skill-scaling.png")
 print("GROUND / SCALING: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
