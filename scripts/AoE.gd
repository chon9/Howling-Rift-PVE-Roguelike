extends Node2D
class_name AoE

var src = null
var team: int = 0
var radius: float = 100
var dmg: float = 0
var duration: float = 0.5
var elapsed: float = 0.0
var hit_set: Array = []
var cone_ang: float = -999.0
var arc: float = 0.0
var color: Color = Color.WHITE
var slow_pct: float = 0.0
var slow_duration: float = 0.0
var art_row: int = -1
var stun_time: float = 0.0
var wind_kind: int = -1
var damage_type: String = "skill"
var ring: bool = false
var tick_interval: float = 0
var next_tick: float = 0
var effect_id: String = ""
var effect_dir: Vector2 = Vector2.RIGHT
var zone_kind: String = ""
var arm_delay: float = 0.0
var follows_src: bool = false
var airborne_time: float = 0.
var spell_id: String = ""
var special_hit: bool = false
# Retained for protocol 8 snapshots; spell art no longer draws collision outlines.
var readable_boundary: bool = false
var footprint_kind: String = ""
var footprint_width: float = 0.
var broken_walls: Array = [false,false,false,false,false]
var previous_positions: Dictionary = {}

func setup(_src, pos: Vector2, opts: Dictionary) -> void:
	effect_id=opts.get("effect_id", "");effect_dir=opts.get("effect_dir",Vector2.RIGHT);zone_kind=opts.get("zone_kind", "");arm_delay=opts.get("arm_delay",0.);follows_src=opts.get("follows_src",false)
	special_hit=opts.get("special_hit",false)
	footprint_kind=opts.get("footprint_kind","");footprint_width=opts.get("footprint_width",0.)
	spell_id=opts.get("spell_id",effect_id)
	airborne_time=opts.get("airborne",0.)
	src = _src
	damage_type=opts.get("damage_type","skill");ring=opts.get("ring",false);tick_interval=opts.get("tick_interval",0.)
	team = _src.team
	global_position = pos
	radius = opts.get("radius", 100)
	dmg = opts.get("dmg", 0)
	if dmg>0 and SkillFootprint.AREA_RADII.has(spell_id) and zone_kind not in ["lantern","soul","dagger","sphere"]:radius=SkillFootprint.AREA_RADII[spell_id]
	# Trap siblings share hit history; explosions can exclude their direct victim.
	hit_set = opts.get("hit_set",[])
	duration = opts.get("duration", 0.5)
	cone_ang = opts.get("cone_ang", -999.0)
	arc = opts.get("arc", 0.0)
	color = opts.get("color", Color.WHITE)
	slow_pct = opts.get("slow", 0.0)
	stun_time = opts.get("stun",0.0)
	wind_kind = int(opts.get("wind_kind",-1))
	slow_duration = opts.get("slow_dur", 0.0)
	z_index = Constants.Z_AOE
	art_row = SpellArt.row_for(src)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void:
	if zone_kind in ["soul","dagger"]:
		# Rift3D: the pickup icon stands up as a ZoneProp3D card.
		if ViewConfig.is_active():return
		var icon=AbilityArt.icon_for("thresh" if zone_kind=="soul" else "katarina",1 if zone_kind=="soul" else 0)
		draw_texture_rect(icon,Rect2(-12,-24,24,24),false,Color(1,1,1,.85))
		return
	if KitEffectArt.has_effect(effect_id):
		_draw_kit_effect()
		draw_set_transform(Vector2.ZERO)
		return
	if cone_ang>-900:
		var region=SpellArt.frame(SpellArt.impacts,maxi(0,art_row),mini(7,int(elapsed/duration*8)))
		draw_set_transform(Vector2.ZERO,cone_ang)
		var sector=footprint();sector.angle=0.
		var extent=radius*sin(arc*.5)
		SkillFootprint.draw_clipped(self,SpellArt.impacts,region,Rect2(0,-extent,radius,extent*2),sector,Color(1,1,1,.7))
		draw_set_transform(Vector2.ZERO)
		return
	if ring:
		var fade=clampf((duration-elapsed)*2.,0.,1.)
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(color,fade*.85),7.,true)
		# Rift3D: the upright spikes are ZoneProp3D bars; the arc stays on the ground.
		if ViewConfig.is_active():return
		for i in range(8):
			var point=Vector2.from_angle(i*TAU/8.)*radius
			draw_line(point,point+Vector2(0,-30),Color(color,fade),5.,true)
		return
	if wind_kind >= 0:
		if ViewConfig.is_active():return
		draw_texture_rect_region(WindArt.texture,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),WindArt.frame(wind_kind,mini(3,int(elapsed/duration*4))),Color(1,1,1,0.9))
		return
	if art_row >= 0:
		draw_texture_rect_region(SpellArt.impacts, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), SpellArt.frame(SpellArt.impacts, art_row, mini(7, int(elapsed / duration * 8))), Color(1, 1, 1, 0.7))
		return
	# Untextured effects retain a soft glow, without a hard perimeter.
	var alpha = 0.55 * (1.0 - elapsed / duration)
	if alpha < 0: alpha = 0
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, alpha * 0.6))

func update_frame(delta: float) -> void:
	elapsed += delta
	if follows_src and is_instance_valid(src) and not src.dead:global_position=src.world_pos()
	if zone_kind=="silence_field":
		_support_silence(delta)
		queue_redraw()
		if elapsed>=duration:GameState.aoes.erase(self);queue_free()
		return
	if zone_kind in ["sphere","trap","heal_field","soul","dagger"]:
		_roster_zone(delta)
		queue_redraw()
		if elapsed>=duration:GameState.aoes.erase(self);queue_free()
		return
	if zone_kind in ["box","cage","lantern"]:
		_update_zone()
		queue_redraw()
		if elapsed>=duration:GameState.aoes.erase(self);queue_free()
		return
	if tick_interval>0 and elapsed>=next_tick:
		hit_set.clear();next_tick=elapsed+tick_interval
	# Deal damage once per entity
	if dmg > 0 and elapsed >= arm_delay:
		var collision=footprint()
		var cands = GameState.minions + GameState.champions + GameState.structures
		for u in cands:
			if hit_set.has(u) or u == null or u.dead or u.team == team or not u.is_targetable:
				continue
			if u.kind=="structure" and effect_id.get_slice("_",0) in RosterExpansion12.KEYS:continue
			if u.kind == "structure" and not u.is_structure_attackable():
				continue
			var d = global_position.distance_to(u.world_pos())
			if SkillFootprint.contains(collision,(u.world_pos()-global_position).rotated(-effect_dir.angle() if footprint_kind in ["capsule","rectangle"] else 0.),u.size*.3):
				var payload=Roster12Combat.special_damage(effect_id,src,u,dmg,global_position) if special_hit else dmg
				get_tree().call_group("game_main", "deal_damage", src, u, payload, damage_type,spell_id)
				hit_set.append(u)
				var guarded="buffs" in u and (u.buffs.has("cc_guard") or u.buffs.has("spell_guard") or u.buffs.has("parry"))
				if airborne_time>0 and not guarded:HeroControl.airborne(u,airborne_time)
				if stun_time > 0 and "stun" in u and not guarded: u.stun = maxf(u.stun,stun_time)
				if slow_pct > 0 and "buffs" in u and not guarded:
					u.buffs["slow"] = {"pct": slow_pct, "time": slow_duration}
	queue_redraw()
	if elapsed >= duration:
		GameState.aoes.erase(self)
		queue_free()

func _draw_kit_effect() -> void:
	var view3d_active=ViewConfig.is_active()
	if view3d_active:
		# Rift3D: side-view kit art stands up as a ZoneProp3D card / ribbon; the ground keeps a soft footprint.
		var standing=ZoneProp3D.kind_of(self)
		if standing==ZoneProp3D.KIND_STAND or standing==ZoneProp3D.KIND_BAND:
			_draw_soft_footprint(standing==ZoneProp3D.KIND_BAND)
			return
	var frame=mini(3,int(elapsed/maxf(.01,duration)*4))
	if zone_kind in ["box","cage"]:frame=0 if elapsed<arm_delay else 3 if duration-elapsed<.35 else 1+int(elapsed*3)%2
	if effect_id=="veigar_w":frame=0 if elapsed<arm_delay*.6 else 1 if elapsed<arm_delay else 2 if elapsed<arm_delay+.2 else 3
	var sheet=KitEffectArt.sheet(effect_id);var region=KitEffectArt.region(effect_id,frame)
	var rect=Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2)
	if effect_id in ["veigar_w","veigar_e"]:rect=KitEffectArt.ground_rect(effect_id,radius)
	if footprint_kind=="capsule":
		draw_set_transform(Vector2.ZERO,effect_dir.angle());rect=Rect2(-radius-footprint_width,-footprint_width,(radius+footprint_width)*2,footprint_width*2)
	elif effect_id=="xinzhao_q":
		if view3d_active:return
		draw_set_transform(Vector2(0,-25),effect_dir.angle());rect=Rect2(-radius*.5,-radius*.18,radius,radius*.36)
	elif effect_id=="xinzhao_e":
		if view3d_active:return
		draw_set_transform(Vector2(0,-32),effect_dir.angle());rect=Rect2(-radius*.6,-radius*.28,radius*1.2,radius*.56)
	if effect_id=="thresh_e":
		draw_set_transform(Vector2.ZERO,effect_dir.angle());rect=Rect2(-220,-65,440,130)

	if cone_ang>-900 or footprint_kind in ["capsule","rectangle"]:
		var local_shape=footprint()
		if cone_ang>-900:
			draw_set_transform(Vector2.ZERO,cone_ang);local_shape.angle=0.
			var extent=radius*sin(arc*.5)
			rect=Rect2(0,-extent,radius,extent*2)
		SkillFootprint.draw_clipped(self,sheet,region,rect,local_shape,Color(1,1,1,.9))
	elif KitEffectArt.has_ground_profile(effect_id):KitEffectArt.draw_ground(self,effect_id,frame,radius,Color(1,1,1,.9),broken_walls if zone_kind=="box" else [],view3d_active)
	elif not (view3d_active and zone_kind in ["sphere","trap","lantern"]):draw_texture_rect_region(sheet,rect,region,Color(1,1,1,.9))
	if zone_kind=="lantern" and not view3d_active and is_instance_valid(GameState.player) and GameState.player.team==team:
		draw_string(ThemeDB.fallback_font,Vector2(-44,38),"RIGHT-CLICK",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b9ffe6"))
# Rift3D ground part of a standing kit effect: a faint tinted fill and a thin rim over the hit area (circle, or the
# band's rectangle / capsule along effect_dir), fading out with the effect.
func _draw_soft_footprint(band: bool) -> void:
	var fade=1.-smoothstep(.7,1.,elapsed/maxf(.01,duration))
	var fill=Color(color,.1*fade);var rim=Color(color,.35*fade)
	if not band:
		draw_circle(Vector2.ZERO,radius,fill)
		draw_arc(Vector2.ZERO,radius,0,TAU,48,rim,2.,true)
		return
	draw_set_transform(Vector2.ZERO,effect_dir.angle())
	if footprint_kind=="capsule":
		var w=footprint_width
		draw_rect(Rect2(-radius,-w,radius*2,w*2),fill)
		draw_arc(Vector2(-radius,0),w,PI*.5,PI*1.5,24,rim,2.,true)
		draw_arc(Vector2(radius,0),w,-PI*.5,PI*.5,24,rim,2.,true)
		draw_line(Vector2(-radius,-w),Vector2(radius,-w),rim,2.,true)
		draw_line(Vector2(-radius,w),Vector2(radius,w),rim,2.,true)
	else:
		var r=Rect2(-220,-65,440,130) if effect_id=="thresh_e" else Rect2(-radius,-footprint_width,radius*2,footprint_width*2)
		draw_rect(r,fill)
		draw_rect(r,rim,false,2.)
	draw_set_transform(Vector2.ZERO)
func _update_zone() -> void:
	if zone_kind=="lantern":
		if not is_instance_valid(src) or src.dead:return
		for ally in GameState.champions:
			if ally.dead or ally.team!=team or hit_set.has(ally) or ally.world_pos().distance_to(global_position)>100:continue
			CombatEffects.shield(ally,"lantern_shield",dmg,4.,src);hit_set.append(ally)
		return
	for unit in GameState.champions+GameState.minions:
		if unit.dead or unit.team==team or (zone_kind=="box" and unit.kind!="champion"):continue
		var key=unit.get_instance_id();var before=previous_positions.get(key,unit.world_pos());previous_positions[key]=unit.world_pos()
		if elapsed<arm_delay:continue
		# Blinks can bypass a cage; ordinary movement and forced movement cannot.
		if before.distance_to(unit.world_pos())>180:before=unit.world_pos()
		if zone_kind=="cage":
			if hit_set.has(unit):continue
			var closest=Geometry2D.get_closest_point_to_segment(global_position,before,unit.world_pos())
			if closest.distance_to(global_position)>radius+unit.size*.3+10 or maxf(before.distance_to(global_position),unit.world_pos().distance_to(global_position))<radius-unit.size*.3-10:continue
			hit_set.append(unit)
			if not unit.buffs.has("cc_guard") and not unit.buffs.has("spell_guard") and not ExpansionCombat.spell_block(unit,"magic"):
				unit.stun=maxf(unit.stun,stun_time)
				if "is_dashing" in unit:unit.is_dashing=false
		else:
			for wall in range(5):
				if broken_walls[wall]:continue
				var a=global_position+Vector2.from_angle(-PI/2+wall*TAU/5)*radius
				var b=global_position+Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*radius
				var near=Geometry2D.get_closest_point_to_segment(unit.world_pos(),a,b).distance_to(unit.world_pos())<12+unit.size*.3
				if not near and Geometry2D.segment_intersects_segment(before,unit.world_pos(),a,b)==null:continue
				var first=not broken_walls.has(true);broken_walls[wall]=true
				if first:NewHeroKits.hit(src,unit,dmg,"magic")
				if not unit.dead and not unit.buffs.has("cc_guard") and not unit.buffs.has("spell_guard"):unit.buffs.slow={"pct":.99,"time":2. if first else 1.}
				break
func try_lantern(unit,point: Vector2) -> bool:
	if zone_kind!="lantern" or not is_instance_valid(src) or src.dead or unit==src or unit.team!=team or unit.dead or unit.stun>0 or point.distance_to(global_position)>55 or unit.world_pos().distance_to(global_position)>180:return false
	if unit.is_bot and not BotSafety.can_enter(unit,src.world_pos()):return false
	unit.stop_actions();unit.dash_target=src.world_pos();unit.is_dashing=true
	return true

func _roster_zone(delta: float) -> void:
	if not is_instance_valid(src) or (src.dead and zone_kind!="soul"):elapsed=duration;return
	if zone_kind=="sphere" or elapsed<arm_delay:return
	if zone_kind=="soul":
		if src.dead:return
		var collected=src.world_pos().distance_to(global_position)<65
		for a in GameState.aoes:
			if a.src==src and a.zone_kind=="lantern" and a.global_position.distance_to(global_position)<65:collected=true
		if collected:src.passive_state.souls=int(src.passive_state.get("souls",0))+1;HeroPassives.add_stats(src,.75,.75);elapsed=duration
		return
	if zone_kind=="dagger":
		if src.world_pos().distance_to(global_position)<65:
			elapsed=duration;src.skill_cds[2]*=.22
			for u in Roster12Kits.enemies(src,src.world_pos(),140):HeroPassives.proc(src,u,35.+mini(src.level,18)*6.+src.bonus_ap*.65+src.bonus_ad*.5)
		return
	if zone_kind=="heal_field":
		for ally in GameState.champions:
			if not ally.dead and ally.team==team and ally.world_pos().distance_to(global_position)<=radius:Roster12Combat.heal(ally,(25.+src.ad*.12)*delta);HeroPassives.support(src,ally)
		return
	for unit in GameState.champions:
		if unit.dead or unit.team==team or unit.world_pos().distance_to(global_position)>radius+unit.size*.3:continue
		Roster12Kits.control(unit,1.5);unit.buffs.rifle_mark={"time":4.,"src":src};elapsed=duration;break

func footprint() -> Dictionary:
	if zone_kind=="lantern":return SkillFootprint.circle(100.)
	if footprint_kind=="capsule":return SkillFootprint.capsule(radius*2,footprint_width)
	if footprint_kind=="rectangle":return {"shape":"rectangle","length":radius*2,"width":footprint_width}
	if zone_kind=="box":return {"shape":"box","radius":radius}
	if ring or zone_kind=="cage":return {"shape":"ring","radius":radius,"width":22. if ring else 10.,"outer_width":0. if ring else 10.}
	return SkillFootprint.circle(radius,cone_ang,arc)

func _support_silence(delta: float) -> void:
	if not is_instance_valid(src):return
	for unit in GameState.champions+GameState.minions:
		if unit.dead or unit.team==team or unit.world_pos().distance_to(global_position)>radius+unit.size*.3:continue
		if unit.buffs.has("cc_guard") or unit.buffs.has("spell_guard") or unit.buffs.has("parry"):continue
		if not hit_set.has(unit):
			NewHeroKits.hit(src,unit,dmg,"magic");hit_set.append(unit)
		if unit.dead:continue
		unit.buffs.silence={"time":.15}
		if elapsed>=duration:
			unit.buffs.root={"time":1.}
			if unit.kind=="champion":unit.is_dashing=false
