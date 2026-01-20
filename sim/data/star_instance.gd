extends Resource
class_name StarInstance

@export var id: int = -1
@export var pos: Vector2i = Vector2i.ZERO
@export var name: String = "Unnamed"
@export var type_id: Enums.StarType = Enums.StarType.YELLOW
@export var yields: YieldBundle = YieldBundle.new()
@export var owner_id: int = -1

# Readability/gameplay metadata
# 1 = small, 2 = medium, 3 = large
@export_range(1, 3) var size: int = 2
@export var is_capital: bool = false
