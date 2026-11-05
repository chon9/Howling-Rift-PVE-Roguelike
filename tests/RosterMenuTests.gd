extends Node
var failures = 0
var checks = 0
func check(value: bool,text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 check(game.menu_page == "main" and not GameState.started and game.hero_cards.is_empty(),"boot opens title menu before hero selection")
 game._show_menu()
 check(game.hero_cards.size() == ChampionData.CHAMPIONS.size() and game.menu_page == "heroes","solo play opens all eighteen heroes")
 game._back_from_heroes()
 check(game.menu_page == "main","hero screen goes back to title menu")
 game._show_start_upgrades()
 check(game.menu_page == "upgrades","account upgrades accessible from title")
 game._show_main_menu()
 game._start_game("yasuo")
 game.toggle_in_game_menu()
 var texts: PackedStringArray = []
 for node in descendants(game.in_game_menu):
  if node is Button: texts.append(node.text)
 check(texts.has("RESUME [ESC]") and texts.has("RETURN TO MAIN MENU") and texts.has("QUIT GAME"),"Esc menu contains conventional game actions")
 game._request_return()
 check(game.has_node("ReturnConfirmation"),"unfinished match return has confirmation")
 game._close_confirmation()
 check(GameState.started,"cancelling return preserves match")
 game._return_to_main_menu()
 check(not GameState.started and GameState.champions.is_empty() and game.menu_page == "main","return resets match and rebuilds clean title screen")
 game.queue_free()
 await get_tree().process_frame
 for hero in HeroArt.KEYS:
  GameState.reset()
  game = load("res://scripts/Main.gd").new()
  add_child(game)
  game.set_process(false)
  game._start_game(hero)
  var p = GameState.player
  var target = GameState.champions[3]
  target.is_bot = false
  for other in GameState.champions: other.global_position = Constants.FOUNT_B if other.team == 0 else Constants.FOUNT_R
  p.global_position = Vector2(1300,270)
  target.global_position = Vector2(1400,270)
  target.hp = 10000; target.hp_max = 10000
  check(p.champion_texture != null and p.champion_texture.get_image().detect_alpha() != Image.ALPHA_NONE,hero+" has transparent painted art")
  p.grant_xp(Constants.xp_to_level(3)+Constants.xp_to_level(4)+Constants.xp_to_level(5))
  p.skill_ranks = [1,1,1,1]
  for index in range(4):
   p.global_position = Vector2(1300,270)
   p.stop_actions()
   p.stun = 0
   p.buffs.erase("silence")
   target.global_position = Vector2(1400,270)
   target.stun = 1
   p.skill_cds[index] = 0
   p.mp = p.mp_max
   check(AbilityArt.icon_for(hero,index) != null,hero+" skill icon "+str(index))
   check(p.try_cast_skill(index,target.world_pos()),hero+" skill casts "+str(index))
   for frame in range(75):
    p.update_frame(0.02)
    target.update_frame(0.02)
    for missile in GameState.projectiles.duplicate():
     if is_instance_valid(missile): missile.update_frame(0.02)
    for area in GameState.aoes.duplicate():
     if is_instance_valid(area): area.update_frame(0.02)
    if frame%20 == 0: await get_tree().process_frame
  check(target.hp < 10000,hero+" kit damages enemies")
  if hero == "kayle": check(p.auto_type == "ranged" and p.atk_range == 350,"Kayle-inspired hero ascends at level six")
  # Run the new hero through its normal bot AI, including skills and shopping.
  p.is_bot = true
  for c in GameState.champions:
   c.global_position = Constants.FOUNT_B if c.team == 0 else Constants.FOUNT_R
   c.hp = c.hp_max
   c.stop_actions()
  for frame in range(2400):
   game._process(1.0/60)
   if frame%40 == 0: await get_tree().process_frame
  check(GameState.wave_num > 0 and p.inventory.count("") < 6,hero+" AI participates and buys items")
  print("NEW HERO VERIFIED: "+hero)
  game.queue_free()
  await get_tree().process_frame
 print("ROSTER / MENU: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
func descendants(node: Node) -> Array:
 var result = [node]
 for child in node.get_children(): result.append_array(descendants(child))
 return result
