class_name AnimatedCorpse
extends Node2D
var key: String
var height: float
var flipped: bool
var elapsed: float = 0.0
var lifetime: float = 1.8
static func spawn(unit) -> AnimatedCorpse:
 var corpse = AnimatedCorpse.new()
 corpse.key = "hero_"+unit.hero_key if unit.kind=="champion" else "minion_"+unit.subkind
 corpse.height = Constants.CHAMP_ART_HEIGHT if unit.kind=="champion" else unit.size*2.7
 corpse.flipped = unit.animator.is_flipped()
 corpse.global_position = unit.world_pos()
 corpse.z_index = Constants.Z_UNITS-1
 corpse.material=unit.material.duplicate()
 corpse.material.set_shader_parameter("hit_whiten",0.)
 unit.get_parent().add_child(corpse)
 return corpse
func _process(delta: float) -> void:
 if GameState.paused: return
 elapsed += delta
 modulate.a = clampf((lifetime-elapsed)/0.6,0,1)
 if elapsed>=lifetime: queue_free()
 else: queue_redraw()
func _draw() -> void:
 var frame = clampi(int(elapsed/0.72*6),0,5)
 ActionSpriteArt.apply_frame_mask(material,key,"death",frame)
 draw_set_transform(Vector2.ZERO,0,Vector2(-1,1) if flipped else Vector2.ONE)
 draw_texture_rect_region(ActionSpriteArt.texture(key),ActionSpriteArt.rect(key,"death",frame,height),ActionSpriteArt.region(key,"death",frame))
