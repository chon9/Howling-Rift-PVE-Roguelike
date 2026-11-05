extends Node

const UPGRADES = {
	"vitality": {"name": "Vitality", "stat": "bonus_hp", "value": 35.0, "unit": "health", "cost": 500},
	"might": {"name": "Might", "stat": "bonus_ad", "value": 3.0, "unit": "attack damage", "cost": 600},
	"sorcery": {"name": "Sorcery", "stat": "bonus_ap", "value": 4.0, "unit": "spell power", "cost": 600},
	"guard": {"name": "Guard", "stat": "bonus_armor", "value": 2.0, "unit": "armor", "cost": 500},
	"recovery": {"name": "Recovery", "stat": "bonus_hp_regen", "value": 0.3, "unit": "health / sec", "cost": 450},
	"haste": {"name": "Haste", "stat": "bonus_as", "value": 0.015, "unit": "attack speed", "cost": 650},
	"stride": {"name": "Stride", "stat": "bonus_ms", "value": 0.005, "unit": "movement speed", "cost": 750}
}
var music_volume: float = 0.28
var smart_cast: bool = true
var allied_bots: bool = true
var edge_smoothing: bool = true
var world_sharpness: float = 0.35
var frame_limit: int = 120
var vsync_enabled: bool = true
var fullscreen_enabled: bool = false
# Rift3D presentation (ViewConfig.configure reads these after a profile loads; flags and HOWLING_VIEW still win).
var view_3d: bool = true
var view_3d_chosen: bool = false # The VIEW row was used; until then the shipped ViewConfig default applies.
var view_camera: String = "lol"
var view_quality: String = "high"
var renderer: String = "gl_compatibility"
const RENDERERS = ["gl_compatibility", "forward_plus"]
const DEFAULT_SAVE_PATH = "user://progression.cfg"
const LEGACY_SAVE = "Godot/app_userdata/Howling Rift/progression.cfg" # Classic 2D profile, under OS.get_data_dir()
var credits: int = 0
var difficulty: int = 1
var levels: Dictionary = {}
var save_path: String = "user://progression.cfg"
var persistent: bool = false
var build_records: Array = []
var last_reward: int = 0
var awarded: bool = false
var save_error: String = ""
const STASH_LIMIT=200
const DAILY_QUESTS={
 "first_run":{"name":"Into the Rift","desc":"Complete 1 match","field":"matches","goal":1},
 "victory":{"name":"Claim the Throne","desc":"Win 1 match","field":"wins","goal":1},
 "hunter":{"name":"Hero Hunter","desc":"Earn 12 hero kills across completed matches","field":"kills","goal":12},
 "farmer":{"name":"Lane Harvester","desc":"Last-hit 80 minions across completed matches","field":"cs","goal":80},
 "veteran":{"name":"Rift Veteran","desc":"Complete 3 matches","field":"matches","goal":3}
}
var gear_stash: Array=[]
var gear_equipped: Dictionary={}
var next_gear_id: int=1
var daily: Dictionary={}
var last_drops: Array=[]
var clock_date: String="" # Isolated tests can supply a date without changing the system clock.
var loot_rng=RandomNumberGenerator.new()


func load_profile() -> void:
	persistent = true
	loot_rng.randomize()
	levels.clear();gear_stash.clear();gear_equipped.clear();daily.clear();build_records.clear()
	# Release builds only: editor/dev runs of the clone keep their own fresh profile.
	if save_path == DEFAULT_SAVE_PATH and OS.has_feature("template"): migrate_legacy_save()
	var file = ConfigFile.new()
	if file.load(save_path) != OK:
		refresh_daily(false)
		return
	music_volume = clampf(float(file.get_value("audio","music_volume",0.28)),0,1)
	smart_cast = bool(file.get_value("controls","smart_cast",true))
	allied_bots = bool(file.get_value("match","allied_bots",true))
	fullscreen_enabled = bool(file.get_value("graphics","fullscreen",false))
	edge_smoothing = bool(file.get_value("graphics","edge_smoothing",true))
	world_sharpness = clampf(float(file.get_value("graphics","world_sharpness",0.35)),0.,1.)
	vsync_enabled = bool(file.get_value("graphics","vsync",true))
	frame_limit = int(file.get_value("graphics","frame_limit",120))
	if frame_limit not in [0,60,120,144,240]: frame_limit = 120
	view_3d = bool(file.get_value("view","view_3d",true))
	view_3d_chosen = bool(file.get_value("view","view_3d_chosen",false))
	view_camera = str(file.get_value("view","camera","lol"))
	if not ViewConfig.PRESETS.has(view_camera): view_camera = "lol"
	view_quality = str(file.get_value("view","quality","high"))
	if not ViewConfig.QUALITY.has(view_quality): view_quality = "high"
	renderer = str(file.get_value("view","renderer","gl_compatibility"))
	if renderer not in RENDERERS: renderer = "gl_compatibility"
	credits = clampi(int(file.get_value("profile", "credits", 0)), 0, 2000000000)
	difficulty = clampi(int(file.get_value("profile", "difficulty", 1)), 1, 99)
	for key in UPGRADES: levels[key] = clampi(int(file.get_value("upgrades", key, 0)), 0, 99)
	var saved_builds=file.get_value("build_stealer","records",[])
	if saved_builds is Array:build_records=BuildStealer.ranked(saved_builds)
	var saved_stash=file.get_value("equipment","stash",[])
	if saved_stash is Array:
		var ids={}
		for raw in saved_stash:
			var item=GearLoot.validate(raw)
			if item.is_empty() or ids.has(item.id) or gear_stash.size()>=STASH_LIMIT:continue
			gear_stash.append(item);ids[item.id]=true
	var saved_equipped=file.get_value("equipment","equipped",{})
	if saved_equipped is Dictionary:
		for slot in GearLoot.SLOTS:
			var id=str(saved_equipped.get(slot,""));var item=gear_item(id)
			if not item.is_empty() and GearLoot.compatible(item,slot) and not gear_equipped.values().has(id):gear_equipped[slot]=id
	next_gear_id=maxi(1,int(file.get_value("equipment","next_id",1)))
	var saved_daily=file.get_value("daily","state",{})
	if saved_daily is Dictionary:daily=saved_daily.duplicate(true)
	normalize_daily()
	refresh_daily(false)


func save_profile() -> bool:
	if not persistent: return true
	var file = ConfigFile.new()
	file.set_value("audio","music_volume",music_volume)
	file.set_value("controls","smart_cast",smart_cast)
	file.set_value("match","allied_bots",allied_bots)
	file.set_value("graphics","edge_smoothing",edge_smoothing)
	file.set_value("graphics","world_sharpness",world_sharpness)
	file.set_value("graphics","frame_limit",frame_limit)
	file.set_value("graphics","vsync",vsync_enabled)
	file.set_value("graphics","fullscreen",fullscreen_enabled)
	file.set_value("view","view_3d",view_3d)
	file.set_value("view","view_3d_chosen",view_3d_chosen)
	file.set_value("view","camera",view_camera)
	file.set_value("view","quality",view_quality)
	file.set_value("view","renderer",renderer)
	file.set_value("profile", "credits", credits)
	file.set_value("profile", "difficulty", difficulty)
	for key in UPGRADES: file.set_value("upgrades", key, int(levels.get(key, 0)))
	file.set_value("profile","schema",3)
	file.set_value("build_stealer","records",build_records)
	file.set_value("equipment","stash",gear_stash)
	file.set_value("equipment","equipped",gear_equipped)
	file.set_value("equipment","next_id",next_gear_id)
	file.set_value("daily","state",daily)
	# Replace only after the complete new profile has been written successfully.
	var error = file.save(save_path+".tmp")
	if error==OK:error=DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))
	save_error = "" if error == OK else "Could not save progression (%d)" % error
	return error == OK

# One-time copy of the classic 2D profile into this build's user dir (HowlingRift3D) when it has no save yet.
# The legacy file is only read, never changed. Returns true when a copy was made.
func migrate_legacy_save(legacy_path: String = "") -> bool:
	if FileAccess.file_exists(save_path): return false
	var source = legacy_path if not legacy_path.is_empty() else OS.get_data_dir().path_join(LEGACY_SAVE)
	var target = ProjectSettings.globalize_path(save_path)
	if source.is_empty() or not FileAccess.file_exists(source): return false
	if ProjectSettings.globalize_path(source).simplify_path() == target.simplify_path(): return false
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source), target) == OK

func cost(key: String) -> int:
	# Long-term progression: early ranks take several runs; later ranks are a grind.
	var lv = clampi(int(levels.get(key, 0)), 0, 99)
	return int(ceil(UPGRADES[key].cost * pow(1.0 + 0.22 * lv, 2.0) * (1.0 + 0.015 * lv)))

func buy(key: String) -> bool:
	if GameState.started: return false # Account purchases are between runs only.
	if not UPGRADES.has(key) or int(levels.get(key, 0)) >= 99: return false
	var price = cost(key)
	if credits < price: return false
	credits -= price
	levels[key] = int(levels.get(key, 0)) + 1
	if save_profile(): return true
	credits += price
	levels[key] -= 1
	return false

func bonuses() -> Dictionary:
	var result = {}
	for key in UPGRADES:
		result[UPGRADES[key].stat] = UPGRADES[key].value * int(levels.get(key, 0))
	var gear=equipment_bonuses()
	for stat in gear:result[stat]=result.get(stat,0.)+gear[stat]
	return result

func begin_match() -> void:
	awarded = false
	last_reward = 0
	last_drops.clear()
	refresh_daily()

func reward_multiplier(stage: int) -> float:
	var n = float(clampi(stage, 1, 99)-1)
	return 1.0 + n*0.08 + n*n*0.0004

func reward_preview(stage: int) -> String:
	return "Credits x%.2f • Win %d+ / Loss %d+" % [reward_multiplier(stage), int(round(100*reward_multiplier(stage))), int(round(30*reward_multiplier(stage)))]

func complete_match(won: bool, seconds: float, kills: int, stage: int, cs: int = 0) -> int:
	if awarded: return last_reward
	var previous={"credits":credits,"stash":gear_stash.duplicate(true),"daily":daily.duplicate(true),"next":next_gear_id}
	awarded = true
	# Both results pay; higher stages improve rewards. Time/kill bonuses are bounded.
	last_reward = int(round((30 + (70 if won else 0) + clampi(int(seconds / 30), 0, 40) + clampi(kills, 0, 30) * 3) * reward_multiplier(stage)))
	credits = mini(2000000000, credits + last_reward)
	refresh_daily(false)
	# A completed victory counts; defeats need two minutes of play to count for quests.
	if won or seconds>=120.:
		var progress=daily.progress
		progress.matches=mini(3,progress.matches+1)
		progress.wins=mini(1,progress.wins+(1 if won else 0))
		progress.kills=mini(12,progress.kills+clampi(kills,0,100))
		progress.cs=mini(80,progress.cs+clampi(cs,0,1000))
		for key in DAILY_QUESTS:
			var quest=DAILY_QUESTS[key]
			if progress[quest.field]>=quest.goal and not daily.ready.has(key):daily.ready[key]=clampi(stage,1,99)
		grant_ready_drops()
	if not save_profile():
		credits=previous.credits;gear_stash=previous.stash;daily=previous.daily;next_gear_id=previous.next
		last_reward=0;last_drops.clear();awarded=false
	return last_reward

func scaling(stage: int) -> Dictionary:
	var n = float(clampi(stage, 1, 99) - 1)
	return {"experience":1.0+n*.02+n*n*.00015,"health": 1.0 + n * 0.045 + n * n * 0.0013, "damage": 1.0 + n * 0.03 + n * n * 0.0006, "armor": n * 0.8, "magic_resist": n * 0.65, "speed": 1.0 + n * 0.0015, "attack_speed": 1.0 + n * 0.007, "reaction": 0.3 / (1.0 + n * 0.025), "vision": 440.0 + n * 3.0, "chase": 3.5 + n * 0.055, "structure_health": 1.0 + n * 0.16 + n * n * 0.004, "structure_damage": 1.0 + n * 0.065 + n * n * 0.0008}

func difficulty_preview(stage: int) -> String:
	var stats=scaling(stage)
	return "N%d\nEnemy HP x%.2f • Damage x%.2f\nEnemy structure HP x%.2f • Tower damage x%.2f\nEnemy armor +%.1f • Magic resistance +%.1f\nEnemy XP x%.2f · Bonus gold begins after an enemy hero's 10th death\nHigher N also improves attack speed, reaction and pursuit.\nDaily relic level %d–%d · Epic/Legendary chance %.0f%%" % [clampi(stage,1,99),stats.health,stats.damage,stats.structure_health,stats.structure_damage,stats.armor,stats.magic_resist,stats.experience,maxi(1,stage-2),clampi(stage,1,99),(GearLoot.rarity_odds(stage)[3]+GearLoot.rarity_odds(stage)[4])*100.]

func today() -> String:
	return clock_date if not clock_date.is_empty() else Time.get_date_string_from_system(false)
func normalize_daily() -> void:
	var progress=daily.get("progress",{})
	if not progress is Dictionary:progress={}
	var clean={}
	for field in ["matches","wins","kills","cs"]:clean[field]=clampi(int(progress.get(field,0)),0,{"matches":3,"wins":1,"kills":12,"cs":80}[field])
	var claimed=daily.get("claimed",[]);var ready=daily.get("ready",{})
	var valid_claims=[];var valid_ready={}
	for key in DAILY_QUESTS:
		var quest=DAILY_QUESTS[key]
		if clean[quest.field]<quest.goal:continue
		if claimed is Array and claimed.has(key):valid_claims.append(key)
		if ready is Dictionary and ready.has(key):valid_ready[key]=clampi(int(ready[key]),1,99)
	daily={"date":str(daily.get("date","")),"progress":clean,"claimed":valid_claims,"ready":valid_ready}
func refresh_daily(persist_change: bool = true) -> void:
	var date=today()
	# A clock rollback cannot reset a previously claimed day.
	if str(daily.get("date",""))>=date:return
	var previous=daily.duplicate(true)
	daily={"date":date,"progress":{"matches":0,"wins":0,"kills":0,"cs":0},"claimed":[],"ready":{}}
	if persist_change and not save_profile():daily=previous
func grant_ready_drops() -> void:
	for key in DAILY_QUESTS:
		if not daily.ready.has(key) or daily.claimed.has(key) or gear_stash.size()>=STASH_LIMIT:continue
		var id="relic_%d" % next_gear_id
		while not gear_item(id).is_empty():next_gear_id+=1;id="relic_%d" % next_gear_id
		var item=GearLoot.roll(int(daily.ready[key]),loot_rng,id)
		next_gear_id+=1;gear_stash.append(item);last_drops.append(item.duplicate(true));daily.claimed.append(key)
func claim_pending() -> bool:
	if GameState.started:return false
	refresh_daily()
	var previous={"stash":gear_stash.duplicate(true),"daily":daily.duplicate(true),"next":next_gear_id,"drops":last_drops.duplicate(true)}
	grant_ready_drops()
	if save_profile():return true
	gear_stash=previous.stash;daily=previous.daily;next_gear_id=previous.next;last_drops=previous.drops
	return false
func gear_item(id: String) -> Dictionary:
	for item in gear_stash:
		if item.id==id:return item
	return {}
func equip_gear(id: String,slot: String) -> bool:
	if GameState.started:return false
	var item=gear_item(id)
	if item.is_empty() or not GearLoot.compatible(item,slot):return false
	var previous=gear_equipped.duplicate()
	for other in gear_equipped.keys():
		if gear_equipped[other]==id:gear_equipped.erase(other)
	gear_equipped[slot]=id
	if save_profile():return true
	gear_equipped=previous;return false
func unequip_gear(slot: String) -> bool:
	if GameState.started or not gear_equipped.has(slot):return false
	var previous=gear_equipped.duplicate();gear_equipped.erase(slot)
	if save_profile():return true
	gear_equipped=previous;return false
func salvage_gear(id: String) -> bool:
	if GameState.started or gear_equipped.values().has(id):return false
	var item=gear_item(id)
	if item.is_empty():return false
	var previous=gear_stash.duplicate(true);var balance=credits
	gear_stash.erase(item);credits=mini(2000000000,credits+salvage_value(item))
	if save_profile():return true
	gear_stash=previous;credits=balance;return false
func salvage_value(item: Dictionary) -> int:
	return 5+item.level*(item.rarity+1)*2
func equipment_bonuses() -> Dictionary:
	var result={};var used=[]
	for slot in gear_equipped:
		var item=gear_item(str(gear_equipped[slot]))
		if item.is_empty() or not GearLoot.compatible(item,slot) or used.has(item.id):continue
		used.append(item.id)
		for stat in item.stats:result[stat]=result.get(stat,0.)+item.stats[stat]
	for stat in GearLoot.CAPS:
		if result.has(stat):result[stat]=minf(result[stat],GearLoot.CAPS[stat])
	return result
func daily_summary() -> String:
	return "Daily gear drops: %d / 5 · Resets at local midnight" % daily.get("claimed",[]).size()
func drop_summary() -> String:
	var names=PackedStringArray()
	for item in last_drops:names.append("%s %s (Lv %d)" % [GearLoot.RARITIES[item.rarity],item.name,item.level])
	return "Gear drops: "+"; ".join(names) if not names.is_empty() else daily_summary()
