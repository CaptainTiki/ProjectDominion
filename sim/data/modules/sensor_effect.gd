extends ModuleEffect
class_name SensorEffect

# Passive detection range, and optional deep-scan capability.
@export_range(0, 20) var passive_range_bonus: int = 0
@export_range(0, 10) var fleet_detail_tier_bonus: int = 0

# Strategic scan support (star scans)
@export_range(0, 10) var scan_range_bonus: int = 0
@export_range(0, 10) var scan_speed_bonus: int = 0

# Enables deep scan of fleets (weapons/bonuses intel).
@export var enables_deep_scan: bool = false
