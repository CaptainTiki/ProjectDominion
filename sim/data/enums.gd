extends Node
class_name Enums

enum StarType {
	RED,
	BLUE,
	YELLOW,
	NEUTRON
}

enum ShipClass {
	SCOUT,
	FRIGATE,
	DESTROYER,
	BATTLESHIP,
	COLONY
}

# New canonical ship taxonomy (hull sizes). ShipClass is legacy and will be phased out.
enum HullSize {
	SMALL,
	MEDIUM,
	LARGE,
	XLARGE
}

# Slot types used by module-based ship building.
enum ModuleSlotType {
	WEAPON,
	ARMOR,
	SENSOR,
	CARGO,
	ENGINE
}

enum TurnPhase {
	PLANNING,
	RESOLVING
}

static func star_type_name(t: StarType) -> String:
	match t:
		StarType.RED: return "Red Star"
		StarType.BLUE: return "Blue Star"
		StarType.YELLOW: return "Yellow Star"
		StarType.NEUTRON: return "Neutron Star"
		_: return "Unknown"

static func ship_class_name(t: ShipClass) -> String:
	match t:
		ShipClass.SCOUT: return "Scout"
		_: return "Unknown Ship"

static func hull_size_name(t: HullSize) -> String:
	match t:
		HullSize.SMALL: return "Small"
		HullSize.MEDIUM: return "Medium"
		HullSize.LARGE: return "Large"
		HullSize.XLARGE: return "X-Large"
		_: return "Unknown"

static func module_slot_type_name(t: ModuleSlotType) -> String:
	match t:
		ModuleSlotType.WEAPON: return "Weapon"
		ModuleSlotType.ARMOR: return "Armor"
		ModuleSlotType.SENSOR: return "Sensor"
		ModuleSlotType.CARGO: return "Cargo"
		ModuleSlotType.ENGINE: return "Engine"
		_: return "Unknown"
