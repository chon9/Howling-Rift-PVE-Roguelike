class_name BuildStealer
extends RefCounted
const LIMIT=10
const CANDIDATE_LIMIT=20
const MIN_KILLS=15
const MIN_KD=5.
static var last_used: Array=[]
static var last_normal: String=""
static func number(data: Dictionary,key: String,low: float,high: float,fallback: float=0.) -> float:
 var value=data.get(key,fallback)
 return clampf(float(value),low,high) if (value is int or value is float) and is_finite(float(value)) else fallback
static func qualifies(kills: int,deaths: int) -> bool:return kills>=MIN_KILLS and float(kills)/maxi(1,deaths)>=MIN_KD
static func score(record: Dictionary) -> int:
 return int(round(Progression.reward_multiplier(record.stage)*(record.kills*100.+record.assists*15.)/maxi(1,record.deaths)))+(500 if record.won else 0)
static func validate(raw) -> Dictionary:
 if not raw is Dictionary or not raw.get("hero","") is String or not ChampionData.CHAMPIONS.has(raw.hero):return {}
 var kills=int(number(raw,"kills",0,100000));var deaths=int(number(raw,"deaths",0,100000))
 if not qualifies(kills,deaths):return {}
 var items=raw.get("items",[])
 if not items is Array or items.is_empty() or items.size()>6:return {}
 var clean_items=[];var boots=0
 for id in items:
  if not id is String or not ItemData.ITEMS.has(id) or ItemData.ITEMS[id].get("consumable",false):return {}
  if ItemData.ITEMS[id].cat=="boot":boots+=1
  if boots>1 or (clean_items.has(id) and not ItemData.ITEMS[id].recipe.is_empty()):return {}
  clean_items.append(id)
 var upgrades=[];var seen={};var source=raw.get("augments",[])
 if not source is Array or source.size()>8:return {}
 for entry in source:
  if not entry is Dictionary:return {}
  var level=int(number(entry,"level",0,100));var index=int(number(entry,"index",-1,999,-1))
  if level not in [4,6,8,10,12,14,16,18] or seen.has(level) or index<0 or index>=LaneAugmentsData.AUGMENTS.size():return {}
  var base=LaneAugmentsData.AUGMENTS[index];var values=entry.get("stats",{})
  if not values is Dictionary or values.size()!=base.stats.size():return {}
  var stats={}
  for key in base.stats:
   if not values.has(key):return {}
   var value=number(values,key,0.,float(base.stats[key])*2.,-1.)
   if value<0:return {}
   stats[key]=value
  upgrades.append({"level":level,"index":index,"name":base.name,"stats":stats});seen[level]=true
 upgrades.sort_custom(func(a,b):return a.level<b.level)
 var elixirs={};var counts=raw.get("elixirs",{})
 if not counts is Dictionary:return {}
 for key in MatchTraining.KEYS:
  var count=int(number(counts,key,0,1000))
  if count>0:elixirs[key]=count
 var spells=raw.get("spells",["flash","ignite"])
 if not spells is Array or spells.size()!=2 or spells[0]==spells[1] or not SummonerData.SPELLS.has(spells[0]) or not SummonerData.SPELLS.has(spells[1]):return {}
 var skill_order=[];var order=raw.get("skill_order",[]);var ranks=[1,1,1,0]
 if not order is Array or order.size()>18:return {}
 for entry in order:
  if not entry is Dictionary:return {}
  var index=int(number(entry,"index",-1,4,-1));var rank=int(number(entry,"rank",0,5))
  if index<0 or index>3 or rank!=ranks[index]+1 or rank>ChampionData.CHAMPIONS[raw.hero].skills[index].max:return {}
  ranks[index]=rank;skill_order.append({"index":index,"rank":rank})
 var record={"hero":raw.hero,"name":str(raw.get("name","Player")).replace("\n"," ").replace("\r"," ").left(32),"stage":int(number(raw,"stage",1,99,1)),"kills":kills,"deaths":deaths,"assists":int(number(raw,"assists",0,100000)),"won":raw.get("won",false)==true,"items":goal_order(clean_items),"augments":upgrades,"elixirs":elixirs,"skill_order":skill_order,"spells":spells.duplicate()}
 var canonical=clean_items.duplicate();canonical.sort()
 record.id=JSON.stringify({"hero":record.hero,"items":canonical,"augments":upgrades,"elixirs":elixirs,"skills":skill_order,"spells":record.spells}).sha256_text().left(20)
 record.score=score(record)
 return record
# The script is read lazily rather than constructing a draft UI just to validate saved rolls.
const LaneAugmentsData=preload("res://scripts/LaneAugments.gd")
static func ranked(raw: Array) -> Array:
 var unique={}
 for candidate in raw.slice(0,CANDIDATE_LIMIT):
  var record=validate(candidate)
  if record.is_empty():continue
  # Each hero owns one library slot, even when items or rolled upgrades differ.
  # Equal scores keep the existing record; only an improvement replaces it.
  if not unique.has(record.hero) or record.score>unique[record.hero].score:unique[record.hero]=record
 var records=unique.values()
 records.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else (a.stage>b.stage if a.stage!=b.stage else a.id<b.id))
 return records.slice(0,LIMIT)
static func capture(c,stage: int,won: bool) -> Dictionary:
 if not is_instance_valid(c) or c.is_bot or c.owner_peer<=0 or c.team!=Constants.BLUE or not qualifies(c.kills,c.deaths):return {}
 var items=c.inventory.filter(func(id):return id!="")
 # Retain the order the player completed their final items, not arbitrary inventory slot order.
 items.sort_custom(func(a,b):return c.purchase_history.rfind(a)<c.purchase_history.rfind(b))
 return validate({"hero":c.hero_key,"name":c.char_name,"stage":stage,"kills":c.kills,"deaths":c.deaths,"assists":c.assists,"won":won,"items":items,"augments":c.augment_history,"elixirs":c.consumable_counts,"skill_order":c.skill_history,"spells":c.summoner_spells})
static func record_match(winner: int) -> String:
 if GameState.is_pvp() or LanSession.is_client():return ""
 var previous=Progression.build_records.duplicate(true);var candidates=previous.duplicate(true);var learned=[]
 for c in GameState.champions:
  var record=capture(c,GameState.reward_difficulty,winner==c.team)
  if not record.is_empty():candidates.append(record);learned.append(record)
 Progression.build_records=ranked(candidates)
 if learned.is_empty():return "Build stealer: 15+ hero kills and K/D ≥ 5 records your build."
 if not Progression.save_profile():Progression.build_records=previous;return "Build stealer: could not save this run's builds."
 var retained=0
 for candidate in learned:
  if Progression.build_records.any(func(record):return record==candidate):retained+=1
 return "Build stealer: %d qualifying build(s), %d in the best 10 • Unique heroes %d/10" % [learned.size(),retained,Progression.build_records.size()]
static func assign(config: Dictionary) -> void:
 config["stolen_builds"]=[]
 if str(config.get("mode","pve"))=="pvp":return
 config.red=MatchRoster.unique_enemies(config.red,config.blue)
 var pool=ranked(Progression.build_records)
 if pool.is_empty():return
 var fresh=pool.filter(func(record):return not last_used.has(record.id))
 if fresh.size()>=2:pool=fresh
 pool.shuffle();var picks=pool.slice(0,2)
 var slots=[0,1,2];slots.shuffle();last_used=picks.map(func(record):return record.id)
 for i in range(picks.size()):
  config.red[slots[i]]=picks[i].hero
  config.stolen_builds.append({"slot":3+slots[i],"record":picks[i].duplicate(true)})
 # Until two distinct heroes are learned, leave the spare slot on normal AI.
 # Enemy heroes are unique; Echoes may still mirror allied heroes.
 var blocked=picks.map(func(record):return record.hero)
 for i in range(picks.size(),3):
  var options=ChampionData.CHAMPIONS.keys().filter(func(key):return key!=last_normal and not blocked.has(key) and not config.blue.has(key) and not MatchRoster.previous_enemies.has(key))
  if options.is_empty():options=ChampionData.CHAMPIONS.keys().filter(func(key):return not blocked.has(key) and not config.blue.has(key))
  config.red[slots[i]]=options.pick_random();last_normal=config.red[slots[i]];blocked.append(last_normal)
 MatchRoster.previous_enemies=config.red.duplicate()
static func attach(c,record: Dictionary,echo: int) -> void:
 if GameState.is_pvp() or not c.is_bot or c.team!=Constants.RED:return
 var clean=validate(record)
 if clean.is_empty() or clean.hero!=c.hero_key:return
 c.stolen_blueprint=clean;c.stolen_skill_cursor=0;c.stolen_items_complete=false;c.summoner_spells=clean.spells.duplicate()
 c.char_name="Echo %d • N%d" % [echo,clean.stage];c.name_label.text=c.char_name
static func contains_component(parent: String,child: String,depth: int=0) -> bool:
 if depth>8:return false
 for id in ItemData.ITEMS[parent].recipe:
  if id==child or contains_component(id,child,depth+1):return true
 return false
static func goal_order(items: Array) -> Array:
 var remaining=items.duplicate();var ordered=[]
 while not remaining.is_empty():
  var found=false
  for id in remaining:
   if remaining.any(func(parent):return parent!=id and contains_component(parent,id)):continue
   ordered.append(id);remaining.erase(id);found=true;break
  if not found:ordered.append_array(remaining);break
 return ordered
static func missing_components(id: String,working: Array,depth: int=0) -> Array:
 if depth>8:return []
 var slot=working.find(id)
 if slot>=0:working[slot]="";return []
 var result=[id]
 for child in ItemData.ITEMS[id].recipe:result.append_array(missing_components(child,working,depth+1))
 return result
static func buy_next(c) -> bool:
 if c.stolen_items_complete:return c._bot_buy_original(true)
 var needed={}
 for id in c.stolen_blueprint.items:
  needed[id]=int(needed.get(id,0))+1
  if c.inventory.count(id)>=needed[id]:continue
  if c.try_buy_item(id):return true
  var working=c.inventory.duplicate();var components=[]
  for child in ItemData.ITEMS[id].recipe:components.append_array(missing_components(child,working))
  for component in components:
   var plan=ItemData.purchase_plan(component,c.inventory,c.consumable_counts)
   if plan.valid and c.gold>=plan.cost and c.try_buy_item(component):return true
  return false
 # A component from the stolen loadout may be upgraded by the original AI
 # plan. Latch completion so that it is never bought again as a saved goal.
 c.stolen_items_complete=true
 return c._bot_buy_original(true)
static func buy_training(c) -> bool:
 var choices=[]
 for id in c.stolen_blueprint.elixirs:
  if int(c.consumable_counts.get(id,0))<int(c.stolen_blueprint.elixirs[id]):choices.append(id)
 if choices.is_empty():return c._bot_buy_training()
 choices.sort_custom(func(a,b):return MatchTraining.price(a,c.consumable_counts)<MatchTraining.price(b,c.consumable_counts))
 return c.try_buy_item(choices[0])
static func upgrade_at(c,level: int) -> Dictionary:
 for upgrade in c.stolen_blueprint.get("augments",[]):
  if upgrade.level==level:return upgrade
 return {}
static func stats_label(stats: Dictionary) -> String:
 var labels={"bonus_ad":"AD","bonus_ap":"AP","bonus_hp":"health","bonus_mp":"mana","bonus_armor":"armor","bonus_mr":"magic resist","bonus_as":"attack speed","bonus_ms":"move speed","bonus_crit":"crit chance","bonus_cdr":"cooldown reduction","bonus_lifesteal":"lifesteal","bonus_hp_regen":"HP/sec","bonus_heal_power":"heal/shield power","bonus_mp_regen":"mana/sec"}
 var percent=["bonus_as","bonus_ms","bonus_crit","bonus_cdr","bonus_lifesteal","bonus_heal_power"];var parts=[]
 for stat in stats:parts.append("+%.0f%s %s" % [stats[stat]*(100. if stat in percent else 1.),"%" if stat in percent else "",labels.get(stat,stat)])
 return ", ".join(parts)
static func tooltip(record: Dictionary) -> String:
 if record.is_empty():return ""
 var names=[]
 for id in record.items:names.append(ItemData.ITEMS[id].name)
 return "STOLEN BUILD • %s
N%d • Score %d • %d / %d / %d
%s
Buys with earned gold. Copied upgrades unlock at their level milestones.
After the saved path ends, normal hero skills, upgrades and purchases continue." % [record.name,record.stage,record.score,record.kills,record.deaths,record.assists,", ".join(names)]
