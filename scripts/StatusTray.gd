extends Control
# Fixed controls: no nodes or signal connections created by status churn.
var unit
var slots=[]
var elapsed=0.
var phase=0.
var shown: Array=[]
var styles={}
func _ready() -> void:
 name="StatusTray";mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in range(12):
  var panel=Panel.new();panel.position=Vector2(i*34,0);panel.size=Vector2(32,36);panel.mouse_filter=Control.MOUSE_FILTER_PASS
  var icon=TextureRect.new();icon.position=Vector2(3,1);icon.size=Vector2(26,26);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var label=Label.new();label.position=Vector2(0,23);label.size=Vector2(32,12);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",10);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(panel);panel.add_child(icon);panel.add_child(label);panel.hide();slots.append({"panel":panel,"icon":icon,"label":label})
func _process(delta: float) -> void:
 if not GameState.paused:phase+=delta
 elapsed+=delta
 if elapsed<.1:return
 elapsed=0.;refresh()
func refresh() -> void:
 shown=StatusArt.collect(unit)
 var fx=unit.get_node_or_null("StatusVisual") if is_instance_valid(unit) else null
 if fx!=null and fx.heal_remaining>0:shown.append({"id":"heal","label":"HEALING","time":fx.heal_remaining,"stacks":0,"detail":"Health restored."})
 visible=not shown.is_empty() and not GameState.attack_move_pending
 for i in range(slots.size()):
  var slot=slots[i];slot.panel.visible=i<shown.size()
  if i>=shown.size():continue
  var status=shown[i]
  if i==slots.size()-1 and shown.size()>slots.size():
   slot.icon.texture=null;slot.label.text="+%d" % (shown.size()-i);slot.panel.tooltip_text="\n\n".join(shown.slice(i).map(func(s):return StatusArt.tooltip(s)));continue
  if not styles.has(status.id):
   var style=StyleBoxFlat.new();style.bg_color=Color(.025,.035,.055,.95);style.border_color=StatusArt.color(status.id).darkened(.15);style.set_border_width_all(1);style.set_corner_radius_all(3);styles[status.id]=style
  slot.panel.add_theme_stylebox_override("panel",styles[status.id]);slot.icon.texture=StatusArt.icon(status.id,phase)
  slot.label.text="x%d" % status.stacks if status.stacks>0 else ("%.1f" % status.time if status.time>0 and status.time<10 else ("%d" % ceili(status.time) if status.time>0 and status.time<100 else ""))
  slot.panel.tooltip_text=StatusArt.tooltip(status)
