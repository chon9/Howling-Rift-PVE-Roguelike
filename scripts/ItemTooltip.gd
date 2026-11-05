class_name ItemTooltip
extends RefCounted
static func create(text: String) -> Control:
 var panel=PanelContainer.new()
 var style=StyleBoxFlat.new();style.bg_color=Color("091422");style.border_color=Color("bb9b51");style.set_border_width_all(2);style.set_content_margin_all(18)
 panel.add_theme_stylebox_override("panel",style)
 var label=Label.new();label.text=text;label.custom_minimum_size.x=550;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",22);label.add_theme_color_override("font_color",Color("f2e3bf"))
 panel.add_child(label)
 return panel
