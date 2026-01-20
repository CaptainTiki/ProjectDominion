extends Resource
class_name StarTypeDef

@export var type_id: Enums.StarType = Enums.StarType.YELLOW
@export var display_name: String = "Yellow Star"

# Weighted pick chance in generator
@export var weight: float = 1.0

# Yield ranges per star of this type (inclusive)
@export var credits_range: Vector2i = Vector2i(1, 3)
@export var research_range: Vector2i = Vector2i(0, 2)
@export var production_range: Vector2i = Vector2i(1, 3)

@export var tint: Color = Color.WHITE
