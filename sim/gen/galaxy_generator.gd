extends Node
class_name GalaxyGenerator

const GalaxyConfig := preload("res://sim/data/galaxy_config.gd")
const GenerationSettings := preload("res://sim/data/generation_settings.gd")
const StarInstance := preload("res://sim/data/star_instance.gd")
const YieldBundle := preload("res://sim/data/yield_bundle.gd")
const FactionDef := preload("res://sim/data/faction_def.gd")
const StarTypeCatalog := preload("res://sim/data/star_type_catalog.gd")
const StarTypeDef := preload("res://sim/data/star_type_def.gd")


static func generate(settings: GenerationSettings, factions: Array[FactionDef]) -> GalaxyConfig:
	var cfg := GalaxyConfig.new()
	cfg.galaxy_size = int(settings.galaxy_size)
	cfg.factions = factions
	cfg.star_types = settings.star_types.duplicate(true)
	cfg.ship_types = settings.ship_types.duplicate(true)
	if settings.ship_designs != null:
		cfg.ship_designs = settings.ship_designs.duplicate(true)
	if settings.module_catalog != null:
		cfg.module_catalog = settings.module_catalog.duplicate(true)
	if settings.tech_types != null:
		cfg.tech_types = settings.tech_types.duplicate(true)
	
	var rng := RandomNumberGenerator.new()

	# Seed behavior:
	# - If seed_text is a valid int, use it (reproducible)
	# - Otherwise generate a new random seed for each call
	var seed_str := settings.seed_text.strip_edges()
	if seed_str.is_valid_int():
		var seed_val := int(seed_str)
		rng.seed = seed_val
		cfg.seed_used = str(seed_val)
	else:
		rng.randomize()
		var seed_val := rng.randi()
		rng.seed = seed_val
		cfg.seed_used = str(seed_val)

	var gal_size : int = max(20, cfg.galaxy_size)

	# Prevent border spawns so stars don't sit on the outer frame.
	# (On tiny maps, there may be no "inner" area, so fall back to full range.)
	var min_xy : int = 0
	var max_xy : int = gal_size - 1
	if gal_size > 2:
		min_xy = 1
		max_xy = gal_size - 2
	var usable_side : int = max(1, max_xy - min_xy + 1)
	var usable_cells : int = usable_side * usable_side
	var count : int = clamp(int(settings.star_count), 1, usable_cells)

	var catalog: StarTypeCatalog = settings.star_types
	if catalog == null:
		# Safe default if caller forgot to pass one.
		catalog = load("res://sim/content/star_types_default.tres") as StarTypeCatalog

	var used := {}
	var used_names := {}
	var stars: Array[StarInstance] = []

	var tries := 0
	while stars.size() < count:
		tries += 1
		if tries > count * 200:
			push_warning("GalaxyGenerator: hit placement safety limit; generated %d/%d stars" % [stars.size(), count])
			break

		var p := Vector2i(rng.randi_range(min_xy, max_xy), rng.randi_range(min_xy, max_xy))
		var key := str(p.x) + ":" + str(p.y)
		if used.has(key):
			continue
		used[key] = true

		var type_def: StarTypeDef = null
		if catalog != null:
			type_def = catalog.pick_weighted(rng)

		# Fallback: if the catalog is empty, still generate something.
		var type_id := 0
		var c_range := Vector2i(1, 3)
		var r_range := Vector2i(0, 2)
		var p_range := Vector2i(1, 3)
		if type_def != null:
			type_id = int(type_def.type_id)
			c_range = type_def.credits_range
			r_range = type_def.research_range
			p_range = type_def.production_range

		var y := YieldBundle.new()
		y.credits = rng.randi_range(c_range.x, c_range.y)
		y.research = rng.randi_range(r_range.x, r_range.y)
		y.production = rng.randi_range(p_range.x, p_range.y)

		var s_name := _unique_star_name(rng, used_names)

		var star := StarInstance.new()
		star.id = stars.size()
		star.pos = p
		star.name = s_name
		star.type_id = type_id
		star.yields = y
		star.owner_id = -1
		star.size = _size_from_yields(y)
		star.is_capital = false
		stars.append(star)

	# Assign faction home stars (capitals) after stars exist.
	_assign_capitals(cfg, stars, factions, rng)

	cfg.stars = stars
	return cfg

static func _unique_star_name(rng: RandomNumberGenerator, used_names: Dictionary) -> String:
	var s_name : String = RandomNameGen.star_name(rng)
	var attempts := 0
	while used_names.has(s_name) and attempts < 40:
		attempts += 1
		s_name = RandomNameGen.star_name(rng)
	used_names[s_name] = true
	return s_name


static func _size_from_yields(y: YieldBundle) -> int:
	# Simple v1 buckets: total yields => size.
	# Tuned for readability: most stars are medium, some small/large.
	var total := int(y.credits) + int(y.research) + int(y.production)
	if total >= 11:
		return 3
	if total >= 7:
		return 2
	return 1


static func _assign_capitals(cfg: GalaxyConfig, stars: Array[StarInstance], factions: Array[FactionDef], rng: RandomNumberGenerator) -> void:
	if factions == null or factions.is_empty():
		return
	if stars.is_empty():
		return

	# If we have more factions than stars, cap what we can.
	var f_count : int = min(factions.size(), stars.size())
	if f_count < factions.size():
		push_warning("GalaxyGenerator: more factions than stars; only assigning %d capitals" % f_count)

	# Greedy max-min distance selection for capital placement.
	var chosen: Array[int] = []

	# First pick is random.
	chosen.append(rng.randi_range(0, stars.size() - 1))

	while chosen.size() < f_count:
		var best_idx := -1
		var best_score := -1.0
		for i in range(stars.size()):
			if chosen.has(i):
				continue
			var score := _min_dist_sq_to_set(stars[i].pos, stars, chosen)
			if score > best_score:
				best_score = score
				best_idx = i
		if best_idx < 0:
			break
		chosen.append(best_idx)

	# Apply ownership + capital flags.
	for fi in range(f_count):
		var f := factions[fi]
		# Ensure stable faction id
		f.id = fi
		var si := chosen[fi]
		var star := stars[si]
		star.owner_id = f.id
		star.is_capital = true
		f.home_star_id = star.id

	# Persist mutated faction resources into config (defensive copy not required, but explicit is nice)
	cfg.factions = factions


static func _min_dist_sq_to_set(p: Vector2i, stars: Array[StarInstance], chosen: Array[int]) -> float:
	var best := INF
	for idx in chosen:
		var q := stars[idx].pos
		var dx := float(p.x - q.x)
		var dy := float(p.y - q.y)
		var d2 := dx * dx + dy * dy
		if d2 < best:
			best = d2
	return best
