extends Resource
class_name StarTypeCatalog

@export var types: Array[StarTypeDef] = []

func pick_weighted(rng: RandomNumberGenerator) -> StarTypeDef:
	if types.is_empty():
		return null

	var total := 0.0
	for t in types:
		total += max(0.0, t.weight)

	if total <= 0.0:
		return types[0]

	var roll := rng.randf() * total
	var acc := 0.0
	for t in types:
		acc += max(0.0, t.weight)
		if roll <= acc:
			return t
	return types[-1]
