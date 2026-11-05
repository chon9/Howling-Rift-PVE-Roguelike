extends Node
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL GEAR PRESENTATION: "+message)
func _ready() -> void:
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 var source=GearArt.sheet().get_image()
 GameState.reset();Progression.persistent=false;Progression.levels.clear()
 var old_stash=[];var equipped={};var expected={}
 for slot in GearLoot.BASES:
  for base in GearLoot.BASES[slot]:
   var old_icon=""
   for icon in GearLoot.LEGACY_ICONS:
    if GearLoot.LEGACY_ICONS[icon]==base[1]:old_icon=icon;break
   var id="legacy_"+base[1]
   var item={"id":id,"name":"Vital "+str(GearLoot.LEGACY_NAMES.get(base[1],base[0])),"slot":slot,"level":43,"rarity":2,"icon":old_icon,"stats":{"bonus_hp":123.4,"bonus_ad":7.3,"bonus_as":.0345},"affixes":[{"name":"Vital","stat":"bonus_hp","value":90.}]}
   old_stash.append(item);expected[id]=base
   if not equipped.has("ring_1" if slot=="ring" else slot):equipped["ring_1" if slot=="ring" else slot]=id
 equipped.ring_2="legacy_war_ring"
 var cfg=ConfigFile.new();var path="res://tests/gear-migration-v042.cfg"
 cfg.set_value("profile","credits",4321);cfg.set_value("equipment","stash",old_stash);cfg.set_value("equipment","equipped",equipped);cfg.set_value("upgrades","might",3);cfg.save(path)
 var profile=load("res://scripts/Progression.gd").new();profile.save_path=path;profile.load_profile()
 check(profile.gear_stash.size()==19 and profile.gear_equipped==equipped,"all legacy items and their nine equipped positions migrate")
 check(profile.credits==4321 and profile.levels.might==3,"migration preserves account credits and ranks")
 for old in old_stash:
  var item=profile.gear_item(old.id);var base=expected[old.id]
  check(item.base_id==base[1] and item.icon==base[1] and item.slot==old.slot,"legacy icon maps to the right equipment class: "+base[0])
  check(item.name=="Vital "+base[0],"name matches actual depicted object: "+base[0])
  for stat in old.stats:check(is_equal_approx(item.stats[stat],old.stats[stat]),"migration keeps rolled stat: "+stat)
  check(item.level==old.level and item.rarity==old.rarity and item.affixes==old.affixes,"migration does not reroll level, rarity or modifiers")
  var icon=GearArt.icon_for(item.base_id);var atlas=GearArt.sheet();var bounds=Rect2(Vector2.ZERO,atlas.get_size())
  check(icon!=null and icon is AtlasTexture and icon.atlas==atlas and icon.filter_clip and bounds.encloses(icon.region),"dedicated icon uses a clipped valid sprite region")
  check(GearLoot.icon_key(item)==base[1],"rendering follows canonical item identity")
  var rect=icon.region
  var edge_clean=true
  for offset in range(ceili(rect.size.x)):
   for point in [Vector2(rect.position.x+offset,rect.position.y),Vector2(rect.position.x+offset,rect.end.y-1),Vector2(rect.position.x,rect.position.y+offset),Vector2(rect.end.x-1,rect.position.y+offset)]:
    if source.get_pixel(clampi(int(point.x),0,source.get_width()-1),clampi(int(point.y),0,source.get_height()-1)).a>.08:edge_clean=false
  check(edge_clean,"measured crop has transparent edges and no neighboring fragment: "+base[0])
 check(profile.save_profile(),"migrated identity persists to disk")
 var restored=load("res://scripts/Progression.gd").new();restored.save_path=path;restored.load_profile()
 for item in restored.gear_stash:check(item.base_id==profile.gear_item(item.id).base_id and item.name==profile.gear_item(item.id).name,"corrected art and name survive reload")
 var broken=old_stash[0].duplicate(true);broken.icon="sunfire";broken.name="Wrong body armor name"
 var fixed=GearLoot.validate(broken)
 check(fixed.slot=="head" and fixed.base_id=="iron_helm" and fixed.name=="Vital Iron Helm","cross-slot icon/name cannot turn head equipment into body art")
 Progression.gear_stash=profile.gear_stash.duplicate(true);Progression.gear_equipped=profile.gear_equipped.duplicate();Progression.credits=4321
 var game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._show_equipment()
 await get_tree().process_frame;await get_tree().process_frame
 var screen=game.menu.find_child("EquipmentScreen",true,false)
 for slot in GearLoot.SLOTS:
  var node=screen.find_child("GearSlot_"+slot,true,false)
  check(node!=null and node.icon.atlas==GearArt.sheet(),"equipped slot uses new equipment art: "+slot)
 screen.selected_id="legacy_iron_helm";screen.selected_slot="head";screen.refresh_detail()
 await get_tree().process_frame;await get_tree().process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/equipment-art-v042.png")
  game.menu.hide()
  var layer=CanvasLayer.new();layer.layer=100;add_child(layer)
  var gallery=Control.new();gallery.size=Vector2(1920,1080);layer.add_child(gallery)
  var background=ColorRect.new();background.color=Color("0a1522");background.size=gallery.size;gallery.add_child(background)
  var index=0
  for slot in GearLoot.BASES:
   for base in GearLoot.BASES[slot]:
    var pos=Vector2(140+(index%5)*340,50+int(index/5)*245)
    var art=TextureRect.new();art.texture=GearArt.icon_for(base[1]);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=pos;art.size=Vector2(200,190);gallery.add_child(art)
    var title=Label.new();title.text=base[0]+"\n"+("Ring" if slot=="ring" else GearLoot.SLOTS[slot]);title.position=pos+Vector2(-40,184);title.size.x=280;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",22);title.add_theme_color_override("font_color",Color("dbc48e"));gallery.add_child(title)
    index+=1
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://tests/equipment-icon-gallery-v042.png")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path));profile.free();restored.free()
 print("GEAR PRESENTATION: %d checks, %d failures" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
