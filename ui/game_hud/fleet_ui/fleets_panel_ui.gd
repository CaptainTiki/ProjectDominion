extends PanelContainer
class_name FleetsPanelUI

signal close_pressed
signal create_fleet_requested
signal transfer_requested(ship_id: StringName, count: int, fleet_id: int)

@onready var ctx_label: Label = %ContextLabel
@onready var garrison_list: ItemList = %GarrisonList
@onready var fleets_list: ItemList = %FleetsList
@onready var fleet_ships_list: ItemList = %FleetShipsList
@onready var error_label: Label = %ErrorLabel

@onready var btn_close: Button = %CloseBtn
@onready var btn_create: Button = %CreateFleetBtn
@onready var btn_add1: Button = %AddOneBtn
@onready var btn_add5: Button = %AddFiveBtn

var _gs: GameState = null
var _cfg: GalaxyConfig = null
var _star: StarInstance = null
var _selected_fleet_id: int = -1

func _ready() -> void:
	hide()
	btn_close.pressed.connect(func(): close_pressed.emit())
	btn_create.pressed.connect(func(): create_fleet_requested.emit())
	btn_add1.pressed.connect(func(): _request_transfer(1))
	btn_add5.pressed.connect(func(): _request_transfer(5))
	fleets_list.item_selected.connect(_on_fleet_selected)

func open_for_context(gs: GameState, cfg: GalaxyConfig, star: StarInstance, prefer_fleet_id: int = -1) -> void:
	_gs = gs
	_cfg = cfg
	_star = star
	_error(" ")
	_refresh()
	if prefer_fleet_id > 0:
		_select_fleet_id(prefer_fleet_id)
	show()

func refresh(gs: GameState, cfg: GalaxyConfig, star: StarInstance) -> void:
	_gs = gs
	_cfg = cfg
	_star = star
	_refresh()

func _refresh() -> void:
	if _cfg == null or _gs == null or _star == null:
		ctx_label.text = "Select a star to manage fleets."
		garrison_list.clear()
		fleets_list.clear()
		fleet_ships_list.clear()
		btn_create.disabled = true
		btn_add1.disabled = true
		btn_add5.disabled = true
		return

	ctx_label.text = "At: %s (%d, %d)" % [_star.name, _star.pos.x, _star.pos.y]

	# Garrison
	garrison_list.clear()
	var g := TurnSystem.get_garrison(_gs, _star.id)
	if g.size() == 0:
		garrison_list.add_item("(empty)")
		garrison_list.set_item_disabled(0, true)
	else:
		for key in g.keys():
			var cnt := int(g[key])
			var did := StringName(String(key))
			var name := TurnSystem.design_display_name(_cfg, did)
			garrison_list.add_item("%dx %s" % [cnt, name])
			garrison_list.set_item_metadata(garrison_list.item_count - 1, StringName(String(key)))

	# Fleets at star
	fleets_list.clear()
	var fleets := TurnSystem.get_fleets_at_star(_gs, _star.id)
	for f in fleets:
		var fleet: FleetState = f
		var label := "%s  (%d ships)" % [fleet.name, fleet.get_total_ships()]
		fleets_list.add_item(label)
		fleets_list.set_item_metadata(fleets_list.item_count - 1, int(fleet.id))

	if fleets.is_empty():
		fleets_list.add_item("(none)")
		fleets_list.set_item_disabled(0, true)
		_selected_fleet_id = -1
		fleet_ships_list.clear()
	else:
		# Keep selection if possible, else default to first.
		if _selected_fleet_id <= 0:
			_selected_fleet_id = int(fleets[0].id)
		_update_fleet_ships()

	# Buttons
	btn_create.disabled = (_star.owner_id != _gs.active_faction_id)
	var can_transfer := (_selected_fleet_id > 0 and g.size() > 0)
	btn_add1.disabled = not can_transfer
	btn_add5.disabled = not can_transfer

func _on_fleet_selected(index: int) -> void:
	var meta = fleets_list.get_item_metadata(index)
	if meta is int:
		_selected_fleet_id = int(meta)
		_update_fleet_ships()
		_refresh()

func _update_fleet_ships() -> void:
	fleet_ships_list.clear()
	var fleet: FleetState = TurnSystem.get_fleet_by_id(_gs, _selected_fleet_id)
	if fleet == null:
		return
	if fleet.ships.size() == 0:
		fleet_ships_list.add_item("(empty)")
		fleet_ships_list.set_item_disabled(0, true)
		return
	for key in fleet.ships.keys():
		var cnt := int(fleet.ships[key])
		var did := StringName(String(key))
		var name := TurnSystem.design_display_name(_cfg, did)
		fleet_ships_list.add_item("%dx %s" % [cnt, name])

func _select_fleet_id(fid: int) -> void:
	_selected_fleet_id = fid
	# Try to select in UI list.
	for i in range(fleets_list.item_count):
		var meta = fleets_list.get_item_metadata(i)
		if meta is int and int(meta) == fid:
			fleets_list.select(i)
			_update_fleet_ships()
			return

func _request_transfer(n: int) -> void:
	if _star == null or _gs == null:
		return
	if _selected_fleet_id <= 0:
		return
	var sel := garrison_list.get_selected_items()
	if sel.size() == 0:
		_error("Pick a garrison ship first.")
		return
	var idx := sel[0]
	var ship_id : StringName = garrison_list.get_item_metadata(idx)
	if ship_id == null or not (ship_id is StringName):
		_error("Pick a valid garrison ship.")
		return
	transfer_requested.emit(ship_id, n, _selected_fleet_id)

func show_error(msg: String) -> void:
	_error(msg)

func _error(msg: String) -> void:
	if error_label:
		error_label.text = msg