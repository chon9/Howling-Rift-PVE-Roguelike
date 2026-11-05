extends Node
var checks=0
var failures=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL FOOTPRINT: "+message)
func _ready() -> void:
 await get_tree().process_frame
 Progression.persistent=false
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("annie")
 for c in GameState.champions:c.is_bot=false;c.stop_actions();c.global_position=Constants.FOUNT_R if c.team==1 else Constants.FOUNT_B
 var caster=GameState.player;caster.global_position=Vector2(1200,270);caster.skill_ranks=[1,1,1,1]
 var inside=GameState.champions[3];var outside=GameState.champions[4]
 inside.global_position=caster.world_pos()+Vector2(200,0);outside.global_position=caster.world_pos()+Vector2(0,200)
 for c in [inside,outside]:c.hp_max=10000.;c.hp=10000.;c.buffs.clear();c.shield=0.
 caster._annie_w(caster.world_pos()+Vector2.RIGHT*300)
 var cone=GameState.aoes.back();cone.update_frame(.01)
 check(inside.hp<10000. and outside.hp==10000.,"real cone hits forward and misses outside its drawn sector")
 check(cone.footprint().shape=="cone" and not cone.readable_boundary,"cone keeps actual collision sector without extra outline")
 check(SkillFootprint.preview(caster,caster.hero.skills[1]).radius==cone.radius,"Annie preview and active radius agree")
 check(not SkillFootprint.contains(cone.footprint(),Vector2(-100,0)),"cone never claims rearward damage")
 # Test damage at the rendered circle edge, including the target's collision padding.
 for c in [inside,outside]:c.hp=10000.;c.buffs.clear()
 var padding=inside.size*.3
 inside.global_position=caster.world_pos()+Vector2(140.+padding-.1,0)
 outside.global_position=caster.world_pos()+Vector2(0,140.+outside.size*.3+.1)
 game.spawn_aoe(caster,caster.world_pos(),{"radius":140.,"dmg":10.,"effect_id":"brand_w","arm_delay":.7,"duration":1.1})
 var pillar=GameState.aoes.back();pillar.update_frame(.1)
 check(inside.hp==10000. and outside.hp==10000.,"pillar warning does not damage before it arms")
 pillar.update_frame(.61)
 check(inside.hp<10000. and outside.hp==10000.,"pillar damage exactly follows the drawn rim plus unit collision padding")
 check(pillar.radius==SkillFootprint.AREA_RADII.brand_w,"area hit radius shares preview metadata")
 for c in [inside,outside]:c.hp=10000.;c.buffs.clear()
 inside.global_position=Vector2(1500,270)+Vector2(30.+inside.size*.3-.1,0)
 outside.global_position=Vector2(1500,270)+Vector2(30.+outside.size*.3+.1,0)
 game.spawn_aoe(caster,Vector2(1500,270),{"radius":300.,"dmg":10.,"effect_id":"xerath_q","footprint_kind":"capsule","footprint_width":30.,"effect_dir":Vector2.DOWN})
 GameState.aoes.back().update_frame(.01)
 check(inside.hp<10000. and outside.hp==10000.,"rotated beam damages inside its visible width and misses just outside")
 for key in ChampionData.CHAMPIONS:
  var fake=game.ChampionS.new();game.world_root.add_child(fake);fake.setup(0,key,false,"Test")
  for skill in fake.hero.skills:
   var shape=SkillFootprint.preview(fake,skill)
   check(shape.has("shape") and shape.has("at"),skill.cast_id+" has valid preview")
   if shape.shape!="none" and shape.shape!="traps":check(SkillFootprint.polygon(shape).size()>=3,skill.cast_id+" preview is drawable")
  fake.queue_free()
 for id in ["lucian_q","xerath_q","xinzhao_w"]:
  var width=26. if id=="lucian_q" else 30. if id=="xerath_q" else 42.
  game.spawn_aoe(caster,Vector2(1500,270),{"effect_id":id,"radius":235.,"dmg":0.,"footprint_kind":"capsule","footprint_width":width,"effect_dir":Vector2.DOWN})
  var beam=GameState.aoes.back()
  check(SkillFootprint.contains(beam.footprint(),Vector2(0,width-.1)) and not SkillFootprint.contains(beam.footprint(),Vector2(0,width+.1)),id+" exact line edge")
  var state=LanSnapshot.encode().aoes.back()
  check(state.footprint_width==width and state.footprint_kind=="capsule" and state.effect_dir==Vector2.DOWN,id+" replicates footprint width and orientation")
  var replica=AoE.new();game.world_root.add_child(replica)
  for field in ["radius","footprint_kind","footprint_width","effect_dir","cone_ang","arc","zone_kind","ring"]:replica.set(field,state[field])
  check(replica.footprint()==beam.footprint(),id+" guest reconstructs identical geometry")
  replica.queue_free()
 for key in RosterExpansion12.KEYS:
  for letter in ["q","w","e","r"]:
   var id=key+"_"+letter;var first=KitEffectArt.region(id,0)
   for frame in range(4):
    var region=KitEffectArt.region(id,frame)
    check(region.size==first.size and Rect2(Vector2.ZERO,KitEffectArt.sheet(id).get_size()).encloses(region),id+" stable frame footprint "+str(frame))
 for id in KitEffectArt.GROUND_PROFILES:
  for frame in range(4):check(Rect2(Vector2.ZERO,KitEffectArt.sheet(id).get_size()).encloses(KitEffectArt.ground_region(id,frame)),id+" ground anchor source "+str(frame))
 var spin=load("res://scripts/SpinAura.gd").new();caster.buffs.spin={"time":2.,"radius":140.};caster.add_child(spin)
 if DisplayServer.get_name()!="headless":
  await render_active_effects(caster)
  await visual_gallery()
 print("SKILL FOOTPRINT: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
func render_active_effects(caster) -> void:
 for key in RosterExpansion12.KEYS+ExpansionRoster.KEYS:
  for letter in ["q","w","e","r"]:
   var id=key+"_"+letter
   game.spawn_aoe(caster,caster.world_pos(),{"effect_id":id,"radius":90.,"duration":2.})
   var fx=GameState.aoes.back()
   for frame in range(4):
    fx.elapsed=frame*.5;fx.queue_redraw()
    await get_tree().process_frame;await RenderingServer.frame_post_draw
   fx.queue_free();GameState.aoes.erase(fx)

 for opts in [{"effect_id":"thresh_r","zone_kind":"box"},{"effect_id":"darius_e","cone_ang":PI*.5,"arc":acos(.35)*2.,"effect_dir":Vector2.DOWN},{"effect_id":"xinzhao_w","footprint_kind":"capsule","footprint_width":42.,"effect_dir":Vector2.UP}]:
  opts.duration=3.;game.spawn_aoe(caster,caster.world_pos(),opts)
  var fx=GameState.aoes.back()
  if fx.zone_kind=="box":fx.broken_walls[1]=true
  fx.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
  fx.queue_free();GameState.aoes.erase(fx)
class Gallery extends Node2D:
 func _draw() -> void:
  var ids=["brand_w","leona_r","xerath_w","thresh_r"]
  for i in range(ids.size()):
   draw_set_transform(Vector2(260+i*400,340))
   KitEffectArt.draw_ground(self,ids[i],2,70.,Color.WHITE)
   SkillFootprint.draw_outline(self,{"shape":"box","radius":70.} if ids[i]=="thresh_r" else SkillFootprint.circle(70.),Color.CYAN)
   draw_string(WorldTextFont.get_font(),Vector2(-60,130),ids[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20)
  for i in range(3):
   draw_set_transform(Vector2(340+i*560,760))
   var shape=SkillFootprint.circle(120.,0.,1.2) if i==0 else SkillFootprint.capsule(320.,30.) if i==1 else {"shape":"rectangle","length":320.,"width":65.}
   SkillFootprint.draw_clipped(self,SpellArt.impacts,SpellArt.frame(SpellArt.impacts,i,4),Rect2(-200,-130,400,260),shape,Color.WHITE)
   SkillFootprint.draw_outline(self,shape,Color.CYAN)
func visual_gallery() -> void:
 game.hide();game.hud.hide();game.graphics_quality.hide();game.camera.enabled=false;get_window().size=Vector2i(1920,1080)
 var layer=CanvasLayer.new();layer.layer=20;add_child(layer)
 var gallery=Gallery.new();layer.add_child(gallery)
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 var image=get_viewport().get_texture().get_image()
 image.save_png("res://tests/skill-footprints-v062.png")
 check(image.get_size()==Vector2i(1920,1080),"native visual gallery renders all footprint shapes")
