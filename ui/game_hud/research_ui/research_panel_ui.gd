extends PanelContainer
class_name ResearchPanelUI

signal close_pressed

var _game_state : GameState
var _catalog : TechTypeCatalog

func _ready() -> void:
	%CloseBtn.pressed.connect(func(): close_pressed.emit())


func open_for_context(gs: GameState) -> void:
	_game_state = gs
	_catalog = (gs.config.tech_types if gs != null and gs.config != null else null)

	show()

func refresh() -> void:
	pass
