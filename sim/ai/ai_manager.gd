extends Node
class_name AIManager

# Dominion AI v0: policy-based planner.
# Queues orders during PLANNING; TurnSystem resolves them.

const COLONY_KEY: StringName = &"COLONY"  # design id used in ship dictionaries

# Tuning
const FLEET_MIN_SHIPS := 4
const ATTACK_ADVANTAGE_RATIO := 1.2
const THREAT_RADIUS_TILES := 3
const HOME_GUARD_FRACTION := 0.45

static func plan_orders(gs: GameState, faction_id: int) -> void:
	if gs == null or gs.config == null:
		return
	if int(gs.phase) != int(Enums.TurnPhase.PLANNING):
		return
	# Safety: this planner assumes TurnSystem validations use gs.active_faction_id.
	# Caller should set gs.active_faction_id = faction_id before invoking.
	if int(gs.active_faction_id) != int(faction_id):
		gs.active_faction_id = faction_id

	var cfg := gs.config
	var home_star_id := _get_home_star_id(cfg, faction_id)
	var owned_stars := _get_owned_stars(cfg, faction_id)
	if owned_stars.is_empty():
		return

	# 1) Consolidate newly built ships into fleets.
	_plan_fleet_formation(gs, cfg, faction_id, home_star_id, owned_stars)

	# 2) Production: decide what to build.
	_plan_production(gs, cfg, faction_id, home_star_id, owned_stars)

	# 3) Orders: defend, colonize, then attack.
	_plan_orders_for_fleets(gs, cfg, faction_id, home_star_id)


static func _get_home_star_id(cfg: GalaxyConfig, faction_id: int) -> int:
	if cfg == null:
		return -1
	for f_any in cfg.factions:
		var f := f_any as FactionDef
		if f != null and int(f.id) == int(faction_id):
			return int(f.home_star_id)
	return -1

static func _get_owned_stars(cfg: GalaxyConfig, faction_id: int) -> Array[StarInstance]:
	var out: Array[StarInstance] = []
	if cfg == null:
		return out
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s != null and int(s.owner_id) == int(faction_id):
			out.append(s)
	return out

static func _get_unowned_stars(cfg: GalaxyConfig) -> Array[StarInstance]:
	var out: Array[StarInstance] = []
	if cfg == null:
		return out
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s != null and int(s.owner_id) < 0:
			out.append(s)
	return out

static func _get_enemy_owned_stars(cfg: GalaxyConfig, faction_id: int) -> Array[StarInstance]:
	var out: Array[StarInstance] = []
	if cfg == null:
		return out
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s != null and int(s.owner_id) >= 0 and int(s.owner_id) != int(faction_id):
			out.append(s)
	return out

# -----------------
# Fleet formation
# -----------------
static func _plan_fleet_formation(gs: GameState, cfg: GalaxyConfig, faction_id: int, home_star_id: int, owned_stars: Array[StarInstance]) -> void:
	# If a star has garrison ships, push them into an existing fleet at that star.
	# If no fleet exists there and we have enough ships, create a new fleet.
	for star in owned_stars:
		if star == null:
			continue
		var g := TurnSystem.get_garrison(gs, int(star.id))
		var total := TurnSystem.get_garrison_total(gs, int(star.id))
		if total <= 0:
			continue

		var fleets_here := TurnSystem.get_fleets_at_star(gs, int(star.id))
		var our_fleets: Array[FleetState] = []
		for f_any in fleets_here:
			var f := f_any as FleetState
			if f != null and int(f.owner_id) == int(faction_id):
				our_fleets.append(f)

		var target_fleet: FleetState = null
		if not our_fleets.is_empty():
			# Reinforce the largest fleet at this star.
			target_fleet = _pick_strongest_fleet(cfg, our_fleets)
		else:
			# Create a fleet if we have enough ships.
			if total < FLEET_MIN_SHIPS:
				continue
			var new_id := int(gs.next_fleet_id)
			var err := TurnSystem.try_create_fleet(gs, int(star.id))
			if err != "":
				continue
			target_fleet = TurnSystem.get_fleet_by_id(gs, new_id)

		if target_fleet == null:
			continue

		# Transfer ALL ships from garrison to the chosen fleet.
		for k_any in g.keys():
			var key := String(k_any)
			var cnt := int(g.get(key, 0))
			if cnt <= 0:
				continue
			TurnSystem.try_transfer_garrison_to_fleet(gs, int(star.id), int(target_fleet.id), StringName(key), cnt)

static func _pick_strongest_fleet(cfg: GalaxyConfig, fleets: Array[FleetState]) -> FleetState:
	var best: FleetState = null
	var best_pow := -INF
	for f in fleets:
		if f == null:
			continue
		var p := _fleet_power(cfg, f)
		if p > best_pow:
			best_pow = p
			best = f
	return best

static func _fleet_power(cfg: GalaxyConfig, fleet: FleetState) -> float:
	# Cheap heuristic based on compiled design stats: attack + 0.5*hull
	if cfg == null or fleet == null:
		return 0.0
	var p := 0.0
	for k_any in fleet.ships.keys():
		var design_id := StringName(String(k_any))
		var cnt := int(fleet.ships.get(k_any, 0))
		if cnt <= 0:
			continue
		var stats := TurnSystem.compile_design_stats(cfg, design_id)
		p += float(cnt) * (float(stats.get("attack", 0)) + float(stats.get("hull", 0)) * 0.5)
	return p

static func _count_colony_ships_in_fleets(gs: GameState, faction_id: int) -> int:
	var total := 0
	if gs == null:
		return 0
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null:
			continue
		if int(f.owner_id) != int(faction_id):
			continue
		total += int(f.ships.get(COLONY_KEY, 0))
	return total

static func _count_colony_ships_in_garrisons(gs: GameState, star_ids: Array[int]) -> int:
	var total := 0
	if gs == null:
		return 0
	for sid in star_ids:
		var g := TurnSystem.get_garrison(gs, sid)
		total += int(g.get(COLONY_KEY, 0))
	return total

static func _count_colony_ships_in_queue(gs: GameState) -> int:
	var total := 0
	if gs == null:
		return 0
	for o_any in gs.build_queue:
		var o := o_any as BuildOrder
		if o == null:
			continue
		var did := o.get_effective_design_id()
		if did == COLONY_KEY:
			total += maxi(1, int(o.quantity))
	return total

# -----------------
# Production planning
# -----------------
static func _plan_production(gs: GameState, cfg: GalaxyConfig, faction_id: int, home_star_id: int, owned_stars: Array[StarInstance]) -> void:
	if gs == null or cfg == null:
		return
	# Don't spam queues: only queue if our best production star has no pending orders.
	var build_star := _pick_best_production_star(owned_stars)
	if build_star == null:
		return
	# If the star is devastated/unowned we can't build there.
	if int(build_star.owner_id) != int(faction_id):
		return
	# Check if we already have a queued order at this star.
	for o_any in gs.build_queue:
		var o := o_any as BuildOrder
		if o != null and int(o.star_id) == int(build_star.id):
			return

	# Expansion desire
	var owned_count := owned_stars.size()
	var target_colonies := 2
	if gs.turn >= 10:
		target_colonies = 3
	if gs.turn >= 25:
		target_colonies = 4
	var unowned := _get_unowned_stars(cfg)
	var want_expand := (owned_count < target_colonies) and (not unowned.is_empty())

	var star_ids: Array[int] = []
	for s in owned_stars:
		star_ids.append(int(s.id))

	var colony_in_fleets := _count_colony_ships_in_fleets(gs, faction_id)
	var colony_in_garrisons := _count_colony_ships_in_garrisons(gs, star_ids)
	var colony_in_queue := _count_colony_ships_in_queue(gs)
	var total_colony := colony_in_fleets + colony_in_garrisons + colony_in_queue

	var design_id_to_build := &"SCOUT"
	var qty := 1
	if want_expand and total_colony <= 0:
		design_id_to_build = &"COLONY"
		qty = 1
	else:
		design_id_to_build = _pick_combat_ship_id(cfg, gs.turn)
		qty = 1

	var err := TurnSystem.try_queue_design_build(gs, int(build_star.id), design_id_to_build, qty)
	# Ignore errors (not enough credits, etc.) for now.
	if err != "":
		return

static func _pick_best_production_star(owned_stars: Array[StarInstance]) -> StarInstance:
	var best: StarInstance = null
	var best_prod := -INF
	for s in owned_stars:
		if s == null or s.yields == null:
			continue
		var p := float(s.yields.production)
		if p > best_prod:
			best_prod = p
			best = s
	return best

static func _pick_combat_ship_id(cfg: GalaxyConfig, turn: int) -> StringName:
	# Simple techless progression by turn number.
	# Prefer ship_designs; fall back to hull catalog if needed.
	if cfg == null:
		return &"SCOUT"
	var preferred: Array[StringName] = []
	if turn < 10:
		preferred = [&"FRIGATE", &"SCOUT"]
	elif turn < 25:
		preferred = [&"DESTROYER", &"FRIGATE", &"SCOUT"]
	else:
		preferred = [&"BATTLESHIP", &"DESTROYER", &"FRIGATE", &"SCOUT"]
	for did in preferred:
		if cfg.ship_designs != null and cfg.ship_designs.get_by_id(did) != null:
			return did
		# Compatibility: if design catalog missing, allow hull IDs.
		if cfg.ship_types != null and cfg.ship_types.get_by_id(did) != null:
			return did
	return &"SCOUT"

# -----------------
# Orders: defend / colonize / attack
# -----------------
static func _plan_orders_for_fleets(gs: GameState, cfg: GalaxyConfig, faction_id: int, home_star_id: int) -> void:
	if gs == null or cfg == null:
		return
	# Collect our fleets
	var our_fleets: Array[FleetState] = []
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f != null and int(f.owner_id) == int(faction_id):
			_ensure_grid_pos(gs, cfg, f)
			our_fleets.append(f)
	if our_fleets.is_empty():
		return

	var home_pos := Vector2i(0, 0)
	var home_star := TurnSystem.get_star_by_id(cfg, home_star_id)
	if home_star != null:
		home_pos = home_star.pos

	# Threat check: if enemy is near home, prefer to pull fleets back.
	var threat := _compute_home_threat(gs, cfg, faction_id, home_pos)

	# Ensure at least one guard fleet stays home when possible.
	_ensure_home_guard(gs, cfg, faction_id, home_pos, threat)

	# Colonizer behavior
	for f in our_fleets:
		if f == null:
			continue
		if int(f.ships.get(COLONY_KEY, 0)) <= 0:
			continue
		# If on unowned star and uncontested: queue colonize
		if _can_colonize_here(gs, cfg, faction_id, f.grid_pos):
			TurnSystem.try_colonize_from_fleet(gs, int(f.id))
			continue
		# Otherwise move toward nearest unowned star
		var target := _nearest_unowned_star_pos(cfg, f.grid_pos)
		if target != Vector2i(-1, -1):
			TurnSystem.try_move_fleet_to_tile(gs, int(f.id), target)

	# Combat behavior
	for f in our_fleets:
		if f == null:
			continue
		if int(f.ships.get(COLONY_KEY, 0)) > 0:
			continue
		# If contact with enemy, attack if advantaged
		var here := TurnSystem.get_fleets_at_tile(gs, f.grid_pos)
		var enemy_present := false
		var friendly_power := 0.0
		var enemy_power := 0.0
		for other_any in here:
			var other := other_any as FleetState
			if other == null:
				continue
			if int(other.owner_id) == int(faction_id):
				friendly_power += _fleet_power(cfg, other)
			else:
				enemy_present = true
				enemy_power += _fleet_power(cfg, other)
		if enemy_present:
			if friendly_power >= enemy_power * ATTACK_ADVANTAGE_RATIO:
				TurnSystem.try_attack_from_fleet(gs, int(f.id))
			else:
				# Retreat if losing
				TurnSystem.try_move_fleet_to_tile(gs, int(f.id), home_pos)
			continue

		# If home is threatened, converge on home.
		if threat["threatened"]:
			TurnSystem.try_move_fleet_to_tile(gs, int(f.id), home_pos)
			continue

		# Otherwise, push toward nearest enemy-owned star.
		var target_e := _nearest_enemy_star_pos(cfg, faction_id, f.grid_pos)
		if target_e != Vector2i(-1, -1):
			TurnSystem.try_move_fleet_to_tile(gs, int(f.id), target_e)


# -----------------
# Helpers: threat / targeting
# -----------------
static func _ensure_grid_pos(gs: GameState, cfg: GalaxyConfig, fleet: FleetState) -> void:
	if fleet == null:
		return
	if fleet.grid_pos.x >= 0 and fleet.grid_pos.y >= 0:
		return
	var star := TurnSystem.get_star_by_id(cfg, int(fleet.star_id))
	if star != null:
		fleet.grid_pos = star.pos
	else:
		fleet.grid_pos = Vector2i(0, 0)

static func _compute_home_threat(gs: GameState, cfg: GalaxyConfig, faction_id: int, home_pos: Vector2i) -> Dictionary:
	var enemy_power := 0.0
	var friendly_power := 0.0
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null:
			continue
		_ensure_grid_pos(gs, cfg, f)
		if _dist_sq(f.grid_pos, home_pos) > THREAT_RADIUS_TILES * THREAT_RADIUS_TILES:
			continue
		if int(f.owner_id) == int(faction_id):
			friendly_power += _fleet_power(cfg, f)
		else:
			enemy_power += _fleet_power(cfg, f)
	var threatened := enemy_power > 0.0 and enemy_power >= friendly_power
	return {"threatened": threatened, "enemy_power": enemy_power, "friendly_power": friendly_power}

static func _ensure_home_guard(gs: GameState, cfg: GalaxyConfig, faction_id: int, home_pos: Vector2i, threat: Dictionary) -> void:
	# Keep at least one (strong) fleet at home when possible.
	var total_power := 0.0
	var home_power := 0.0
	var strongest: FleetState = null
	var strongest_power := -INF
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null or int(f.owner_id) != int(faction_id):
			continue
		_ensure_grid_pos(gs, cfg, f)
		var p := _fleet_power(cfg, f)
		total_power += p
		if p > strongest_power and int(f.ships.get(COLONY_KEY, 0)) <= 0:
			strongest_power = p
			strongest = f
		if f.grid_pos == home_pos:
			home_power += p

	if strongest == null:
		return
	var need := maxf(1.0, total_power * HOME_GUARD_FRACTION)
	if home_power < need or bool(threat.get("threatened", false)):
		# Move the strongest combat fleet home (unless it's already there).
		if strongest.grid_pos != home_pos:
			TurnSystem.try_move_fleet_to_tile(gs, int(strongest.id), home_pos)

static func _can_colonize_here(gs: GameState, cfg: GalaxyConfig, faction_id: int, tile: Vector2i) -> bool:
	var sid := _get_star_id_at_tile(cfg, tile)
	if sid < 0:
		return false
	var star := TurnSystem.get_star_by_id(cfg, sid)
	if star == null:
		return false
	if int(star.owner_id) >= 0:
		return false
	# Must be uncontested.
	var here := TurnSystem.get_fleets_at_tile(gs, tile)
	for other_any in here:
		var other := other_any as FleetState
		if other == null:
			continue
		if int(other.owner_id) != int(faction_id):
			return false
	return true

static func _nearest_unowned_star_pos(cfg: GalaxyConfig, from_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s == null:
			continue
		if int(s.owner_id) >= 0:
			continue
		var d := _dist_sq(from_tile, s.pos)
		if d < best_d:
			best_d = d
			best = s.pos
	return best

static func _nearest_enemy_star_pos(cfg: GalaxyConfig, faction_id: int, from_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s == null:
			continue
		if int(s.owner_id) < 0:
			continue
		if int(s.owner_id) == int(faction_id):
			continue
		var d := _dist_sq(from_tile, s.pos)
		if d < best_d:
			best_d = d
			best = s.pos
	return best

static func _get_star_id_at_tile(cfg: GalaxyConfig, tile: Vector2i) -> int:
	if cfg == null:
		return -1
	for s_any in cfg.stars:
		var s := s_any as StarInstance
		if s != null and s.pos == tile:
			return int(s.id)
	return -1

static func _dist_sq(a: Vector2i, b: Vector2i) -> float:
	var dx := float(a.x - b.x)
	var dy := float(a.y - b.y)
	return dx * dx + dy * dy
