extends Node
var failures: int = 0
var checks: int = 0
func check(value: bool, description: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + description)
func key(code: int) -> void:
 var event = InputEventKey.new()
 event.keycode = code
 event.pressed = true
 get_viewport().push_input(event,true)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game._show_menu()
 await get_tree().process_frame
 var hero_click = InputEventMouseButton.new()
 hero_click.button_index = MOUSE_BUTTON_LEFT
 hero_click.position = game.hero_cards["lux"].get_global_rect().position+Vector2(130,75)
 hero_click.pressed = true
 get_viewport().push_input(hero_click,true)
 hero_click = hero_click.duplicate()
 hero_click.pressed = false
 get_viewport().push_input(hero_click,true)
 check(game.selected_hero == "lux" and game.launch_button.text.contains("Solara"), "portrait clicks select a hero and show chosen hero")
 game.summoner_selectors[0].select(2)
 game.summoner_selectors[0].item_selected.emit(2)
 game.summoner_selectors[1].select(3)
 game.summoner_selectors[1].item_selected.emit(3)
 check(game.selected_summoners == ["heal","ghost"], "selecting Heal and Ghost stores loadout")
 game.summoner_selectors[0].select(3)
 game.summoner_selectors[0].item_selected.emit(3)
 check(game.selected_summoners == ["ghost","heal"], "duplicate spell selection swaps slots")
 game.summoner_selectors[0].select(2)
 game.summoner_selectors[0].item_selected.emit(2)
 game._start_game("garen")
 var p = GameState.player
 var ui = game.hud.get_node("HudRoot")
 var draft = game.lane_augments
 check(GameState.champions.size() == 6, "ARAM is the only match")
 check(draft.pending.is_empty(), "starting level gives no free build")
 draft.refresh_milestones()
 game._process(0.1)
 check(draft.pending.is_empty(), "time and refresh cannot grant builds")
 p.grant_xp(Constants.xp_to_level(3))
 check(p.level == 4 and draft.pending == [4], "real level up unlocks build choice")
 draft.toggle_panel()
 var offers = draft.choices.duplicate()
 draft.toggle_panel(); draft.toggle_panel()
 check(draft.choices == offers, "reopening cannot reroll")
 draft.choose(offers[0])
 draft.on_level_up(p)
 check(draft.pending.is_empty() and draft.picked.size() == 1, "one reward per milestone")
 p.grant_xp(Constants.xp_to_level(4))
 check(p.level == 5 and draft.pending.is_empty(), "odd level gives skill point without build choice")
 p.grant_xp(Constants.xp_to_level(5))
 check(p.level == 6 and draft.pending == [6], "next build earned at level six")
 # Component synthesis handles full inventories and repeated components.
 var inventory = ["long_sword","bf_sword","cloak","ruby_crystal","boots","amp_tome"]
 var plan = ItemData.purchase_plan("infinity_edge",inventory)
 check(plan.valid and plan.cost == 1150 and plan.consume.size() == 3 and inventory[0] == "long_sword", "recipe consumes three owned components without mutating quote")
 plan = ItemData.purchase_plan("rabadon",["needlessly_rod","needlessly_rod","","","",""])
 check(plan.cost == 900 and plan.consume.size() == 2, "duplicate recipe components receive separate discounts")
 plan = ItemData.purchase_plan("warmog",["ruby_crystal","ruby_crystal","ruby_crystal","","",""])
 check(plan.cost == 1600 and plan.consume.size() == 3, "nested recipe credits partially built components")
 p.inventory = inventory.duplicate()
 p.gold = 1150
 check(p.try_buy_item("infinity_edge") and p.gold == 0 and p.inventory.has("infinity_edge") and not p.inventory.has("bf_sword"), "purchase assembles item at remaining cost in full inventory")
 var before = p.inventory.duplicate()
 check(not p.try_buy_item("rabadon") and p.inventory == before, "failed purchase preserves inventory")
 p.global_position = Vector2(1300,270)
 p.gold = 9999
 check(not p.try_buy_item("dagger") and not p.try_sell_item(0), "transactions require fountain")
 p.dead = true
 check(p.try_buy_item("dagger") and p.hp == 0, "dead heroes can shop without reviving")
 p.dead = false
 p.inventory = ["boots","","","","",""]
 p.global_position = Constants.FOUNT_B
 check(p.try_buy_item("berserker_greaves") and not p.inventory.has("boots"), "boots upgrade consumes starter boots")
 check(not p.try_buy_item("sorcerer_shoes"), "one boots item enforced")
 p.inventory = ["","","","","",""]
 p._apply_items()
 # Nearby deaths grant XP even when a minion or tower gets the kill.
 p.global_position = Vector2(1300,270)
 var ally = GameState.champions[1]
 ally.global_position = Vector2(1300,300)
 var far = GameState.champions[2]
 far.global_position = Constants.FOUNT_B
 var enemy = GameState.champions[3]
 enemy.global_position = Vector2(1400,270)
 var creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",Vector2(1380,270))
 GameState.minions.append(creep)
 var xp = p.xp
 var ally_xp = ally.xp
 var far_xp = far.xp
 var enemy_xp = enemy.xp
 var gold = p.gold
 var cs = p.cs
 game._handle_death(null,creep)
 check(is_equal_approx(p.xp-xp,creep.xp_val*1.2) and ally.xp > ally_xp, "XP soaking works regardless of killer")
 check(far.xp == far_xp and enemy.xp == enemy_xp and p.gold == gold and p.cs == cs, "outside radius, own deaths and missed last hits give no farming reward")
 creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",Vector2(1380,270))
 GameState.minions.append(creep)
 xp = p.xp
 game._handle_death(p,creep)
 check(is_equal_approx(p.xp-xp,creep.xp_val*1.5) and p.cs == cs+1 and p.gold == gold+creep.gold_val, "last hits grant gold, CS and bonus XP")
 # A-click prioritizes the creep nearest the cursor, with a cancellable windup.
 creep = game.MinionS.new()
 game.world_root.add_child(creep)
 creep.setup(1,"melee",Vector2(1370,270))
 GameState.minions.append(creep)
 enemy.global_position = Vector2(1320,300)
 game._issue_player_order({"type":"amove","point":creep.world_pos()})
 check(p.attack_target == creep and p.attack_move, "cursor creep wins over nearer enemy hero")
 var hp = creep.hp
 p.atk_cd = 0
 p.update_frame(0.01)
 check(p.queued_auto_target == creep and creep.hp == hp, "attack starts a visible windup")
 p.stop_actions()
 p.update_frame(0.3)
 check(creep.hp == hp and p.queued_auto_target == null, "S cancels windup before damage")
 game._issue_player_order({"type":"amove","point":creep.world_pos()})
 p.update_frame(0.01)
 p.update_frame(0.3)
 check(creep.hp < hp, "completed windup lands a melee attack")
 game._issue_player_order({"type":"smart","point":Vector2(1200,350)})
 check(p.attack_target == null and p.has_move_target and not p.attack_move, "right click ground breaks attack lock")
 # Chosen spells use independent slots and tick while dead.
 check(p.summoner_spells == ["heal","ghost"], "hero select spells reach the champion")
 p.hp = p.hp_max-400
 ally.hp = ally.hp_max-400
 ally.global_position = p.world_pos()+Vector2(30,0)
 var old_hp = p.hp
 var old_ally = ally.hp
 game.cast_summoner(p,0)
 check(p.hp > old_hp and ally.hp > old_ally and p.summoner_cds[0] == 40, "Heal heals self and nearby ally")
 var speed = p.effective_move_speed()
 game.cast_summoner(p,1)
 check(p.buffs.has("ghost") and p.effective_move_speed() > speed and p.summoner_cds[1] == 30, "Ghost grants movement speed in chosen F slot")
 p.dead = true
 p.tick_cooldowns(2)
 check(p.summoner_cds == [38.0,28.0], "death does not stop summoner cooldowns")
 p.dead = false
 # Distinct item passives work in actual combat.
 p.buffs.clear()
 p.inventory = ["infinity_edge","","","","",""]
 p.run_bonus.clear()
 p._apply_items()
 p.bonus_crit = 1
 enemy.bonus_armor = 0
 enemy.shield = 0
 enemy.hp = 10000
 enemy.hp_max = 10000
 p._perform_auto(enemy)
 check(is_equal_approx(10000-enemy.hp,floor(p.ad*2.1)), "Infinity Edge changes actual critical strike damage")
 p.inventory = ["sheen","","","","",""]
 p._apply_items()
 p.buffs["spellblade"] = {"time":5.0}
 enemy.hp = 10000
 p._perform_auto(enemy)
 check(is_equal_approx(10000-enemy.hp,floor(p.ad*1.75)) and not p.buffs.has("spellblade"), "Spellblade is consumed by one empowered auto")
 p.inventory = ["blade_ruined_king","","","","",""]
 p._apply_items()
 creep.hp = 2000
 creep.hp_max = 2000
 p._perform_auto(creep)
 check(is_equal_approx(2000-creep.hp,floor(p.ad+60)), "percent health on-hit is capped against creeps")
 p.inventory = ["ludens","","","","",""]
 p._apply_items()
 enemy.hp = 10000
 game.deal_damage(p,enemy,10,"skill")
 var first_hit = 10000-enemy.hp
 var hp_before = enemy.hp
 game.deal_damage(p,enemy,10,"skill")
 check(first_hit > hp_before-enemy.hp and p.item_cds.ludens == 6, "Luden procs once, then respects item cooldown")
 p.inventory = ["warmog","","","","",""]
 p._apply_items()
 p.stop_actions()
 p.hp = p.hp_max-500
 p.time_since_damage = 7
 var before_regen = p.hp
 p.update_frame(1)
 check(p.hp > before_regen+p.hp_regen+10, "Warmog restores percent HP out of combat")
 p.inventory = ["bloodthirster","","","","",""]
 p._apply_items()
 p.hp = p.hp_max
 p.shield = 0
 game.deal_damage(p,enemy,100,"auto")
 check(p.shield == 20, "Bloodthirster converts excess lifesteal to shield")
 p.inventory = ["archangel","rabadon","","","",""]
 p._apply_items()
 var expected_ap = 160*1.3 if p.hero.mp==0 else (160+(p.hero.mp+p.hero.mp_per_lv*(p.level-1)+500)*0.025)*1.3
 check(is_equal_approx(p.bonus_ap,expected_ap), "mana conversion and Deathcap scale the final AP total")
 p.inventory = ["","","","","",""]
 p._apply_items()
 p.global_position = Constants.FOUNT_B
 p.gold = 1000
 # Real input dispatch: shop Escape must not also open the pause menu.
 await get_tree().process_frame
 ui.toggle_shop()
 await get_tree().process_frame
 check(ui.shop_panel.get_global_rect().position.x >= 0 and ui.shop_panel.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x, "large shop is centered inside logical viewport")
 ui.shop_panel.selected = "long_sword"
 ui.shop_panel.refresh_shop(true)
 await get_tree().process_frame
 var click = InputEventMouseButton.new()
 click.position = ui.shop_panel.buy.get_global_rect().get_center()
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 get_viewport().push_input(click,true)
 click = click.duplicate()
 click.pressed = false
 get_viewport().push_input(click,true)
 check(p.inventory.has("long_sword") and p.gold == 650, "real shop Buy click purchases exactly one item")
 ui.shop_panel.search.grab_focus()
 key(KEY_ESCAPE)
 check(not ui.shop_open and not GameState.paused and not game.in_game_menu.has_node("MatchPanel"), "Escape closes shop once without pausing")
 key(KEY_ESCAPE)
 check(GameState.paused and game.in_game_menu.has_node("MatchPanel"), "next Escape opens match menu")
 key(KEY_ESCAPE)
 check(not GameState.paused and not game.in_game_menu.has_node("MatchPanel"), "Escape resumes match")
 draft.toggle_panel()
 key(KEY_ESCAPE)
 check(not draft.panel.visible and not GameState.paused, "Escape closes upgrade panel before menu")
 print("ARAM LOOP: %d checks, %d failures" % [checks,failures])
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
