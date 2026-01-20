extends Resource
class_name FactionState

# Matches FactionDef.id
@export var faction_id: int = -1

@export var credits: int = 0
@export var research_per_turn: int = 0
@export var production_per_turn: int = 0

var unlocked_techs: Dictionary = {}      # { tech_id: true }

# Convenience helpers
func reset_incomes() -> void:
	# Throughput gets recomputed every turn.
	research_per_turn = 0
	production_per_turn = 0

func has_tech(id: StringName) -> bool:
	return unlocked_techs.has(id)

func unlock_tech(tech: TechDef) -> void:
	if has_tech(tech.id): return
	unlocked_techs[tech.id] = true
	tech.apply(self)
