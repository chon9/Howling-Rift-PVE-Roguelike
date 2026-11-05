class_name UnitViewFactory
extends RefCounted
## Chooses the view class for a sim unit (W1-UNITS). The caller adds the view to its host and binds it.
## This is the per-unit swap point (e.g. the optional W5 model minions).


static func create(src: Node2D) -> UnitView3D:
	if src == null or not is_instance_valid(src):
		return UnitView3D.new()
	if src is Champion or src is Minion:
		return SpriteUnitView3D.new()
	if src is Structure:
		return StructureView3D.new()
	match str(src.get("kind")):
		"champion", "minion":
			return SpriteUnitView3D.new()
		"structure":
			return StructureView3D.new()
	return UnitView3D.new()


static func create_corpse(_corpse: Node2D) -> Node3D:
	return CorpseView3D.new()
