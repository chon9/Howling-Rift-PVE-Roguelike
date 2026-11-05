extends Node
# Hardware cursors stay responsive independently of the match simulation.
var main: Node2D
var state: String = ""
var cursor_size: int = 0
var textures: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in ["default", "attack", "ally", "attack_move", "aim", "blocked", "hand"]:
		textures[key] = load("res://assets/ui/cursors/%s.png" % key)
	refresh()

func state_at(point: Vector2, over_ui: bool = false) -> String:
	if over_ui or not GameState.running or GameState.paused: return "default"
	var p = GameState.player
	if not is_instance_valid(p) or p.dead: return "blocked"
	if GameState.attack_move_pending: return "attack_move"
	if is_instance_valid(main.skill_aimer) and main.skill_aimer.aiming_idx >= 0: return "aim"
	var target = GameState.find_target_at(point, -1, 8)
	if target != null: return "ally" if target.team == p.team else "attack"
	return "default"

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(main): return
	var hovered = get_viewport().gui_get_hovered_control()
	var control = hovered
	while control != null:
		if control is BaseButton:
			control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			break
		control = control.get_parent_control()
	var next = state_at(main.cursor_ui_point(), hovered != null)
	var size_px = clampi(int(48 * get_window().size.y / 1080.0), 32, 64)
	if next == state and size_px == cursor_size: return
	state = next
	cursor_size = size_px
	if DisplayServer.get_name() == "headless": return
	var centered = state in ["attack_move", "aim"]
	Input.set_custom_mouse_cursor(_scaled(state), Input.CURSOR_ARROW,
		Vector2.ONE * (cursor_size / 2.0 if centered else cursor_size / 16.0))
	Input.set_custom_mouse_cursor(_scaled("hand"), Input.CURSOR_POINTING_HAND, Vector2.ONE * cursor_size / 16.0)

func _scaled(key: String) -> Texture2D:
	var img: Image = textures[key].get_image()
	img.resize(cursor_size, cursor_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
