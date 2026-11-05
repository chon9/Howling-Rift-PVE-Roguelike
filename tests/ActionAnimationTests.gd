extends Node
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset(); Progression.persistent=false; Progression.levels.clear(); Progression.difficulty=1
 var game=load("res://scripts/Main.gd").new()
 add_child(game); game.set_process(false); game._start_game("garen")
 for c in GameState.champions: c.is_bot=false; c.stop_actions()
 var p=GameState.player
 var enemy=GameState.champions[3]
 p.global_position=Vector2(1650,270); enemy.global_position=p.world_pos()+Vector2(50,0)
 enemy.hp_max=100000; enemy.hp=100000; enemy.hp_regen=0; enemy.bonus_armor=0
 p.atk_cd=0
 game._issue_champion_order(p,{"type":"smart","point":enemy.world_pos()})
 var hp=enemy.hp
 p.update_frame(0.01)
 check(p.animator.pose().action=="attack" and p.animator.pose().frame==0,"melee windup begins at first anticipation frame")
 check(enemy.hp==hp,"windup cannot apply early damage")
 var windup=p.auto_windup
 p.update_frame(windup*.6)
 check(p.animator.pose().frame in [1,2] and enemy.hp==hp,"windup frames progress without early contact")
 p.animator.moving=false
 p.update_frame(p.auto_windup+.001)
 check(p.animator.pose().frame==3 and enemy.hp<hp,"contact frame coincides with actual melee damage")
 hp=enemy.hp
 p.animator.advance(p.anim_duration*.6)
 check(p.animator.pose().frame in [4,5],"followthrough plays after contact")
 p.cancel_auto(); p.atk_cd=0; p.update_frame(.01)
 game._issue_champion_order(p,{"type":"smart","point":p.world_pos()+Vector2(-200,0)})
 check(p.animator.pose().action!="attack" and p.queued_auto_target==null,"movement cancels an unfinished swing")
 p.animator.previous_position=p.world_pos(); p.global_position.x+=25; p.animator.advance(.1)
 check(p.animator.pose().action=="run","actual movement plays the run row")
 var stride=p.animator.pose().frame
 p.global_position.x+=25; p.animator.advance(.1)
 check(p.animator.pose().frame!=stride,"gait follows distance traveled")
 GameState.paused=true
 var phase=p.animator.phase; p.animator.advance(1)
 check(p.animator.phase==phase,"pause freezes animation clocks")
 GameState.paused=false; p.stop_actions(); p.animator.moving=false
 p.recall_time=1
 check(p.animator.pose().action=="recall","recall selects the channeling sheet row")
 p.recall_time=-1; p.stun=1
 check(p.animator.pose().action=="hit","stunned units stop running")
 p.stun=0
 for key in ChampionData.CHAMPIONS:
  var data=ActionSpriteArt.entry("hero_"+key)
  check(data.frames.size()==60 and data.actions.size()==10,"ten six-frame actions for "+key)
  for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
   for frame in range(6):
    var region=ActionSpriteArt.region("hero_"+key,action,frame)
    var texture=ActionSpriteArt.texture_for_frame("hero_"+key,action,frame)
    check(region.position.x>=0 and region.position.y>=0 and region.end.x<=texture.get_width() and region.end.y<=texture.get_height(),"mapped frame within correct source atlas")
  var unit=game.ChampionS.new(); game.world_root.add_child(unit)
  unit.setup(Constants.BLUE,key,false,key)
  GameState.champions.append(unit)
  unit.skill_ranks=[1,1,1,1]
  for index in range(4):
   unit.global_position=Vector2(1650,270); enemy.global_position=Vector2(1720,270)
   unit.buffs.clear(); unit.stun=0; unit.mp=10000; unit.skill_cds=[0.,0.,0.,0.]; unit.is_dashing=false
   enemy.stun=3; enemy.hp=100000; enemy.buffs.clear()
   check(unit.try_cast_skill(index,enemy.world_pos()),"real cast succeeds for "+key+" "+str(index))
   check(unit.anim_action==["q","w","e","r"][index],"real cast chooses correct animation row")
  if key=="leesin":
   unit.skill_cds[0]=0; unit.mp=10000
   unit.try_cast_skill(0,enemy.world_pos())
   check(unit.anim_from==0 and unit.anim_to==2,"sonic projectile uses Q first-cast subclip")
   enemy.buffs.sonic_mark={"src":unit,"time":4.}; unit.sonic_target=enemy
   check(unit.try_cast_skill(0,enemy.world_pos()) and unit.anim_from==3,"Lee Q2 uses flying-kick subclip")
  unit.buffs.clear(); unit.is_dashing=false
 var minions=[]
 for key in ["melee","caster","siege","super","tibbers"]:
  var m=game.MinionS.new();game.world_root.add_child(m);m.setup(Constants.BLUE,key,Vector2(1600,270))
  GameState.minions.append(m);minions.append(m)
  var data=ActionSpriteArt.entry("minion_"+key)
  check(data.frames.size()==30 and data.actions.size()==5,"minion has five six-frame action sequences")
  m.animator.moving=true; m.animator.phase=.2
  check(m.animator.pose().action=="run","minion uses articulated gait")
  m.animator.begin_attack(.15); m.attack_windup=.1; m.animator.moving=false
  check(m.animator.pose().action=="attack" and m.animator.pose().frame<3,"minion attack has anticipation")
  m._attack(enemy)
  check(m.animator.pose().frame==3,"minion release maps to contact frame")
 # Visual shot size cannot change gameplay collision or damage.
 p.dead=false;p.hero_key="garen";p.buffs.spin={"time":3.0};p.animator.start("r",.42)
 check(p.animator.pose().action=="r","casting R during Garen spin temporarily takes priority")
 p.buffs.clear();p.animator.start("idle",0);p.animator.previous_position=p.world_pos()
 p.global_position.x+=5;p.animator.advance(.016)
 check(p.animator.moving,"moving begins a real gait")
 p.animator.advance(.016)
 check(p.animator.moving,"one missing movement tick cannot flash the idle row")
 p.animator.advance(.08)
 check(not p.animator.moving,"standing still settles after the movement hold")
 p.facing=Vector2.LEFT
 check(p.animator.is_flipped(),"left facing selects mirrored art")
 p.facing=Vector2(.03,1).normalized()
 check(p.animator.is_flipped(),"near-vertical movement does not flicker between mirrored views")
 p.facing=Vector2.RIGHT
 check(not p.animator.is_flipped(),"a clear horizontal turn changes the art direction")
 var source=GameState.champions.filter(func(c):return c.hero_key=="ezreal")[0]
 var proj=game.ProjectileS.new();game.world_root.add_child(proj)
 proj.setup(source,source.world_pos(),Vector2.RIGHT,{"size":7,"dmg":77,"damage_type":"auto"})
 GameState.projectiles.append(proj)
 check(proj.size==7 and proj.dmg==77,"visual scaling preserves collision radius and damage")
 check(is_equal_approx(proj.visual_dimensions.x,Constants.CHAMP_ART_HEIGHT*.32) and proj.visual_dimensions.y<16,"auto missile is visible and proportionate to the hero")
 check(is_equal_approx(proj.visual_height,52*Constants.CHAMP_ART_SCALE),"ranged attacks travel at torso height")
 for angle in [0.0,PI/2,PI,-PI/2]:
  proj.rotation=angle
  check(proj.visual_origin().rotated(proj.rotation).is_equal_approx(Vector2(0,-52*Constants.CHAMP_ART_SCALE)),"shot altitude stays screen-up in every aim direction")
 proj.rotation=0
 proj.setup(source,source.world_pos(),Vector2.RIGHT,{"size":40,"is_ult":true,"damage_type":"skill"})
 check(proj.visual_dimensions.x<=Constants.CHAMP_ART_HEIGHT*.85+.001 and proj.size==40,"large ult visuals are bounded without shrinking hitboxes")
 var packet=LanSnapshot.encode()
 check(packet.projectiles[0].has("visual_height") and packet.projectiles[0].has("visual_dimensions") and is_equal_approx(packet.projectiles[0].visual_scale,Constants.CHAMP_ART_SCALE),"LAN sends matching projectile size and altitude")
 check(packet.champs[0].has("anim_action") and packet.champs[0].has("auto_windup"),"LAN sends hero animation state and real windup")
 check(packet.minions[0].has("anim_serial") and packet.minions[0].has("attack_windup"),"LAN sends minion animation state")
 var corpse=AnimatedCorpse.spawn(p)
 corpse._process(.2)
 check(is_instance_valid(corpse) and corpse.elapsed>0,"death sequence advances independently of untargetable body")
 var elapsed=corpse.elapsed;GameState.paused=true;corpse._process(1)
 check(corpse.elapsed==elapsed,"corpse respects pause")
 GameState.paused=false; corpse._process(2)
 check(corpse.is_queued_for_deletion(),"corpse fades and frees itself")
 print("ACTION ANIMATION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
