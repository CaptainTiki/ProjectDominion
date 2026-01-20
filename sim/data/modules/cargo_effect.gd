extends ModuleEffect
class_name CargoEffect

enum CargoRole {
	STANDARD,
	COLONY_POD,
	HAULER
}

@export var role: CargoRole = CargoRole.STANDARD

# General cargo capacity (later: used for logistics/resource hauling).
@export_range(0, 1000000) var capacity: int = 0

# Colony deployment payload (only meaningful when role == COLONY_POD)
@export_range(0, 100000000) var colonists_delivered: int = 0

# Future hook: transfer rate for hauling/logistics.
@export_range(0, 1000000) var transfer_rate: int = 0
