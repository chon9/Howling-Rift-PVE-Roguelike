class_name ViewConfig
extends RefCounted
## Rift3D presentation constants and mode switches. Pure data + static helpers (no scene access).

const SUN_YAW_DEG := -35.0         # compass direction of the sun (shadow cards turn to face it)
const S := 0.02                    # metres per sim px. The ground plane is never scaled.
const UNIT_SCALE := 1.25           # champion / minion / corpse card height vs 2D art height
const MINION_SCALE := 1.05         # minion cards (and their corpses) are drawn a little smaller, so heroes stand out
const STRUCTURE_SCALE := 1.25      # structure card height vs Structure.art_rect
const FX_SCALE := 1.25             # upright FX and projectile sizes vs their 2D px sizes
const OVERHEAD_SCALE := 1.75       # screen px per authored 2D overhead px (bars, names, badges, floating text)
const OVERHEAD_SCALE_MINION := 1.2 # minion hp bars stay small (LoL): a 40-minion clump is not a wall of bars
## Floating combat text (final fix, declutter): smaller than the bars' OVERHEAD_SCALE so mid-fight text no longer
## covers the champions. Numbers ("-112", "+42g") stay punchy; worded callouts ("LEVEL 4", "TURRET DESTROYED",
## "+75g ASSIST", "Q +1") are drawn near their authored 2D size.
const FLOAT_SCALE_NUMBER := 1.35
const FLOAT_SCALE_WORD := 1.15
const CHEST_PX := 27.0             # 52 * Constants.CHAMP_ART_SCALE: hero missile / impact height in art px
const FX_RAY_BIAS_M := 0.3         # upright FX are pulled this far toward the camera along their view ray
const MAX_LOD := 1.25              # mip clamp for atlas cards (cell-bleed guard)
const PROCESS_PRIORITY := 100      # View3D runs after LanSession, Main and every UnitAnimator
const RECOLOR_RED_HEROES := false  # 2D never recoloured champions; team reads from rings and bars

const PRESETS := {
	"lol": {"pitch": 56.0, "fov": 40.0, "distance": 17.5, "focus_z": 0.8, "zoom_min": 15.0, "zoom_max": 21.0},
	"mlbb": {"pitch": 50.0, "fov": 40.0, "distance": 13.5, "focus_z": 0.3, "zoom_min": 13.5, "zoom_max": 13.5},
}
const DEFAULT_PRESET := "lol"
const ZOOM_STEP_M := 1.0
const ZOOM_EASE := 12.0
const ZOOM_2D_REFERENCE := 1.7                  # Constants.BATTLE_CAMERA_ZOOM; other camera.zoom values scale distance
const EDGE_PAN_SPEED_3D := 900.0                # sim px / s (2D keeps 540)
const CAM_Y_CLAMP_3D := Vector2(180.0, 360.0)   # unlocked cam_target.y range in 3D
## Vertical framing band of the 3D camera (CameraRig3D.follow clamps the focus with it, locked or not): the
## near rail (sim y CAM_DECK_Y.y) stays at or below screen row CAM_FRAME.y and the far parapet (sim y
## CAM_DECK_Y.x) at or above row CAM_FRAME.x (fractions of the screen height from the top). When both cannot
## hold (zoomed far out) the focus centres between the two limits.
const CAM_DECK_Y := Vector2(40.0, 482.0)
const CAM_FRAME := Vector2(0.24, 0.74)

const OVERLAY_TEXELS_PER_SIM_PX := 1.7
## GPU features plus two CPU levers (W3 fix: Low must buy frames, and its cost is mostly CPU side):
## "overlay_every" renders the GroundOverlay SubViewport every Nth frame (its camera and rect move only on those
## frames, so ground decals stay world-locked), "hover_every" re-picks the hovered unit every Nth frame (the
## cursor ground point still updates every frame). Low also drops the units' shadow capsules (no shadow maps).
const QUALITY := {
	"low": {"overlay": Vector2i(2048, 1024), "hd2d": false, "shadows": false, "msaa": Viewport.MSAA_DISABLED, "glow": false, "snow": false, "sway": false, "overlay_every": 2, "hover_every": 2},
	"medium": {"overlay": Vector2i(3072, 1536), "hd2d": true, "shadows": true, "msaa": Viewport.MSAA_2X, "glow": true, "snow": true, "sway": true, "overlay_every": 1, "hover_every": 1},
	"high": {"overlay": Vector2i(3072, 1536), "hd2d": true, "shadows": true, "msaa": Viewport.MSAA_4X, "glow": true, "snow": true, "sway": true, "overlay_every": 1, "hover_every": 1},
}

static var enabled: bool = true    # 3D for the NEXT match (W4: 3D is the default; --view2d / HOWLING_VIEW=2d / the VIEW row pick classic 2D).
static var preset: String = DEFAULT_PRESET
static var quality: String = "high"
static var _active: bool = false   # written only by View3D.activate()/_exit_tree()

static func configure() -> void:
	# Precedence: command line > environment > saved settings (W3) > defaults.
	apply_saved(_profile())
	var env := OS.get_environment("HOWLING_VIEW").to_lower()
	if env == "3d": enabled = true
	elif env == "2d": enabled = false
	var args := OS.get_cmdline_user_args()
	if args.has("--view3d"): enabled = true
	if args.has("--view2d"): enabled = false

static func is_active() -> bool:
	return _active

static func set_active(value: bool) -> void:
	_active = value

static func camera_preset() -> Dictionary:
	return PRESETS.get(preset, PRESETS[DEFAULT_PRESET])

static func quality_settings() -> Dictionary:
	return QUALITY.get(quality, QUALITY["high"])


## Card scale of a sim unit: STRUCTURE_SCALE for structures, MINION_SCALE for minions, else UNIT_SCALE.
static func scale_of(unit: Object) -> float:
	if unit == null:
		return UNIT_SCALE
	var kind := str(unit.get("kind"))
	if kind == "minion":
		return MINION_SCALE
	if kind == "structure":
		return STRUCTURE_SCALE
	return UNIT_SCALE


## Screen px per authored overhead px for a unit's bars: minions use the smaller OVERHEAD_SCALE_MINION.
static func overhead_scale_of(unit: Object) -> float:
	if unit != null and str(unit.get("kind")) == "minion":
		return OVERHEAD_SCALE_MINION
	return OVERHEAD_SCALE


## Saved settings (the Progression autoload) for the next match. Only a loaded profile applies: tests and tools
## never load one, so they keep the values they set. VIEW applies only once the player has chosen it in settings,
## so the shipped default (`enabled` above) stands until then.
static func apply_saved(profile: Object) -> void:
	if profile == null or not bool(profile.get("persistent")):
		return
	var cam := str(profile.get("view_camera"))
	if PRESETS.has(cam):
		preset = cam
	var q := str(profile.get("view_quality"))
	if QUALITY.has(q):
		quality = q
	if bool(profile.get("view_3d_chosen")):
		enabled = bool(profile.get("view_3d"))


## The launch flag or environment value that overrides the saved VIEW choice this session ("" when none).
static func mode_override() -> String:
	var args := OS.get_cmdline_user_args()
	if args.has("--view2d"):
		return "--view2d"
	if args.has("--view3d"):
		return "--view3d"
	var env := OS.get_environment("HOWLING_VIEW").to_lower()
	if env == "3d" or env == "2d":
		return "HOWLING_VIEW=" + env
	return ""


static func _profile() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Progression")
