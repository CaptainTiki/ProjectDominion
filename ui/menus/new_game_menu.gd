#new_game_menu.gd
extends Control
class_name NewGameMenu

signal canceled
signal accepted_config(config: Resource)

@onready var preview_tex: TextureRect = %PreviewTexture

@onready var galaxy_size: HSlider = %GalaxySize
@onready var star_count: HSlider = %StarCount
@onready var faction_count: HSlider = %FactionCount
@onready var rnd_seed: LineEdit = %RndSeed

@onready var faction_list: VBoxContainer = %FactionList

@onready var btn_randomize: Button = %RandomizeBtn
@onready var btn_generate: Button = %GenerateMapBtn
@onready var btn_cancel: Button = %CancelBtn
@onready var btn_accept: Button = %AcceptBtn

var current_config: GalaxyConfig
var has_generated := false

var _star_types_catalog: StarTypeCatalog
var _ship_types_catalog : ShipTypeCatalog
var _ship_designs_catalog : ShipDesignCatalog
var _module_catalog : ModuleCatalog
var _tech_types_catalog : TechTypeCatalog

const FACTION_ROW_SCENE: PackedScene = preload("uid://dpuixeaamkr7b")

# We keep one RNG for UI randomness (names / palette picks), separate from map RNG.
var _ui_rng := RandomNumberGenerator.new()

# Fixed resolution preview so a 20x20 and a 100x100 galaxy are the same size on screen.
const PREVIEW_RES := 512

func _ready() -> void:
	_ui_rng.randomize()
	current_config = GalaxyConfig.new()
	_star_types_catalog = load("res://sim/content/star_types_default.tres") as StarTypeCatalog
	_ship_types_catalog = preload("res://sim/content/ship_types_default.tres")
	_ship_designs_catalog = preload("res://sim/content/ship_designs_default.tres")
	_module_catalog = preload("res://sim/content/modules_default.tres")
	_tech_types_catalog = preload("res://sim/content/tech_types_default.tres")
	_init_defaults()

	btn_randomize.pressed.connect(_randomize_settings)
	btn_generate.pressed.connect(_generate_preview)
	btn_cancel.pressed.connect(_cancel)
	btn_accept.pressed.connect(_accept)

	galaxy_size.value_changed.connect(func(_v): _on_knob_changed())
	star_count.value_changed.connect(func(_v): _on_knob_changed())
	faction_count.value_changed.connect(func(_v): _on_faction_count_changed(_v))
	_empty_factions_on_ready()
	_on_faction_count_changed(faction_count.value)

	# Generate a starting preview so the user isn't staring at a blank panel.
	# After this, we only regenerate when the user presses Generate Map.
	# Defer one frame so FactionRow @onready vars exist before we read them.
	call_deferred("_generate_preview", true)

func _init_defaults() -> void:
	# Allow tiny and huge maps without changing preview size (dots scale down).
	galaxy_size.min_value = 20
	galaxy_size.max_value = 100
	galaxy_size.step = 5
	galaxy_size.value = 30

	# Star count is intentionally capped for v1 so we don't create 10,000-dot galaxies.
	star_count.min_value = 10
	star_count.max_value = 60
	star_count.step = 1
	star_count.value = 25

	# For now we're keeping it to 2 factions to keep early gameplay + UI simple.
	faction_count.min_value = 2
	faction_count.max_value = 2
	faction_count.step = 1
	faction_count.value = 2

	# Leave blank = random seed per generate press.
	rnd_seed.text = ""
	rnd_seed.placeholder_text = "(blank = random)"

	btn_accept.disabled = true
	has_generated = false

func _on_knob_changed() -> void:
	# Don't wipe the existing preview. Just mark it stale until Generate Map is pressed.
	has_generated = false
	btn_accept.disabled = true
	# Dim the preview slightly to indicate settings changed.
	preview_tex.modulate = Color(0.85, 0.85, 0.85)

func _on_faction_count_changed(v: float) -> void:
	_build_faction_rows(int(v))
	_on_knob_changed()

func _build_faction_rows(count: int) -> void:
	for c in faction_list.get_children():
		c.queue_free()

	for i in range(count):
		var row = FACTION_ROW_SCENE.instantiate()

		# Defaults: first human, second AI easy.
		var default_control := 0 if i == 0 else 1
		var default_name := "Faction %d" % (i + 1)

		# Spread colors a little by index.
		var default_color_index := i

		faction_list.add_child(row)

		# Wait until it's in the tree and ready
		row.call_deferred("configure", i, default_name, default_color_index, default_control, _ui_rng)


func _randomize_settings() -> void:
	# Blank seed means "new random seed each time".
	rnd_seed.text = ""
	galaxy_size.value = [20, 25, 30, 35, 40, 50, 60, 80, 100].pick_random()
	star_count.value = randi_range(10, 60)
	# Currently locked to 2 factions for v1.
	faction_count.value = 2

	_generate_preview()

func _generate_preview(is_initial := false) -> void:
	
	current_config = _build_config_from_ui()

	# Render preview texture
	preview_tex.texture = _render_preview_texture(current_config)
	preview_tex.modulate = Color(1, 1, 1)

	has_generated = true
	btn_accept.disabled = false

	# If this is the initial auto-generate, keep Accept enabled (it's already a valid galaxy).
	if is_initial:
		pass

func _build_config_from_ui() -> GalaxyConfig:
	var settings := GenerationSettings.new()
	settings.galaxy_size = int(galaxy_size.value)
	settings.star_count = int(star_count.value)
	settings.seed_text = rnd_seed.text.strip_edges()
	settings.star_types = _star_types_catalog
	settings.ship_types = _ship_types_catalog
	settings.ship_designs = _ship_designs_catalog
	settings.module_catalog = _module_catalog
	settings.tech_types = _tech_types_catalog
	
	var factions: Array[FactionDef] = []
	for child in faction_list.get_children():
		print("child found in factions list")
		var row := child as FactionRow
		if row != null:
			print("child was faction")
			factions.append(row.get_faction_def())
	
	# This returns a GalaxyConfig with typed StarInstance resources.
	return GalaxyGenerator.generate(settings, factions)

func _empty_factions_on_ready() -> void:
	for child in faction_list.get_children():
		if child is FactionRow:
			child.queue_free()

func _collect_factions() -> Array[FactionDef]:
	var out: Array[FactionDef] = []

	for child in faction_list.get_children():
		if child is FactionRow:
			var row := child as FactionRow
			var f := row.get_faction_def()
			if f != null:
				f.id = out.size()
				out.append(f)

	return out


func _update_preview_placeholder(generated: bool) -> void:
	# If we haven't generated yet, tint the preview dim.
	if not generated:
		preview_tex.modulate = Color(0.7, 0.7, 0.7)
	else:
		preview_tex.modulate = Color(1, 1, 1)

# ------------------------------------------------------------
# MAP GENERATION (Preview + handoff to GalaxyMap)
# ------------------------------------------------------------

## NOTE: Star generation moved into sim/gen/galaxy_generator.gd

func _render_preview_texture(cfg: GalaxyConfig) -> Texture2D:
	# Fixed resolution preview so a 20x20 and a 100x100 map preview are the same size.
	var img := Image.create(PREVIEW_RES, PREVIEW_RES, false, Image.FORMAT_RGBA8)
	
	# Background (subtle)
	var bg := Color(0.05, 0.06, 0.08, 1.0)
	img.fill(bg)

	# Grid hint (very faint)
	var grid_size : int = max(2, cfg.galaxy_size)
	var step_px := float(PREVIEW_RES) / float(grid_size)
	var grid_col := Color(1, 1, 1, 0.05)
	for i in range(1, grid_size):
		var px := int(round(i * step_px))
		for y in PREVIEW_RES:
			if px >= 0 and px < PREVIEW_RES:
				img.set_pixel(px, y, grid_col)
		for x in PREVIEW_RES:
			if px >= 0 and px < PREVIEW_RES:
				img.set_pixel(x, px, grid_col)

	# Base dot size scales with galaxy size (bigger maps => smaller dots)
	# We'll then nudge per-star using StarInstance.size.
	var base_r := int(clamp((step_px * 0.18), 1.0, 5.0))

	# Draw stars
	for s in cfg.stars:
		var p: Vector2i = s.pos
		var fx := 0.0 if grid_size <= 1 else float(p.x) / float(grid_size - 1)
		var fy := 0.0 if grid_size <= 1 else float(p.y) / float(grid_size - 1)
		var cx := int(round(fx * float(PREVIEW_RES - 1)))
		var cy := int(round(fy * float(PREVIEW_RES - 1)))

		var dot_r := _preview_radius_for_star(base_r, int(s.size))
		var core := _preview_star_color(int(s.type_id))
		var halo := core
		halo.a = 0.25

		# Halo then core
		_draw_circle(img, cx, cy, dot_r + 2, halo)
		_draw_circle(img, cx, cy, dot_r, core)

		# Capital marker: faction-colored ring around the star.
		if s.is_capital and int(s.owner_id) >= 0 and int(s.owner_id) < cfg.factions.size():
			var fcol := (cfg.factions[int(s.owner_id)] as FactionDef).color
			fcol.a = 1.0
			var ring_radius_add : int = 6 + s.size
			_draw_ring(img, cx, cy, dot_r + ring_radius_add, 2, fcol)

	return ImageTexture.create_from_image(img)


func _preview_star_color(type_id: int) -> Color:
	if _star_types_catalog != null:
		for t in _star_types_catalog.types:
			if int(t.type_id) == type_id:
				var c := t.tint
				# Ensure the preview is readable on dark bg
				c.a = 1.0
				return c
	return Color(0.85, 0.92, 1.0, 1.0)


func _preview_radius_for_star(base_r: int, size: int) -> int:
	# 1 small, 2 medium, 3 large
	match size:
		1:
			return max(1, base_r - 1)
		2:
			return base_r + 1
		3:
			return base_r + 3
		_:
			return base_r + 1


func _draw_ring(img: Image, cx: int, cy: int, r: int, thickness: int, col: Color) -> void:
	# Outline ring with given thickness.
	var r_outer : float = r
	var r_inner : float = max(0, r - thickness)
	var r2_outer : float = r_outer * r_outer
	var r2_inner : float = r_inner * r_inner
	for y in range(cy - r_outer, cy + r_outer + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r_outer, cx + r_outer + 1):
			if x < 0 or x >= img.get_width():
				continue
			var dx := x - cx
			var dy := y - cy
			var d2 := dx * dx + dy * dy
			if d2 <= r2_outer and d2 >= r2_inner:
				img.set_pixel(x, y, col)

func _draw_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			var dx := x - cx
			var dy := y - cy
			if (dx * dx + dy * dy) <= r2:
				img.set_pixel(x, y, col)

func _cancel() -> void:
	canceled.emit()

func _accept() -> void:
	if not has_generated:
		return
	accepted_config.emit(current_config)
