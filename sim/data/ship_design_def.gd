extends Resource
class_name ShipDesignDef

# A ship design is a hull + a list of module IDs.
# This is the object production will build once we finish migrating.

@export var id: StringName = &"DESIGN_UNSET"
@export var display_name: String = "Unnamed Design"

@export_group("Design Composition")
# Prefer drag-and-drop resource references in the inspector.
@export var hull: HullDef
@export var modules: Array[ModuleDef] = []

@export_group("Unlocks")
@export var required_techs: Array[TechDef] = []

@export_group("Legacy (Deprecated)")
@export var hull_id: StringName = &"HULL_SMALL"
# Module IDs in loadout order (UI can group by slot type).
@export var module_ids: Array[StringName] = []
@export var required_tech_ids: Array[StringName] = []
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
