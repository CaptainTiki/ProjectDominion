extends Node
class_name RandomNameGen

# Simple name generator for v1.
# We can upgrade this later with syllable chaining, faction themes, etc.

static var _prefixes := [
	"Nova", "Orion", "Vega", "Astra", "Helio", "Solar", "Iron", "Void", "Crimson", "Azure",
	"Titan", "Echo", "Pioneer", "Stellar", "Quantum", "Obsidian", "Radiant", "Frontier"
]

static var _suffixes := [
	"Union", "Combine", "Dynasty", "Syndicate", "Federation", "Clans", "Concord", "Dominion",
	"League", "Collective", "Empire", "Republic", "Consortium", "Directorate", "Enclave"
]

static var _star_prefixes := [
	"Zeta", "Sigma", "Delta", "Epsilon", "Tau", "Lambda", "Rho", "Kappa", "Omicron", "Iota"
]

static var _star_suffixes := [
	"Prime", "Secundus", "III", "IV", "V", "Station", "Outpost", "Gate", "Belt", "Reach"
]

static func faction_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [_prefixes[rng.randi_range(0, _prefixes.size()-1)], _suffixes[rng.randi_range(0, _suffixes.size()-1)]]

static func star_name(rng: RandomNumberGenerator) -> String:
	var a : String = _star_prefixes[rng.randi_range(0, _star_prefixes.size()-1)]
	var b : String = _star_suffixes[rng.randi_range(0, _star_suffixes.size()-1)]
	return "%s %s" % [a, b]
