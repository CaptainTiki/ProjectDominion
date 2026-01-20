extends Resource
class_name GameState

@export var turn: int = 1

# Two-phase turn model: planning -> resolving
@export var phase: int = Enums.TurnPhase.PLANNING

# For simultaneous turns: which factions have submitted their plans for this turn.
@export var ready_factions: Dictionary = {}

# Which faction the local player is currently controlling/viewing.
@export var active_faction_id: int = 0

# Static map/content data for this run.
@export var config: GalaxyConfig

# Per-faction runtime totals (credits / research / production).
@export var faction_states: Array[FactionState] = []

# Global build queue (v0). We filter by star_id in the UI.
@export var build_queue: Array[BuildOrder] = []

# Ships stationed at a star ("garrison" for now). Stored as:
#   stationed_ships[star_id][ship_id_string] = count
@export var stationed_ships: Dictionary = {}

# Mobile fleets (v0). Each FleetState has ships and a current star_id.
@export var fleets: Array = []
@export var next_fleet_id: int = 1

# Combat reports generated during the most recently resolved turn.
# Each entry is a Dictionary produced by TurnSystem (see TurnSystem._resolve_battle_at_tile).
@export var combat_reports_last_turn: Array = []

# Working buffer used during RESOLVING. Not exported/serialized.
var _combat_reports_working: Array = []
