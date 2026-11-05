class_name ReticleText
extends RefCounted
## Reticle captions shared by 2D (_ReticleLayer) and 3D (OverheadLayer). "offset" is authored 2D px from the anchor.
## Complete and frozen (W0-B). Each item: {text, size, color, anchor ("cursor"|"unit"), unit, world, offset}.


static func labels(cursor: Vector2) -> Array:
	var out: Array = []
	if not GameState.running: return out
	var p = GameState.player
	if p == null or p.dead: return out
	if GameState.attack_move_pending:
		out.append({"text": "A • CLICK TO ATTACK", "size": 15, "color": Color(1, 0.9, 0.5), "anchor": "cursor", "unit": null, "world": cursor, "offset": Vector2(18, -18)})
		for creep in GameState.minions:
			if creep.dead or creep.team == p.team: continue
			if p.world_pos().distance_to(creep.world_pos()) > p.atk_range + creep.size * 0.3: continue
			if creep.hp <= GameState.last_hit_damage(p, creep):
				out.append({"text": "LAST HIT", "size": 10, "color": Color(1, 0.85, 0.2), "anchor": "unit", "unit": creep, "world": creep.world_pos(), "offset": Vector2(-16, -42)})
	var mark = NewHeroKits.recast_info(p, 0)
	if p.hero_key in ["leesin", "thresh"] and not mark.is_empty():
		var target = mark.target
		out.append({"text": "Q2 %.1fs" % mark.time, "size": 15, "color": Color("ceffff"), "anchor": "unit", "unit": target, "world": target.world_pos(), "offset": Vector2(-30, -48)})
	return out


static func draw_2d(canvas: CanvasItem, items: Array) -> void:
	for item in items:
		canvas.draw_string(ThemeDB.fallback_font, item.world + item.offset, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.size, item.color)
