extends Node2D
# Draws a LoL-style range indicator under the player when the user hovers a
# skill slot in the HUD (or holds a skill key). Shows:
#   * cast range as a dashed circle around champion
#   * a skillshot preview that follows the cursor (line, cone, or target circle)

var aiming_idx: int = -1
var player = null
var override_aim: bool = false
var override_point: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = Constants.Z_AOE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_aim(p, idx: int) -> void:
	player = p
	aiming_idx = idx
	queue_redraw()

func clear_aim() -> void:
	aiming_idx = -1
	override_aim = false
	queue_redraw()

func _process(_delta: float) -> void:
	if aiming_idx >= 0:
		if player == null or player.dead:
			aiming_idx = -1
		queue_redraw()

func _draw() -> void:
	if aiming_idx < 0 or player == null or player.dead: return
	var sk = player.hero["skills"][aiming_idx]
	var rng = sk.get("range", 0.0)
	var kind = sk.get("kind", "self")
	var ppos = player.global_position
	var mouse = override_point if override_aim else (GameState.cursor_world if ViewConfig.is_active() else get_global_mouse_position())
	var atk_col = Color(1.0, 0.86, 0.33, 0.9)
	var line_col = Color(1.0, 0.86, 0.33, 0.5)

	# Base: dashed range circle
	if rng > 0:
		_draw_dashed_arc(ppos, rng, 72, line_col, 2.0, 10, 6)
	# Skillshot preview
	var cursor_dir = (mouse - ppos)
	var cursor_dist = cursor_dir.length()
	if cursor_dist < 0.001: cursor_dir = Vector2.RIGHT
	else: cursor_dir = cursor_dir.normalized()
	# Clamp to range for the aim point
	var aim_pt = ppos + cursor_dir * min(cursor_dist, rng if rng > 0 else cursor_dist)
	var footprint=SkillFootprint.preview(player,sk)
	if footprint.shape=="none":return
	var origin=ppos
	var angle=0.
	match footprint.at:
		"cursor","target":
			origin=aim_pt
			if kind=="target":
				var victim=NewHeroKits.target(player,mouse,rng)
				if is_instance_valid(victim):origin=victim.world_pos()
		"line":origin=ppos+cursor_dir*footprint.length*.5;angle=cursor_dir.angle()
		"direction":angle=cursor_dir.angle()
		"wall":origin=ppos+cursor_dir*50.;angle=cursor_dir.angle()
		"cone":footprint.angle=cursor_dir.angle()
	draw_set_transform(origin,angle)
	if footprint.shape=="traps":
		for offset in [-50,0,50]:
			draw_set_transform(origin+Vector2(offset,0))
			SkillFootprint.draw_outline(self,SkillFootprint.circle(footprint.radius),atk_col,true)
	else:SkillFootprint.draw_outline(self,footprint,atk_col,true)
	if sk.cast_id=="xinzhao_w":
		draw_set_transform(ppos)
		SkillFootprint.draw_outline(self,SkillFootprint.circle(125.,cursor_dir.angle(),PI*.65),line_col,true)
	draw_set_transform(Vector2.ZERO)

func _draw_dashed_arc(center: Vector2, radius: float, pts: int, col: Color,
		width: float, on_segs: int, off_segs: int) -> void:
	var period = on_segs + off_segs
	var prev = Vector2(center.x + radius, center.y)
	for i in range(1, pts + 1):
		var a = TAU * i / float(pts)
		var p = center + Vector2(cos(a), sin(a)) * radius
		if (i - 1) % period < on_segs:
			draw_line(prev, p, col, width, true)
		prev = p
