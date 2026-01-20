extends Node3D
class_name GalaxyMap

signal selection_changed(sel, kind)
signal selection_cleared(kind)
signal fleet_move_completed(fleet_id: int, dest_star_id: int, err: String)

var config: Resource
var game_state: GameState = null

@onready var grid_plane: MeshInstance3D = %GridPlane
@onready var fog_plane: FogOfWar = %FogPlane
@onready var camera_rig: CameraRig = %CameraRig
@onready var selection_system: SelectionSystem = %SelectionSystem
@onready var stars_root: Node = %StarsRoot
@onready var fleets_root: Node = %FleetsRoot
@onready var cam: Camera3D = %Camera3D

var _fleet_nodes_by_id: Dictionary = {} # int -> Node3D

@export var tile_size := 1.0

const STAR_SCENE: PackedScene = preload("uid://cfv1tw3ndekn1")
const FLEET_SCENE: PackedScene = preload("uid://bc356nqi4a8v0")

func set_config(cfg: Resource) -> void:
	config = cfg

func set_game_state(gs: GameState) -> void:
	game_state = gs
	# If we're already initialized, update world markers.
	if is_inside_tree() and config:
		_spawn_fleets_from_state()
		_apply_garrison_markers()

func _ready() -> void:
	if config:
		_init_galaxy_view()
	
	selection_system.configure(cam, camera_rig, stars_root, fleets_root, int(config.galaxy_size) if config else 0)
	selection_system.selection_changed.connect(func(sel, kind): selection_changed.emit(sel, kind))
	selection_system.selection_cleared.connect(func(kind): selection_cleared.emit(kind))
	selection_system.move_destination_tile_chosen.connect(_on_move_destination_tile_chosen)
	selection_system.move_destination_tile_hovered.connect(_on_move_destination_tile_hovered)
	selection_system.move_cancelled.connect(_on_move_cancelled)

func _process(delta: float) -> void:
	# Turn-based movement: fleets only advance when End Turn resolves in TurnSystem.
	# We keep _process free of movement so orders don't execute immediately.
	pass


## External API ---------------------------------------------------------------

func begin_move_fleet(fleet_id: int) -> void:
	# Enters a "click a destination" mode for this fleet.
	if selection_system:
		selection_system.start_move_fleet(fleet_id)
		# Show hover preview immediately (snapped to grid) even if the mouse doesn't move.
		selection_system.update_move_hover_from_mouse_pos(get_viewport().get_mouse_position())


func _on_move_destination_tile_hovered(fleet_id: int, tile: Vector2i, _snapped_world: Vector3) -> void:
	# Hover preview while picking a destination. This is purely visual; it does NOT issue orders.
	var node := _find_fleet_node_by_id(fleet_id)
	var marker := node as FleetMarker if node != null else null
	if marker == null:
		return
	if tile == Vector2i(-1, -1):
		# Out of bounds: hide the hover line (it will be restored on cancel).
		marker.clear_destination()
		return
	marker.set_destination_global(_world_pos_for_tile(tile), true)

func _on_move_cancelled(fleet_id: int) -> void:
	# Restore the marker to the fleet's actual order state.
	_spawn_fleets_from_state()
	fleet_move_completed.emit(fleet_id, -1, "cancelled")

func _on_move_destination_tile_chosen(fleet_id: int, tile: Vector2i, _hit_world: Vector3) -> void:
	if game_state == null or config == null:
		fleet_move_completed.emit(fleet_id, -1, "No active game.")
		return
	var err : String = TurnSystem.try_move_fleet_to_tile(game_state, fleet_id, tile)
	if err == "":
		# Ensure marker exists and is selected.
		_spawn_fleets_from_state()
		var moved := _find_fleet_node_by_id(fleet_id)
		if moved != null:
			selection_system.select_node(moved, "fleet")
		var sid := _get_star_id_at_tile(tile)
		fleet_move_completed.emit(fleet_id, sid, "")
		return
	# Report failure
	# Restore marker visuals to the fleet's real order state (no hover)
	_spawn_fleets_from_state()
	var sid2 := _get_star_id_at_tile(tile)
	fleet_move_completed.emit(fleet_id, sid2, err)


func _find_fleet_node_by_id(fleet_id: int) -> Node3D:
	var n := _fleet_nodes_by_id.get(fleet_id, null) as Node3D
	return n if n != null and is_instance_valid(n) else null


func _init_galaxy_view() -> void:
	# 1) Resize + center grid plane to match galaxy size
	_apply_grid_params()

	# 2) Spawn stars from config (generated in New Game menu)
	_spawn_stars_from_config()
	# 2b) Spawn fleets + garrison markers if state exists
	_spawn_fleets_from_state()
	_apply_garrison_markers()

	# 3) Frame the camera so the whole map is visible
	_frame_camera_to_map()

func _apply_grid_params() -> void:
	# --- Ensure unique mesh + material so we don't mutate the editor resources ---
	if grid_plane.mesh and not (grid_plane.mesh is PlaneMesh):
		push_warning("GridPlane mesh is not a PlaneMesh")
		return

	var plane_mesh := grid_plane.mesh as PlaneMesh
	if plane_mesh:
		plane_mesh = plane_mesh.duplicate(true)
		plane_mesh.size = Vector2(config.galaxy_size, config.galaxy_size)
		grid_plane.mesh = plane_mesh

	# Center the plane so tile coords (0..size-1) map nicely
	grid_plane.position = Vector3(config.galaxy_size * 0.5, 0.0, config.galaxy_size * 0.5)
	_apply_fog_params()

	var mat := grid_plane.get_active_material(0) as ShaderMaterial
	if mat == null:
		push_warning("GridPlane has no material")
		return
	mat = mat.duplicate(true)
	grid_plane.set_surface_override_material(0, mat)

	# Keep one cell per tile
	mat.set_shader_parameter("grid_cells", float(config.galaxy_size))

	# Optional: make thickness scale slightly for readability on big maps
	var thickness := 0.2
	mat.set_shader_parameter("line_thickness", thickness)

func _apply_fog_params() -> void:
	if fog_plane == null:
		return
	# Resize + center fog plane to match the grid, but offset slightly above to avoid z-fighting.
	if fog_plane.mesh and not (fog_plane.mesh is PlaneMesh):
		push_warning("FogPlane mesh is not a PlaneMesh")
		return
	var plane_mesh := fog_plane.mesh as PlaneMesh
	if plane_mesh:
		plane_mesh = plane_mesh.duplicate(true)
		plane_mesh.size = Vector2(config.galaxy_size, config.galaxy_size)
		fog_plane.mesh = plane_mesh
	# Position: centered like the grid, but slightly above.
	fog_plane.position = Vector3(config.galaxy_size * 0.5, 0.01, config.galaxy_size * 0.5)
	# Initialize paintable fog mask texture.
	fog_plane.setup(int(config.galaxy_size))

func set_fog_enabled(enabled: bool) -> void:
	if fog_plane:
		fog_plane.visible = enabled

func _spawn_stars_from_config() -> void:
	# Clear old stars
	for c in stars_root.get_children():
		c.queue_free()

	# GalaxyConfig always has a 'stars' array; if it's empty, the user likely skipped Generate Map.
	var stars: Array = config.stars
	if stars.is_empty():
		push_warning("No stars in config. Did you press Generate Map?")
		return
	for i in range(stars.size()):
		var s: StarInstance = stars[i]
		if s == null:
			continue

		var star_node: Node3D = STAR_SCENE.instantiate()
		star_node.name = "Star_%d" % i
		star_node.position = _tile_to_world(s.pos)
		star_node.set_meta("star_instance", s)
		stars_root.add_child(star_node)

		# Basic label (v1 readability): star name
		var label: Label3D = star_node.get_node_or_null("Label3D") as Label3D
		if label:
			label.text = s.name
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position.y = 0.6

		# Star size (readability): small/medium/large
		var visual := star_node.get_node_or_null("Visual") as Node3D
		if visual:
			var scale_factor := 1.0
			match int(s.size):
				1: scale_factor = 0.7
				2: scale_factor = 1.0
				3: scale_factor = 1.35
				_: scale_factor = 1.0
			visual.scale = Vector3.ONE * scale_factor

		# Owner ring tint
		_apply_ring(star_node.get_node_or_null("OwnerRing") as MeshInstance3D, int(s.owner_id), false)

		# Capital ring tint (always faction colored)
		if s.is_capital:
			_apply_ring(star_node.get_node_or_null("CapitalRing") as MeshInstance3D, int(s.owner_id), true)
		else:
			var cap := star_node.get_node_or_null("CapitalRing") as MeshInstance3D
			if cap:
				cap.visible = false

func _spawn_fleets_from_state() -> void:
	if fleets_root == null:
		return
	# Reconcile markers against state (reuse nodes so movement can be smooth).
	var keep: Dictionary = {}
	if game_state == null or config == null:
		return
	for f in game_state.fleets:
		var fleet: FleetState = f
		if fleet == null:
			continue
		keep[int(fleet.id)] = true
		var node := _fleet_nodes_by_id.get(int(fleet.id), null) as Node3D
		if node == null or not is_instance_valid(node):
			node = FLEET_SCENE.instantiate()
			node.name = "Fleet_%d" % int(fleet.id)
			node.set_meta("fleet_id", int(fleet.id))
			_apply_fleet_color(node, int(fleet.owner_id))
			fleets_root.add_child(node)
			_fleet_nodes_by_id[int(fleet.id)] = node

		# Ensure fleet has a starting grid position.
		if fleet.grid_pos == Vector2i(-1, -1):
			var star := TurnSystem.get_star_by_id(config, int(fleet.star_id))
			if star != null:
				fleet.grid_pos = star.pos
			else:
				fleet.grid_pos = Vector2i(0, 0)

		# Place marker
		node.position = _world_pos_for_fleet(fleet)
		# Update movement line
		var marker := node as FleetMarker
		if marker != null:
			if fleet.is_moving and fleet.dest_grid_pos != Vector2i(-1, -1):
				marker.set_destination_global(_world_pos_for_tile(fleet.dest_grid_pos), true)
			else:
				marker.clear_destination()

	# Remove markers for fleets that no longer exist
	for key in _fleet_nodes_by_id.keys():
		if not keep.has(int(key)):
			var old := _fleet_nodes_by_id[key] as Node3D
			if old != null and is_instance_valid(old):
				old.queue_free()
			_fleet_nodes_by_id.erase(key)

func _apply_fleet_color(fleet_node: Node3D, owner_id: int) -> void:
	if fleet_node == null:
		return
	var vis := fleet_node.get_node_or_null("Visual") as MeshInstance3D
	if vis == null:
		return
	var col := Color(0.8, 0.8, 0.8, 1)
	if config != null and owner_id >= 0 and owner_id < config.factions.size():
		col = (config.factions[owner_id] as FactionDef).color
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	vis.material_override = mat
	# Also tint selection ring if present.
	var sel := fleet_node.get_node_or_null("Selection") as MeshInstance3D
	if sel:
		sel.material_override = mat

func _apply_garrison_markers() -> void:
	# Simple "has ships" marker: show a small cube on the right of the star.
	if config == null:
		return
	if game_state == null:
		return
	# Ensure each star node has (or updates) a garrison marker.
	for child in stars_root.get_children():
		var star_node := child as Node3D
		if star_node == null:
			continue
		if not star_node.has_meta("star_instance"):
			continue
		var s: StarInstance = star_node.get_meta("star_instance")
		var g := TurnSystem.get_garrison(game_state, int(s.id))
		var has_garrison := false
		for k in g.keys():
			if int(g[k]) > 0:
				has_garrison = true
				break
		var marker := star_node.get_node_or_null("GarrisonMarker") as MeshInstance3D
		if marker == null:
			marker = MeshInstance3D.new()
			marker.name = "GarrisonMarker"
			var bm := BoxMesh.new()
			bm.size = Vector3(0.18, 0.18, 0.18)
			marker.mesh = bm
			marker.position = Vector3(0.35, 0.12, 0.0)
			star_node.add_child(marker)
		# Tint by owner and toggle
		marker.visible = has_garrison
		if has_garrison:
			var col := Color(0.8, 0.8, 0.8, 1)
			if s.owner_id >= 0 and s.owner_id < config.factions.size():
				col = (config.factions[s.owner_id] as FactionDef).color
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = col
			mat.emission_enabled = true
			mat.emission = col
			marker.material_override = mat


func _tile_to_world(t: Vector2i) -> Vector3:
	# Center of tile
	return Vector3(float(t.x), 0.05, float(t.y))

func _get_star_id_at_tile(tile: Vector2i) -> int:
	if config == null:
		return -1
	for s in config.stars:
		var si := s as StarInstance
		if si != null and si.pos == tile:
			return int(si.id)
	return -1

func _world_pos_for_tile(tile: Vector2i) -> Vector3:
	# Fleets sit slightly offset when parked at a star so the markers don't overlap.
	var p := _tile_to_world(tile)
	var sid := _get_star_id_at_tile(tile)
	if sid >= 0:
		p += Vector3(-0.35, 0.0, 0.0)
	return p

func _world_pos_for_fleet(fleet: FleetState) -> Vector3:
	if fleet == null:
		return Vector3.ZERO
	# If we're parked at a star, offset the marker for readability.
	# If we're in deep space (star_id == -1), stay centered on the tile.
	var p := _tile_to_world(fleet.grid_pos)
	if int(fleet.star_id) >= 0:
		p = _world_pos_for_tile(fleet.grid_pos)
	return p



func _apply_ring(ring: MeshInstance3D, owner_id: int, is_capital: bool) -> void:
	if ring == null:
		return
	if owner_id < 0 or owner_id >= config.factions.size():
		ring.visible = false
		return

	# Capital rings only show on capital stars.
	if is_capital == false and owner_id < 0:
		ring.visible = false
		return

	# Ensure ring has some geometry (OwnerRing/CapitalRing are intentionally lightweight in scene).
	if ring.mesh == null:
		var tm := TorusMesh.new()
		if is_capital:
			tm.inner_radius = 0.62
			tm.outer_radius = 0.68
		else:
			tm.inner_radius = 0.50
			tm.outer_radius = 0.56
		tm.ring_segments = 16
		tm.rings = 12
		ring.mesh = tm

	var col: Color = (config.factions[owner_id] as FactionDef).color
	col.a = 1.0
	if is_capital:
		# Slightly brighter to pop
		col = col * 1.25
		ring.position.y = 0.04
	else:
		ring.position.y = 0.03

	# Ensure we have a material and make it emissive/unshaded for readability.
	var mat: StandardMaterial3D = null
	if ring.material_override and ring.material_override is StandardMaterial3D:
		mat = (ring.material_override as StandardMaterial3D).duplicate(true)
	else:
		mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	ring.material_override = mat
	ring.visible = true


func _frame_camera_to_map() -> void:
	if camera_rig == null:
		return
		
	camera_rig.set_map_size(config.galaxy_size)
