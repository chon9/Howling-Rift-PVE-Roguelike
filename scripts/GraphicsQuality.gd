class_name GraphicsQuality
extends CanvasLayer
# A single native-resolution world-only canvas pass. HUD, menus and cursor render above layer 1.
var screen: ColorRect
func _ready() -> void:
 name = "GraphicsQuality"
 layer = 1
 screen = ColorRect.new()
 screen.name = "WorldEdgeSmoothing"
 screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var fx = ShaderMaterial.new()
 fx.shader = preload("res://assets/shaders/world-fxaa.gdshader")
 screen.material = fx
 add_child(screen)
 apply()
func _process(_delta: float) -> void:
 screen.visible = (Progression.edge_smoothing or Progression.world_sharpness>0.) and GameState.started
func apply() -> void:
 screen.material.set_shader_parameter("smoothing",.45 if Progression.edge_smoothing else 0.)
 screen.material.set_shader_parameter("sharpness",Progression.world_sharpness)
 screen.visible = (Progression.edge_smoothing or Progression.world_sharpness>0.) and GameState.started
 # Rift3D: the 3D frame gets hardware MSAA per 3D quality; the layer-1 FXAA/sharpen pass above is unchanged.
 var view=View3D.current
 if view!=null and is_instance_valid(view) and view.is_active():get_viewport().msaa_3d=ViewConfig.quality_settings().msaa
 # Headless checks don't render; don't throttle simulation tests.
 if DisplayServer.get_name() != "headless":
  Engine.max_fps = Progression.frame_limit
  var mode=DisplayServer.VSYNC_ENABLED if Progression.vsync_enabled else DisplayServer.VSYNC_DISABLED
  if DisplayServer.window_get_vsync_mode()!=mode:DisplayServer.window_set_vsync_mode(mode)
static func settings_row(parent: Control,quality: CanvasLayer) -> void:
 var smooth = CheckButton.new()
 smooth.name = "EdgeSmoothing"
 smooth.text = "LIGHT EDGE SMOOTHING"
 smooth.button_pressed = Progression.edge_smoothing
 smooth.tooltip_text = "Light smoothing preserves fine sprite details and overhead text. Rendering stays at your display resolution. To remove the extra GPU pass, switch this off and set world sharpness to 0%."
 smooth.toggled.connect(func(enabled): Progression.edge_smoothing = enabled; quality.apply(); Progression.save_profile())
 parent.add_child(smooth)
 var clarity_row=HBoxContainer.new()
 clarity_row.add_child(RiftMenus.label("WORLD SHARPNESS",20))
 var sharp=HSlider.new();sharp.name="WorldSharpness";sharp.custom_minimum_size=Vector2(220,36);sharp.min_value=0.;sharp.max_value=100.;sharp.step=5.;sharp.value=Progression.world_sharpness*100.
 sharp.tooltip_text="Restores fine world detail without changing HUD text. 35% is the balanced default. 0% disables sharpening. Excessive sharpening can emphasize texture grain."
 var amount=RiftMenus.label("%d%%" % sharp.value,20);amount.custom_minimum_size=Vector2(62,36)
 sharp.value_changed.connect(func(value):Progression.world_sharpness=value/100.;amount.text="%d%%" % value;quality.apply();Progression.save_profile())
 clarity_row.add_child(sharp);clarity_row.add_child(amount);parent.add_child(clarity_row)

 var vsync = CheckButton.new()
 vsync.name = "VSync"
 vsync.text = "V-SYNC (PREVENT SCREEN TEARING)"
 vsync.button_pressed = Progression.vsync_enabled
 vsync.tooltip_text = "On: sync to your display refresh rate. Off: permit higher FPS with lower latency, but tearing may appear. The frame limit still applies."
 vsync.toggled.connect(func(enabled): Progression.vsync_enabled = enabled; quality.apply(); Progression.save_profile())
 parent.add_child(vsync)
 var row = HBoxContainer.new()
 row.add_child(RiftMenus.label("FRAME LIMIT",20))
 var limit = OptionButton.new()
 limit.name = "FrameLimit"
 limit.custom_minimum_size = Vector2(200,40)
 var values = [60,120,144,240,0]
 for fps in values: limit.add_item("UNLIMITED" if fps == 0 else "%d FPS" % fps)
 limit.select(maxi(0,values.find(Progression.frame_limit)))
 limit.tooltip_text = "A cap reduces unnecessary GPU/CPU work. Unlimited can improve response on fast PCs; smoothing costs some GPU time."
 limit.item_selected.connect(func(index): Progression.frame_limit = values[index]; quality.apply(); Progression.save_profile())
 row.add_child(limit)
 parent.add_child(row)
 RiftMenus.view_settings(parent,quality)
