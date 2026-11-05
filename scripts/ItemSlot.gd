extends PanelContainer
func _make_custom_tooltip(text: String) -> Object:
 return ItemTooltip.create(text)
func _ready() -> void:
 ItemHover.attach_ref.call_deferred(weakref(self))
func _get_tooltip(_point: Vector2) -> String:
 # The in-viewport hover panel owns rendering, including fullscreen scaling.
 return ""
