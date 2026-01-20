extends Node
class_name SelectionSystem

signal selection_changed(selected: Node3D, kind: String)
signal selection_cleared(kind: String)
signal move_destination_tile_chosen(fleet_id: int, tile: Vector2i, world_pos: Vector3)
signal move_destination_tile_hovered(fleet_id: int, tile: Vector2i, world_pos: Vector3)
signal move_cancelled(fleet_id: int)

@export var grid_plane_y: float = 0.0
@export var base_pick_radius: float = 1.0        # minimum pick radius (zoomed in)
@export var zoom_pick_scale: float = 0.03        # radius grows with zoom

@export var pop_time: float = 0.12               # quick “draw attention” pop
@export var pulse_scale: float = 1.12            # subtle breathing scale
@export var pulse_time: float = 0.55             # pulse speed

var _camera: Camera3D
var _camera_rig: Node = null                     # optional: to read spring length
var _stars_root: Node = null
var _fleets_root: Node = null
var _map_size: int = 0

var _selected: Node3D = null
var _selected_kind: String = ""

# When set, the next left-click will choose a destination star for this fleet.
var _move_fleet_id: int = -1

var _pulse_tween: Tween = null

func _ready() -> void:
	# Be explicit so this keeps working even as UI grows.
	set_process_unhandled_input(true)

func configure(camera: Camera3D, camera_rig: Node, stars_root: Node, fleets_root: Node = null, map_size: int = 0) -> void:
	_camera = camera
	_camera_rig = camera_rig
	_stars_root = stars_root
	_fleets_root = fleets_root
	_map_size = map_size

func _unhandled_input(event: InputEvent) -> void:
	# Cancel move targeting with ESC (nice little QoL, doesn't interfere with normal play)
	if _move_fleet_id > 0 and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		var fid := _move_fleet_id
		_move_fleet_id = -1
		move_cancelled.emit(fid)
		return

	if event is InputEventMouseMotion and _move_fleet_id > 0:
		_emit_move_hover(event.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_select_at_mouse(event.position)

## External API ---------------------------------------------------------------

func start_move_fleet(fleet_id: int) -> void:
	_move_fleet_id = fleet_id

func update_move_hover_from_mouse_pos(mouse_pos: Vector2) -> void:
	# Call this right after start_move_fleet so the preview line appears even if the mouse doesn't move.
	_emit_move_hover(mouse_pos)

func cancel_move_fleet() -> void:
	if _move_fleet_id > 0:
		var fid := _move_fleet_id
		_move_fleet_id = -1
		move_cancelled.emit(fid)

func select_node(node: Node3D, kind: String) -> void:
	_select(node, kind)

func _raycast_to_plane(mouse_pos: Vector2) -> Variant:
	if _camera == null:
		return null
	var origin := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.00001:
		return null
	var t := (grid_plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t

func _emit_move_hover(mouse_pos: Vector2) -> void:
	# Emits a snapped-to-grid hover tile while in move targeting mode.
	if _move_fleet_id <= 0:
		return
	var hit_pos : Vector3 = _raycast_to_plane(mouse_pos)
	if hit_pos == null:
		return
	var tile : Vector2i = _world_to_tile(hit_pos)
	if tile.x < 0:
		move_destination_tile_hovered.emit(_move_fleet_id, Vector2i(-1, -1), Vector3.ZERO)
		return
	# Snap the hover world position to the tile center so it doesn't feel like it 'floats'.
	var snapped : Vector3 = Vector3(float(tile.x), grid_plane_y, float(tile.y))
	move_destination_tile_hovered.emit(_move_fleet_id, tile, snapped)

func _try_select_at_mouse(mouse_pos: Vector2) -> void:
	if _camera == null or _stars_root == null:
		return

	var hit : Vector3 = _raycast_to_plane(mouse_pos)
	if hit == null:
		return
	var hit_pos := hit as Vector3

	var pick_radius := _get_pick_radius()

	# If we're in move targeting mode, the next click chooses a DESTINATION TILE (anywhere on the map).
	if _move_fleet_id > 0:
		var tile := _world_to_tile(hit_pos)
		# If the click is outside the plane bounds, cancel (so it doesn't feel like a misclick issues an order).
		if tile.x < 0:
			var fid2 := _move_fleet_id
			_move_fleet_id = -1
			move_cancelled.emit(fid2)
			return
		var fid := _move_fleet_id
		_move_fleet_id = -1
		move_destination_tile_chosen.emit(fid, tile, hit_pos)
		return

	# Search stars (and later fleets)
	var best: Node3D = null
	var best_kind := ""
	var best_dist := INF

	var star_res := _find_nearest_in_root(_stars_root, hit_pos, pick_radius)
	best = star_res["node"]
	best_dist = float(star_res["dist"])
	best_kind = "star" if best != null else ""

	# Optional: if fleets_root exists, also consider fleets
	if _fleets_root != null:
		var fleet_res := _find_nearest_in_root(_fleets_root, hit_pos, pick_radius)
		var best2: Node3D = fleet_res["node"]
		var best2_dist := float(fleet_res["dist"])
		if best2 != null and best2_dist < best_dist:
			best = best2
			best_dist = best2_dist
			best_kind = "fleet"

	if best != null:
		_select(best, best_kind)
	else:
		_clear_selection("any")

func _find_nearest_in_root(root: Node, hit_pos: Vector3, radius: float) -> Dictionary:
	var best: Node3D = null
	var best_dist := INF

	for child in root.get_children():
		if not (child is Node3D):
			continue
		var d := (child as Node3D).global_position.distance_to(hit_pos)
		if d <= radius and d < best_dist:
			best_dist = d
			best = child

	return {"node": best, "dist": best_dist}

func _get_pick_radius() -> float:
	# If you use SpringArm3D, zoom feels best tied to spring length
	var zoom := 30.0
	if _camera_rig != null and _camera_rig.has_node("Pivot/SpringArm3D"):
		var arm := _camera_rig.get_node("Pivot/SpringArm3D")
		if arm is SpringArm3D:
			zoom = (arm as SpringArm3D).spring_length

	return clamp(base_pick_radius + zoom * zoom_pick_scale, 0.8, 3.0)

func _world_to_tile(pos: Vector3) -> Vector2i:
	# Map plane is aligned so world x/z correspond to tile x/y.
	# We round to the nearest tile center for nice clicks.
	if _map_size <= 0:
		# no bounds info; do our best
		return Vector2i(int(round(pos.x)), int(round(pos.z)))
	var tx := int(round(pos.x))
	var ty := int(round(pos.z))
	if tx < 0 or ty < 0 or tx >= _map_size or ty >= _map_size:
		return Vector2i(-1, -1)
	return Vector2i(tx, ty)

func _select(node: Node3D, kind: String) -> void:
	if _selected == node and _selected_kind == kind:
		return

	_clear_selection("switch")

	_selected = node
	_selected_kind = kind

	_apply_selection_visual(_selected, true)
	_emit_selection_changed()

func _clear_selection(reason_kind: String) -> void:
	if _selected == null:
		return

	var prev_kind := _selected_kind
	_apply_selection_visual(_selected, false)
	_selected = null
	_selected_kind = ""

	_stop_pulse()

	selection_cleared.emit(prev_kind)

func _emit_selection_changed() -> void:
	selection_changed.emit(_selected, _selected_kind)

func _apply_selection_visual(node: Node3D, enabled: bool) -> void:
	if node == null:
		return

	var sel := node.get_node_or_null("Selection")
	if sel == null:
		return

	(sel as Node).visible = enabled
	if not enabled:
		(sel as Node3D).scale = Vector3.ONE
		return

	# Pop + pulse
	var s := sel as Node3D
	s.scale = Vector3.ONE * 0.65

	_stop_pulse()

	# Pop tween
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(s, "scale", Vector3.ONE, pop_time)
	pop.finished.connect(func():
		_start_pulse(s)
	)

func _start_pulse(sel_node: Node3D) -> void:
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sel_node, "scale", Vector3.ONE * pulse_scale, pulse_time)
	_pulse_tween.tween_property(sel_node, "scale", Vector3.ONE, pulse_time)

func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
