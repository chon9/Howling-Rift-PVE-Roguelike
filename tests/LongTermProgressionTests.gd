extends Node
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(message)
func capture(path: String) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
 await get_tree().process_frame
 GameState.reset()
 Progression.persistent = false
 Progression.levels.clear()
 Progression.credits = 10000
 Progression.difficulty = 1
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 var selector = game.menu.find_child("PreGameDifficulty",true,false)
 check(selector != null,"difficulty selector is on start menu")
 selector.value = 12
 check(Progression.difficulty==12 and not GameState.started,"pre-game choice affects the next game")
 await capture("res://tests/51-start-difficulty.png")
 var previous = 0.0
 for stage in range(1,100):
  check(Progression.reward_multiplier(stage)>previous,"rewards increase at N%d" % stage)
  previous = Progression.reward_multiplier(stage)
 for key in Progression.UPGRADES:
  Progression.levels[key]=0
  var first = Progression.cost(key)
  check(first>=450,"first stat rank takes multiple N1 completions")
  Progression.levels[key]=50
  check(Progression.cost(key)>100000,"rank 51 remains a long-term goal")
  Progression.levels[key]=98
  check(Progression.cost(key)>500000,"final rank is expensive even at high N")
 Progression.levels.clear()
 game._show_start_upgrades()
 var stride = game.menu.find_child("Permanent_stride",true,false)
 check(stride != null and not stride.disabled,"movement upgrade can be bought before a game")
 stride.pressed.emit()
 check(Progression.levels.stride==1 and Progression.credits==9250,"stride spends the shown 750 credits")
 check(is_equal_approx(Progression.bonuses().bonus_ms,0.005),"stride adds 0.5 percent starting movement speed")
 check(is_equal_approx(LanSession.sanitize_bonuses(Progression.bonuses()).bonus_ms,0.005),"LAN preserves the starting movement bonus")
 await capture("res://tests/52-long-term-upgrades.png")
 game._show_menu()
 game._start_game("ashe")
 var p = GameState.player
 check(GameState.difficulty==12 and GameState.reward_difficulty==12,"launch captures selected N and reward stage")
 check(is_equal_approx(p.bonus_ms,0.005),"new hero starts with bought movement bonus")
 game.change_match_difficulty(99)
 check(GameState.difficulty==12 and Progression.difficulty==12,"running game cannot change N")
 check(not Progression.buy("might"),"running game cannot buy starting AD")
 var draft = game.lane_augments
 draft.refresh_attention()
 check(not draft.ready_prompt.visible,"no highlighted choice before level-up")
 for c in GameState.champions:
  c.is_bot=false; c.stop_actions()
 p.global_position=Vector2(1650,270)
 game._update_camera(1)
 p.level=4
 draft.on_level_up(p)
 draft.refresh_attention()
 check(draft.pending.size()==1 and draft.ready_prompt.visible,"level four shows the persistent clickable build prompt")
 check(draft.badge.text.contains("BUILD READY") and draft.badge.get_theme_stylebox("normal")==draft.ready_style,"ready badge has gold highlight")
 await capture("res://tests/53-build-ready.png")
 draft.ready_prompt.pressed.emit()
 check(draft.panel.visible and not draft.ready_prompt.visible,"highlight opens three choices")
 await capture("res://tests/54-build-choice.png")
 var rect=draft.panel.get_global_rect()
 check(rect.position.x>=0 and rect.end.x<=get_viewport().get_visible_rect().size.x,"draft panel is centered within screen")
 draft.choose(draft.choices[0])
 check(draft.pending.is_empty() and not draft.ready_prompt.visible,"spending the choice clears the alert")
 draft.on_level_up(p)
 check(draft.pending.is_empty(),"same level cannot grant another choice")
 p.level=6; draft.on_level_up(p)
 game.toggle_in_game_menu()
 draft.refresh_attention()
 check(not draft.ready_prompt.visible and GameState.paused,"pause hides the build prompt without spending it")
 game.toggle_in_game_menu()
 draft.refresh_attention()
 check(draft.ready_prompt.visible and draft.pending.size()==1,"resume restores unspent build alert")
 game._end_game(Constants.BLUE)
 var awarded=Progression.last_reward
 check(awarded>0,"completion pays permanent points")
 var balance=Progression.credits
 game.award_match_credits(true,p.kills)
 check(Progression.credits==balance,"completion pays only once")
 game._return_to_main_menu()
 check(Progression.levels.stride==1,"return preserves account upgrades")
 print("LONG TERM PROGRESSION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
