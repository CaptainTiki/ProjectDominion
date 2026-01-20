extends Resource
class_name ShipTypeCatalog

@export var ships: Array[HullDef] = []

func get_by_id(ship_id: StringName) -> HullDef:
	for s in ships:
		if s.id == ship_id:
			return s
	return null
