extends Resource
class_name BuildOrder

@export var star_id: int = -1

# Canonical identifier for what is being built.
# During the transition, our legacy ship IDs (SCOUT/FRIGATE/etc.) also act as Design IDs.
@export var design_id: StringName = &"SCOUT"

# DEPRECATED (compat only). Older code may still set this.
@export var ship_id: StringName = &""

@export var quantity: int = 1

# Remaining production required to complete this order.
# Production is applied each turn from the star's production throughput.
@export var remaining_prod: int = 0

func get_effective_design_id() -> StringName:
	# Backward compatibility: if design_id wasn't set, fall back to ship_id.
	if design_id != null and String(design_id) != "":
		return design_id
	if ship_id != null and String(ship_id) != "":
		return ship_id
	return &""
