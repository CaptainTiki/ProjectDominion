extends PanelContainer
class_name LeftDockUI

signal move_fleet_requested(fleet_id: int)
signal attack_fleet_requested(fleet_id: int)
signal colonize_fleet_requested(fleet_id: int)

@onready var star_panel: StarInfoUI = %StarInfoUI
@onready var fleet_panel: FleetInfoUI = %FleetInfoUI

func _ready() -> void:
	# Default hidden until selection.
	hide_dock()
	if fleet_panel and not fleet_panel.move_requested.is_connected(_on_move_requested):
		fleet_panel.move_requested.connect(_on_move_requested)
	if fleet_panel and not fleet_panel.attack_requested.is_connected(_on_attack_requested):
		fleet_panel.attack_requested.connect(_on_attack_requested)
	if fleet_panel and not fleet_panel.colonize_requested.is_connected(_on_colonize_requested):
		fleet_panel.colonize_requested.connect(_on_colonize_requested)

func _on_move_requested(fid: int) -> void:
	move_fleet_requested.emit(fid)
	# Provide immediate feedback in the dock.
	if fleet_panel:
		fleet_panel.indicate_move_targeting(true)

func _on_attack_requested(fid: int) -> void:
	attack_fleet_requested.emit(fid)

func _on_colonize_requested(fid: int) -> void:
	colonize_fleet_requested.emit(fid)

func clear_move_targeting() -> void:
	if fleet_panel:
		fleet_panel.indicate_move_targeting(false)

func show_dock() -> void:
	show()

func hide_dock() -> void:
	if star_panel:
		star_panel.hide_panel()
	if fleet_panel:
		fleet_panel.hide_panel()
	hide()

func show_star(star: StarInstance, gs: GameState, cfg: GalaxyConfig) -> void:
	if cfg == null:
		hide_dock()
		return
	show_dock()
	if fleet_panel:
		fleet_panel.hide_panel()
	if star_panel:
		star_panel.set_star(star, gs, cfg.factions as Array, cfg.star_types, cfg.ship_types)

func show_fleet(fleet: FleetState, gs: GameState, cfg: GalaxyConfig) -> void:
	if cfg == null:
		hide_dock()
		return
	show_dock()
	if star_panel:
		star_panel.hide_panel()
	if fleet_panel:
		fleet_panel.set_fleet(fleet, gs, cfg)
