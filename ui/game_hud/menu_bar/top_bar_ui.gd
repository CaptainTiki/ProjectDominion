extends PanelContainer
class_name TopBarUI

signal end_turn_pressed
signal production_pressed
signal empire_pressed
signal fleets_pressed
signal research_pressed
signal fog_toggled(enabled: bool)

@onready var turn_label: Label = %TurnLabel
@onready var credits_label: Label = %CreditsTotal
@onready var research_label: Label = %ResearchTotal
@onready var production_label: Label = %ProductionTotal

func _ready() -> void:
	%EndTurnBtn.pressed.connect(func(): end_turn_pressed.emit())
	%ProductionBtn.pressed.connect(func(): production_pressed.emit())
	%EmpireBtn.pressed.connect(func(): empire_pressed.emit())
	%FleetsBtn.pressed.connect(func(): fleets_pressed.emit())
	%ResearchBtn.pressed.connect(func(): research_pressed.emit())
	%FogBtn.toggled.connect(func(v: bool): fog_toggled.emit(v))

func set_state(turn: int, credits: int, research: int, production: int) -> void:
	turn_label.text = "Turn %d" % turn
	credits_label.text = "C: %d" % credits
	research_label.text = "R/t: %d" % research
	production_label.text = "P/t: %d" % production

func get_fog_enabled() -> bool:
	return %FogBtn.button_pressed
