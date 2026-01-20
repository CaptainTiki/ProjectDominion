extends PanelContainer
class_name ProductionPanelUI

signal close_pressed
signal build_requested(design_id: StringName, quantity: int)

@onready var ship_list: ItemList = %ShipList
@onready var star_label: Label = %StarLabel
@onready var cost_label: Label = %CostLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var message_label: Label = %MessageLabel
@onready var queue_list: ItemList = %QueueList

var _design_catalog: ShipDesignCatalog
var _selected_star: StarInstance
var _game_state: GameState

func _ready() -> void:
	%CloseBtn.pressed.connect(func(): close_pressed.emit())
	%Build1Btn.pressed.connect(func(): _request_build(1))
	%Build5Btn.pressed.connect(func(): _request_build(5))
	ship_list.item_selected.connect(_on_design_selected)
	_hide_details()

func open_for_context(gs: GameState, selected_star: StarInstance) -> void:
	_game_state = gs
	_design_catalog = (gs.config.ship_designs if gs != null and gs.config != null else null)
	_selected_star = selected_star
	_refresh_star()
	_refresh_design_list()
	_refresh_queue()
	message_label.text = ""
	show()

func refresh_context(gs: GameState, selected_star: StarInstance) -> void:
	# Call this when selection changes or state changes (end turn).
	_game_state = gs
	_design_catalog = (gs.config.ship_designs if gs != null and gs.config != null else null)
	_selected_star = selected_star
	_refresh_star()
	_refresh_queue()
	# Keep current selection and details.
	if ship_list.get_selected_items().size() > 0:
		_on_design_selected(ship_list.get_selected_items()[0])

func show_message(text: String) -> void:
	message_label.text = text

func _refresh_star() -> void:
	if _selected_star == null:
		star_label.text = "Select a star to build ships"
	else:
		star_label.text = "Building at: %s" % _selected_star.name

func _refresh_design_list() -> void:
	ship_list.clear()
	if _design_catalog == null:
		ship_list.add_item("(Missing ship designs)")
		ship_list.set_item_disabled(0, true)
		return
	for d_any in _design_catalog.designs:
		var d := d_any as ShipDesignDef
		if d == null:
			continue
		var name := d.display_name if d.display_name.strip_edges() != "" else String(d.id)
		ship_list.add_item(name)
		ship_list.set_item_metadata(ship_list.item_count - 1, d.id)

func _refresh_queue() -> void:
	queue_list.clear()
	if _game_state == null:
		return
	var sid := -1
	if _selected_star != null:
		sid = _selected_star.id
	var star_p := 0
	if _selected_star != null and _selected_star.yields != null:
		star_p = int(_selected_star.yields.production)
	for o_any in _game_state.build_queue:
		var o := o_any as BuildOrder
		if o == null:
			continue
		if sid != -1 and o.star_id != sid:
			continue
		var did := o.get_effective_design_id()
		var name := TurnSystem.design_display_name(_game_state.config, did) if _game_state.config != null else String(did)
		var rem_p := int(o.remaining_prod)
		var eta := ""
		if star_p > 0 and rem_p > 0:
			var turns := int(ceil(float(rem_p) / float(star_p)))
			eta = "  (~%dt)" % turns
		queue_list.add_item("%dx %s  [rem %dP]%s" % [o.quantity, name, rem_p, eta])

func _hide_details() -> void:
	cost_label.text = "Select a design"
	stats_label.text = ""
	%Build1Btn.disabled = true
	%Build5Btn.disabled = true

func _on_design_selected(index: int) -> void:
	if _game_state == null or _game_state.config == null:
		_hide_details()
		return
	if index < 0 or index >= ship_list.item_count:
		_hide_details()
		return
	var did_meta = ship_list.get_item_metadata(index)
	if not (did_meta is StringName):
		_hide_details()
		return
	var did: StringName = did_meta

	var costs := TurnSystem.design_costs(_game_state.config, did)
	var parts: Array[String] = []
	var p := int(costs.get("production", 0))
	var c := int(costs.get("credits", 0))
	var u := int(costs.get("upkeep", 0))
	if p > 0:
		parts.append("P %d" % p)
	if c > 0:
		parts.append("C %d" % c)
	if u > 0:
		parts.append("U %d" % u)
	if parts.is_empty():
		parts.append("Free")
	cost_label.text = "Cost: %s" % ", ".join(parts)

	var s := TurnSystem.compile_design_stats(_game_state.config, did)
	var dn := TurnSystem.design_display_name(_game_state.config, did)
	stats_label.text = "[b]%s[/b]\nHull: %d  Atk: %d  Def: %d  Spd: %d  Grid: %d" % [
		dn,
		int(s.get("hull", 1)),
		int(s.get("attack", 0)),
		int(s.get("defense", 0)),
		int(s.get("speed", 1)),
		int(s.get("grid_range_per_turn", 1))
	]

	%Build1Btn.disabled = false
	%Build5Btn.disabled = false

func _request_build(qty: int) -> void:
	if ship_list.get_selected_items().size() == 0:
		show_message("Pick a design first.")
		return
	var idx := ship_list.get_selected_items()[0]
	var meta = ship_list.get_item_metadata(idx)
	if not (meta is StringName):
		show_message("Invalid selection.")
		return
	build_requested.emit(meta, qty)
