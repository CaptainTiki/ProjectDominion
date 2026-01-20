extends Resource
class_name ModuleCatalog

@export var modules: Array[ModuleDef] = []

func get_by_id(module_id: StringName) -> ModuleDef:
	for m in modules:
		if m.id == module_id:
			return m
	return null
