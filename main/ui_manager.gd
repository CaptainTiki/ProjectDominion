extends CanvasLayer
class_name UIManager

signal request_end_turn
signal game_state_changed

@onready var menus: Control = %Menus
@onready var left_dock: LeftDockUI = %LeftDockUI
@onready var top_bar: TopBarUI = %TopBarUI
@onready var production_panel: ProductionPanelUI = %ProductionPanelUI
@onready var fleets_panel: FleetsPanelUI = %FleetsPanelUI
@onready var research_panel: PanelContainer = %ResearchPanelUI
@onready var combat_results_panel: CombatResultsPanelUI = %CombatResultsPanelUI

var game_state: GameState
var selected_star: StarInstance
var selected_fleet_id: int = -1

func _ready() -> void:
	top_bar.hide()
	left_dock.hide_dock()
	production_panel.hide()
	fleets_panel.hide()
	research_panel.hide()
	combat_results_panel.hide_panel()

	# Top bar actions
	top_bar.end_turn_pressed.connect(func(): request_end_turn.emit())
	top_bar.production_pressed.connect(_toggle_production)
	top_bar.fleets_pressed.connect(_toggle_fleets)
	top_bar.research_pressed.connect(_toggle_research)

	production_panel.close_pressed.connect(func(): production_panel.hide())
	production_panel.build_requested.connect(_on_build_requested)

	fleets_panel.close_pressed.connect(func(): fleets_panel.hide())
	fleets_panel.create_fleet_requested.connect(_on_create_fleet_requested)
	fleets_panel.transfer_requested.connect(_on_transfer_requested)
	
	research_panel.close_pressed.connect(func(): research_panel.hide())
	combat_results_panel.closed.connect(func(): combat_results_panel.hide_panel())

func clear_game_ui() -> void:
	# Called when exiting a game back to menus.
	top_bar.hide()
	production_panel.hide()
	fleets_panel.hide()
	research_panel.hide()
	left_dock.hide_dock()
	game_state = null
	selected_star = null
	selected_fleet_id = -1

func set_game_state(gs: GameState) -> void:
	game_state = gs
	_refresh_top_bar()
	if production_panel.visible:
		production_panel.refresh_context(game_state, selected_star)
	if fleets_panel.visible:
		fleets_panel.refresh(game_state, game_state.config, selected_star)
	if research_panel.visible:
		research_panel.refresh()

func set_selected_star(star: StarInstance) -> void:
	selected_star = star
	selected_fleet_id = -1
	if production_panel.visible:
		production_panel.refresh_context(game_state, selected_star)
	if fleets_panel.visible and game_state != null:
		fleets_panel.refresh(game_state, game_state.config, selected_star)

func set_selected_fleet(fleet_id: int) -> void:
	selected_fleet_id = fleet_id

func _refresh_top_bar() -> void:
	if game_state == null:
		return
	var fs := TurnSystem.get_faction_state(game_state, game_state.active_faction_id)
	if fs == null:
		return
	# Credits are banked; research/production are throughput per turn.
	var thr := TurnSystem.compute_faction_throughput(game_state, game_state.active_faction_id)
	top_bar.set_state(game_state.turn, fs.credits, int(thr["research"]), int(thr["production"]))

func _toggle_production() -> void:
	if production_panel.visible:
		production_panel.hide()
		return
	if game_state == null:
		return
	production_panel.open_for_context(game_state, selected_star)

func _toggle_fleets() -> void:
	if fleets_panel.visible:
		fleets_panel.hide()
		return
	if game_state == null:
		return
	fleets_panel.open_for_context(game_state, game_state.config, selected_star, selected_fleet_id)

func _toggle_research() -> void:
	if research_panel.visible:
		research_panel.hide()
		return
	if game_state == null:
		return
	research_panel.open_for_context(game_state)

func _on_build_requested(design_id: StringName, quantity: int) -> void:
	if game_state == null:
		production_panel.show_message("No active game.")
		return
	if selected_star == null:
		production_panel.show_message("Select a star first.")
		return
	var err := TurnSystem.try_queue_design_build(game_state, selected_star.id, design_id, quantity)
	if err != "":
		production_panel.show_message(err)
	else:
		production_panel.show_message("Queued!")
		_refresh_top_bar()
		production_panel.refresh_context(game_state, selected_star)
		game_state_changed.emit()

func _on_create_fleet_requested() -> void:
	if game_state == null:
		fleets_panel.show_error("No active game.")
		return
	if selected_star == null:
		fleets_panel.show_error("Select a star first.")
		return
	var err := TurnSystem.try_create_fleet(game_state, selected_star.id)
	if err != "":
		fleets_panel.show_error(err)
		return
	# Select newest fleet at this star.
	var fleets := TurnSystem.get_fleets_at_star(game_state, selected_star.id)
	if not fleets.is_empty():
		selected_fleet_id = int(fleets[-1].id)
	_refresh_top_bar()
	fleets_panel.refresh(game_state, game_state.config, selected_star)
	game_state_changed.emit()

func _on_transfer_requested(ship_id: StringName, count: int, fleet_id: int) -> void:
	if game_state == null or selected_star == null:
		return
	var err := TurnSystem.try_transfer_garrison_to_fleet(game_state, selected_star.id, fleet_id, ship_id, count)
	if err != "":
		fleets_panel.show_error(err)
		return
	fleets_panel.show_error("Transferred.")
	fleets_panel.refresh(game_state, game_state.config, selected_star)
	game_state_changed.emit()


## -----------------
## Combat Results
## -----------------

func show_combat_results_from_state() -> void:
	if game_state == null or game_state.config == null:
		return
	var reports := game_state.combat_reports_last_turn
	if reports == null or reports.is_empty():
		return
	combat_results_panel.open_for_reports(reports, game_state.config)
