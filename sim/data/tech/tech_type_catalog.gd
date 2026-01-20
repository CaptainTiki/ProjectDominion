extends Resource
class_name TechTypeCatalog

@export var techs: Array[TechDef] = []

func get_by_id(tech_id: StringName) -> TechDef:
	for t in techs:
		if t.id == tech_id:
			return t
	return null
