class_name LanSnapshot
extends RefCounted
const CHAMP_FIELDS = ["hp_regen","mp_regen","last_order_sequence","bonus_heal_power","bonus_mp_regen","is_dashing","roster_active","level","xp","gold","cs","hp","hp_max","mp","mp_max","shield","dead","respawn_at","is_targetable","kills","deaths","assists","skill_ranks","skill_cds","skill_points","level_bonus","comeback_gold_awarded","last_comeback_gold","summoner_cds","summoner_spells","inventory","run_bonus","consumable_bonus","consumable_counts","permanent_bonus","difficulty_stats","ad","atk_range","auto_type","bonus_ad","bonus_ap","bonus_hp","bonus_mp","bonus_as","bonus_ms","bonus_cdr","bonus_lifesteal","bonus_armor","bonus_mr","base_mr","bonus_armor_pen","bonus_magic_pen","bonus_lethality","bonus_reflect","bonus_hp_regen","bonus_crit","bonus_crit_damage","stun","recall_time","brush_revealed_until","vision_teams","passive_state","has_move_target","move_target","facing","attack_pulse","item_cds","attack_move","attack_move_destination","owner_peer","is_bot","char_name","auto_windup","anim_action","anim_elapsed","anim_duration","anim_windup","anim_released","anim_serial","anim_from","anim_to"]
static func clean_buffs(buffs: Dictionary) -> Dictionary:
 var result = {}
 for key in buffs:
  var buff = {}
  for field in buffs[key]:
   var value = buffs[key][field]
   if value is Object:
    if field == "src": buff["src_index"] = GameState.champions.find(value)
   else: buff[field] = value
  result[key] = buff
 return result
static func encode() -> Dictionary:
 var packet = {"time":GameState.time,"wave":GameState.wave_num,"score":GameState.score.duplicate(),"stage":GameState.difficulty,"reward":GameState.reward_difficulty,"allied_bots":GameState.allied_bots,"mode":GameState.match_mode,"team_size":GameState.team_size,"fill_bots":GameState.fill_bots,"champs":[],"minions":[],"structures":[],"projectiles":[],"aoes":[]}
 for c in GameState.champions:
  c.vision_teams=[BrushVision.visible_to(c,Constants.BLUE),BrushVision.visible_to(c,Constants.RED)]
  var state = {"position":c.world_pos(),"buffs":clean_buffs(c.buffs),"attack":target_ref(c.attack_target),"flay_charge":c.flay_charge}
  for field in CHAMP_FIELDS: state[field] = c.get(field)
  if LanSession.players.has(c.owner_peer): state.char_name = LanSession.players[c.owner_peer].name
  packet.champs.append(state)
 for m in GameState.minions:
  if m.dead: continue
  packet.minions.append({"id":m.get_instance_id(),"team":m.team,"subkind":m.subkind,"position":m.world_pos(),"hp":m.hp,"hp_max":m.hp_max,"stun":m.stun,"buffs":clean_buffs(m.buffs),"facing_sign":m.facing_sign,"attack_anim":m.attack_anim,"attack_windup":m.attack_windup,"anim_action":m.anim_action,"anim_elapsed":m.anim_elapsed,"anim_duration":m.anim_duration,"anim_windup":m.anim_windup,"anim_released":m.anim_released,"anim_serial":m.anim_serial,"anim_from":m.anim_from,"anim_to":m.anim_to})
 for s in GameState.structures:
  packet.structures.append({"hp":s.hp,"hp_max":s.hp_max,"dead":s.dead,"visible":s.visible,"is_targetable":s.is_targetable})
 for p in GameState.projectiles:
  if not is_instance_valid(p): continue
  packet.projectiles.append({"id":p.get_instance_id(),"source":target_ref(p.src),"team":p.team,"damage_type":p.damage_type,"position":p.global_position,"rotation":p.rotation,"dir":p.dir,"size":p.size,"color":p.color,"shape":p.shape,"art_row":p.art_row,"expansion_art":p.expansion_art,"is_ult":p.is_ult,"animation_time":p.animation_time,"hook_chain":p.hook_chain,"effect_id":p.effect_id,"wind_kind":p.wind_kind,"visual_height":p.visual_height,"visual_dimensions":p.visual_dimensions,"visual_scale":p.visual_scale})
 for a in GameState.aoes:
  if not is_instance_valid(a): continue
  packet.aoes.append({"id":a.get_instance_id(),"source":target_ref(a.src),"position":a.global_position,"radius":a.radius,"duration":a.duration,"elapsed":a.elapsed,"cone_ang":a.cone_ang,"arc":a.arc,"color":a.color,"art_row":a.art_row,"wind_kind":a.wind_kind,"ring":a.ring,"effect_id":a.effect_id,"effect_dir":a.effect_dir,"zone_kind":a.zone_kind,"arm_delay":a.arm_delay,"readable_boundary":a.readable_boundary,"footprint_kind":a.footprint_kind,"footprint_width":a.footprint_width,"broken_walls":a.broken_walls.duplicate(),"team":a.team})
 return packet
static func restore_buffs(buffs: Dictionary) -> Dictionary:
 var result = buffs.duplicate(true)
 for key in result:
  if result[key].has("src_index"):
   var index = result[key].src_index
   result[key].src = GameState.champions[index] if index >= 0 and index < GameState.champions.size() else null
   result[key].erase("src_index")
 return result
static func apply(packet: Dictionary, session) -> void:
 if not GameState.started: return
 GameState.time = packet.time
 GameState.wave_num = packet.wave
 GameState.score = packet.score
 GameState.difficulty = packet.stage
 GameState.allied_bots = bool(packet.get("allied_bots",true))
 GameState.match_mode=str(packet.get("mode","pve"));GameState.team_size=int(packet.get("team_size",3));GameState.fill_bots=bool(packet.get("fill_bots",true))
 GameState.reward_difficulty = packet.reward
 for index in range(mini(packet.champs.size(),GameState.champions.size())):
  var c = GameState.champions[index]
  var state = packet.champs[index]
  var was_dead = c.dead
  for field in CHAMP_FIELDS: c.set(field,state[field])
  if c.dead and not was_dead and c.roster_active: AnimatedCorpse.spawn(c)
  c.buffs = restore_buffs(state.buffs)
  session.record_position(c,state.position)
  if c == GameState.player: c.char_name = "You"
  c.name_label.text = c.char_name
  c._sync_bars()
  c.queue_redraw()
 for index in range(mini(packet.structures.size(),GameState.structures.size())):
  var structure = GameState.structures[index]
  for field in packet.structures[index]: structure.set(field,packet.structures[index][field])
  structure._sync_bar()
  structure.queue_redraw()
 reconcile(packet.minions,session.replica_minions,session,"minion")
 reconcile(packet.projectiles,session.replica_projectiles,session,"projectile")
 reconcile(packet.aoes,session.replica_aoes,session,"aoe")
 for index in range(mini(packet.champs.size(),GameState.champions.size())):
  GameState.champions[index].attack_target = resolve_target(packet.champs[index].attack,session)
 BrushVision.update_presentation()
 var ui = session.main.hud.get_node("HudRoot")
 ui.difficulty_label.text = "PVP • "+("BLUE" if GameState.player.team==0 else "RED") if GameState.is_pvp() else "N%d" % GameState.difficulty
 if GameState.player.dead: ui.show_death_overlay()
 else: ui.hide_death_overlay()
 if packet.has("draft"):
  var draft = session.main.lane_augments
  var changed = draft.pending != packet.draft.pending or draft.choices != packet.draft.choices
  draft.pending = packet.draft.pending.duplicate()
  draft.choices = packet.draft.choices.duplicate()
  draft.offers = packet.draft.get("offers",{}).duplicate(true)
  draft.picked = packet.draft.picked.duplicate()
  if changed and draft.panel.visible: draft.build_panel()
static func reconcile(states: Array, registry: Dictionary, session, type: String) -> void:
 var present = {}
 for state in states:
  present[state.id] = true
  if not registry.has(state.id):
   var node
   match type:
    "minion":
     node = session.main.MinionS.new()
     session.main.world_root.add_child(node)
     node.setup(state.team,state.subkind,state.position)
     GameState.minions.append(node)
    "projectile":
     node = session.main.ProjectileS.new()
     node.z_index = Constants.Z_PROJ
     node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
     session.main.world_root.add_child(node)
     GameState.projectiles.append(node)
    "aoe":
     node = session.main.AoES.new()
     node.z_index = Constants.Z_AOE
     session.main.world_root.add_child(node)
     GameState.aoes.append(node)
   registry[state.id] = node
   node.global_position = state.position
  var node = registry[state.id]
  for field in state:
   if field in ["id","position","subkind","source"]: continue
   node.set(field,restore_buffs(state[field]) if field == "buffs" else state[field])
  if type in ["projectile","aoe"]:node.src=resolve_target(state.get("source",{}),session)
  session.record_position(node,state.position)
  if type == "minion": node._sync_bar()
  node.queue_redraw()
 for id in registry.keys():
  if present.has(id): continue
  var node = registry[id]
  session.positions.erase(node);session.motion_samples.erase(node)
  GameState.minions.erase(node); GameState.projectiles.erase(node); GameState.aoes.erase(node)
  if type == "minion": AnimatedCorpse.spawn(node)
  node.queue_free()
  registry.erase(id)

static func target_ref(unit) -> Dictionary:
 if not is_instance_valid(unit): return {}
 return {"kind":unit.kind,"id":GameState.champions.find(unit) if unit.kind == "champion" else (GameState.structures.find(unit) if unit.kind == "structure" else unit.get_instance_id())}
static func resolve_target(reference: Dictionary, session):
 if reference.is_empty(): return null
 match reference.kind:
  "champion": return GameState.champions[reference.id] if reference.id >= 0 and reference.id < GameState.champions.size() else null
  "structure": return GameState.structures[reference.id] if reference.id >= 0 and reference.id < GameState.structures.size() else null
  "minion": return session.replica_minions.get(reference.id)
 return null
