extends Node
class_name DesignCompiler

# Stateless helpers to validate and compile a ship design into computed stats.
#
# This is intentionally minimal for the transition. We'll expand it once
# production and combat switch over to building ShipDesignDef rather than HullDef.

static func validate_design(hull: HullDef, modules: Array[ModuleDef]) -> Array[String]:
	var errors: Array[String] = []
	if hull == null:
		errors.append("Hull is null")
		return errors
	var slot_counts := hull.get_slot_counts()
	var used := {
		Enums.ModuleSlotType.WEAPON: 0,
		Enums.ModuleSlotType.ARMOR: 0,
		Enums.ModuleSlotType.SENSOR: 0,
		Enums.ModuleSlotType.CARGO: 0,
		Enums.ModuleSlotType.ENGINE: 0,
	}
	for m in modules:
		if m == null:
			errors.append("Null module in list")
			continue
		# Size gating: module must fit this hull size.
		if not m.fits_hull(hull):
			errors.append("%s requires %s hull or larger" % [m.display_name, Enums.hull_size_name(m.min_hull_size)])
			continue
		var v := m.validate()
		if v != "":
			errors.append("%s: %s" % [m.display_name, v])
		used[m.slot_type] += 1
	for k in used.keys():
		var max_slots := int(slot_counts.get(k, 0))
		if used[k] > max_slots:
			errors.append("Too many %s modules: %d/%d" % [Enums.module_slot_type_name(k), used[k], max_slots])
	return errors

static func compile_stats(hull: HullDef, modules: Array[ModuleDef]) -> Dictionary:
	# Transitional: keep legacy hull/attack/defense/speed, then add module deltas.
	var stats := {
		"hull": hull.hull,
		"attack": hull.attack,
		"defense": hull.defense,
		"speed": hull.speed,
		"mass": hull.mass,
		"signature": hull.signature,
		"power": hull.power_output,
		"grid_range_per_turn": hull.speed, # placeholder until engine rules replace speed
		"colonists_delivered": 0,
		"cargo_capacity": 0,
		"sensor_scan_range_bonus": 0,
		"sensor_deep_scan": false,
	}

	for m in modules:
		if m == null:
			continue
		# Enforce size gating at compile-time too (so incompatible modules never apply stats).
		if not m.fits_hull(hull):
			continue
		stats.mass += m.mass_delta
		stats.signature += m.signature_delta
		stats.power += m.power_delta
		# Apply typed effects (minimal set for now)
		match m.slot_type:
			Enums.ModuleSlotType.WEAPON:
				var w := m.effect as WeaponEffect
				if w != null:
					stats.attack += int(round(w.damage * float(w.shots_per_turn)))
			Enums.ModuleSlotType.ARMOR:
				var a := m.effect as ArmorEffect
				if a != null:
					stats.defense += a.armor_bonus
			Enums.ModuleSlotType.ENGINE:
				var e := m.effect as EngineEffect
				if e != null:
					stats.grid_range_per_turn = e.grid_range_per_turn
			Enums.ModuleSlotType.SENSOR:
				var s := m.effect as SensorEffect
				if s != null:
					stats.sensor_scan_range_bonus += s.scan_range_bonus
					stats.sensor_deep_scan = stats.sensor_deep_scan or s.enables_deep_scan
			Enums.ModuleSlotType.CARGO:
				var c := m.effect as CargoEffect
				if c != null:
					stats.cargo_capacity += c.capacity
					if c.role == CargoEffect.CargoRole.COLONY_POD:
						stats.colonists_delivered += c.colonists_delivered
	return stats
