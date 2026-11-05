class_name ViewWarmup
extends RefCounted
## Shader / particle warm-up behind the loading overlay (W3-SETTINGS). Main._launch_game awaits
## View3D.warm_up() -> ViewWarmup.run(host) right after _start_game, while MatchLoading's overlay (layer 90) still
## covers the screen. One sample of every 3D shader and blend variant is drawn in front of the live camera for
## WARM_FRAMES frames, so the first real missile, beam or hero card does not hitch on a pipeline compile; then
## every sample is freed. The samples are plain nodes under a "ViewWarmup" root and never touch sim state.

const WARM_FRAMES := 2
const SPACING_M := 0.7
const MINION_KEYS := ["minion_melee", "minion_caster", "minion_siege", "minion_super"]
const SHADERS := {
	"fx_card_mix": "res://assets/shaders/view3d/fx_card_mix.gdshader",
	"fx_card_add": "res://assets/shaders/view3d/fx_card_add.gdshader",
	"projectile_shape": "res://assets/shaders/view3d/projectile_shape.gdshader",
	"beam_scroll": "res://assets/shaders/view3d/beam_scroll.gdshader",
	"hook_chain": "res://assets/shaders/view3d/hook_chain.gdshader",
	"pillar_add": "res://assets/shaders/view3d/pillar_add.gdshader",
	"brush_card": "res://assets/shaders/view3d/brush_card.gdshader",
	"brush_card_fade": "res://assets/shaders/view3d/brush_card_fade.gdshader",
}

## What the last run drew: {"unit_keys", "shaders", "particles", "frames", "nodes"}. Diagnostics and tests.
static var last_report: Dictionary = {}


static func run(host: Node3D) -> void:
	last_report = {"unit_keys": [], "shaders": [], "particles": false, "frames": 0, "nodes": 0}
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var tree := host.get_tree()
	var cam: Camera3D = host.call("camera") if host.has_method("camera") else null
	if cam == null or not cam.is_inside_tree():
		await tree.process_frame
		last_report.frames = 1
		return
	var headless := DisplayServer.get_name() == "headless"
	var root := Node3D.new()
	root.name = "ViewWarmup"
	host.add_child(root)
	var samples: Array = []
	for key in unit_keys():
		var card := SpriteUnitView3D.make_card("Warm_" + str(key))
		var height: float = Constants.CHAMP_ART_HEIGHT if str(key).begins_with("hero_") else 40.0
		SpriteUnitView3D.apply_cell(card, card.material_override as ShaderMaterial, key, "idle", 0, height, false)
		samples.append(card)
		last_report.unit_keys.append(key)
	for id in SHADERS:
		var path: String = SHADERS[id]
		if not ResourceLoader.exists(path):
			continue
		var quad := MeshInstance3D.new()
		quad.name = "Warm_" + str(id)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.6, 0.6)
		quad.mesh = mesh
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = load(path)
		mat.set_shader_parameter("max_lod", ViewConfig.MAX_LOD)
		quad.material_override = mat
		samples.append(quad)
		last_report.shaders.append(id)
	if not headless:
		# GPU particles only when rendering (headless has no GPU; plan global rule 6).
		samples.append(_particles())
		last_report.particles = true
	for s in samples:
		root.add_child(s)
	_place(samples, cam)
	last_report.nodes = samples.size()
	for f in range(WARM_FRAMES):
		if headless:
			await tree.process_frame
		else:
			await RenderingServer.frame_post_draw
		last_report.frames = f + 1
		if not is_instance_valid(root) or not is_instance_valid(cam):
			break
		_place(samples, cam)
	if is_instance_valid(root):
		# Detach now (nothing of the samples may be drawn or found after run() returns), free at frame end.
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.queue_free()


## Animation keys that get one unit_card sample each: every champion in the match plus the minion kinds.
static func unit_keys() -> Array:
	var keys: Array = []
	for c in GameState.champions:
		if c == null or not is_instance_valid(c):
			continue
		var key := "hero_" + str(c.get("hero_key"))
		if not keys.has(key) and SpriteUnitView3D.has_art(key):
			keys.append(key)
	for kind in MINION_KEYS:
		if SpriteUnitView3D.has_art(kind):
			keys.append(kind)
	return keys


## Lines the samples up across the screen centre at the camera's focus distance, facing the camera.
static func _place(samples: Array, cam: Camera3D) -> void:
	if not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var basis := cam.global_transform.basis
	var dist := 8.0
	var vp := cam.get_viewport()
	if vp != null:
		var hit = ViewMath.ground_hit(cam, vp.get_visible_rect().get_center())
		if hit is Vector3:
			dist = clampf(cam.global_position.distance_to(hit), 2.0, 40.0)
	var centre := cam.global_position - basis.z * dist
	var n := samples.size()
	for i in range(n):
		var s = samples[i]
		if not is_instance_valid(s) or not s.is_inside_tree():
			continue
		var x := (float(i) - float(n - 1) * 0.5) * SPACING_M
		s.global_transform = Transform3D(basis, centre + basis.x * x)


static func _particles() -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "Warm_particles"
	gp.amount = 8
	gp.lifetime = 0.5
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	gp.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	mesh.material = mat
	gp.draw_pass_1 = mesh
	gp.emitting = true
	return gp
