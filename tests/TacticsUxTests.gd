extends Node
var checks=0
var failures=0
var game
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("FAIL TACTICS UX: "+message)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset();Progression.persistent=false;Progression.difficulty=1;Progression.levels.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("thresh")
 var p=GameState.player;var enemy=GameState.champions[3]
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_B if c.team==0 else Constants.FOUNT_R
 var ui=game.hud.get_node("HudRoot");p.inventory[0]="long_sword";p._apply_items();ui.refresh(0)
 check(ui.inv_slots[0].panel.tooltip_text.contains("attack damage") and ui.inv_slots[0].panel.tooltip_text.contains("Upgrades into"),"owned item hover describes stats and upgrade paths")
 var tooltip=ui.inv_slots[0].panel._make_custom_tooltip(ui.inv_slots[0].panel.tooltip_text)
 check(tooltip is PanelContainer and tooltip.get_child(0).get_theme_font_size("font_size")==22,"item tooltip uses large readable styled panel")
 tooltip.free()
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 ui.inv_slots[0].panel.gui_input.emit(click)
 check(ui.shop_open and ui.shop_panel.category=="upgrades" and ui.shop_panel.selected=="long_sword","inventory left click opens its upgrade tree")
 check(ItemData.upgrades_for("long_sword").has("infinity_edge") and ItemData.upgrades_for("long_sword").has("maw"),"tree includes direct and later recipe upgrades")
 check(ui.shop_panel.grid.get_child_count()==ItemData.upgrades_for("long_sword").size(),"catalog shows precisely the selected component descendants")
 var gold=p.gold;check(not p.inventory.has("maw") and p.gold==gold,"browsing does not buy or sell items")
 ui.shop_panel.view_upgrades("rabadon");check(ui.shop_panel.grid.get_child(0) is Label and ui.shop_panel.upgrades_button.disabled,"finished item has clear no-upgrades state")
 ui.close_shop()
 var draft=game.lane_augments;draft.rng.seed=12345
 check(draft.AUGMENTS.size()==33,"thirty-three level-up templates cover varied playstyles")
 for hero in ["malphite","lux","darius","ashe"]:
  p.hero_key=hero
  var choices=draft.roll_choices(p)
  check(choices.size()==3 and choices[0]!=choices[1] and choices[0]!=choices[2] and choices[1]!=choices[2],"three distinct offers: "+hero)
  check(draft.AUGMENTS[choices[0]].get("role","")==draft.role_for(p),"at least one role-compatible option: "+hero)
 p.hero_key="thresh"
 var offer1=draft.roll_offer(9,4);var offer2=draft.roll_offer(9,4)
 check(offer1.stats!=offer2.stats,"same template has varied random stat magnitudes")
 draft.pending=[4];draft.choices.clear();draft.build_panel();var offers=draft.offers.duplicate(true);var choices=draft.choices.duplicate();draft.build_panel()
 check(draft.offers==offers and draft.choices==choices,"reopening preserves exact rolled stats and choices")
 var picked=choices[0];var previous=p.run_bonus.duplicate();draft.choose(picked)
 for stat in offers[picked].stats:check(is_equal_approx(p.run_bonus[stat],previous.get(stat,0.)+offers[picked].stats[stat]),"chosen preview matches actual granted stat: "+stat)
 GameState.time=10
 var patch=BrushVision.PATCHES[1];enemy.global_position=patch.get_center();enemy.brush_revealed_until=-1
 p.global_position=Vector2(1050,270)
 check(not BrushVision.visible_to(enemy,p.team),"enemy is hidden inside unoccupied bush")
 check(GameState.find_target_at(enemy.world_pos(),p.team)==null and NewHeroKits.target(p,enemy.world_pos(),600)==null,"hidden enemy cannot be clicked or selected by targeted skills")
 BrushVision.update_presentation();check(not enemy.visible,"hidden enemy sprite disappears for opposing viewer")
 p.global_position=patch.get_center()-Vector2(100,0)
 check(BrushVision.visible_to(enemy,p.team),"entering same bush reveals its occupant")
 p.global_position=Vector2(1050,270);BrushVision.reveal(enemy)
 check(BrushVision.visible_to(enemy,p.team),"attacking reveals hidden hero for two seconds")
 GameState.time+=2.1;check(not BrushVision.visible_to(enemy,p.team),"reveal expires when enemy remains concealed")
 p.global_position=enemy.world_pos()-Vector2(230,0)
 var projectile=game.ProjectileS.new();game.world_root.add_child(projectile);projectile.setup(p,enemy.world_pos()-Vector2(10,0),Vector2.RIGHT,{"dmg":20,"size":10,"speed":100,"life":1,"damage_type":"magic"});GameState.projectiles.append(projectile)
 var hp=enemy.hp;projectile.update_frame(.01)
 check(enemy.hp<hp and BrushVision.visible_to(enemy,p.team),"skillshots can hit and reveal concealed enemies")
 enemy.global_position=Vector2(1450,270);p.global_position=Vector2(1000,270);enemy.brush_revealed_until=-1
 p.skill_cds=[0.,0.,0.,0.];p.mp=1000
 check(p.try_cast_skill(0,enemy.world_pos()),"Thresh can launch actual hook")
 var hook=GameState.projectiles.back()
 check(hook.hook_chain and not hook.targeted and hook.visual_dimensions.x>=30,"hook has visible chain and full sized head")
 var sheet=SpellArt.missile_sheet(true);var crop=SpellArt.missile_frame(sheet,5,0);var next=SpellArt.missile_frame(sheet,5,1)
 check(crop.size==next.size and crop.position-SpellArt.frame(sheet,5,0).position==next.position-SpellArt.frame(sheet,5,1).position,"projectile crop remains stable across animation frames")
 check(crop.size.x<=sheet.get_width()/8. and crop.size.y<=sheet.get_height()/6.,"mapped projectile crop stays within atlas cell")
 var packet=LanSnapshot.encode();check(packet.projectiles.back().hook_chain and packet.champs[3].has("brush_revealed_until"),"hook and concealment reveal state replicate")
 for shot in GameState.projectiles.duplicate():shot._destroy()
 enemy.is_bot=true;enemy.stop_actions();enemy.difficulty_stats=Progression.scaling(1);enemy.dodge_noticed.clear();enemy.dodge_until=-1
 var shot=game.ProjectileS.new();game.world_root.add_child(shot);shot.setup(p,enemy.world_pos()-Vector2(500,0),Vector2.RIGHT,{"dmg":100,"size":12,"speed":500,"life":2,"damage_type":"magic"});GameState.projectiles.append(shot)
 check(not BotDodge.update(enemy,.1) and not BotDodge.update(enemy,.1),"N1 bot waits through its reaction time")
 check(BotDodge.update(enemy,.11) and absf(enemy.move_target.y-enemy.world_pos().y)>20,"bot sidesteps predictable distant skillshot after reaction")
 enemy.dodge_until=-1;enemy.dodge_noticed.clear();shot.global_position=enemy.world_pos()-Vector2(10,0)
 check(not BotDodge.update(enemy,.4),"point-blank shot cannot be dodged when escape is too late")
 shot.global_position=enemy.world_pos()-Vector2(500,0);shot.homing=enemy;shot.targeted=true
 check(not BotDodge.update(enemy,.4),"homing attacks do not cause pointless sidesteps")
 shot.targeted=false;shot.homing=null;enemy.dodge_noticed.clear();enemy.difficulty_stats=Progression.scaling(99)
 check(BotDodge.update(enemy,.1),"higher N reacts faster to the same visible skillshot")
 shot._destroy();enemy.is_bot=false;enemy.stop_actions();p.global_position=Vector2(1150,270);enemy.global_position=Vector2(1450,270)
 var ambush=BrushVision.ambush_point(enemy)
 check(ambush!=null and BrushVision.patch_at(ambush)>=0,"bot chooses a safe nearby ambush patch")
 game._update_camera(1);game.set_fullscreen(false)
 ui.shop_panel.player=p;ui.shop_panel.view_upgrades("long_sword");ui.shop_open=true;ui.shop_panel.show()
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/tactics-item-upgrades-v027.png")
 if DisplayServer.get_name()!="headless":
  ui.close_shop();ui.refresh(0)
  var motion=InputEventMouseMotion.new();motion.position=ui.inv_slots[0].panel.get_global_rect().get_center();Input.parse_input_event(motion)
  ui.inv_slots[0].panel.mouse_entered.emit()
  await get_tree().create_timer(.2).timeout
  var hover=get_tree().root.get_node("ItemHover")
  check(is_instance_valid(hover.panel) and hover.panel.visible,"hover renders inside the viewport at fullscreen UI scale")
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/tactics-item-hover-v027.png")
  ui.inv_slots[0].panel.mouse_exited.emit()
  Input.warp_mouse(Vector2(100,100))
  p.skill_cds[0]=0;p.mp=500;p.try_cast_skill(0,enemy.world_pos())
  var visible_hook=GameState.projectiles.back();visible_hook.update_frame(.25)
  BrushVision.update_presentation()
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/tactics-brush-hook-v027.png")
 print("TACTICS UX: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
