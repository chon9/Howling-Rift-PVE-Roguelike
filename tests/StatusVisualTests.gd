extends Node
var failures = 0
var checks = 0
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("FAIL: "+text)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent = false
 var game = load("res://scripts/Main.gd").new()
 add_child(game)
 game.set_process(false)
 game.network_config={"blue":["ashe","garen","lux"],"red":["ashe","garen","lux"],"players":[{"peer":1,"name":"Test","bonuses":{},"spells":["flash","ignite"]}],"stage":1}
 game._start_game("ashe")
 for c in GameState.champions:
  c.is_bot = false
  c.stop_actions()
 var p = GameState.player
 p.global_position = Vector2(1650,270)
 var enemy = GameState.champions[3]
 enemy.global_position = p.world_pos()+Vector2(120,0)
 game.mouse_world = enemy.world_pos()
 game.cast_summoner(p,1)
 var fx = enemy.get_node("StatusVisual")
 fx.refresh()
 check(fx.ignite_remaining == 5.0 and fx.visible,"real Ignite cast activates persistent five-second flames")
 check(fx.fire_texture != null and fx.fire_texture.get_image().detect_alpha() != Image.ALPHA_NONE,"burn sprite has preserved transparency")
 var frame = fx.fire_frame()
 fx.phase += 1.0/8.0
 check(fx.fire_frame() != frame,"persistent flames animate")
 enemy.stun = 2.25
 fx.refresh()
 check(fx.stun_remaining == 2.25 and fx.ignite_remaining == 5.0,"stun and Ignite can display together")
 enemy.update_frame(0.25)
 fx.refresh()
 check(is_equal_approx(fx.stun_remaining,2.0) and is_equal_approx(fx.ignite_remaining,4.75),"status labels follow gameplay durations")
 var packet = LanSnapshot.encode()
 check(is_equal_approx(packet.champs[3].stun,2.0) and is_equal_approx(packet.champs[3].buffs.ignite.time,4.75),"LAN packets carry both remaining durations")
 var restored = LanSnapshot.restore_buffs(packet.champs[3].buffs)
 check(restored.ignite.src == p,"LAN Ignite source restores correctly")
 var phase = fx.phase
 GameState.paused = true
 fx._process(0.5)
 check(fx.phase == phase,"paused status animation stays still")
 GameState.paused = false
 var minion = game.MinionS.new()
 game.world_root.add_child(minion)
 minion.setup(Constants.RED,"melee",Vector2(1790,335))
 minion.stun = 1.5
 minion.get_node("StatusVisual").refresh()
 check(minion.get_node("StatusVisual").visible,"minion stun has the same overhead indicator")
 game._update_camera(1)
 await get_tree().process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/46-stun-ignite-status.png")
 enemy.stun = 0
 enemy.buffs.erase("ignite")
 fx.refresh()
 check(not fx.visible and fx.stun_remaining == 0 and fx.ignite_remaining == 0,"expired statuses remove their visuals immediately")
 enemy.stun = 2
 enemy.buffs.ignite = {"time":3.0,"src":p,"total":100}
 enemy.dead = true
 fx.refresh()
 check(not fx.visible,"death hides remaining status effects")
 print("STATUS VISUALS: %d checks, %d failures" % [checks,failures])
 get_tree().quit(1 if failures else 0)
