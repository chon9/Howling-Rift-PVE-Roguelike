extends Node
var failures=0
var checks=0
var game
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("PVP: "+message)
func _ready() -> void:
 Progression.persistent=false
 Progression.difficulty=99;Progression.levels={"ad":100,"hp":100}
 Progression.credits=12345
 game=load("res://scripts/Main.gd").new();add_child(game)
 var people={1:{"peer":1,"hero":"ashe","spells":["heal","ghost"],"team":1,"ready":true,"name":"Host","bonuses":{"bonus_ad":9999}},2:{"peer":2,"hero":"ashe","spells":["flash","ignite"],"team":0,"ready":true,"name":"Guest","bonuses":{"bonus_hp":9999}}}
 for size in [1,2,3]:
  var rules=MatchRules.settings("pvp",size,true)
  check(MatchRules.capacity(rules)==size*2,"room capacity")
  check(MatchRules.start_error(people,rules).is_empty(),"one human per team with bots can start")
  check(MatchRules.start_error(people,MatchRules.settings("pvp",size,false)).is_empty()==(size==1),"no-fill requires full human teams")
  var config=MatchRules.build_config(people,rules,99,false)
  check(config.stage==1 and config.players.all(func(p):return p.bonuses.is_empty()),"difficulty and permanent stats stripped")
  game._start_network_match(config)
  check(GameState.is_pvp() and GameState.difficulty==1,"PvP mode and difficulty restored after reset")
  check(GameState.player==GameState.champions[3] and GameState.player.team==1,"host can own red slot")
  check(GameState.player.summoner_spells==["heal","ghost"],"chosen summoners retained")
  check(GameState.champions.filter(func(c):return c.roster_active).size()==size*2,"correct active team sizes")
  var a=GameState.champions[0];var b=GameState.champions[3]
  check(is_equal_approx(a.hp_max,b.hp_max) and is_equal_approx(a.ad,b.ad) and a.gold==b.gold,"mirror champions have equal starting stats")
  check(a.permanent_bonus.is_empty() and b.permanent_bonus.is_empty(),"no relic or upgrade bonuses")
  for index in range(6):
   check(is_equal_approx(GameState.structures[index].hp_max,GameState.structures[index+6].hp_max),"both teams have equal structure HP")
  var red_bot=GameState.champions[4];red_bot.deaths=15
  check(red_bot.grant_comeback_gold()==0,"PvP bots cannot receive comeback gold")
  check(game.award_match_credits(true,0)==0 and Progression.credits==12345,"PvP cannot award permanent credits")
  GameState.running=false
  game._return_to_main_menu()
 var resumed=MatchRules.build_config(people,MatchRules.settings("pvp",3,false),99,false)
 resumed.resuming=true;resumed.players=resumed.players.filter(func(p):return p.peer==1)
 game._start_network_match(resumed)
 check(GameState.champions.all(func(c):return c.roster_active),"resuming preserves other disconnected slots for HUD and snapshot restoration")
 GameState.running=false;game._return_to_main_menu()
 var one=people.duplicate(true);one.erase(2)
 check(not MatchRules.start_error(one,MatchRules.settings("pvp")).is_empty(),"solo room cannot start PvP")
 people[2].ready=false
 check(not MatchRules.start_error(people,MatchRules.settings("pvp")).is_empty(),"ready check enforced")
 check(MatchRules.capacity(MatchRules.settings("pve"))==3,"PvE remains three human co-op")
 print("PVP rules: %d checks, %d failures" % [checks,failures])
 game.queue_free();GameState.reset()
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
