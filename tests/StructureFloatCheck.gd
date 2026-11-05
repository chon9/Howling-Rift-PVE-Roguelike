extends Node
## Private windowed capture for the structure grounding fix (run without --headless, "-- --view3d").
## Saves base shots of both teams and an outer turret, then hides one 3D layer at a time and reports how much
## each layer changes the frame (used to trace stray glow sprites). Output dir: "--out=<abs dir>" (default res://tests/).

var game: Node2D
var view: View3D
var out_dir := "res://tests/"


func _ready() -> void:
	await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--out="):
			out_dir = str(a).substr(6).trim_suffix("/") + "/"
	if DisplayServer.get_name() == "headless":
		print("STRUCTURE FLOAT CHECK: skipped in headless")
		get_tree().quit(0)
		return
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	seed(20261013)
	Progression.persistent = false
	GameState.reset()
	ViewConfig.enabled = true
	OS.set_environment("HOWLING_VIEW", "3d")
	game = load("res://scripts/Main.gd").new()
	add_child(game)
	game.set_process(false)
	game._start_game("ashe", {"blue": ["ashe", "garen", "lux"], "red": ["darius", "annie", "ezreal"], "mode": "pve", "stolen_builds": []})
	view = game.view3d
	GameState.running = true
	GameState.paused = true
	for c in GameState.champions:
		c.global_position = Vector2(1400 + 30 * GameState.champions.find(c), 120)
	await _frames(6)
	await _shot("float_base_blue.png", Constants.FOUNT_B + Vector2(350, 0), true)
	await _shot("float_base_red.png", Constants.FOUNT_R - Vector2(350, 0), false)
	var outer: Node2D = null
	for s in GameState.structures:
		if s.type == "turret" and (outer == null or absf(s.global_position.x - 1400.0) < absf(outer.global_position.x - 1400.0)):
			outer = s
	if outer != null:
		await _shot("float_outer_turret.png", outer.global_position + Vector2(0, 60), false)
		# Destroyed: the card dissolves to the ruin plinth + rubble under the painted base's centre.
		outer.dead = true
		outer.visible = false
		GameState.paused = false
		await _frames(90)
		GameState.paused = true
		await _shot("float_dead_turret.png", outer.global_position + Vector2(0, 60), false)
	await _blink_probe()
	print("STRUCTURE FLOAT CHECK: done")


## Reproduces View3DVisual's bot loop (30 sim frames per rendered frame, then a paused capture) and lists the
## blink flares UnitExtras3D spawns: a champion walking > BLINK_PX between two view syncs reads as a blink, and
## FxCard3D flares do not age while GameState.paused, so the last batch stays frozen in the capture.
func _blink_probe() -> void:
	GameState.paused = false
	for c in GameState.champions:
		c.is_bot = true
		c.global_position = Vector2(500 + 40 * GameState.champions.find(c), 270)
	for i in range(240):
		game._process(1.0 / 60.0)
		if i % 30 == 0:
			await get_tree().process_frame
	GameState.paused = true
	await _frames(3)
	var n := 0
	for f in view.fx_root.get_children():
		if str(f.name).begins_with("Flare_"):
			n += 1
			print("  frozen flare %s at sim %s" % [f.name, f.get("flare_at")])
	print("  frozen blink flares after the batched bot loop: %d" % n)
	var focus: Vector2 = GameState.player.global_position if GameState.player != null else Vector2(700, 270)
	await _shot("float_blink_probe.png", Vector2(focus.x, 270), false)
	get_tree().quit(0)


func _shot(file: String, focus: Vector2, layers: bool) -> void:
	GameState.cam_locked = false
	GameState.cam_target = focus
	game.camera.position = focus
	game.camera_shake_offset = Vector2.ZERO
	view.sync_now()
	await _frames(4)
	var img: Image = await View3DTestKit.capture(self)
	if img == null:
		return
	img.save_png(out_dir + file)
	print("saved %s" % (out_dir + file))
	var cam := view.camera()
	for s in GameState.structures:
		var sp := cam.unproject_position(ViewMath.to3(s.global_position))
		if Rect2(0, 0, 1920, 1080).has_point(sp):
			print("  %s team %d foot screen %s" % [s.type, s.team, sp.round()])
	if not layers:
		return
	# Layer attribution: hide one layer, capture, report the share of changed pixels per structure neighbourhood.
	var probes := {"units": view.units_root, "fx": view.fx_root, "overhead": view.overhead, "arena": view.arena}
	for key in probes:
		var n = probes[key]
		if n == null:
			continue
		n.visible = false
		await _frames(3)
		var alt: Image = await View3DTestKit.capture(self)
		n.visible = true
		print("  hide %-8s changes %.1f%% of the frame" % [key, 100.0 * View3DTestKit.diff_ratio(img, alt, Rect2i(0, 0, img.get_width(), img.get_height()))])
		if alt != null and key in ["units", "fx"]:
			alt.save_png(out_dir + "float_hide_%s.png" % key)
	# Per-structure glow quads.
	for v in view.units_root.get_children():
		if v is StructureView3D:
			(v as StructureView3D).glow.visible = false
	await _frames(1)
	for v in view.units_root.get_children():
		if v is StructureView3D:
			(v as StructureView3D).glow.visible = false
	var no_glow: Image = await View3DTestKit.capture(self)
	no_glow.save_png(out_dir + "float_hide_structure_glow.png")
	print("  hide structure glow changes %.1f%% of the frame" % (100.0 * View3DTestKit.diff_ratio(img, no_glow, Rect2i(0, 0, img.get_width(), img.get_height()))))
	view.sync_now()
	# Small visible meshes near the ground (candidate glow sprites), with their screen positions.
	for n in view.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var bb := g.get_aabb()
		if bb.size.length() > 4.0:
			continue
		var sp := cam.unproject_position(g.global_position)
		if Rect2(0, 0, 1920, 1080).has_point(sp):
			print("  mesh %s (%s) parent %s at %s screen %s" % [g.name, g.get_class(), g.get_parent().name, g.global_position.snapped(Vector3.ONE * 0.01), sp.round()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
