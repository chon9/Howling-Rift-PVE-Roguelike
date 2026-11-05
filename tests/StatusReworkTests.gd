extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL STATUS REWORK: "+message)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false;Progression.fullscreen_enabled=false
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false)
 game.network_config={"blue":["garen","lux","leona"],"red":["ashe","brand","renekton"],"players":[{"peer":1,"name":"Test","bonuses":{},"spells":["flash","heal"]}],"stage":1}
 game._start_game("garen")
 for i in range(6):
  var c=GameState.champions[i];c.is_bot=false;c.stop_actions();c.global_position=Vector2(1080+i*95,270)
  c.skill_ranks=[1,1,1,1];c.buffs.clear();c.hp_max=5000.;c.hp=5000.;c.hp_regen=0.;c.mp_max=1000.;c.mp=1000.;c.shield=0.;c.ad=80.;c.bonus_crit=0.;c.inventory=["","","","","",""]
 var p=GameState.player;var enemy=GameState.champions[3];var fx=enemy.get_node("StatusVisual")
 p.global_position=Vector2(1200,270);enemy.global_position=Vector2(1280,270)
 check(p.try_cast_skill(0,enemy.world_pos()),"Bastion Q arms next attack")
 check(p.buffs.has("decisive") and not enemy.buffs.has("silence"),"casting Q alone does not silence enemies")
 p._perform_auto(enemy);fx.refresh();BrushVision.update_presentation()
 check(fx.visible and fx.silence_remaining==1.5 and fx.primary_status.label=="SILENCED","real empowered attack shows SILENCED 1.5-second indicator")
 check(enemy.visible and enemy.is_targetable and not enemy.dead,"silence keeps enemy model and targetability")
 var mana=enemy.mp;var cd=enemy.skill_cds[0]
 check(not enemy.try_cast_skill(0,p.world_pos()) and enemy.mp==mana and enemy.skill_cds[0]==cd,"silence blocks casting without spending mana/cooldown")
 var before=GameState.projectiles.size();enemy._perform_auto(p)
 check(GameState.projectiles.size()>before,"silenced enemies can still basic attack")
 enemy.stop_actions();enemy.has_move_target=true;enemy.move_target=enemy.world_pos()+Vector2(100,0);var point=enemy.world_pos();enemy.update_frame(.2);fx.refresh()
 check(enemy.world_pos()!=point and is_equal_approx(fx.silence_remaining,1.3),"silence permits movement and counts down from gameplay")
 var slot=game.hud.get_node("HudRoot").skill_slots[0];slot.set_state(enemy)
 check(not slot.ready_to_cast and slot.disable_reason=="SILENCED","silence dims learned skill slot with explicit reason")
 enemy.update_frame(1.31);fx.refresh()
 check(not enemy.buffs.has("silence") and fx.silence_remaining==0.,"silence expires without lingering icon")
 enemy.skill_cds[0]=0.;check(enemy.try_cast_skill(0,p.world_pos()),"casting returns after silence")
 enemy.buffs.clear();p.buffs.decisive={"time":4.5,"used":false,"bonus":40.};enemy.buffs.cc_guard={"time":2.};p._perform_auto(enemy)
 check(not enemy.buffs.has("silence"),"CC immunity prevents Bastion silence")
 enemy.buffs.clear();p.buffs.decisive={"time":4.5,"used":false,"bonus":40.};enemy.buffs.parry={"time":2.};p._perform_auto(enemy)
 check(not enemy.buffs.has("silence"),"parry prevents Bastion silence")
 enemy.buffs.clear();enemy.inventory=["mercury_treads","","","","",""];enemy.buffs.silence={"time":1.5};enemy.update_frame(1.125);fx.refresh()
 check(not enemy.buffs.has("silence"),"tenacity shortens silence and its visual equally")
 enemy.inventory=["","","","","",""]
 for id in StatusArt.TYPES:
  var tex=StatusArt.texture(id);check(tex!=null and tex.get_image().detect_alpha()!=Image.ALPHA_NONE,"transparent generated atlas "+id)
  for frame in range(4):
   var region=StatusArt.frame_rect(id,frame/8.)
   check(Rect2(Vector2.ZERO,tex.get_size()).encloses(region) and region.has_area(),"frame inside own atlas "+id+str(frame))
  check(StatusArt.frame_rect(id,0.)!=StatusArt.frame_rect(id,.125),"animated status frames "+id)
 enemy.stun=1.;enemy.buffs={"silence":{"time":1.4},"slow":{"time":2.,"pct":.4},"ignite":{"time":3.,"src":p,"tick":0.,"total":100.},"grievous":{"time":3.},"armor_shred":{"time":4.,"stacks":2},"hemorrhage_0":{"time":4.,"stacks":5,"tick":0.,"src":p}}
 fx.refresh()
 check(fx.primary_status.id=="stun" and fx.overhead_statuses().any(func(s):return s.id=="silence"),"simultaneous stun does not hide silence")
 var packet=LanSnapshot.encode();var restored=LanSnapshot.restore_buffs(packet.champs[3].buffs)
 check(restored.silence.time==1.4 and restored.ignite.src==p and restored.armor_shred.stacks==2,"co-op packet preserves timings, sources and stack counts")
 enemy.brush_revealed_until=0.;enemy.global_position=BrushVision.PATCHES[5].get_center();p.global_position=Vector2(950,270)
 BrushVision.update_presentation();check(not enemy.visible and not fx.is_visible_in_tree(),"status sprites do not reveal an enemy hidden in a bush")
 BrushVision.reveal(enemy);BrushVision.update_presentation();check(enemy.visible and fx.is_visible_in_tree(),"revealed enemy displays authoritative statuses")
 p.buffs={"haste":{"time":2.,"mult":1.3},"decisive":{"time":4.5,"bonus":30.,"used":false},"courage":{"time":3.,"dr":.3}};p.shield=200.
 var tray=game.hud.get_node("HudRoot").status_tray;tray.unit=p;tray.refresh()
 check(tray.shown.size()==4 and tray.slots[0].panel.tooltip_text!="","HUD names buffs and explains their actual values on hover")
 var node_count=tray.get_child_count()
 for i in range(50):p.buffs.silence={"time":1.};tray.refresh();p.buffs.erase("silence");tray.refresh()
 check(tray.get_child_count()==node_count,"status churn creates no extra controls")
 p.get_node("StatusVisual").refresh();p.hp-=300.;p.get_node("StatusVisual").refresh();p.hp+=100.;p.get_node("StatusVisual").refresh()
 check(p.get_node("StatusVisual").heal_remaining>0.,"real health recovery produces brief healing cue")
 var phase=fx.phase;GameState.paused=true;fx._process(.5);check(fx.phase==phase,"status sprite animation freezes during pause");GameState.paused=false
 # Native overview: effects stay below health bars, labels stay above them.
 for i in range(6):GameState.champions[i].global_position=Vector2(1050+(i%3)*175,220+(i/3)*110)
 GameState.champions[1].buffs={"spell_ward":{"time":3.},"ghost":{"time":6.}}
 GameState.champions[2].buffs={"roster_attack":{"time":3.,"hits":3,"damage":30.,"stun":1.}};GameState.champions[2].shield=150.
 enemy.stun=0.;enemy.buffs.erase("hemorrhage_0");enemy.buffs.erase("armor_shred");enemy.buffs.erase("grievous")
 GameState.champions[4].stun=2.;GameState.champions[4].buffs={"ignite":{"time":3.,"src":p,"total":100.,"tick":0.}}
 GameState.champions[5].buffs={"airborne":{"time":2.,"duration":2.},"hemorrhage_0":{"time":3.,"stacks":5,"src":p,"tick":0.},"grievous":{"time":3.},"armor_shred":{"time":3.,"stacks":4}};GameState.champions[5].stun=2.
 for c in GameState.champions:c.get_node("StatusVisual").refresh();c._sync_bars()
 for structure in GameState.structures:structure.hide()
 game.camera.global_position=Vector2(1225,270);game.hud.get_node("HudRoot").refresh(0);tray.refresh();BrushVision.update_presentation()
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://tests/status-v060.png")
 enemy.dead=true;fx.refresh();check(not fx.visible and fx.statuses.is_empty(),"death removes every status sprite")
 game._return_to_main_menu();check(GameState.champions.is_empty(),"new match has no old status-bearing units")
 print("STATUS REWORK: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
