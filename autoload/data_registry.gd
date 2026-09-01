extends Node

const CONTENT_PATH := "res://data/content.tres"
const RARITIES := ["Common", "Magic", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS := [
	Color("#d8dde8"), Color("#58a6ff"), Color("#ffd166"),
	Color("#b778ff"), Color("#ff7b36"), Color("#ff3fb4")
]

var database: ContentDatabase
var enemies: Array[Dictionary] = []
var bosses: Array[Dictionary] = []
var biomes: Array[Dictionary] = []
var base_items: Array[Dictionary] = []
var affixes: Array[Dictionary] = []
var legendary_powers: Array[Dictionary] = []
var upgrades: Array[Dictionary] = []
var evolutions: Array[Dictionary] = []
var by_enemy: Dictionary = {}
var by_boss: Dictionary = {}
var by_item: Dictionary = {}
var by_power: Dictionary = {}

func _ready() -> void:
	load_database()

func load_database() -> void:
	database = load(CONTENT_PATH) as ContentDatabase
	if database == null:
		push_error("RIFTFALL content database could not be loaded.")
		return
	enemies = _parse_enemy_records(database.enemies)
	bosses = _parse_boss_records(database.bosses)
	biomes = _parse_biome_records(database.biomes)
	base_items = _parse_item_records(database.base_items)
	affixes = _parse_affix_records(database.affixes)
	legendary_powers = _parse_power_records(database.legendary_powers)
	upgrades = _parse_upgrade_records(database.upgrades)
	evolutions = _parse_evolution_records(database.evolutions)
	for record in enemies: by_enemy[record.id] = record
	for record in bosses: by_boss[record.id] = record
	for record in base_items: by_item[record.id] = record
	for record in legendary_powers: by_power[record.id] = record

func _parts(line: String) -> PackedStringArray:
	return line.split("|", false)

func _parse_enemy_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 10: continue
		output.append({"id": p[0], "name": p[1], "role": p[2], "hp": p[3].to_float(),
			"damage": p[4].to_float(), "speed": p[5].to_float(), "progress": p[6].to_float(),
			"element": p[7], "scale": p[8].to_float(), "description": p[9]})
	return output

func _parse_boss_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 8: continue
		output.append({"id": p[0], "name": p[1], "biome": p[2], "hp": p[3].to_float(),
			"damage": p[4].to_float(), "title": p[5], "patterns": p[6].split(","), "element": p[7]})
	return output

func _parse_biome_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 8: continue
		output.append({"id": p[0], "name": p[1], "floor": Color("#" + p[2]),
			"accent_dark": Color("#" + p[3]), "accent": Color("#" + p[4]), "description": p[5],
			"bosses": p[6].split(","), "enemies": p[7].split(",")})
	return output

func _parse_item_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 6: continue
		output.append({"id": p[0], "name": p[1], "slot": p[2], "tags": p[3].split(","),
			"power_min": p[4].to_float(), "power_max": p[5].to_float()})
	return output

func _parse_affix_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 7: continue
		output.append({"id": p[0], "name": p[1], "kind": p[2], "stat": p[3],
			"minimum": p[4].to_float(), "maximum": p[5].to_float(), "tag": p[6]})
	return output

func _parse_power_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 6: continue
		output.append({"id": p[0], "name": p[1], "tags": p[2].split(","),
			"description": p[3], "effect": p[4], "value": p[5].to_float()})
	return output

func _parse_upgrade_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 6: continue
		output.append({"id": p[0], "name": p[1], "description": p[2], "stat": p[3],
			"value": p[4].to_float(), "tag": p[5]})
	return output

func _parse_evolution_records(lines: PackedStringArray) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for line in lines:
		var p := _parts(line)
		if p.size() < 6: continue
		output.append({"id": p[0], "name": p[1], "base": p[2], "power": p[3],
			"tags": p[4].split(","), "description": p[5]})
	return output

func get_biome(biome_id: String) -> Dictionary:
	for biome in biomes:
		if biome.id == biome_id: return biome
	return biomes[0] if not biomes.is_empty() else {}

func enemy_for_biome(biome_id: String, elapsed: float) -> Dictionary:
	var biome := get_biome(biome_id)
	var pool: PackedStringArray = biome.get("enemies", PackedStringArray())
	if pool.is_empty(): return enemies.pick_random()
	var unlocked := clampi(3 + int(elapsed / 28.0), 3, pool.size())
	return by_enemy.get(pool[randi_range(0, unlocked - 1)], enemies[0])

func boss_for_biome(biome_id: String) -> Dictionary:
	var biome := get_biome(biome_id)
	var pool: PackedStringArray = biome.get("bosses", PackedStringArray())
	if pool.is_empty(): return bosses.pick_random()
	return by_boss.get(pool.pick_random(), bosses[0])

func roll_item(item_level: int, tier: int, favored_tags: Array = []) -> Dictionary:
	var base := _weighted_base_item(favored_tags)
	var rarity_index := _roll_rarity(tier)
	var rarity := RARITIES[rarity_index]
	var affix_count := [0, 2, 3, 4, 5, 6][rarity_index]
	var selected: Array[Dictionary] = []
	var candidates := affixes.duplicate()
	candidates.shuffle()
	for affix in candidates:
		if selected.size() >= affix_count: break
		var duplicate_stat := false
		for current in selected:
			if current.stat == affix.stat: duplicate_stat = true
		if duplicate_stat: continue
		var quality := randf_range(0.35, 1.0)
		var value: float = lerpf(affix.minimum, affix.maximum, quality) * (1.0 + item_level * 0.018)
		selected.append({"id": affix.id, "name": affix.name, "kind": affix.kind,
			"stat": affix.stat, "value": snappedf(value, 0.1), "tag": affix.tag})
	var legendary: Dictionary = {}
	if rarity_index >= 4:
		legendary = _weighted_power(Array(base.tags) + favored_tags)
	var base_power: float = randf_range(base.power_min, base.power_max) * (1.0 + item_level * 0.11)
	var item_name: String = base.name
	if not selected.is_empty():
		item_name = (selected[0].name + " " + base.name) if selected[0].kind == "prefix" else (base.name + " " + selected[0].name)
	if rarity_index >= 4 and not legendary.is_empty(): item_name = legendary.name
	return {
		"uid": "%s-%s" % [Time.get_ticks_usec(), randi()], "base_id": base.id, "name": item_name,
		"base_name": base.name, "slot": base.slot, "tags": Array(base.tags), "item_level": item_level,
		"rarity": rarity, "rarity_index": rarity_index, "color": RARITY_COLORS[rarity_index],
		"base_power": snappedf(base_power, 0.1), "affixes": selected, "legendary": legendary,
		"favorite": false
	}

func _weighted_base_item(favored_tags: Array) -> Dictionary:
	var choices: Array = []
	for item in base_items:
		choices.append(item)
		for tag in favored_tags:
			if tag in item.tags: choices.append(item)
	return choices.pick_random()

func _weighted_power(tags: Array) -> Dictionary:
	var choices: Array = []
	for power in legendary_powers:
		choices.append(power)
		for tag in tags:
			if tag in power.tags: choices.append(power)
	return choices.pick_random()

func _roll_rarity(tier: int) -> int:
	# 45/30/16/7/1.8/0.2 baseline, tilted by tier and hidden pity.
	var boost: float = minf(tier * 0.18 + Game.meta.get("pity", 0) * 0.13, 16.0)
	var roll := randf() * 100.0
	if roll < 0.2 + boost * 0.08: return 5
	if roll < 2.0 + boost: return 4
	if roll < 9.0 + boost * 1.7: return 3
	if roll < 25.0 + boost * 2.0: return 2
	if roll < 55.0 + boost: return 1
	return 0

func rarity_color(rarity: String) -> Color:
	var index := RARITIES.find(rarity)
	return RARITY_COLORS[maxi(index, 0)]
