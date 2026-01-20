extends Node
class_name TurnSystem

const AIManager := preload("res://sim/ai/ai_manager.gd")

## Creates a new GameState for a freshly generated GalaxyConfig.
static func create_new_game_state(config: GalaxyConfig) -> GameState:
	var gs := GameState.new()
	gs.config = config
	gs.turn = 1
	gs.phase = Enums.TurnPhase.PLANNING
	gs.ready_factions = {}
	gs.active_faction_id = _find_first_human_faction_id(config)
	gs.faction_states = []
	gs.build_queue = []
	gs.stationed_ships = {}
	gs.fleets = []
	gs.next_fleet_id = 1

	for f in config.factions:
		var fs := FactionState.new()
		fs.faction_id = f.id
		fs.credits = 0
		fs.research_per_turn = 0
		fs.production_per_turn = 0
		gs.faction_states.append(fs)
		gs.ready_factions[int(f.id)] = false

	return gs

## --------
## Garrisons
## --------

static func get_garrison(gs: GameState, star_id: int) -> Dictionary:
	if gs == null:
		return {}
	if not gs.stationed_ships.has(star_id):
		return {}
	return gs.stationed_ships[star_id] as Dictionary

static func get_garrison_total(gs: GameState, star_id: int) -> int:
	var g := get_garrison(gs, star_id)
	var tot := 0
	for k in g.keys():
		tot += int(g[k])
	return tot

## -------
## Fleets
## -------

static func get_fleet_by_id(gs: GameState, fleet_id: int):
	if gs == null:
		return null
	for f in gs.fleets:
		if f != null and int(f.id) == fleet_id:
			return f
	return null

static func get_fleets_at_star(gs: GameState, star_id: int) -> Array:
	var out: Array = []
	if gs == null:
		return out
	for f in gs.fleets:
		if f != null and int(f.star_id) == star_id:
			out.append(f)
	return out

## Returns all fleets whose resolved tile position matches the given tile.
static func get_fleets_at_tile(gs: GameState, tile: Vector2i) -> Array:
	var out: Array = []
	if gs == null:
		return out
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null:
			continue
		_ensure_fleet_grid_pos(gs, f)
		if f.grid_pos == tile:
			out.append(f)
	return out

## Player-declared combat. Attacks ALL enemy fleets at the attacker's current tile
## using ALL friendly fleets at that tile.
## Returns a human-readable summary on success, otherwise an error string.
static func try_attack_from_fleet(gs: GameState, attacker_fleet_id: int) -> String:
	# Planning-phase: queue an attack order (resolution happens on End Turn).
	# This queues an "attack with everyone here" order for ALL friendly fleets at the tile.
	if gs == null or gs.config == null:
		return "No active game."
	var attacker: FleetState = get_fleet_by_id(gs, attacker_fleet_id)
	if attacker == null:
		return "Fleet not found."
	if int(attacker.owner_id) != int(gs.active_faction_id):
		return "That's not your fleet."
	_ensure_fleet_grid_pos(gs, attacker)
	var tile := attacker.grid_pos
	var here := get_fleets_at_tile(gs, tile)
	var friendlies: Array[FleetState] = []
	var enemies: Array[FleetState] = []
	for f_any in here:
		var f := f_any as FleetState
		if f == null:
			continue
		if int(f.owner_id) == int(gs.active_faction_id):
			friendlies.append(f)
		else:
			enemies.append(f)
	if enemies.is_empty():
		return "No enemy fleets in contact."
	# If any friendly fleet here has queued colonize, don't allow attack without clearing it (keeps turn rules simple).
	for f in friendlies:
		if f.wants_colonize:
			return "A friendly fleet here is queued to colonize this turn."
	# Queue attack for ALL friendlies at this tile (so it's one big combined battle).
	for f in friendlies:
		f.wants_attack = true
	return "Attack queued."


static func get_star_by_id(cfg: GalaxyConfig, star_id: int) -> StarInstance:
	return _get_star_by_id(cfg, star_id)

## -----------------------------
## Designs / Hulls / Modules
## -----------------------------

static func resolve_design_def(cfg: GalaxyConfig, design_id: StringName) -> ShipDesignDef:
	if cfg == null:
		return null
	if cfg.ship_designs != null:
		var d := cfg.ship_designs.get_by_id(design_id)
		if d != null:
			return d
	# Compatibility fallback: treat design_id as a hull_id.
	var fallback := ShipDesignDef.new()
	fallback.id = design_id
	fallback.display_name = String(design_id)
	# Legacy fields (deprecated)
	fallback.hull_id = design_id
	fallback.module_ids = []
	# New fields
	if cfg != null and cfg.ship_types != null:
		fallback.hull = cfg.ship_types.get_by_id(design_id)
	return fallback

static func resolve_hull_def(cfg: GalaxyConfig, design_id: StringName) -> HullDef:
	if cfg == null or cfg.ship_types == null:
		return null
	var d := resolve_design_def(cfg, design_id)
	if d == null:
		return null
	# Prefer direct resource reference.
	if d.hull != null:
		return d.hull
	# Fallback legacy ID.
	return cfg.ship_types.get_by_id(d.hull_id)

static func resolve_modules_for_design(cfg: GalaxyConfig, design_id: StringName) -> Array[ModuleDef]:
	var mods: Array[ModuleDef] = []
	if cfg == null:
		return mods
	var d := resolve_design_def(cfg, design_id)
	if d == null:
		return mods
	# Prefer direct resource references.
	if d.modules != null and d.modules.size() > 0:
		for mref in d.modules:
			if mref != null:
				mods.append(mref)
		return mods
	# Fallback legacy IDs via module catalog.
	if cfg.module_catalog == null:
		return mods
	for mid in d.module_ids:
		var m := cfg.module_catalog.get_by_id(mid)
		if m != null:
			mods.append(m)
	return mods

static func compile_design_stats(cfg: GalaxyConfig, design_id: StringName) -> Dictionary:
	# Always returns a dict with at least: hull, attack, defense, speed, grid_range_per_turn
	var hull_def := resolve_hull_def(cfg, design_id)
	if hull_def == null:
		return {"hull": 1, "attack": 0, "defense": 0, "speed": 1, "grid_range_per_turn": 1}
	var mods := resolve_modules_for_design(cfg, design_id)
	return DesignCompiler.compile_stats(hull_def, mods)

static func design_display_name(cfg: GalaxyConfig, design_id: StringName) -> String:
	var d := resolve_design_def(cfg, design_id)
	if d != null and d.display_name.strip_edges() != "":
		return d.display_name
	var h := resolve_hull_def(cfg, design_id)
	if h != null and h.display_name.strip_edges() != "":
		return h.display_name
	return String(design_id)

static func design_costs(cfg: GalaxyConfig, design_id: StringName) -> Dictionary:
	# Returns {"production": int, "credits": int, "upkeep": int}
	var h := resolve_hull_def(cfg, design_id)
	if h == null:
		return {"production": 0, "credits": 0, "upkeep": 0}
	var production := int(h.production_cost)
	var credits := int(h.credit_cost)
	var upkeep := 0
	for m in resolve_modules_for_design(cfg, design_id):
		production += int(m.production_cost)
		credits += int(m.credit_cost)
		upkeep += int(m.upkeep_credits)
	return {"production": production, "credits": credits, "upkeep": upkeep}

## Moves a fleet to a destination star (v0 rule).
## This now issues a tile movement order so fleets can also stage in open space.
## Returns "" on success, otherwise a user-friendly error.
static func try_move_fleet(gs: GameState, fleet_id: int, dest_star_id: int) -> String:
	if gs == null or gs.config == null:
		return "No active game."
	var fleet: FleetState = get_fleet_by_id(gs, fleet_id)
	if fleet == null:
		return "Fleet not found."
	if int(fleet.owner_id) != int(gs.active_faction_id):
		return "That's not your fleet."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	var dest := _get_star_by_id(gs.config, dest_star_id)
	if dest == null:
		return "Destination star not found."
	# If we're already sitting on that star tile, treat it as already there.
	_ensure_fleet_grid_pos(gs, fleet)
	if fleet.grid_pos == dest.pos:
		return "Fleet is already there."
	return try_move_fleet_to_tile(gs, fleet_id, dest.pos)


## Moves a fleet to an arbitrary destination tile.
## Returns "" on success, otherwise a user-friendly error.
static func try_move_fleet_to_tile(gs: GameState, fleet_id: int, dest_tile: Vector2i) -> String:
	if gs == null or gs.config == null:
		return "No active game."
	var fleet: FleetState = get_fleet_by_id(gs, fleet_id)
	if fleet == null:
		return "Fleet not found."
	if int(fleet.owner_id) != int(gs.active_faction_id):
		return "That's not your fleet."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	# Bounds check
	var size := int(gs.config.galaxy_size)
	if dest_tile.x < 0 or dest_tile.y < 0 or dest_tile.x >= size or dest_tile.y >= size:
		return "Destination is out of bounds."

	_ensure_fleet_grid_pos(gs, fleet)
	if fleet.grid_pos == dest_tile:
		return "Fleet is already there."

	# Issue movement order (turn-based resolution happens on End Turn).
	# We intentionally DO NOT move the fleet immediately.
	fleet.dest_grid_pos = dest_tile
	fleet.is_moving = true
	return ""

## Creates a new empty fleet at the given star, owned by the active faction.
## Returns "" on success or a user-friendly error.
static func try_create_fleet(gs: GameState, star_id: int, fleet_name: String = "") -> String:
	if gs == null or gs.config == null:
		return "No active game."
	var star := _get_star_by_id(gs.config, star_id)
	if star == null:
		return "Select a valid star."
	if star.owner_id != gs.active_faction_id:
		return "You can only create fleets at stars you own."
	# Require at least one ship in garrison to form a fleet (v0).
	if get_garrison_total(gs, star_id) <= 0:
		return "No garrison ships here to form a fleet."

	var f := FleetState.new()
	f.id = gs.next_fleet_id
	gs.next_fleet_id += 1
	f.owner_id = gs.active_faction_id
	f.star_id = star_id
	f.grid_pos = star.pos
	f.is_moving = false
	f.dest_grid_pos = Vector2i(-1, -1)
	f.ships = {}
	f.name = fleet_name if fleet_name.strip_edges() != "" else "Fleet %d" % f.id
	gs.fleets.append(f)
	return ""

## Move ships from garrison -> fleet (same star). Returns "" on success.
static func try_transfer_garrison_to_fleet(gs: GameState, star_id: int, fleet_id: int, ship_id: StringName, count: int) -> String:
	if gs == null or gs.config == null:
		return "No active game."
	if count <= 0:
		return "Count must be at least 1."
	var fleet: FleetState = get_fleet_by_id(gs, fleet_id)
	if fleet == null:
		return "Fleet not found."
	if int(fleet.owner_id) != int(gs.active_faction_id):
		return "That's not your fleet."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	if int(fleet.star_id) != int(star_id):
		return "Fleet must be at the selected star."
	var g := get_garrison(gs, star_id)
	var key := String(ship_id)
	var have := int(g.get(key, 0))
	if have < count:
		return "Not enough ships in garrison."
	# subtract from garrison
	if have == count:
		g.erase(key)
	else:
		g[key] = have - count
	gs.stationed_ships[star_id] = g
	# add to fleet
	var fkey := String(ship_id)
	var prev := int(fleet.ships.get(fkey, 0))
	fleet.ships[fkey] = prev + count
	return ""

## Advances the game by one turn and applies economy income.
static func end_turn(gs: GameState) -> void:
	# Simultaneous turns, two phases:
	#   PLANNING: factions queue orders
	#   RESOLVING: we apply movement/combat/colonize/economy once everyone is ready
	if gs == null or gs.config == null:
		return
	if int(gs.phase) != int(Enums.TurnPhase.PLANNING):
		return
	# Local player submits plans.
	var human_id := int(gs.active_faction_id)
	gs.ready_factions[human_id] = true

	# AI factions: plan and submit their turns now.
	# (If we later support multiple humans, this should only plan for non-human factions.)
	for fdef_any in gs.config.factions:
		var fdef := fdef_any as FactionDef
		if fdef == null:
			continue
		var fid := int(fdef.id)
		if int(fdef.control_type) == 0:
			continue
		# Skip if already marked ready by some external system.
		if gs.ready_factions.has(fid) and bool(gs.ready_factions[fid]):
			continue
		gs.active_faction_id = fid
		AIManager.plan_orders(gs, fid)
		gs.ready_factions[fid] = true
	# Restore local faction.
	gs.active_faction_id = human_id
	# If any other human factions exist, we would wait here.
	if not _all_factions_ready(gs):
		return
	_resolve_full_turn(gs)
	_begin_planning_phase(gs)

static func _all_factions_ready(gs: GameState) -> bool:
	if gs == null or gs.config == null:
		return false
	for fdef_any in gs.config.factions:
		var fdef := fdef_any as FactionDef
		if fdef == null:
			continue
		var fid := int(fdef.id)
		if not gs.ready_factions.has(fid) or not bool(gs.ready_factions[fid]):
			return false
	return true

static func _begin_planning_phase(gs: GameState) -> void:
	if gs == null or gs.config == null:
		return
	gs.phase = Enums.TurnPhase.PLANNING
	# Reset readiness
	gs.ready_factions = {}
	for fdef_any in gs.config.factions:
		var fdef := fdef_any as FactionDef
		if fdef == null:
			continue
		gs.ready_factions[int(fdef.id)] = false
	# Clear per-turn action flags
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null:
			continue
		f.wants_attack = false
		f.wants_colonize = false

static func _resolve_full_turn(gs: GameState) -> void:
	if gs == null or gs.config == null:
		return
	gs.phase = Enums.TurnPhase.RESOLVING
	# Clear and prepare per-turn combat reports.
	gs._combat_reports_working = []
	gs.combat_reports_last_turn = []
	# Resolution order is kept simple by the rule: fleets MOVE or ATTACK/COLONIZE (not both).
	# 1) Movement (fleets with move orders advance; fleets queued to attack/colonize do not move this turn)
	_resolve_fleet_movement(gs)
	# 2) Combat (only tiles where at least one fleet queued an attack)
	_resolve_queued_attacks(gs)
	# 3) Colonization (only fleets queued to colonize; happens after combat)
	_resolve_queued_colonize(gs)
	# 4) Economy and production
	_apply_economy_income(gs)
	_process_build_queues(gs)
	# Freeze the turn's combat reports for UI display.
	gs.combat_reports_last_turn = gs._combat_reports_working.duplicate(true)
	gs.turn += 1



## -----------------
## Turn Resolution
## -----------------

static func _resolve_fleet_movement(gs: GameState) -> void:
	# Fleets advance along the hypotenuse toward their destination, in "tiles per turn".
	# We store positions as tile coords (Vector2i) and step using euclidean math.
	if gs == null or gs.config == null:
		return
	var cfg := gs.config
	var size := int(cfg.galaxy_size)
	for f in gs.fleets:
		var fleet := f as FleetState
		if fleet == null:
			continue
		# Fleets that queued ATTACK/COLONIZE do not move this turn.
		if fleet.wants_attack or fleet.wants_colonize:
			continue
		if not fleet.is_moving:
			continue
		if fleet.dest_grid_pos == Vector2i(-1, -1):
			fleet.is_moving = false
			continue

		# Ensure we have a current position.
		_ensure_fleet_grid_pos(gs, fleet)

		var cur := Vector2(float(fleet.grid_pos.x), float(fleet.grid_pos.y))
		var dest := Vector2(float(fleet.dest_grid_pos.x), float(fleet.dest_grid_pos.y))
		var delta := dest - cur
		var dist := delta.length()
		if dist <= 0.001:
			fleet.grid_pos = fleet.dest_grid_pos
			fleet.dest_grid_pos = Vector2i(-1, -1)
			fleet.is_moving = false
			fleet.star_id = _get_star_id_at_tile(cfg, fleet.grid_pos)
			continue

		var speed := float(_get_fleet_speed_tiles_per_turn(cfg, fleet))
		speed = maxf(speed, 0.1)
		var step := minf(speed, dist)
		var new_pos := cur + (delta / dist) * step
		var new_tile := Vector2i(int(round(new_pos.x)), int(round(new_pos.y)))
		# Clamp to map bounds just in case.
		new_tile.x = clampi(new_tile.x, 0, size - 1)
		new_tile.y = clampi(new_tile.y, 0, size - 1)
		fleet.grid_pos = new_tile

		# Arrived?
		if fleet.grid_pos == fleet.dest_grid_pos:
			fleet.dest_grid_pos = Vector2i(-1, -1)
			fleet.is_moving = false

		# Update star attachment: if we're exactly on a star tile, we're "at" that star.
		fleet.star_id = _get_star_id_at_tile(cfg, fleet.grid_pos)


static func _resolve_queued_attacks(gs: GameState) -> void:
	if gs == null or gs.config == null:
		return
	# Collect tiles where any fleet queued an attack.
	var tiles: Array[Vector2i] = []
	var seen := {}
	for f_any in gs.fleets:
		var f := f_any as FleetState
		if f == null:
			continue
		if not f.wants_attack:
			continue
		_ensure_fleet_grid_pos(gs, f)
		var key := "%d,%d" % [f.grid_pos.x, f.grid_pos.y]
		if seen.has(key):
			continue
		seen[key] = true
		tiles.append(f.grid_pos)
	# Deterministic order
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	for tile in tiles:
		var here := get_fleets_at_tile(gs, tile)
		if here.is_empty():
			continue
		# Group fleets by owner
		var groups: Dictionary = {}
		var attackers: Array[int] = []
		for f_any2 in here:
			var f2 := f_any2 as FleetState
			if f2 == null:
				continue
			var oid := int(f2.owner_id)
			if not groups.has(oid):
				groups[oid] = []
			(groups[oid] as Array).append(f2)
			if f2.wants_attack and not attackers.has(oid):
				attackers.append(oid)
		# Need at least two sides present
		if groups.keys().size() < 2:
			continue
		if attackers.is_empty():
			continue
		attackers.sort()
		var attacker_owner := int(attackers[0])
		var friendlies: Array[FleetState] = []
		var enemies: Array[FleetState] = []
		for oid_any in groups.keys():
			var oid := int(oid_any)
			var arr := groups[oid_any] as Array
			if oid == attacker_owner:
				for ff in arr: friendlies.append(ff as FleetState)
			else:
				for ee in arr: enemies.append(ee as FleetState)
		if enemies.is_empty() or friendlies.is_empty():
			continue
		_resolve_battle_at_tile(gs, tile, friendlies, enemies)

	# Attack flags are per-turn; they'll be cleared at the start of next planning phase.

static func _resolve_queued_colonize(gs: GameState) -> void:
	if gs == null or gs.config == null:
		return	
	# Colonize orders resolve after combat.
	# Each queued fleet attempts to colonize the star at its current tile (if still unowned and uncontested).
	var fleets_snapshot := gs.fleets.duplicate()
	for f_any in fleets_snapshot:
		var fleet := f_any as FleetState
		if fleet == null:
			continue
		if not fleet.wants_colonize:
			continue
		_ensure_fleet_grid_pos(gs, fleet)
		# Must still be present in gs (combat may prune)
		if get_fleet_by_id(gs, int(fleet.id)) == null:
			continue
		# If enemies are still here, cannot colonize.
		var here := get_fleets_at_tile(gs, fleet.grid_pos)
		var contested := false
		for other_any in here:
			var other := other_any as FleetState
			if other == null:
				continue
			if int(other.owner_id) != int(fleet.owner_id):
				contested = true
				break
		if contested:
			continue
		# Attempt colonize using the fleet's owner (not gs.active_faction_id).
		_colonize_from_fleet_owner(gs, fleet)

static func _colonize_from_fleet_owner(gs: GameState, fleet: FleetState) -> void:
	if gs == null or gs.config == null or fleet == null:
		return
	var sid := _get_star_id_at_tile(gs.config, fleet.grid_pos)
	if sid < 0:
		return
	var star := _get_star_by_id(gs.config, sid)
	if star == null:
		return
	if int(star.owner_id) >= 0:
		return
	var have := int(fleet.ships.get("COLONY", 0))
	if have <= 0:
		return
	# Consume one colony ship
	if have == 1:
		fleet.ships.erase("COLONY")
	else:
		fleet.ships["COLONY"] = have - 1
	if fleet.get_total_ships() <= 0:
		_prune_empty_fleets(gs)
	# Claim
	star.owner_id = int(fleet.owner_id)
	star.is_capital = false

static func _resolve_battle_at_tile(gs: GameState, tile: Vector2i, friendlies: Array[FleetState], enemies: Array[FleetState]) -> String:
	# Simple deterministic auto-resolve used only when a player presses Attack.
	# This is intentionally conservative: it ignores defense for now and uses hull + attack only.
	if gs == null or gs.config == null:
		return "No active game."
	var cfg := gs.config
	# --- Snapshot BEFORE ---
	var a_before := _snapshot_side_ships(friendlies)
	var b_before := _snapshot_side_ships(enemies)
	var a_fleet_ids_before := _snapshot_fleet_ids(friendlies)
	var b_fleet_ids_before := _snapshot_fleet_ids(enemies)
	var a_owner := int(friendlies[0].owner_id) if friendlies.size() > 0 and friendlies[0] != null else -1
	var defender_owner_ids: Array = []
	for ef in enemies:
		if ef == null:
			continue
		var oid := int(ef.owner_id)
		if not defender_owner_ids.has(oid):
			defender_owner_ids.append(oid)
	defender_owner_ids.sort()
	var b_owner : int = defender_owner_ids[0] if defender_owner_ids.size() > 0 else -1
	var turn_number := int(gs.turn)
	var a_stats := _compute_side_stats(cfg, friendlies)
	var b_stats := _compute_side_stats(cfg, enemies)
	var a_hp0: int = int(a_stats.hp)
	var b_hp0: int = int(b_stats.hp)
	var a_atk: int = maxi(1, int(a_stats.attack))
	var b_atk: int = maxi(1, int(b_stats.attack))
	var a_hp: int = a_hp0
	var b_hp: int = b_hp0
	var rounds := 0
	while rounds < 100 and a_hp > 0 and b_hp > 0:
		a_hp -= b_atk
		b_hp -= a_atk
		rounds += 1

	a_hp = maxi(a_hp, 0)
	b_hp = maxi(b_hp, 0)
	var a_lost := a_hp0 - a_hp
	var b_lost := b_hp0 - b_hp

	_apply_hp_losses(cfg, friendlies, a_lost)
	_apply_hp_losses(cfg, enemies, b_lost)
	_prune_empty_fleets(gs)

	# --- Snapshot AFTER (post losses/prune) ---
	var a_after := _snapshot_side_ships_live(gs, friendlies)
	var b_after := _snapshot_side_ships_live(gs, enemies)
	var a_fleet_ids_after := _snapshot_fleet_ids_live(gs, friendlies)
	var b_fleet_ids_after := _snapshot_fleet_ids_live(gs, enemies)

	# Conquest v0:
	# If this battle happened at a star tile, the colony is devastated.
	# The star becomes neutral/unowned and must be re-colonized by a colony ship.
	var devastation := _devastate_star_if_present(gs, tile)

	var outcome := "Stalemate"
	if a_hp > 0 and b_hp <= 0:
		outcome = "Victory"
	elif b_hp > 0 and a_hp <= 0:
		outcome = "Defeat"

	# Try to print a location string.
	var loc := "(%d, %d)" % [tile.x, tile.y]
	var sid := _get_star_id_at_tile(cfg, tile)
	if sid >= 0:
		var star := _get_star_by_id(cfg, sid)
		if star != null:
			loc = "%s (%d, %d)" % [star.name, tile.x, tile.y]

	# Build and store a combat report for UI.
	if gs._combat_reports_working != null:
		var report := {
			"turn": turn_number,
			"tile": tile,
			"star_id": sid,
			"location": loc,
			"attacker_owner_id": a_owner,
			"defender_owner_id": b_owner,
			"defender_owner_ids": defender_owner_ids,
			"attacker_fleet_ids_before": a_fleet_ids_before,
			"defender_fleet_ids_before": b_fleet_ids_before,
			"attacker_fleet_ids_after": a_fleet_ids_after,
			"defender_fleet_ids_after": b_fleet_ids_after,
			"attacker_ships_before": a_before,
			"defender_ships_before": b_before,
			"attacker_ships_after": a_after,
			"defender_ships_after": b_after,
			"attacker_ships_lost": _diff_ship_counts(a_before, a_after),
			"defender_ships_lost": _diff_ship_counts(b_before, b_after),
			"attacker_hp_start": a_hp0,
			"defender_hp_start": b_hp0,
			"attacker_attack": a_atk,
			"defender_attack": b_atk,
			"attacker_hp_end": a_hp,
			"defender_hp_end": b_hp,
			"rounds": rounds,
			"outcome": outcome,
			"devastation": devastation,
		}
		gs._combat_reports_working.append(report)

	return "Battle at %s: %s (rounds=%d)" % [loc, outcome, rounds]


static func _devastate_star_if_present(gs: GameState, tile: Vector2i) -> Dictionary:
	if gs == null or gs.config == null:
		return {}
	var cfg := gs.config
	var sid := _get_star_id_at_tile(cfg, tile)
	if sid < 0:
		return {}
	var star := _get_star_by_id(cfg, sid)
	if star == null:
		return {}
	# Already neutral/unowned.
	if int(star.owner_id) < 0:
		return {}

	var prev_owner := int(star.owner_id)

	# Wipe ownership.
	star.owner_id = -1
	star.is_capital = false

	# Wipe local garrison storage (if any) and any build orders queued here.
	if gs.stationed_ships.has(sid):
		gs.stationed_ships.erase(sid)
	for i in range(gs.build_queue.size() - 1, -1, -1):
		var o := gs.build_queue[i] as BuildOrder
		if o != null and int(o.star_id) == int(sid):
			gs.build_queue.remove_at(i)

	return {
		"star_id": sid,
		"star_name": star.name,
		"prev_owner_id": prev_owner,
	}


## Colonization
## -----------

## Colonize the star at the selected fleet's current tile, if it's neutral/unowned.
## Requires at least 1 Colony Ship in the fleet. Consumes 1 colony ship on success.
## Returns "" on success, otherwise an error string.
static func try_colonize_from_fleet(gs: GameState, fleet_id: int) -> String:
	# Planning-phase: queue colonization (resolution happens on End Turn).
	if gs == null or gs.config == null:
		return "No active game."
	if int(gs.phase) != int(Enums.TurnPhase.PLANNING):
		return "Turn is resolving."
	var fleet := get_fleet_by_id(gs, fleet_id) as FleetState
	if fleet == null:
		return "Fleet not found."
	if int(fleet.owner_id) != int(gs.active_faction_id):
		return "That's not your fleet."
	if fleet.wants_attack or fleet.wants_colonize:
		return "Fleet already committed this turn."
	# If this fleet (or any friendly fleet here) queued attack, we keep it simple and disallow colonize this turn.
	_ensure_fleet_grid_pos(gs, fleet)
	var here := get_fleets_at_tile(gs, fleet.grid_pos)
	for f_any in here:
		var f := f_any as FleetState
		if f == null:
			continue
		if int(f.owner_id) == int(gs.active_faction_id) and f.wants_attack:
			return "A friendly fleet here is queued to attack this turn."
	# Must be on a star tile and unowned.
	var sid := _get_star_id_at_tile(gs.config, fleet.grid_pos)
	if sid < 0:
		return "No star here to colonize."
	var star := _get_star_by_id(gs.config, sid)
	if star == null:
		return "Star not found."
	if int(star.owner_id) >= 0:
		return "This star is already owned."
	# Must have a colony ship.
	var have := int(fleet.ships.get("COLONY", 0))
	if have <= 0:
		return "Requires a Colony Ship."
	# Queue colonization
	fleet.wants_colonize = true
	return "Colonize queued."


## -----------------
## Combat Reporting
## -----------------

static func _snapshot_side_ships(fleets: Array[FleetState]) -> Dictionary:
	# Returns {"SHIP_ID": count, ...} aggregated across the fleet list.
	var out: Dictionary = {}
	for f in fleets:
		if f == null:
			continue
		for k in f.ships.keys():
			var cnt := int(f.ships[k])
			if cnt <= 0:
				continue
			var key := String(k)
			out[key] = int(out.get(key, 0)) + cnt
	return out

static func _snapshot_side_ships_live(gs: GameState, fleets: Array[FleetState]) -> Dictionary:
	# Like _snapshot_side_ships, but ignores fleets that were pruned from gs.
	var out: Dictionary = {}
	for f in fleets:
		if f == null:
			continue
		if gs != null and get_fleet_by_id(gs, int(f.id)) == null:
			continue
		for k in f.ships.keys():
			var cnt := int(f.ships[k])
			if cnt <= 0:
				continue
			var key := String(k)
			out[key] = int(out.get(key, 0)) + cnt
	return out

static func _snapshot_fleet_ids(fleets: Array[FleetState]) -> Array[int]:
	var out: Array[int] = []
	for f in fleets:
		if f == null:
			continue
		out.append(int(f.id))
	return out

static func _snapshot_fleet_ids_live(gs: GameState, fleets: Array[FleetState]) -> Array[int]:
	var out: Array[int] = []
	for f in fleets:
		if f == null:
			continue
		if gs != null and get_fleet_by_id(gs, int(f.id)) == null:
			continue
		out.append(int(f.id))
	return out

static func _diff_ship_counts(before: Dictionary, after: Dictionary) -> Dictionary:
	# Returns lost counts per ship type (before - after, clamped at 0).
	var out: Dictionary = {}
	for k in before.keys():
		var b := int(before.get(k, 0))
		var a := int(after.get(k, 0))
		var lost := maxi(0, b - a)
		if lost > 0:
			out[String(k)] = lost
	return out




static func _compute_side_stats(cfg: GalaxyConfig, fleets: Array[FleetState]) -> Dictionary:
	var total_hp := 0
	var total_attack := 0
	if cfg == null:
		return {"hp": 0, "attack": 0}
	for f in fleets:
		if f == null:
			continue
		for k in f.ships.keys():
			var cnt := int(f.ships[k])
			if cnt <= 0:
				continue
			var did := StringName(String(k))
			var stats := compile_design_stats(cfg, did)
			total_hp += cnt * int(stats.get("hull", 1))
			total_attack += cnt * int(stats.get("attack", 0))
	return {"hp": total_hp, "attack": total_attack}

static func _apply_hp_losses(cfg: GalaxyConfig, fleets: Array[FleetState], hp_lost: int) -> void:
	if hp_lost <= 0:
		return
	if cfg == null:
		return

	# Build aggregated counts per design id across these fleets.
	var totals: Dictionary = {}
	for f in fleets:
		if f == null:
			continue
		for k in f.ships.keys():
			var cnt := int(f.ships[k])
			if cnt <= 0:
				continue
			var key := String(k)
			totals[key] = int(totals.get(key, 0)) + cnt

	# Sort by hull ascending (fragile designs die first).
	var design_keys := totals.keys()
	design_keys.sort_custom(func(a, b):
		var sa := compile_design_stats(cfg, StringName(String(a)))
		var sb := compile_design_stats(cfg, StringName(String(b)))
		var ha := int(sa.get("hull", 1))
		var hb := int(sb.get("hull", 1))
		return ha < hb
	)
	
	var remaining_hp := hp_lost
	for key_any in design_keys:
		if remaining_hp <= 0:
			break
		var key := String(key_any)
		var total_cnt := int(totals[key])
		if total_cnt <= 0:
			continue
		var stats := compile_design_stats(cfg, StringName(key))
		var hull := int(stats.get("hull", 1))
		hull = max(1, hull)
		var kill : int = min(total_cnt, int(remaining_hp / hull))
		remaining_hp -= kill * hull
		if remaining_hp > 0 and kill < total_cnt:
			kill += 1
			remaining_hp = max(remaining_hp - hull, 0)
		_distribute_kills_across_fleets(fleets, key, kill)

static func _distribute_kills_across_fleets(fleets: Array[FleetState], ship_key: String, kill: int) -> void:
	if kill <= 0:
		return
	for f in fleets:
		if f == null:
			continue
		if kill <= 0:
			break
		var have := int(f.ships.get(ship_key, 0))
		if have <= 0:
			continue
		var take : int = min(have, kill)
		var left : int = have - take
		if left <= 0:
			f.ships.erase(ship_key)
		else:
			f.ships[ship_key] = left
		kill -= take


static func _prune_empty_fleets(gs: GameState) -> void:
	if gs == null:
		return
	for i in range(gs.fleets.size() - 1, -1, -1):
		var f := gs.fleets[i] as FleetState
		if f == null:
			gs.fleets.remove_at(i)
			continue
		if f.get_total_ships() <= 0:
			gs.fleets.remove_at(i)

static func _get_fleet_speed_tiles_per_turn(cfg: GalaxyConfig, fleet: FleetState) -> int:
	# Fleet speed is the slowest ship grid_range_per_turn present in the fleet.
	# If the fleet is empty or missing defs, default to 1.
	if cfg == null or fleet == null:
		return 1
	var slowest := 999999
	for k in fleet.ships.keys():
		var did := StringName(String(k))
		var stats := compile_design_stats(cfg, did)
		var sp := int(stats.get("grid_range_per_turn", stats.get("speed", 1)))
		slowest = min(slowest, sp)
	if slowest == 999999:
		return 1
	return max(slowest, 1)

static func _get_star_id_at_tile(cfg: GalaxyConfig, tile: Vector2i) -> int:
	if cfg == null:
		return -1
	for s in cfg.stars:
		var si := s as StarInstance
		if si != null and si.pos == tile:
			return int(si.id)
	return -1

## Attempts to queue a ship DESIGN build at a star, spending resources.
## Returns an empty string on success, otherwise a user-friendly error message.
static func try_queue_design_build(gs: GameState, star_id: int, design_id: StringName, quantity: int) -> String:
	if gs == null or gs.config == null:
		return "No active game."
	if int(gs.phase) != int(Enums.TurnPhase.PLANNING):
		return "Turn is resolving."
	if quantity <= 0:
		return "Quantity must be at least 1."

	var cfg := gs.config
	var star := _get_star_by_id(cfg, star_id)
	if star == null:
		return "Select a valid star."

	# Must own the star to build there (v0 rule).
	if star.owner_id != gs.active_faction_id:
		return "You can only build at stars you own."

	var hull_def := resolve_hull_def(cfg, design_id)
	if hull_def == null:
		return "Unknown design/hull."

	var fs := get_faction_state(gs, gs.active_faction_id)
	if fs == null:
		return "Faction state not found."

	var costs := design_costs(cfg, design_id)
	var total_cred := int(costs.credits) * quantity
	if fs.credits < total_cred:
		return "Not enough credits. Need %d." % total_cred

	# TODO: implement research unlock checks.
	# For now we keep the old behavior: if anything requires tech, we block.
	var d := resolve_design_def(cfg, design_id)
	if d != null:
		if (d.required_techs != null and d.required_techs.size() > 0) or int(d.required_tech_ids.size()) > 0:
			return "Requires research (not implemented yet)."
	if (hull_def.required_techs != null and hull_def.required_techs.size() > 0) or int(hull_def.required_tech_ids.size()) > 0:
		return "Requires research (not implemented yet)."
	for m in resolve_modules_for_design(cfg, design_id):
		if m == null:
			continue
		if (m.required_techs != null and m.required_techs.size() > 0) or int(m.required_tech_ids.size()) > 0:
			return "Requires research (not implemented yet)."

	# Spend credits (production is throughput applied each turn)
	fs.credits -= total_cred

	# Queue build order
	var order := BuildOrder.new()
	order.star_id = star_id
	order.design_id = design_id
	order.ship_id = &""  # deprecated
	order.quantity = quantity
	order.remaining_prod = int(costs.production) * quantity
	gs.build_queue.append(order)
	return ""

## Backward compatible wrapper: ship_id == design_id during transition.
static func try_queue_ship_build(gs: GameState, star_id: int, ship_id: StringName, quantity: int) -> String:
	return try_queue_design_build(gs, star_id, ship_id, quantity)

static func get_faction_state(gs: GameState, faction_id: int) -> FactionState:
	for fs in gs.faction_states:
		if fs.faction_id == faction_id:
			return fs
	return null

static func _apply_economy_income(gs: GameState) -> void:
	var cfg := gs.config
	# Reset per-turn throughput.
	for fs in gs.faction_states:
		fs.reset_incomes()
	# Sum yields into each faction's per-turn throughput, and bank credits.
	for s in cfg.stars:
		if s.owner_id < 0:
			continue
		var fs := get_faction_state(gs, s.owner_id)
		if fs == null:
			continue
		if s.yields != null:
			fs.credits += int(s.yields.credits)
			fs.research_per_turn += int(s.yields.research)
			fs.production_per_turn += int(s.yields.production)

static func compute_faction_throughput(gs: GameState, faction_id: int) -> Dictionary:
	# Returns {"research": int, "production": int} based on owned stars.
	var out := {"research": 0, "production": 0}
	if gs == null or gs.config == null:
		return out
	for s in gs.config.stars:
		if s.owner_id != faction_id:
			continue
		if s.yields == null:
			continue
		out.research += int(s.yields.research)
		out.production += int(s.yields.production)
	return out

static func _process_build_queues(gs: GameState) -> void:
	# Production is NOT banked. Each owned star applies its production throughput
	# to its queued builds each turn. Unused production is lost.
	if gs == null or gs.config == null:
		return

	# Group build orders by star id while preserving per-star order.
	var orders_by_star: Dictionary = {}
	for o_any in gs.build_queue:
		var o := o_any as BuildOrder
		if o == null:
			continue
		if not orders_by_star.has(o.star_id):
			orders_by_star[o.star_id] = []
		orders_by_star[o.star_id].append(o)

	# Process each star's queue.
	for s_any in gs.config.stars:
		var s := s_any as StarInstance
		if s == null:
			continue
		if s.owner_id < 0:
			continue
		if not orders_by_star.has(s.id):
			continue
		if s.yields == null:
			continue
		var p_left := int(s.yields.production)
		if p_left <= 0:
			continue

		var list: Array = orders_by_star[s.id]
		var i := 0
		while i < list.size() and p_left > 0:
			var o: BuildOrder = list[i]
			if o == null:
				i += 1
				continue

			var design_id := o.get_effective_design_id()
			if String(design_id) == "":
				# Nothing to do.
				i += 1
				continue

			if o.remaining_prod <= 0:
				# Safety: initialize if older queues lacked progress.
				var costs0 := design_costs(gs.config, design_id)
				o.remaining_prod = int(costs0.production) * max(1, o.quantity)

			if o.remaining_prod <= 0:
				i += 1
				continue

			var spend : float = min(p_left, o.remaining_prod)
			o.remaining_prod -= spend
			p_left -= spend

			if o.remaining_prod <= 0:
				_complete_build_order(gs, s.id, o)
				# Remove from both lists and global queue.
				list.remove_at(i)
				gs.build_queue.erase(o)
				continue
			i += 1
		# Unused p_left is lost by design.

static func _complete_build_order(gs: GameState, star_id: int, o: BuildOrder) -> void:
	# Adds completed ships to the stationed pool.
	if gs == null or o == null:
		return
	var design_id := o.get_effective_design_id()
	if String(design_id) == "":
		return
	if not gs.stationed_ships.has(star_id):
		gs.stationed_ships[star_id] = {}
	var bucket: Dictionary = gs.stationed_ships[star_id]
	var key := String(design_id)
	var prev := int(bucket.get(key, 0))
	bucket[key] = prev + max(1, o.quantity)
	gs.stationed_ships[star_id] = bucket
	print("Completed build: ", o.quantity, "x ", String(design_id), " at star ", star_id)

static func _ensure_fleet_grid_pos(gs: GameState, fleet: FleetState) -> void:
	if fleet == null or gs == null or gs.config == null:
		return
	if fleet.grid_pos.x >= 0 and fleet.grid_pos.y >= 0:
		return
	# Fall back to its star position if available.
	var star := _get_star_by_id(gs.config, int(fleet.star_id))
	if star != null:
		fleet.grid_pos = star.pos
		return
	# Last resort: place it at origin so it's not invalid.
	printerr("moving fleet to origin, because of error")
	fleet.grid_pos = Vector2i(0, 0)

static func _get_star_by_id(cfg: GalaxyConfig, star_id: int) -> StarInstance:
	for s in cfg.stars:
		if s.id == star_id:
			return s
	return null

static func _find_first_human_faction_id(cfg: GalaxyConfig) -> int:
	# control_type: 0 = human
	for f in cfg.factions:
		if int(f.control_type) == 0:
			return f.id
	return 0
