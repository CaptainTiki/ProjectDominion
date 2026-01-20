# res://sim/data/tech/content/effects/effect_set_flag.gd
class_name EffectSetFlag
extends TechEffect

@export var flag: StringName
@export var value: bool = true

func apply(empire: FactionState) -> void:
	empire.flags[flag] = value
