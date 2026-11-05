extends Node
## W3-SETTINGS: Rift3D settings persistence, precedence, legacy-save migration, renderer override, settings rows,
## live quality / camera application, 3D MSAA in GraphicsQuality, MatchLoading's 3D frame count and ViewWarmup.
## Headless; run with "-- --view3d" or HOWLING_VIEW=3d (the 3D part forces 3D through View3DTestKit anyway).
## Never touches the real profile: every file lives under user://view3d-settings-test-*.

const TMP := "user://view3d-settings-test-profile.cfg"
const TMP_LEGACY := "user://view3d-settings-test-legacy.cfg"
const TMP_OVERRIDE := "user://view3d-settings-test-override.cfg"

var failures = 0
var checks = 0
var _saved := {}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	await get_tree().process_frame
	_snapshot()
	_test_save_load()
	_test_clamp()
	_test_precedence()
	_test_migration()
	_test_renderer_override()
	_test_rows_2d()
	await _test_loading_frames(2, "2D")
	await _test_match()
	_restore()
	_cleanup_files()
	print("VIEW3D SETTINGS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- persistence ---

func _test_save_load() -> void:
	Progression.save_path = TMP
	Progression.persistent = true
	Progression.view_3d = false
	Progression.view_3d_chosen = true
	Progression.view_camera = "mlbb"
	Progression.view_quality = "low"
	Progression.renderer = "forward_plus"
	check(Progression.save_profile(), "view settings save")
	Progression.view_3d = true
	Progression.view_3d_chosen = false
	Progression.view_camera = "lol"
	Progression.view_quality = "high"
	Progression.renderer = "gl_compatibility"
	Progression.load_profile()
	check(not Progression.view_3d and Progression.view_3d_chosen, "VIEW choice survives reopening")
	check(Progression.view_camera == "mlbb" and Progression.view_quality == "low", "camera and 3D quality survive reopening")
	check(Progression.renderer == "forward_plus", "renderer choice survives reopening")
	var cfg := ConfigFile.new()
	check(cfg.load(TMP) == OK and cfg.get_value("view", "camera", "") == "mlbb", "settings are stored in the [view] section")
	# A profile written before W3 (no [view] section) gets the defaults without losing anything else.
	var legacy := ConfigFile.new()
	legacy.set_value("profile", "credits", 777)
	legacy.save(TMP)
	Progression.load_profile()
	check(Progression.view_3d and not Progression.view_3d_chosen, "old saves default to 3D but count as not chosen")
	check(Progression.view_camera == "lol" and Progression.view_quality == "high" and Progression.renderer == "gl_compatibility", "old saves get LoL / High / Compatibility")
	check(Progression.credits == 777, "old save credits untouched")
	Progression.persistent = false


func _test_clamp() -> void:
	var bad := ConfigFile.new()
	bad.set_value("view", "camera", "dota")
	bad.set_value("view", "quality", "ultra")
	bad.set_value("view", "renderer", "vulkan")
	bad.set_value("view", "view_3d", 0)
	bad.save(TMP)
	Progression.save_path = TMP
	Progression.load_profile()
	check(Progression.view_camera == "lol", "unknown camera clamps to LoL")
	check(Progression.view_quality == "high", "unknown quality clamps to High")
	check(Progression.renderer == "gl_compatibility", "unknown renderer clamps to Compatibility")
	check(Progression.view_3d == false, "numeric VIEW value is read as a bool")
	Progression.persistent = false


# --- precedence: command line > environment > saved > defaults ---

func _flag_mode() -> int:
	# -1 none, 0 forced 2D, 1 forced 3D (the same order configure() applies: --view2d is checked last).
	var args := OS.get_cmdline_user_args()
	if args.has("--view2d"):
		return 0
	if args.has("--view3d"):
		return 1
	return -1


func _test_precedence() -> void:
	var env_before := OS.get_environment("HOWLING_VIEW")
	var flags := _flag_mode()
	# Not loaded (tests, tools): saved values are ignored entirely.
	Progression.persistent = false
	Progression.view_3d_chosen = true
	Progression.view_3d = false
	Progression.view_camera = "mlbb"
	Progression.view_quality = "low"
	ViewConfig.enabled = true
	ViewConfig.preset = "lol"
	ViewConfig.quality = "high"
	ViewConfig.apply_saved(Progression)
	check(ViewConfig.enabled and ViewConfig.preset == "lol" and ViewConfig.quality == "high", "an unloaded profile never overrides ViewConfig")
	# Loaded profile, VIEW never chosen: camera and quality apply, the shipped default for VIEW stands.
	Progression.persistent = true
	Progression.view_3d_chosen = false
	ViewConfig.enabled = true
	ViewConfig.apply_saved(Progression)
	check(ViewConfig.enabled, "an unchosen VIEW keeps the default")
	check(ViewConfig.preset == "mlbb" and ViewConfig.quality == "low", "saved camera and quality apply")
	ViewConfig.enabled = false
	ViewConfig.apply_saved(Progression)
	check(not ViewConfig.enabled, "an unchosen VIEW keeps a 2D default too")
	# Chosen VIEW applies when nothing overrides it.
	Progression.view_3d_chosen = true
	Progression.view_3d = true
	ViewConfig.apply_saved(Progression)
	check(ViewConfig.enabled, "chosen 3D applies")
	Progression.view_3d = false
	ViewConfig.apply_saved(Progression)
	check(not ViewConfig.enabled, "chosen classic 2D applies")
	# configure(): environment beats saved, flags beat both.
	OS.set_environment("HOWLING_VIEW", "")
	Progression.view_3d = true
	ViewConfig.enabled = false
	ViewConfig.configure()
	check(ViewConfig.enabled == (true if flags == -1 else flags == 1), "configure applies saved 3D when no env var (flags still win)")
	OS.set_environment("HOWLING_VIEW", "2d")
	ViewConfig.configure()
	check(ViewConfig.enabled == (false if flags == -1 else flags == 1), "HOWLING_VIEW=2d beats saved 3D")
	check(ViewConfig.mode_override() == ("HOWLING_VIEW=2d" if flags == -1 else ("--view2d" if flags == 0 else "--view3d")), "mode_override names the winning override")
	Progression.view_3d = false
	OS.set_environment("HOWLING_VIEW", "3D")
	ViewConfig.configure()
	check(ViewConfig.enabled == (true if flags == -1 else flags == 1), "HOWLING_VIEW=3d (any case) beats saved 2D")
	check(ViewConfig.preset == "mlbb" and ViewConfig.quality == "low", "configure applies saved camera and quality")
	Progression.view_camera = "nonsense"
	ViewConfig.preset = "lol"
	ViewConfig.apply_saved(Progression)
	check(ViewConfig.preset == "lol", "an invalid saved camera is ignored")
	OS.set_environment("HOWLING_VIEW", "")
	if flags == -1:
		check(ViewConfig.mode_override() == "", "no override without env var or flag")
	OS.set_environment("HOWLING_VIEW", env_before)
	Progression.persistent = false
	Progression.view_camera = "lol"
	Progression.view_quality = "high"


# --- one-time legacy save copy ---

func _test_migration() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	var legacy := ConfigFile.new()
	legacy.set_value("profile", "credits", 4242)
	legacy.set_value("graphics", "world_sharpness", 0.5)
	legacy.save(TMP_LEGACY)
	Progression.save_path = TMP
	check(Progression.migrate_legacy_save(ProjectSettings.globalize_path(TMP_LEGACY)), "missing profile copies the legacy save")
	Progression.load_profile()
	check(Progression.credits == 4242 and is_equal_approx(Progression.world_sharpness, 0.5), "copied profile keeps credits and settings")
	var changed := ConfigFile.new()
	changed.set_value("profile", "credits", 1)
	changed.save(TMP_LEGACY)
	check(not Progression.migrate_legacy_save(ProjectSettings.globalize_path(TMP_LEGACY)), "an existing profile is never overwritten (one-time copy)")
	Progression.load_profile()
	check(Progression.credits == 4242, "existing profile untouched by a second migration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	check(not Progression.migrate_legacy_save(ProjectSettings.globalize_path("user://view3d-settings-test-missing.cfg")), "no legacy file means no copy")
	check(not FileAccess.file_exists(TMP), "nothing is created without a legacy file")
	check(not Progression.migrate_legacy_save(ProjectSettings.globalize_path(TMP)), "a file never copies onto itself")
	check(Progression.LEGACY_SAVE.ends_with("Howling Rift/progression.cfg"), "legacy path targets the classic game's user dir")
	Progression.persistent = false
	Progression.credits = 0
	Progression.world_sharpness = 0.35


# --- renderer override.cfg ---

func _test_renderer_override() -> void:
	var path := ProjectSettings.globalize_path(TMP_OVERRIDE)
	var keep := ConfigFile.new()
	keep.set_value("display", "window/size/mode", 0)
	keep.save(path)
	check(RiftMenus.write_renderer_override("forward_plus", path) == OK, "Forward+ override written")
	var cfg := ConfigFile.new()
	cfg.load(path)
	check(cfg.get_value("rendering", "renderer/rendering_method", "") == "forward_plus", "override.cfg sets [rendering] renderer/rendering_method")
	check(cfg.get_value("display", "window/size/mode", -1) == 0, "other override.cfg settings are kept")
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("[rendering]") and text.contains("renderer/rendering_method=\"forward_plus\""), "override.cfg uses the project settings syntax")
	check(RiftMenus.write_renderer_override("gl_compatibility", path) == OK, "Compatibility override written")
	cfg = ConfigFile.new()
	cfg.load(path)
	check(cfg.get_value("rendering", "renderer/rendering_method", "") == "gl_compatibility", "switching back writes Compatibility")
	check(RiftMenus.write_renderer_override("forward_plus", "") == ERR_UNAVAILABLE, "no path (development build) reports unavailable")
	check(RiftMenus.write_renderer_override("metal", path) == ERR_INVALID_PARAMETER, "unknown renderer rejected")
	if OS.has_feature("editor"):
		check(RiftMenus.renderer_override_path() == "", "editor/dev runs never write override.cfg into the project")


# --- settings rows ---

func _rows() -> VBoxContainer:
	var panel := VBoxContainer.new()
	add_child(panel)
	RiftMenus.view_settings(panel, null)
	return panel


func _test_rows_2d() -> void:
	Progression.persistent = false
	ViewConfig.enabled = false
	ViewConfig.preset = "lol"
	ViewConfig.quality = "medium"
	Progression.renderer = "gl_compatibility"
	var panel := _rows()
	var mode := panel.find_child("ViewMode", true, false) as OptionButton
	var cam := panel.find_child("ViewCamera", true, false) as OptionButton
	var level := panel.find_child("ViewQuality", true, false) as OptionButton
	var render := panel.find_child("ViewRenderer", true, false) as OptionButton
	var note := panel.find_child("ViewSettingsNote", true, false) as Label
	check(mode != null and cam != null and level != null and render != null and note != null, "VIEW, CAMERA, 3D QUALITY and RENDERER rows exist")
	if mode == null or cam == null or level == null or render == null or note == null:
		panel.queue_free()
		return
	check(mode.item_count == 2 and cam.item_count == 2 and level.item_count == 3 and render.item_count == 2, "row options: 3D/2D, LoL/MLBB, Low/Medium/High, Compatibility/Forward+")
	check(mode.selected == 1 and cam.selected == 0 and level.selected == 1 and render.selected == 0, "rows show the current settings")
	var env_before := OS.get_environment("HOWLING_VIEW")
	OS.set_environment("HOWLING_VIEW", "")
	mode.select(0)
	mode.item_selected.emit(0)
	check(Progression.view_3d and Progression.view_3d_chosen, "VIEW row stores the choice")
	if _flag_mode() == -1:
		check(ViewConfig.enabled, "VIEW row sets the next-match mode")
		check(note.text.contains("next match"), "VIEW row explains when it applies")
	OS.set_environment("HOWLING_VIEW", "2d")
	mode.select(0)
	mode.item_selected.emit(0)
	check(note.text.contains("HOWLING_VIEW=2d") or note.text.contains("--view"), "an env override is explained instead of silently ignored")
	OS.set_environment("HOWLING_VIEW", env_before)
	cam.select(1)
	cam.item_selected.emit(1)
	check(Progression.view_camera == "mlbb" and ViewConfig.preset == "mlbb", "CAMERA row sets MLBB")
	level.select(0)
	level.item_selected.emit(0)
	check(Progression.view_quality == "low" and ViewConfig.quality == "low", "3D QUALITY row sets Low")
	render.select(1)
	render.item_selected.emit(1)
	check(Progression.renderer == "forward_plus", "RENDERER row stores Forward+")
	if OS.has_feature("editor"):
		check(note.text.contains("--rendering-method forward_plus"), "RENDERER row warns when override.cfg cannot be written")
	panel.queue_free()
	Progression.renderer = "gl_compatibility"
	Progression.view_3d_chosen = false
	Progression.view_3d = true
	ViewConfig.preset = "lol"
	ViewConfig.quality = "high"


# --- MatchLoading.finish_render frame count ---

func _test_loading_frames(expected: int, label: String) -> void:
	var loader := MatchLoading.new()
	add_child(loader)
	var f0 := Engine.get_process_frames()
	var ok: bool = await loader.finish_render()
	var frames := Engine.get_process_frames() - f0
	# Headless counts process frames exactly; windowed waits on frame_post_draw, which may resolve in the
	# frame that is already drawing, so allow one frame less there.
	var lo := expected if DisplayServer.get_name() == "headless" else expected - 1
	check(ok and frames >= lo and frames <= expected, "%s finish_render waits %d frames (got %d)" % [label, expected, frames])
	loader.queue_free()


# --- inside a 3D match ---

func _test_match() -> void:
	var game: Node2D = View3DTestKit.start_3d_match(self, "ashe")
	var v = game.view3d
	check(v != null and v.is_active(), "3D match active")
	if v == null or not v.is_active():
		return
	await get_tree().process_frame
	v.sync_now()
	await _test_loading_frames(4, "3D")
	# GraphicsQuality.apply drives the 3D MSAA; the layer-1 screen pass keeps its semantics.
	var gq = game.graphics_quality
	ViewConfig.quality = "medium"
	gq.apply()
	check(get_viewport().msaa_3d == Viewport.MSAA_2X, "GraphicsQuality.apply sets MSAA 2x for Medium")
	ViewConfig.quality = "high"
	gq.apply()
	check(get_viewport().msaa_3d == Viewport.MSAA_4X, "GraphicsQuality.apply sets MSAA 4x for High")
	check(gq.layer == 1 and gq.screen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "FXAA layer unchanged")
	# The real settings menu carries the rows, and they apply live to the running 3D match.
	game._show_start_upgrades()
	await get_tree().process_frame
	var level = game.menu.find_child("ViewQuality", true, false)
	var cam = game.menu.find_child("ViewCamera", true, false)
	check(level != null and cam != null and game.menu.find_child("ViewMode", true, false) != null and game.menu.find_child("ViewRenderer", true, false) != null, "settings menu shows the Rift3D rows under graphics")
	if DisplayServer.get_name() != "headless":
		var scroll = game.menu.find_child("SettingsScroll", true, false)
		var row = game.menu.find_child("ViewModeRow", true, false)
		if scroll != null and row != null:
			await get_tree().process_frame
			scroll.scroll_vertical = int(maxf(0.0, row.position.y - 260.0))
			await get_tree().process_frame
			var img: Image = await View3DTestKit.capture(self)
			if img != null:
				img.save_png("res://tests/72-3d-settings.png")
	if level != null:
		check(level.selected == 2, "3D QUALITY row shows High")
		level.select(0)
		level.item_selected.emit(0)
		check(v.overlay.size == Vector2i(2048, 1024), "Low applies the small ground canvas live")
		check(get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "Low turns MSAA off live")
		var sun = v.arena.get("sun")
		if sun != null:
			check(not sun.shadow_enabled, "Low turns sun shadows off live")
		level.select(2)
		level.item_selected.emit(2)
		check(v.overlay.size == Vector2i(3072, 1536) and get_viewport().msaa_3d == Viewport.MSAA_4X, "High restores canvas and MSAA")
	if cam != null:
		cam.select(1)
		cam.item_selected.emit(1)
		check(v.rig.preset_name == "mlbb" and is_equal_approx(v.rig.pitch(), 50.0), "CAMERA row switches the live rig to MLBB")
		cam.select(0)
		cam.item_selected.emit(0)
		check(v.rig.preset_name == "lol" and is_equal_approx(v.rig.pitch(), 56.0), "CAMERA row switches back to LoL")
	game.menu.hide()
	# ViewWarmup: one unit_card per hero (and minion kind), every FX shader, freed afterwards; sim untouched.
	var serials := {}
	for u in GameState.champions + GameState.minions:
		serials[u.get_instance_id()] = [u.global_position, u.visible, u.modulate]
	await v.warm_up()
	var rep: Dictionary = ViewWarmup.last_report
	var heroes := {}
	for c in GameState.champions:
		heroes["hero_" + str(c.hero_key)] = true
	var all_heroes := true
	for k in heroes:
		if not (rep.get("unit_keys", []) as Array).has(k):
			all_heroes = false
	check(all_heroes, "warm-up draws a unit_card for every hero key in the match")
	for id in ["fx_card_mix", "fx_card_add", "projectile_shape", "beam_scroll", "hook_chain", "pillar_add", "brush_card"]:
		check((rep.get("shaders", []) as Array).has(id), "warm-up covers " + id)
	check(int(rep.get("frames", 0)) == ViewWarmup.WARM_FRAMES, "warm-up holds the samples for 2 frames")
	var headless := DisplayServer.get_name() == "headless"
	check(bool(rep.get("particles", headless)) != headless, "GPU particle sample only when rendering (none in headless)")
	await get_tree().process_frame
	check(v.get_node_or_null("ViewWarmup") == null, "warm-up samples are freed")
	var untouched := true
	for u in GameState.champions + GameState.minions:
		var s = serials.get(u.get_instance_id())
		if s != null and (s[0] != u.global_position or s[1] != u.visible or s[2] != u.modulate):
			untouched = false
	check(untouched, "warm-up never writes sim fields")
	ViewConfig.preset = "lol"
	ViewConfig.quality = "high"
	game._return_to_main_menu()
	await get_tree().process_frame
	check(not ViewConfig.is_active(), "3D inactive after return to menu")


# --- state hygiene ---

func _snapshot() -> void:
	_saved = {
		"path": Progression.save_path, "persistent": Progression.persistent, "credits": Progression.credits,
		"sharp": Progression.world_sharpness, "v3d": Progression.view_3d, "chosen": Progression.view_3d_chosen,
		"cam": Progression.view_camera, "q": Progression.view_quality, "r": Progression.renderer,
		"enabled": ViewConfig.enabled, "preset": ViewConfig.preset, "quality": ViewConfig.quality,
		"env": OS.get_environment("HOWLING_VIEW"),
	}


func _restore() -> void:
	Progression.save_path = _saved.path
	Progression.persistent = _saved.persistent
	Progression.credits = _saved.credits
	Progression.world_sharpness = _saved.sharp
	Progression.view_3d = _saved.v3d
	Progression.view_3d_chosen = _saved.chosen
	Progression.view_camera = _saved.cam
	Progression.view_quality = _saved.q
	Progression.renderer = _saved.r
	ViewConfig.enabled = _saved.enabled
	ViewConfig.preset = _saved.preset
	ViewConfig.quality = _saved.quality
	OS.set_environment("HOWLING_VIEW", _saved.env)


func _cleanup_files() -> void:
	for p in [TMP, TMP + ".tmp", TMP_LEGACY, TMP_OVERRIDE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
