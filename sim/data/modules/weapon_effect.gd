extends ModuleEffect
class_name WeaponEffect

# Minimal weapon model for the transition.
# We can evolve this into per-weapon profiles (range, accuracy, tags, etc.) later.

@export var damage: float = 1.0
@export var shots_per_turn: int = 1
@export var range_tiles: int = 1
