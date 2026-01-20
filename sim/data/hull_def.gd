extends Resource
class_name HullDef

# HullDef is the new canonical "ship definition" moving forward.
#
# NOTE: During transition, we intentionally keep legacy combat fields (hull/attack/defense/speed)
# so the current UI and production pipeline can still read something meaningful.
# As we migrate to module-based designs, these will become derived stats.

@export var id: StringName = &"HULL_SMALL"
@export var display_name: String = "Small Hull"

# New core classification
@export var hull_size: Enums.HullSize = Enums.HullSize.SMALL

# Hull slot counts (module-based ship building)
@export_range(0, 16) var weapon_slots: int = 1
@export_range(0, 16) var armor_slots: int = 1
@export_range(0, 16) var sensor_slots: int = 0
@export_range(0, 16) var cargo_slots: int = 0
@export_range(0, 16) var engine_slots: int = 1

# Economy / unlocks
@export var production_cost: int = 10
@export var credit_cost: int = 0

@export_group("Unlocks")
# Prefer drag-and-drop TechDef references in the inspector.
@export var required_techs: Array[TechDef] = []

# Legacy (Deprecated): string IDs.
@export_group("Legacy (Deprecated)")
@export var required_tech_ids: Array[StringName] = []

# Universal physical/intel-facing stats (used by fog/sensors later)
@export var mass: float = 1.0
@export var signature: float = 1.0
@export var power_output: int = 0

# --- Legacy combat stats (TRANSITIONAL) ---
# These will be replaced by compiled stats from hull + modules.
@export var hull: int = 1
@export var attack: int = 0
@export var defense: int = 0
@export var speed: int = 1

@export var description: String = ""
@export var icon: Texture2D

func is_unlocked(empire: FactionState) -> bool:
	# Prefer Resource refs if present.
	if required_techs != null and required_techs.size() > 0:
		for t in required_techs:
			if t == null:
				continue
			if not empire.has_tech(t.id):
				return false
		return true
	# Fallback legacy IDs.
	for t_id in required_tech_ids:
		if not empire.has_tech(t_id):
			return false
	return true

func get_slot_counts() -> Dictionary:
	return {
		Enums.ModuleSlotType.WEAPON: weapon_slots,
		Enums.ModuleSlotType.ARMOR: armor_slots,
		Enums.ModuleSlotType.SENSOR: sensor_slots,
		Enums.ModuleSlotType.CARGO: cargo_slots,
		Enums.ModuleSlotType.ENGINE: engine_slots,
	}
