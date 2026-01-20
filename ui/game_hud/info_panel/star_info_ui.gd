extends PanelContainer
class_name StarInfoUI

@onready var star_name: Label = %StarName
@onready var type_label: Label = %TypeLabel
@onready var owner_label: Label = %OwnerLabel
@onready var owner_swatch: ColorRect = %OwnerSwatch
@onready var capital_badge: Label = %CapitalBadge
@onready var credits_label: Label = %CreditsLabel
@onready var research_label: Label = %ResearchLabel
@onready var prod_label: Label = %ProdLabel
@onready var coords_label: Label = %CoordsLabel

@onready var garrison_list: ItemList = %GarrisonList

func show_panel() -> void:
	show()

func hide_panel() -> void:
	clear()
	hide()

func clear() -> void:
	star_name.text = "—"
	type_label.text = "Type:"
	owner_label.text = "Unclaimed"
	owner_swatch.visible = false
	capital_badge.text = "" # keeps spacing without jumping
	credits_label.text = "C: 0"
	research_label.text = "R: 0"
	prod_label.text = "P: 0"
	coords_label.text = "(x, y): ---"
	if garrison_list:
		garrison_list.clear()

func set_star(star: StarInstance, gs: GameState, factions: Array, catalog: StarTypeCatalog, ships: ShipTypeCatalog) -> void:
	if star == null:
		clear()
		return

	show_panel()
	
	star_name.text = star.name
	coords_label.text = "(x, y): %d, %d" % [star.pos.x, star.pos.y]

	# Type display name
	var type_def: StarTypeDef = null
	if catalog:
		for t in catalog.types:
			if t.type_id == star.type_id:
				type_def = t
				break
	type_label.text = "Type: %s" % (type_def.display_name if type_def else str(star.type_id))

	# Owner
	if star.owner_id >= 0 and star.owner_id < factions.size():
		var f := factions[star.owner_id] as FactionDef
		owner_label.text = f.name
		owner_swatch.visible = true
		owner_swatch.color = f.color
	else:
		owner_label.text = "Unclaimed"
		owner_swatch.visible = false

	# Capital
	capital_badge.text = "CAPITAL" if star.is_capital else ""

	# Yields
	if star.yields:
		credits_label.text = "C: %d" % star.yields.credits
		research_label.text = "R: %d" % star.yields.research
		prod_label.text = "P: %d" % star.yields.production

	# Garrison ships
	if garrison_list:
		garrison_list.clear()
		if gs != null:
			var g := TurnSystem.get_garrison(gs, star.id)
			if g.size() == 0:
				garrison_list.add_item("(empty)")
				garrison_list.set_item_disabled(0, true)
			else:
				for key in g.keys():
					var cnt := int(g[key])
					var did := StringName(String(key))
					var name : String = (TurnSystem.design_display_name(gs.config, did) if gs != null and gs.config != null else String(did))
					garrison_list.add_item("%dx %s" % [cnt, name])
		else:
			garrison_list.add_item("(no state)")
			garrison_list.set_item_disabled(0, true)