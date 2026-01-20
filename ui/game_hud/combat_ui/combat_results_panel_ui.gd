extends PanelContainer
class_name CombatResultsPanelUI

signal closed

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _content: VBoxContainer = %Content
@onready var _close_btn: Button = %CloseBtn

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _close_btn != null and not _close_btn.pressed.is_connected(_on_close_pressed):
		_close_btn.pressed.connect(_on_close_pressed)

func open_for_reports(reports: Array, cfg: GalaxyConfig) -> void:
	# reports: Array[Dictionary]
	_clear_content()
	if reports == null or reports.is_empty():
		visible = false
		return
	visible = true
	var turn_num := int(reports[0].get("turn", -1))
	_title.text = "Combat Results"
	_subtitle.text = "Turn %d" % turn_num if turn_num >= 0 else ""

	for rep_any in reports:
		var rep: Dictionary = rep_any
		var card := _build_report_card(rep, cfg)
		_content.add_child(card)

func hide_panel() -> void:
	visible = false

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

func _clear_content() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		c.queue_free()

func _build_report_card(rep: Dictionary, cfg: GalaxyConfig) -> Control:
	var wrapper := PanelContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.custom_minimum_size = Vector2(0, 120)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	wrapper.add_child(vb)

	var header := Label.new()
	header.text = str(rep.get("location", "Unknown location"))
	header.add_theme_font_size_override("font_size", 18)
	vb.add_child(header)

	var meta := Label.new()
	meta.text = _format_meta_line(rep, cfg)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(meta)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD
	rt.text = _format_body(rep, cfg)
	vb.add_child(rt)

	return wrapper

func _format_meta_line(rep: Dictionary, cfg: GalaxyConfig) -> String:
	var rounds : int = int(rep.get("rounds", 0))
	var outcome = str(rep.get("outcome", ""))
	var devastation = rep.get("devastation", {})
	var dev_text := ""
	if typeof(devastation) == TYPE_DICTIONARY and (devastation as Dictionary).size() > 0:
		var d := devastation as Dictionary
		dev_text = " | Colony devastated at %s" % str(d.get("star_name", "star"))
	return "Outcome: %s | Rounds: %d%s" % [outcome, rounds, dev_text]

func _format_body(rep: Dictionary, cfg: GalaxyConfig) -> String:
	var attacker_id := int(rep.get("attacker_owner_id", -1))
	var defender_ids: Array = []
	if rep.has("defender_owner_ids") and typeof(rep["defender_owner_ids"]) == TYPE_ARRAY:
		for x in rep["defender_owner_ids"]:
			defender_ids.append(int(x))
	else:
		defender_ids = [int(rep.get("defender_owner_id", -1))]

	var attacker_name := _faction_name(cfg, attacker_id)
	var defender_name := _faction_name(cfg, defender_ids[0])
	if defender_ids.size() > 1:
		var names: Array = []
		for did in defender_ids:
			names.append(_faction_name(cfg, int(did)))
		defender_name = ", ".join(names)

	var a_before := rep.get("attacker_ships_before", {}) as Dictionary
	var a_after := rep.get("attacker_ships_after", {}) as Dictionary
	var a_lost := rep.get("attacker_ships_lost", {}) as Dictionary

	var d_before := rep.get("defender_ships_before", {}) as Dictionary
	var d_after := rep.get("defender_ships_after", {}) as Dictionary
	var d_lost := rep.get("defender_ships_lost", {}) as Dictionary

	var txt := ""
	txt += "[b]%s[/b]\n" % attacker_name
	txt += _format_side_lines(cfg, a_before, a_after, a_lost)
	txt += "\n[b]%s[/b]\n" % defender_name
	txt += _format_side_lines(cfg, d_before, d_after, d_lost)
	return txt

func _format_side_lines(cfg: GalaxyConfig, before: Dictionary, after: Dictionary, lost: Dictionary) -> String:
	var keys := {}.keys()
	# union of keys
	var union: Dictionary = {}
	for k in before.keys():
		union[String(k)] = true
	for k in after.keys():
		union[String(k)] = true
	var all_keys: Array[String] = []
	for k in union.keys():
		all_keys.append(String(k))
	all_keys.sort()

	var lines: Array[String] = []
	for sid in all_keys:
		var b := int(before.get(sid, 0))
		var a := int(after.get(sid, 0))
		var l := int(lost.get(sid, 0))
		if b == 0 and a == 0 and l == 0:
			continue
		var name := _ship_display_name(cfg, StringName(sid))
		lines.append("  %s: %d → %d   (-%d)" % [name, b, a, l])
	if lines.is_empty():
		return "  (no ships)\n"
	return "\n".join(lines) + "\n"

func _ship_display_name(cfg: GalaxyConfig, ship_id: StringName) -> String:
	return TurnSystem.design_display_name(cfg, ship_id)

func _faction_name(cfg: GalaxyConfig, faction_id: int) -> String:
	if cfg == null:
		return "Faction %d" % faction_id
	for f_any in cfg.factions:
		var f := f_any as FactionDef
		if f != null and int(f.id) == int(faction_id):
			return f.name
	return "Faction %d" % faction_id
