extends Node
## W1-ARENA windowed review shots: lane at x 1400, blue base, red base (FakeView camera, "lol" preset).
## Checks: the four corners differ from the clear colour (no void), a hero standing at y = 110 keeps its head
## in front of the far wall, the near rail projects below the feet of a hero at the south edge, and lit
## regions match the Forward+ reference colours in either renderer (S5 parity).
## Outputs tests/65-3d-arena-lane.png, 65-3d-arena-blue.png, 65-3d-arena-red.png.

const CLEAR := Color(0.02, 0.03, 0.06)
const HERO_KEY := "hero_ahri"
## S5 renderer parity: mean RGB (0..255) of lit regions of 65-3d-arena-lane.png at 1920x1080, the midpoint of the
## Forward+ and Compatibility measurements. This check fails if either renderer drifts. Regions are in base-canvas px.
const PARITY := {
	"deck": {"rect": Rect2(1300, 560, 300, 140), "rgb": Color8(88, 77, 70)},
	"far parapet": {"rect": Rect2(100, 225, 500, 15), "rgb": Color8(43, 39, 40)},
	"near rail": {"rect": Rect2(100, 785, 1700, 15), "rgb": Color8(70, 68, 73)},
	"whole frame": {"rect": Rect2(0, 0, 1920, 1080), "rgb": Color8(55, 53, 58)},
}
const PARITY_TOL := 0.1   # per channel: 10% of the reference, at least 8 levels

var failures = 0
var checks = 0
var host: Node3D
var arena: WorldBuilder3D


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _ready() -> void:
	Progression.persistent = false
	GameState.reset()
	if DisplayServer.get_name() == "headless":
		print("ARENA3D VISUAL: skipped (headless)")
		print("ARENA3D VISUAL: 0 checks, 0 failures")
		get_tree().quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	host = View3DTestKit.make_fake_view(self)
	arena = WorldBuilder3D.new()
	add_child(arena)
	arena.build(null)
	arena.apply_quality(ViewConfig.quality_settings())
	var far_hero := _hero_card(Vector2(1410, 110))       # directly in front of a merlon
	var near_hero := _hero_card(Vector2(1330, 430))      # southern walkable edge, near rail behind its feet
	var lane_heroes := [_hero_card(Vector2(1250, 270)), _hero_card(Vector2(1520, 300))]
	for _i in range(8):
		await get_tree().process_frame
	# Lane at x 1400.
	await _shot(Vector2(1400, 270), "res://tests/65-3d-arena-lane.png")
	var with_hero: Image = await View3DTestKit.capture(self)
	_check_parity(with_hero)
	far_hero.visible = false
	near_hero.visible = false
	for h in lane_heroes:
		h.visible = false
	await get_tree().process_frame
	var without_hero: Image = await View3DTestKit.capture(self)
	_check_head(far_hero, with_hero, without_hero, "hero at y 110")
	_check_head(near_hero, with_hero, without_hero, "hero at y 430")
	_check_rail(Vector2(1330, 430))
	# Bases.
	await _shot(Constants.FOUNT_B + Vector2(350, 0), "res://tests/65-3d-arena-blue.png")
	await _shot(Constants.FOUNT_R - Vector2(350, 0), "res://tests/65-3d-arena-red.png")
	print("ARENA3D VISUAL: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _shot(focus: Vector2, path: String) -> void:
	host.pose(focus)
	arena.update(host, 0.016)
	for _i in range(4):
		await get_tree().process_frame
	var img: Image = await View3DTestKit.capture(self)
	check(img != null, "%s captured" % path)
	if img == null:
		return
	img.save_png(path)
	var w := img.get_width()
	var h := img.get_height()
	for c in [Vector2i(3, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4), Vector2i(w - 4, h - 4)]:
		var px := img.get_pixelv(c)
		var d := maxf(maxf(absf(px.r - CLEAR.r), absf(px.g - CLEAR.g)), absf(px.b - CLEAR.b))
		check(d > 0.015, "%s corner %s differs from the clear colour (%s)" % [path.get_file(), c, px])
	# Luminance variance in the centre: the deck is textured, not a flat colour.
	var sum := 0.0
	var sum2 := 0.0
	var n := 0
	for y in range(int(h * 0.35), int(h * 0.65), 6):
		for x in range(int(w * 0.35), int(w * 0.65), 6):
			var l := img.get_pixel(x, y).get_luminance()
			sum += l
			sum2 += l * l
			n += 1
	var mean := sum / n
	check(sum2 / n - mean * mean >= 0.0005, "%s centre is textured (variance %.5f)" % [path.get_file(), sum2 / n - mean * mean])


## A plain painted hero card (Sprite3D, unit-card geometry from plan 6 W1-UNITS step 2) for review shots.
func _hero_card(feet: Vector2) -> Node3D:
	var root := Node3D.new()
	root.position = ViewMath.to3(feet)
	var sp := Sprite3D.new()
	var data := ActionSpriteArt.entry(HERO_KEY)
	var cell := ActionSpriteArt.frame(HERO_KEY, "idle", 0)
	var reg := ActionSpriteArt.region(HERO_KEY, "idle", 0)
	sp.texture = ActionSpriteArt.texture_for_frame(HERO_KEY, "idle", 0)
	sp.region_enabled = true
	sp.region_rect = reg
	sp.centered = false
	sp.pixel_size = ViewConfig.S * ViewConfig.UNIT_SCALE * 56.0 / float(data.body_height)
	sp.offset = Vector2(-float(cell.pivot[0]), float(cell.pivot[1]) - reg.size.y)
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sp.rotation.x = -deg_to_rad(host.pitch_deg())
	root.add_child(sp)
	root.set_meta("top_px", -ActionSpriteArt.body_rect(HERO_KEY, 56.0).position.y)
	root.set_meta("feet", feet)
	host.add_unit_view(root)
	return root


func _to_image(img: Image, p: Vector2) -> Vector2:
	var vr := get_viewport().get_visible_rect().size
	return p * Vector2(img.get_size()) / vr


func _check_head(hero: Node3D, with_img: Image, without_img: Image, label: String) -> void:
	if with_img == null or without_img == null:
		check(false, "%s: captures exist" % label)
		return
	var cam: Camera3D = host.camera()
	var up: Vector3 = host.card_up()
	var feet: Vector2 = hero.get_meta("feet")
	var top: float = hero.get_meta("top_px")
	var head := _to_image(with_img, cam.unproject_position(ViewMath.lifted(feet, top, up)))
	var chest := _to_image(with_img, cam.unproject_position(ViewMath.lifted(feet, top * 0.75, up)))
	var half_w := maxf(6.0, (chest.y - head.y) * 0.6)
	var rect := Rect2i(Vector2i(int(head.x - half_w), int(head.y)), Vector2i(int(half_w * 2.0), int(maxf(4.0, chest.y - head.y))))
	var ratio := View3DTestKit.diff_ratio(with_img, without_img, rect)
	check(ratio > 0.15, "%s: the head is not covered by walls (%.0f%% of the head rect drawn)" % [label, ratio * 100.0])


func _check_parity(img: Image) -> void:
	if img == null:
		check(false, "parity: capture exists")
		return
	var renderer := RenderingServer.get_current_rendering_method()
	for key in PARITY:
		var r: Rect2 = PARITY[key].rect
		var want: Color = PARITY[key].rgb
		var a := Vector2i(_to_image(img, r.position))
		var b := Vector2i(_to_image(img, r.end))
		var sum := Vector3.ZERO
		var n := 0
		for y in range(a.y, b.y, 2):
			for x in range(a.x, b.x, 2):
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
		var mean := sum / maxf(n, 1) * 255.0
		var ref := Vector3(want.r, want.g, want.b) * 255.0
		var ok := n > 0
		for i in range(3):
			ok = ok and absf(mean[i] - ref[i]) <= maxf(8.0, ref[i] * PARITY_TOL)
		print("PARITY %s %s: mean (%.0f, %.0f, %.0f) ref (%.0f, %.0f, %.0f)" % [renderer, key, mean.x, mean.y, mean.z, ref.x, ref.y, ref.z])
		check(ok, "renderer parity (%s): %s mean (%.0f, %.0f, %.0f) within 10%% of the Forward+ reference (%.0f, %.0f, %.0f)" % [renderer, key, mean.x, mean.y, mean.z, ref.x, ref.y, ref.z])


func _check_rail(feet: Vector2) -> void:
	var cam: Camera3D = host.camera()
	var feet_y := cam.unproject_position(ViewMath.to3(feet)).y
	var rail_y := cam.unproject_position(ViewMath.to3(Vector2(feet.x, 470), 0.28)).y
	check(rail_y > feet_y, "near rail top projects below the feet of a hero at y %.0f (%.1f > %.1f)" % [feet.y, rail_y, feet_y])
