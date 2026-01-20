# res://sim/tech_def.gd
class_name TechDef
extends Resource

#ie: MS-1 (material sciences, tech unlock 1)
@export var id: StringName # this should be 2 letter abrv for domain, a dash, then a number (unique num)
@export var display_name: String
@export_multiline var description: String

@export var rp_cost: int = 50

# Prefer drag-and-drop TechDef references in the inspector.
@export_group("Prerequisites")
@export var prereqs: Array[TechDef] = []

# Legacy (Deprecated): string IDs.
@export_group("Legacy (Deprecated)")
@export var prereq_ids: Array[StringName] = []

@export var effects: Array[TechEffect] = []

func can_research(empire: FactionState) -> bool:
	# Prefer Resource refs if present.
	if prereqs != null and prereqs.size() > 0:
		for t in prereqs:
			if t == null:
				continue
			if not empire.has_tech(t.id):
				return false
		return true

	# Fallback legacy IDs.
	for req in prereq_ids:
		if not empire.has_tech(req):
			return false
	return true

func apply(empire: FactionState) -> void:
	# Called once when tech is earned
	for e in effects:
		e.apply(empire)
