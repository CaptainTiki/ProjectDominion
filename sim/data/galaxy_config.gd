extends Resource
class_name GalaxyConfig

@export var galaxy_size: int = 30
@export var factions: Array[FactionDef] = []
@export var stars: Array[StarInstance] = []
@export var seed_used: String = ""

@export var star_types: StarTypeCatalog

# Hull catalog (legacy name preserved). HullDef is the new canonical chassis.
@export var ship_types: ShipTypeCatalog

# Design catalog: what the game actually builds.
@export var ship_designs: ShipDesignCatalog

# Module catalog for resolving ShipDesignDef.module_ids.
@export var module_catalog: ModuleCatalog

@export var tech_types: TechTypeCatalog
