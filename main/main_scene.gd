extends Node3D
class_name MainScene

@onready var scene_root: Node3D = $SceneRoot

const MAIN_MENU_SCENE: PackedScene = preload("uid://3cnv5sbv4bqr")
const NEW_GAME_SCENE: PackedScene = preload("uid://isn64b5gptwv")
const GALAXY_MAP_SCENE: PackedScene = preload("uid://cyaksad2mmfll")
const UISCENE: PackedScene = preload("uid://d3rupg7whfm6b")

var _current_menu: Control = null
var _current_game: GalaxyMap = null
var UI : UIManager = null
var _game_state: GameState = null

func _ready() -> void:
	UI = UISCENE.instantiate() as UIManager
	add_child(UI)
	UI.game_state_changed.connect(_refresh_world_from_state)
	call_deferred("show_main_menu")

# -----------------------------
# MENU FLOW
# -----------------------------
func show_main_menu() -> void:
	_clear_game()
	UI.clear_game_ui()
	_show_menu(MAIN_MENU_SCENE)

	_current_menu.request_new_game.connect(show_new_game_menu)
	_current_menu.request_settings.connect(_on_request_settings)
	_current_menu.request_exit.connect(_on_request_exit)

func show_new_game_menu() -> void:
	_show_menu(NEW_GAME_SCENE)

	_current_menu.canceled.connect(show_main_menu)
	_current_menu.accepted_config.connect(start_galaxy_map)

func _show_menu(scene: PackedScene) -> void:
	_clear_menu()
	_current_menu = scene.instantiate()
	UI.menus.add_child(_current_menu)

func _clear_menu() -> void:
	if _current_menu and is_instance_valid(_current_menu):
		_current_menu.queue_free()
	_current_menu = null

# -----------------------------
# GAME FLOW
# -----------------------------
func start_galaxy_map(config: Resource) -> void:
	_clear_menu()
	_clear_game()
	UI.top_bar.show()

	_current_game = GALAXY_MAP_SCENE.instantiate() as GalaxyMap

	if _current_game.has_method("set_config"):
		_current_game.set_config(config)

	# Create runtime state (turn + resources) for this new game.
	_game_state = TurnSystem.create_new_game_state(_current_game.config)
	UI.set_game_state(_game_state)
	_refresh_world_from_state()
	if UI.request_end_turn.is_connected(_on_request_end_turn):
		UI.request_end_turn.disconnect(_on_request_end_turn)
	UI.request_end_turn.connect(_on_request_end_turn)

	scene_root.add_child(_current_game)

	# Debug: allow toggling fog-of-war overlay on/off from the top bar.
	if UI.top_bar.fog_toggled.is_connected(_on_fog_toggled):
		UI.top_bar.fog_toggled.disconnect(_on_fog_toggled)
	UI.top_bar.fog_toggled.connect(_on_fog_toggled)
	_current_game.set_fog_enabled(UI.top_bar.get_fog_enabled())

	if _current_game.has_signal("request_exit_to_menu"):
		_current_game.request_exit_to_menu.connect(show_main_menu)
	if _current_game.has_signal("selection_changed"):
		_current_game.selection_changed.connect(_on_selection_changed)
	if _current_game.has_signal("selection_cleared"):
		_current_game.selection_cleared.connect(_on_selection_cleared)
	if _current_game.has_signal("fleet_move_completed"):
		_current_game.fleet_move_completed.connect(_on_fleet_move_completed)

	# Dock action: request move fleet
	if UI.left_dock and not UI.left_dock.move_fleet_requested.is_connected(_on_move_fleet_requested):
		UI.left_dock.move_fleet_requested.connect(_on_move_fleet_requested)
	# Dock action: request attack
	if UI.left_dock and not UI.left_dock.attack_fleet_requested.is_connected(_on_attack_fleet_requested):
		UI.left_dock.attack_fleet_requested.connect(_on_attack_fleet_requested)
	# Dock action: request colonize
	if UI.left_dock and not UI.left_dock.colonize_fleet_requested.is_connected(_on_colonize_fleet_requested):
		UI.left_dock.colonize_fleet_requested.connect(_on_colonize_fleet_requested)
	
	#UI.selected_label.text = "Selected: (none)"

func _clear_game() -> void:
	if _current_game and is_instance_valid(_current_game):
		_current_game.queue_free()
	_current_game = null
	_game_state = null

func _refresh_world_from_state() -> void:
	# Push latest GameState into the 3D world so it can update markers.
	if _current_game == null:
		return
	if _game_state == null:
		return
	if _current_game.has_method("set_game_state"):
		_current_game.set_game_state(_game_state)

func _on_selection_changed(selected: Node3D, kind: String) -> void:
	if selected == null:
		UI.left_dock.hide_dock()
		UI.set_selected_star(null)
		return

	if kind == "star" and selected.has_meta("star_instance"):
		UI.left_dock.clear_move_targeting()
		var star: StarInstance = selected.get_meta("star_instance")
		UI.left_dock.show_star(star, _game_state, _current_game.config)
		UI.set_selected_star(star)
		return
	if kind == "fleet" and selected.has_meta("fleet_id"):
		var fid := int(selected.get_meta("fleet_id"))
		var fleet: FleetState = TurnSystem.get_fleet_by_id(_game_state, fid)
		UI.left_dock.show_fleet(fleet, _game_state, _current_game.config)
		UI.set_selected_fleet(fid)
		# Also set star context for panels.
		var star := TurnSystem.get_star_by_id(_current_game.config, int(fleet.star_id)) if fleet != null else null
		UI.set_selected_star(star)
		return

func _on_selection_cleared(_kind: String) -> void:
	UI.left_dock.hide_dock()
	UI.set_selected_star(null)
	UI.left_dock.clear_move_targeting()

func _on_move_fleet_requested(fleet_id: int) -> void:
	if _current_game == null:
		return
	_current_game.begin_move_fleet(fleet_id)

func _on_attack_fleet_requested(fleet_id: int) -> void:
	if _game_state == null:
		return
	var msg := TurnSystem.try_attack_from_fleet(_game_state, fleet_id)
	if msg != "":
		print(msg)
	# Attack is queued; combat resolves on End Turn.
	UI.set_game_state(_game_state)
	_refresh_world_from_state()
	if _current_game != null:
		var fleet: FleetState = TurnSystem.get_fleet_by_id(_game_state, fleet_id)
		if fleet != null:
			UI.left_dock.show_fleet(fleet, _game_state, _current_game.config)
			UI.set_selected_fleet(fleet_id)
			var star := TurnSystem.get_star_by_id(_current_game.config, int(fleet.star_id))
			UI.set_selected_star(star)
func _on_colonize_fleet_requested(fleet_id: int) -> void:
	if _game_state == null:
		return
	var msg := TurnSystem.try_colonize_from_fleet(_game_state, fleet_id)
	if msg != "":
		print(msg)
	# Colonize is queued; resolution happens on End Turn.
	UI.set_game_state(_game_state)
	_refresh_world_from_state()
	if _current_game != null:
		var fleet: FleetState = TurnSystem.get_fleet_by_id(_game_state, fleet_id)
		if fleet != null:
			UI.left_dock.show_fleet(fleet, _game_state, _current_game.config)
			UI.set_selected_fleet(fleet_id)
			var star := TurnSystem.get_star_by_id(_current_game.config, int(fleet.star_id))
			UI.set_selected_star(star)
func _on_fleet_move_completed(_fleet_id: int, _dest_star_id: int, err: String) -> void:
	# We don't have a toast system yet; keep it simple and clear the targeting hint.
	UI.left_dock.clear_move_targeting()
	if err != "" and err != "cancelled":
		print("Fleet move failed: ", err)

func _on_request_end_turn() -> void:
	if _game_state == null:
		return
	TurnSystem.end_turn(_game_state)
	UI.set_game_state(_game_state)
	_refresh_world_from_state()
	# If any combats happened during resolution, show the report panel.
	UI.show_combat_results_from_state()

# -----------------------------
# BUTTON HOOKS
# -----------------------------
func _on_request_settings() -> void:
	print("Settings clicked (TODO)")

func _on_request_exit() -> void:
	get_tree().quit()

func _on_fog_toggled(enabled: bool) -> void:
	if _current_game != null and is_instance_valid(_current_game):
		_current_game.set_fog_enabled(enabled)
