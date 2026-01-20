extends Control
class_name FactionRow

@onready var lbl: Label = %FactionLabel
@onready var name_edit: LineEdit = %Name
@onready var rnd_btn: Button = %RndBtn
@onready var control_type: OptionButton = %ControlType
@onready var color_left: Button = %ColorLeft
@onready var color_right: Button = %ColorRight
@onready var color_rect: ColorRect = %ColorRect

# Small curated palette: readable on dark UI + visually distinct.
const COLOR_PALETTE: Array[Color] = [
	Color("#4A90E2"), # Blue
	Color("#E94E77"), # Pink/Red
	Color("#7ED321"), # Green
	Color("#F5A623"), # Orange
	Color("#BD10E0"), # Purple
	Color("#50E3C2"), # Teal
	Color("#F8E71C"), # Yellow
	Color("#FFFFFF"), # White
]

var faction_index: int = 0
var color_index: int = 0

# Optional: a shared rng for generating names.
var _rng: RandomNumberGenerator

func _ready() -> void:
	# Populate dropdown
	control_type.clear()
	control_type.add_item("Human")
	control_type.add_item("AI Easy")
	control_type.add_item("AI Med")
	control_type.add_item("AI Hard")

	# Hooks
	rnd_btn.pressed.connect(_on_random_name)
	color_left.pressed.connect(func(): _cycle_color(-1))
	color_right.pressed.connect(func(): _cycle_color(1))

	# Defaults
	_update_label()
	_set_color_index(color_index)

func configure(idx: int, default_name: String, default_color_index: int, default_control: int, rng: RandomNumberGenerator) -> void:
	faction_index = idx
	_rng = rng
	name_edit.text = default_name
	control_type.selected = clamp(default_control, 0, control_type.item_count - 1)
	_set_color_index(default_color_index)
	_update_label()

func _update_label() -> void:
	lbl.text = "Faction %d" % (faction_index + 1)

func _on_random_name() -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	name_edit.text = RandomNameGen.faction_name(_rng)

func _cycle_color(dir: int) -> void:
	_set_color_index(color_index + dir)

func _set_color_index(i: int) -> void:
	if COLOR_PALETTE.is_empty():
		return
	color_index = i % COLOR_PALETTE.size()
	if color_index < 0:
		color_index += COLOR_PALETTE.size()
	color_rect.color = COLOR_PALETTE[color_index]

func get_faction_dict() -> Dictionary:
	var control_str := "AI_EASY"
	match control_type.selected:
		0: control_str = "HUMAN"
		1: control_str = "AI_EASY"
		2: control_str = "AI_MED"
		3: control_str = "AI_HARD"

	return {
		"name": name_edit.text.strip_edges(),
		"color": color_rect.color,
		"control": control_str
	}


func get_faction_def() -> FactionDef:
	var f := FactionDef.new()
	f.id = faction_index
	# Be defensive: NewGameMenu may read us before our @onready nodes are ready.
	var nm := "Faction %d" % (faction_index + 1)
	if name_edit != null:
		nm = name_edit.text.strip_edges()
	if nm.is_empty():
		nm = "Faction %d" % (faction_index + 1)
	f.name = nm

	var col := COLOR_PALETTE[color_index] if color_index >= 0 and color_index < COLOR_PALETTE.size() else Color.WHITE
	if color_rect != null:
		col = color_rect.color
	f.color = col

	var ct := 0
	if control_type != null:
		ct = control_type.selected
	f.control_type = ct
	return f
