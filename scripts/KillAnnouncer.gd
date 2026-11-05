extends Node
const MULTIKILL_WINDOW = 8.0
const TITLES = {"first_blood":"FIRST BLOOD","double_kill":"DOUBLE KILL","triple_kill":"TRIPLE KILL","quadra_kill":"MANIAC","penta_kill":"SAVAGE","killing_spree":"KILLING SPREE","mega_kill":"MEGA KILL","unstoppable":"UNSTOPPABLE","monster_kill":"MONSTER KILL","godlike":"GODLIKE","legendary":"LEGENDARY","shutdown":"SHUTDOWN","slain":"CHAMPION SLAIN"}
const SPREES={3:"killing_spree",4:"mega_kill",5:"unstoppable",6:"monster_kill",7:"godlike"}
var streaks: Dictionary = {}
var main
var events: Array = []
func register(killer, victim) -> void:
 var victim_state = streaks.get(victim.get_instance_id(),{"streak":0})
 var shutdown = victim_state.streak >= 3
 streaks[victim.get_instance_id()] = {"streak":0,"count":0,"last":-100.0}
 if not killer is Object or not is_instance_valid(killer) or killer.kind != "champion": return
 var id = killer.get_instance_id()
 var state = streaks.get(id,{"streak":0,"count":0,"last":-100.0})
 state.count = state.count+1 if GameState.time-state.last<=MULTIKILL_WINDOW else 1
 state.streak += 1
 state.last = GameState.time
 streaks[id] = state
 var event = "slain"
 if state.count>=5: event = "penta_kill"
 elif state.count==4: event = "quadra_kill"
 elif state.count==3: event = "triple_kill"
 elif state.count==2: event = "double_kill"
 elif shutdown: event = "shutdown"
 elif GameState.score[0]+GameState.score[1]==1: event = "first_blood"
 elif state.streak>=8:event="legendary"
 elif SPREES.has(state.streak):event=SPREES[state.streak]
 events.append(event)
 if events.size()>32: events.pop_front()
 main.announce_kill(event,killer.team,killer.hero.name,killer)
