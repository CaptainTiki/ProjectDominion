# res://sim/data/tech/content/effects/effect_unlock_hull.gd
class_name EffectUnlockHull
extends TechEffect

@export_group("Unlock Target")
# Prefer drag-and-drop HullDef.
@export var hull: HullDef

# Legacy (Deprecated): string ID.
@export var hull_id: StringName

func apply(empire: FactionState) -> void:
	var key: StringName = hull_id
	if hull != null:
		key = hull.id
	empire.unlocked_hulls[key] = true
