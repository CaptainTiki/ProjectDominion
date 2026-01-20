extends Resource
class_name ModuleDef

# A single module that occupies one slot on a hull.
# Modules are intentionally constrained by SlotType and typed effects.

@export var id: StringName = &"MOD_UNSET"
@export var display_name: String = "Unnamed Module"

@export var slot_type: Enums.ModuleSlotType = Enums.ModuleSlotType.WEAPON

# Size gating: a module may require a minimum hull size.
# Compatibility is always "down" (bigger hulls can fit smaller modules), never "up".
@export var min_hull_size: Enums.HullSize = Enums.HullSize.SMALL

# Common / universal deltas (safe for all module types)
@export var production_cost: int = 0
@export var credit_cost: int = 0
@export var upkeep_credits: int = 0

@export var mass_delta: float = 0.0
@export var signature_delta: float = 0.0
@export var power_delta: int = 0

# Typed effect payload. Must match slot_type.
@export var effect: ModuleEffect

@export_group("Unlocks")
# Prefer drag-and-drop TechDef references in the inspector.
@export var required_techs: Array[TechDef] = []

# Legacy (Deprecated): string IDs.
@export_group("Legacy (Deprecated)")
@export var required_tech_ids: Array[StringName] = []
@export var description: String = ""
@export var icon: Texture2D

func validate() -> String:
	if effect == null:
		return "ModuleDef effect is null"
	match slot_type:
		Enums.ModuleSlotType.WEAPON:
			if not (effect is WeaponEffect): return "WEAPON modules require WeaponEffect"
		Enums.ModuleSlotType.ARMOR:
			if not (effect is ArmorEffect): return "ARMOR modules require ArmorEffect"
		Enums.ModuleSlotType.SENSOR:
			if not (effect is SensorEffect): return "SENSOR modules require SensorEffect"
		Enums.ModuleSlotType.CARGO:
			if not (effect is CargoEffect): return "CARGO modules require CargoEffect"
		Enums.ModuleSlotType.ENGINE:
			if not (effect is EngineEffect): return "ENGINE modules require EngineEffect"
		_:
			return "Unknown slot_type"
	return ""

func fits_hull(hull: HullDef) -> bool:
	if hull == null:
		return false
	return int(hull.hull_size) >= int(min_hull_size)

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
