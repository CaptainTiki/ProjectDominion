extends Resource
class_name GenerationSettings

@export_range(20, 100) var galaxy_size: int = 30
@export_range(5, 200) var star_count: int = 30
@export var seed_text: String = ""

@export var star_types: StarTypeCatalog

# Hull catalog (legacy name). HullDef based.
@export var ship_types: ShipTypeCatalog

# New catalogs for design-based ships
@export var ship_designs: ShipDesignCatalog
@export var module_catalog: ModuleCatalog

@export var tech_types: TechTypeCatalog
