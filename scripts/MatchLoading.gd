class_name MatchLoading
extends Node
# Match-scoped resource ownership prevents first-use disk loads without retaining every hero.
const COMMON_TEXTURES=[
 "res://assets/vfx/projectiles.png","res://assets/vfx/impacts.png",
 "res://assets/vfx/expansion-projectiles-v1.png","res://assets/vfx/combat-impact-v1.png",
 "res://assets/vfx/wind-samurai-v2.png","res://assets/structures/rift-structures.png"]
const EFFECT_SCRIPTS=["Beam","SpellBurst","WindBurst","MeleeStrike","MinionHit","HeroImpact","SpinAura","AnimatedCorpse","LaneAugments"]
const MAX_IN_FLIGHT=2
var resources: Dictionary={}
var action_paths: Dictionary={}
var paths: Array=[]
var cancelled=false
var pending=true
var overlay: CanvasLayer
var warm_layer: CanvasLayer
var status_label: Label
var progress_bar: ProgressBar
var errors: Array=[]
var stats: Dictionary={}
var start_usec=0

static func resource_plan(hero_keys: Array) -> Dictionary:
 var actions={};var all={}
 if ActionSpriteArt.manifest.is_empty():ActionSpriteArt.entry("minion_melee")
 for key in ActionSpriteArt.manifest:
  if not key.begins_with("minion_") and key.trim_prefix("hero_") not in hero_keys:continue
  var data=ActionSpriteArt.manifest[key];actions[str(data.path)]=true
  for cell in data.frames:actions[str(cell.get("path",data.path))]=true
 for path in actions:all[path]=true
 for path in COMMON_TEXTURES:all[path]=true
 for path in StatusArt.PATHS.values():all[path]=true
 for key in CombatFeedbackArt.CREST_KEYS:all["res://assets/vfx/crests-v2/"+key+".png"]=true
 for name in EFFECT_SCRIPTS:all["res://scripts/"+name+".gd"]=true
 for key in hero_keys:
  if key in SupportRoster.KEYS:
   all["res://assets/vfx/support-skills-v1.png"]=true;all["res://assets/ui/support-icons-v1.png"]=true
  elif key in RosterExpansion12.KEYS:
   all["res://assets/vfx/"+key+"-skills-v1.png"]=true
   all["res://assets/ui/roster12-icons-%d-v1.png" % (RosterExpansion12.KEYS.find(key)/4)]=true
  else:
   if KitEffectArt.GROUPS.has(key):all["res://assets/vfx/"+KitEffectArt.GROUPS[key]+"-skills-v1.png"]=true
   if key=="veigar":all["res://assets/vfx/vexel-ground-v2.png"]=true
   if key in ExpansionRoster.KEYS:all["res://assets/ui/expansion-hero-icons-v1.png"]=true
   elif key in HeroArt.KEYS:all["res://assets/champions/extended-roster.png"]=true
   else:all["res://assets/champions/"+key+"-painted.png"]=true
 return {"actions":actions,"paths":all.keys()}

func show_loading(on_cancel: Callable) -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 overlay=CanvasLayer.new();overlay.name="MatchLoadingScreen";overlay.layer=90;add_child(overlay)
 var root=Control.new();root.name="LoadingRoot";overlay.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color("070f1c");root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var art=TextureRect.new();art.texture=preload("res://assets/environment/rift-chasm.png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.modulate=Color(.35,.4,.5,.4);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var center=CenterContainer.new();root.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel=PanelContainer.new();center.add_child(panel)
 var frame=StyleBoxFlat.new();frame.bg_color=Color(.025,.045,.075,.92);frame.border_color=Color("9d7c45");frame.set_border_width_all(1);frame.set_content_margin_all(30.);panel.add_theme_stylebox_override("panel",frame)
 var box=VBoxContainer.new();box.custom_minimum_size=Vector2(540,0);box.add_theme_constant_override("separation",22);panel.add_child(box)
 var title=RiftMenus.label("ENTERING THE RIFT",36);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.modulate=Color("ddbe7f");box.add_child(title)
 status_label=RiftMenus.label("Preparing your match…",22);status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(status_label)
 progress_bar=ProgressBar.new();progress_bar.custom_minimum_size=Vector2(540,14);progress_bar.show_percentage=false
 var fill=StyleBoxFlat.new();fill.bg_color=Color("be9853");progress_bar.add_theme_stylebox_override("fill",fill)
 var back=StyleBoxFlat.new();back.bg_color=Color("26303b");progress_bar.add_theme_stylebox_override("background",back);box.add_child(progress_bar)
 var cancel_button=RiftMenus.button("BACK TO MAIN MENU",on_cancel);cancel_button.custom_minimum_size=Vector2(320,48);box.add_child(cancel_button)

func _set_progress(value: float,text: String) -> void:
 if is_instance_valid(status_label):status_label.text=text
 if is_instance_valid(progress_bar):progress_bar.value=value

func prepare(hero_keys: Array) -> bool:
 start_usec=Time.get_ticks_usec()
 var plan=resource_plan(hero_keys);action_paths=plan.actions;paths=plan.paths
 ActionSpriteArt.begin_match(hero_keys);KitEffectArt.begin_match(hero_keys)
 var active=[];var cursor=0;var completed=0
 # Always let the loading screen draw before scheduling I/O.
 await get_tree().process_frame
 while cursor<paths.size() or not active.is_empty():
  if cancelled:cursor=paths.size()
  while not cancelled and active.size()<MAX_IN_FLIGHT and cursor<paths.size():
   var path=str(paths[cursor]);cursor+=1
   var error=ResourceLoader.load_threaded_request(path)
   if error!=OK:errors.append(path);completed+=1
   else:active.append(path)
  for path in active.duplicate():
   var state=ResourceLoader.load_threaded_get_status(path)
   if state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:continue
   # Get only finished requests, including on cancellation, to release engine task ownership.
   if state==ResourceLoader.THREAD_LOAD_LOADED:
    var resource=ResourceLoader.load_threaded_get(path)
    if not cancelled:resources[path]=resource
   else:errors.append(path)
   active.erase(path);completed+=1
  _set_progress(80.*completed/maxi(1,paths.size()),"Preparing your match… %d%%" % int(80.*completed/maxi(1,paths.size())))
  await get_tree().process_frame
 if cancelled:return _abort_complete()
 if not errors.is_empty():
  _set_progress(0.,"Could not load match assets. Please update or reinstall.")
  pending=false;resources.clear();return false
 # Prime the same caches and crop tables used by gameplay, not a separate preload-only cache.
 for path in action_paths:ActionSpriteArt.texture("",path)
 for key in hero_keys:
  HeroArt.texture_for(key)
  for skill in ["q","w","e","r","auto"]:
   var id=str(key)+"_"+skill
   if KitEffectArt.has_effect(id):
    for frame in range(4):KitEffectArt.region(id,frame)
 for id in StatusArt.TYPES:
  for frame in range(4):StatusArt.icon(id,frame/8.)
 var missiles=SpellArt.missile_sheet(true)
 for row in range(6):SpellArt.missile_frame(missiles,row,0);SpellArt.missile_frame(SpellArt.missiles,row,0)
 CombatFeedbackArt.impact_texture()
 for row in range(6):CombatFeedbackArt.banner_texture(row)
 await _warm_textures()
 if cancelled:return _abort_complete()
 stats={"resources":resources.size(),"action_pages":action_paths.size(),"prepare_ms":(Time.get_ticks_usec()-start_usec)/1000.}
 _set_progress(95.,"Preparing the battlefield…")
 return true

func _warm_textures() -> void:
 if DisplayServer.get_name()=="headless":return
 warm_layer=CanvasLayer.new();warm_layer.layer=89;add_child(warm_layer)
 var textures=[]
 for resource in resources.values():
  if resource is Texture2D:textures.append(resource)
 for batch in range(0,textures.size(),4):
  if cancelled:break
  var paint=_WarmDraw.new();paint.textures=textures.slice(batch,mini(batch+4,textures.size()));warm_layer.add_child(paint)
  _set_progress(80.+14.*minf(batch+4,textures.size())/maxi(1,textures.size()),"Preparing effects…")
  await RenderingServer.frame_post_draw
  warm_layer.remove_child(paint);paint.queue_free()
 if is_instance_valid(warm_layer):warm_layer.queue_free();warm_layer=null

func finish_render() -> bool:
 # The real HUD, unit materials and screen shader draw while simulation stays stopped.
 # Rift3D needs two more frames so the warmed 3D pipelines (ViewWarmup) settle behind the overlay.
 for frame in range(4 if ViewConfig.is_active() else 2):
  if DisplayServer.get_name()=="headless":await get_tree().process_frame
  else:await RenderingServer.frame_post_draw
 if cancelled:return _abort_complete()
 stats["total_ms"]=(Time.get_ticks_usec()-start_usec)/1000.;pending=false
 _set_progress(100.,"Waiting for other players…")
 return true

func dismiss() -> void:
 if is_instance_valid(overlay):overlay.queue_free();overlay=null

func cancel() -> void:
 cancelled=true;dismiss()
 if is_instance_valid(warm_layer):warm_layer.visible=false
 if not pending:resources.clear();queue_free()

func _abort_complete() -> bool:
 pending=false;resources.clear();queue_free();return false

class _WarmDraw extends Control:
 var textures: Array=[]
 func _ready() -> void:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  if has_meta("leaf"):return
  var body=_WarmDraw.new();body.textures=textures;body.set_meta("leaf",true)
  var cloth=ShaderMaterial.new();cloth.shader=preload("res://assets/minions/team-cloth.gdshader");body.material=cloth;add_child(body)
  var additive=_WarmDraw.new();additive.textures=textures;additive.set_meta("leaf",true)
  var glow=CanvasItemMaterial.new();glow.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;additive.material=glow;add_child(additive)
 func _draw() -> void:
  for i in range(textures.size()):draw_texture_rect(textures[i],Rect2(12+i*10,12,8,8),false)
  draw_string(CombatFeedbackArt.font(),Vector2(12,44),"KNOCKOUT DOUBLE TRIPLE MANIAC SAVAGE KILLING SPREE",HORIZONTAL_ALIGNMENT_LEFT,-1,28)
  draw_string(CombatFeedbackArt.font(),Vector2(12,66),"You Ally Buddy Vanguard Rival Villain Nemesis A minion Turret ⚔",HORIZONTAL_ALIGNMENT_LEFT,-1,17)
