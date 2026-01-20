extends PanelContainer
class_name FleetInfoUI

signal move_requested(fleet_id: int)
signal attack_requested(fleet_id: int)
signal colonize_requested(fleet_id: int)

@onready var title_label: Label = %TitleLabel
@onready var fleet_name: Label = %FleetName
@onready var owner_label: Label = %OwnerLabel
@onready var owner_swatch: ColorRect = %OwnerSwatch
@onready var location_label: Label = %LocationLabel
@onready var ships_list: ItemList = %ShipsList
@onready var move_btn: Button = %MoveBtn
@onready var attack_btn: Button = %AttackBtn
@onready var colonize_btn: Button = %ColonizeBtn
@onready var contact_label: Label = %ContactLabel

var _fleet_id: int = -1
var _can_move: bool = false
var _enemy_contacts: Array[FleetState] = []

var _gs: GameState = null
var _cfg: GalaxyConfig = null

func show_panel() -> void:
	show()

func _ready() -> void:
	move_btn.pressed.connect(func(): if _fleet_id > 0: move_requested.emit(_fleet_id) )
	attack_btn.pressed.connect(_on_attack_pressed)
	if colonize_btn:
		colonize_btn.pressed.connect(_on_colonize_pressed)

func hide_panel() -> void:
	clear()
	hide()

func clear() -> void:
	_fleet_id = -1
	_can_move = false
	_gs = null
	_cfg = null
	fleet_name.text = "—"
	owner_label.text = ""
	owner_swatch.visible = false
	location_label.text = ""
	ships_list.clear()
	if move_btn:
		move_btn.text = "Move"
		move_btn.disabled = true
	if attack_btn:
		attack_btn.text = "Attack"
		attack_btn.disabled = true
	if colonize_btn:
		colonize_btn.text = "Colonize"
		colonize_btn.disabled = true
	if contact_label:
		contact_label.text = "Contact: None"

func _on_attack_pressed() -> void:
	if _fleet_id < 0:
		return
	if _enemy_contacts.is_empty():
		return

	attack_requested.emit(_fleet_id)

func _on_colonize_pressed() -> void:
	if _fleet_id < 0:
		return
	colonize_requested.emit(_fleet_id)


func set_fleet(fleet: FleetState, gs: GameState, cfg: GalaxyConfig) -> void:
	if fleet == null or cfg == null:
		clear()
		return
	show_panel()
	_gs = gs
	_cfg = cfg
	_fleet_id = int(fleet.id)

	title_label.text = "Selected"
	fleet_name.text = fleet.name
	
	_refresh_contacts(fleet)
	_refresh_colonize(fleet)
	
	# Owner
	if fleet.owner_id >= 0 and fleet.owner_id < cfg.factions.size():
		var fdef := cfg.factions[fleet.owner_id] as FactionDef
		owner_label.text = fdef.name
		owner_swatch.visible = true
		owner_swatch.color = fdef.color
	else:
		owner_label.text = "Unknown"
		owner_swatch.visible = false

	# Location
	var star := TurnSystem.get_star_by_id(cfg, int(fleet.star_id))
	if star != null:
		location_label.text = "At: %s (%d, %d)" % [star.name, star.pos.x, star.pos.y]
	else:
		# Open-space staging: show tile coords if we have them.
		if fleet.grid_pos != Vector2i(-1, -1):
			location_label.text = "At: Deep Space (%d, %d)" % [fleet.grid_pos.x, fleet.grid_pos.y]
		else:
			location_label.text = "At: Deep Space"

	# Ships
	ships_list.clear()
	if fleet.ships.size() == 0:
		ships_list.add_item("(empty)")
		ships_list.set_item_disabled(0, true)
	else:
		for key in fleet.ships.keys():
			var cnt := int(fleet.ships[key])
			var did := StringName(String(key))
			var s_name := TurnSystem.design_display_name(cfg, did)
			ships_list.add_item("%dx %s" % [cnt, s_name])

	# Move button: only enable for the active faction's fleets.
	var is_player_fleet := (gs != null and int(fleet.owner_id) == int(gs.active_faction_id))
	var is_planning := (gs != null and int(gs.phase) == int(Enums.TurnPhase.PLANNING))
	_can_move = is_player_fleet and is_planning and (not fleet.wants_attack) and (not fleet.wants_colonize)
	if move_btn:
		move_btn.text = "Move"
		move_btn.disabled = not _can_move

	# Attack button: queue an attack during planning when there are enemies in contact.
	if attack_btn:
		if fleet.wants_attack:
			attack_btn.text = "Attack (Queued)"
			attack_btn.disabled = true
		else:
			attack_btn.text = "Attack"
			attack_btn.disabled = not (is_player_fleet and is_planning and _enemy_contacts.size() > 0 and (not fleet.wants_colonize))

	# Colonize button: queue colonization during planning when eligible.
	_refresh_colonize(fleet)


func _get_star_at_fleet_tile(fleet: FleetState) -> StarInstance:
	if fleet == null or _cfg == null:
		return null
	var tile := _get_fleet_tile(fleet)
	for s_any in _cfg.stars:
		var s := s_any as StarInstance
		if s != null and s.pos == tile:
			return s
	return null

func indicate_move_targeting(active: bool) -> void:
	# Optional UI hint: we keep it subtle and reversible.
	if move_btn == null:
		return
	if active:
		move_btn.text = "Click destination..."
		move_btn.disabled = true
		title_label.text = "Move Fleet"
	else:
		move_btn.text = "Move"
		move_btn.disabled = not _can_move
		title_label.text = "Selected"

func _refresh_contacts(fleet: FleetState = null) -> void:
	_enemy_contacts.clear()

	attack_btn.disabled = true
	contact_label.text = "Contact: None"

	if _gs == null:
		contact_label.text = "Contact: (no gamestate)"
		return
	if fleet == null:
		fleet = TurnSystem.get_fleet_by_id(_gs, _fleet_id)
	if fleet == null:
		contact_label.text = "Contact: (fleet missing)"
		return

	# Determine this fleet's tile.
	var tile := _get_fleet_tile(fleet)

	# Include the selected fleet in the friendly count.
	var friendly := 1
	var enemy := 0
	for other_any in _gs.fleets:
		var other := other_any as FleetState
		if other == null:
			continue
		if int(other.id) == int(fleet.id):
			continue
		if _get_fleet_tile(other) != tile:
			continue
		if int(other.owner_id) == int(fleet.owner_id):
			friendly += 1
		else:
			enemy += 1
			_enemy_contacts.append(other)

	if enemy <= 0:
		contact_label.text = "Contact: None"
		attack_btn.disabled = true
		return

	contact_label.text = "Contact: %d friendly, %d enemy" % [friendly, enemy]
	# Only active faction fleets can attack.
	var is_planning := int(_gs.phase) == int(Enums.TurnPhase.PLANNING)
	attack_btn.disabled = (not is_planning) or (int(fleet.owner_id) != int(_gs.active_faction_id)) or fleet.wants_attack
	# Colonize availability may change after combat.
	_refresh_colonize(fleet)


func _refresh_colonize(fleet: FleetState = null) -> void:
	if colonize_btn == null:
		return
	colonize_btn.text = "Colonize"
	colonize_btn.disabled = true
	if _gs == null or _cfg == null:
		return
	if fleet == null:
		fleet = TurnSystem.get_fleet_by_id(_gs, _fleet_id)
	if fleet == null:
		return
	# If already queued, show it and bail.
	if fleet.wants_colonize:
		colonize_btn.text = "Colonize (Queued)"
		colonize_btn.disabled = true
		return
	# Only during planning.
	if int(_gs.phase) != int(Enums.TurnPhase.PLANNING):
		colonize_btn.disabled = true
		return
	# If any friendly fleet queued an attack, keep it simple: no colonize this turn.
	if fleet.wants_attack:
		colonize_btn.text = "Colonize (blocked by Attack)"
		colonize_btn.disabled = true
		return

	# Only active faction can colonize.
	if int(fleet.owner_id) != int(_gs.active_faction_id):
		return
	# Must be on a star tile.
	var star := _get_star_at_fleet_tile(fleet)
	if star == null:
		return
	# Must be neutral/unowned.
	if int(star.owner_id) >= 0:
		return
	# Must have colony ship.
	var have := int(fleet.ships.get("COLONY", 0))
	if have <= 0:
		colonize_btn.text = "Colonize (need Colony Ship)"
		colonize_btn.disabled = true
		return
	colonize_btn.disabled = false
func _get_fleet_tile(f: FleetState) -> Vector2i:
	if f == null:
		return Vector2i(-1, -1)
	if f.grid_pos != Vector2i(-1, -1):
		return f.grid_pos
	# Fall back to star position if needed.
	if _cfg != null:
		var star := TurnSystem.get_star_by_id(_cfg, int(f.star_id))
		if star != null:
			return star.pos
	return Vector2i(0, 0)