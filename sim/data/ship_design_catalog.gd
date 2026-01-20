extends Resource
class_name ShipDesignCatalog

@export var designs: Array[ShipDesignDef] = []

func get_by_id(design_id: StringName) -> ShipDesignDef:
	for d in designs:
		if d.id == design_id:
			return d
	return null
