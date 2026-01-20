extends Resource
class_name FleetState

@export var id: int = -1
@export var name: String = "Fleet"
@export var owner_id: int = 0

# Current star location (StarInstance.id)
@export var star_id: int = -1

# Current grid location (tile coordinates). When invalid (-1,-1), we fall back to the star position.
@export var grid_pos: Vector2i = Vector2i(-1, -1)

# Movement order. If is_moving is true and dest_grid_pos is valid, the fleet marker will travel
# toward that tile in real time.
@export var is_moving: bool = false
@export var dest_grid_pos: Vector2i = Vector2i(-1, -1)

# Ships in this fleet: ship_id_string -> count
@export var ships: Dictionary = {}

# Per-turn declared actions (planning phase).
# A fleet can effectively MOVE (has a move order) or ATTACK/COLONIZE (which pauses movement this turn).
@export var wants_attack: bool = false
@export var wants_colonize: bool = false

func get_total_ships() -> int:
	var total := 0
	for k in ships.keys():
		total += int(ships[k])
	return total
