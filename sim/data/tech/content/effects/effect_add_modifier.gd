# res://sim/data/tech/content/effects/effect_add_modifier.gd
class_name EffectAddModifier
extends TechEffect

@export var key: StringName          # e.g. &"hull_hp_mult"
@export var add: float = 0.0         # additive
@export var mul: float = 1.0         # multiplicative

func apply(empire: FactionState) -> void:
	empire.add_modifier(key, add, mul)
