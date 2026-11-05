class_name MatchTraining
extends RefCounted
const KEYS = ["training_ad","training_ap","training_hp","training_armor","training_mr","training_as"]
const SPECS = [
 ["War Elixir","bonus_ad",25.0,"+25 attack damage","bf_sword"],
 ["Arcane Elixir","bonus_ap",40.0,"+40 ability power","needlessly_rod"],
 ["Vitality Elixir","bonus_hp",400.0,"+400 maximum health","ruby_crystal"],
 ["Iron Elixir","bonus_armor",20.0,"+20 armor","chain_vest"],
 ["Warding Elixir","bonus_mr",20.0,"+20 magic resistance","negatron"],
 ["Fury Elixir","bonus_as",0.15,"+15% attack speed","dagger"]]
static func items() -> Dictionary:
 var result = {}
 for i in range(KEYS.size()):
  var spec = SPECS[i]
  result[KEYS[i]] = {"name":spec[0],"cost":8000,"cat":"consumable","consumable":true,"stats":{spec[1]:spec[2]},"recipe":[],"icon":"","desc":spec[3]+". Consumed immediately; stacks for this match and survives death. Uses no inventory slot. Each purchase of this elixir raises its next price by 35%. Resets next match; does not affect permanent credits."}
 return result
static func price(id: String, counts: Dictionary) -> int:
 # Linear-after-cap exponent avoids overflow in arbitrarily long sessions.
 var count = int(counts.get(id,0))
 return int(ceil(8000.0 * pow(1.35,min(count,20)) * (1.0+maxi(0,count-20)*0.35)))
static func icon_source(id: String) -> String:
 return SPECS[KEYS.find(id)][4]
