class_name ItemHover
extends Node
var layer: CanvasLayer
var panel: Control
var watched: Control
static func attach_ref(reference: WeakRef) -> void:
 var control=reference.get_ref()
 if control is Control:attach(control)
static func attach(control: Control) -> void:
 if not is_instance_valid(control) or not control.is_inside_tree() or control.is_queued_for_deletion():return
 var root=control.get_tree().root
 var manager=root.get_node_or_null("ItemHover")
 if manager==null:
  manager=ItemHover.new();manager.name="ItemHover";root.add_child(manager)
 control.mouse_entered.connect(func():manager.show_for(control))
 control.mouse_exited.connect(func():manager.hide_hover())
 control.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed:manager.hide_hover())
func _ready() -> void:
 layer=CanvasLayer.new();layer.layer=40;add_child(layer)
func show_for(control: Control) -> void:
 hide_hover()
 if control.tooltip_text.is_empty():return
 watched=control;panel=ItemTooltip.create(control.tooltip_text);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.get_child(0).mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(panel)
 _process(0)
func hide_hover() -> void:
 if is_instance_valid(panel):panel.queue_free()
 panel=null;watched=null
func _process(_delta: float) -> void:
 if not is_instance_valid(panel):return
 if not is_instance_valid(watched) or not watched.is_visible_in_tree():hide_hover();return
 panel.get_child(0).text=watched.tooltip_text
 panel.size=panel.get_combined_minimum_size()
 var viewport=get_viewport().get_visible_rect().size
 var point=get_viewport().get_mouse_position()+Vector2(18,18)
 panel.position=Vector2(clampf(point.x,12,maxf(12,viewport.x-panel.size.x-12)),clampf(point.y,12,maxf(12,viewport.y-panel.size.y-12)))
