extends Resource
class_name FactionDef

@export var id: int = -1
@export var name: String = "Faction"
@export var color: Color = Color.WHITE
@export var control_type: int = 0 # 0 human, 1 ai_easy, etc (we can enum later)

# Assigned by generator / game start
@export var home_star_id: int = -1
