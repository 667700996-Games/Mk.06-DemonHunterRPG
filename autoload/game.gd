extends Node

signal settings_changed
signal meta_changed
signal run_started
signal run_ended(result: Dictionary)
signal inventory_changed

const SAVE_VERSION := 1
const SLOTS := ["weapon", "head", "chest", "gloves", "boots", "amulet", "ring_1", "ring_2"]
const INVENTORY_CAP := 80
const ARMOR_SLOTS := ["head", "chest", "gloves", "boots"]

var settings := {
	"language": "ko", "fullscreen": false, "resolution": "1920x1080", "vsync": true, "fps_limit": 120, "master_volume": 0.8,
	"music_volume": 0.6, "sfx_volume": 0.8, "ui_volume": 0.8, "screen_shake": 0.75,
	"damage_numbers": 0.75, "flash_intensity": 0.7, "auto_attack": true,
	"gamepad_vibration": true, "ui_scale": 1.0, "hold_to_attack": true,
	"auto_potion": false, "auto_barrier": false,
	"auto_salvage_common": false, "auto_salvage_magic": false, "auto_salvage_rare": false
}
var meta := {
	"currency": 0, "highest_tier": 1, "unlocked_tier": 1, "starting_gold": 0,
	"starting_rerolls": 1, "passive_power": 0, "pity": 0, "unlocked_powers": [],
	"unlocked_items": []
}
var statistics := {
	"total_runs": 0, "total_kills": 0, "elite_kills": 0, "boss_kills": 0,
	"highest_tier": 1, "fastest_clear": 0.0, "highest_damage": 0.0,
	"highest_dps": 0.0, "legendary_drops": 0
}
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}
var current_run: Dictionary = {}

func _ready() -> void:
	for slot in SLOTS: equipment[slot] = {}

func hydrate(data: Dictionary) -> void:
	_merge_known(settings, data.get("settings", {}))
	_merge_known(meta, data.get("meta", {}))
	_merge_known(statistics, data.get("statistics", {}))
	inventory.assign(data.get("inventory", []))
	for index in inventory.size(): inventory[index] = _normalize_item(inventory[index])
	_enforce_inventory_cap()
	var saved_equipment: Dictionary = data.get("equipment", {})
	for slot in SLOTS: equipment[slot] = _normalize_item(saved_equipment.get(slot, {}))
	apply_settings()

func _normalize_item(item: Dictionary) -> Dictionary:
	if item.is_empty(): return item
	var colors := [Color("#d8dde8"), Color("#58a6ff"), Color("#ffd166"), Color("#b778ff"), Color("#ff7b36"), Color("#ff3fb4")]
	var rarity_index := clampi(int(item.get("rarity_index", 0)), 0, colors.size() - 1)
	item["color"] = colors[rarity_index]
	return item

func localized_item_name(item: Dictionary) -> String:
	if item.is_empty(): return TranslationServer.translate("Unknown")
	var legendary: Dictionary = item.get("legendary", {})
	if not legendary.is_empty(): return TranslationServer.translate(str(legendary.get("name", item.get("name", "Unknown"))))
	var base_name := TranslationServer.translate(str(item.get("base_name", item.get("name", "Unknown"))))
	var affixes: Array = item.get("affixes", [])
	if affixes.is_empty(): return base_name
	var affix_name := TranslationServer.translate(str(affixes[0].get("name", "")))
	if str(settings.get("language", "ko")) == "ko": return "%s %s" % [affix_name, base_name]
	return str(item.get("name", base_name))

func localized_item_slot(item: Dictionary) -> String:
	var slot := str(item.get("slot", "weapon")).replace("_", " ").to_upper()
	return TranslationServer.translate(slot)

func localized_item_type(item: Dictionary) -> String:
	var slot := str(item.get("slot", "weapon"))
	var tags: Array = item.get("tags", [])
	if slot == "weapon":
		return TranslationServer.translate("MELEE WEAPON" if "melee" in tags else "RANGED WEAPON")
	if slot in ARMOR_SLOTS: return TranslationServer.translate("ARMOR")
	return TranslationServer.translate("ACCESSORY")

func localized_item_usage(item: Dictionary) -> String:
	var slot := str(item.get("slot", "weapon"))
	var tags: Array = item.get("tags", [])
	if slot == "weapon" and "melee" in tags:
		return TranslationServer.translate("Uses a close-range sweeping attack.")
	if slot == "weapon": return TranslationServer.translate("Fires projectiles at enemies from range.")
	if slot in ARMOR_SLOTS:
		return TranslationServer.translate("Provides defensive or build-focused equipment bonuses.")
	return TranslationServer.translate("Provides specialized build and utility bonuses.")

func localized_item_tags(item: Dictionary) -> String:
	var translated: Array[String] = []
	for tag in item.get("tags", []): translated.append(TranslationServer.translate(str(tag)))
	return " / ".join(translated)

func localized_stat_name(stat_name: String) -> String:
	return TranslationServer.translate(stat_name.replace("_", " ").to_upper())

func localized_affix_description(affix: Dictionary) -> String:
	return "%s  •  %s +%.1f" % [TranslationServer.translate(str(affix.get("name", "Unknown"))), localized_stat_name(str(affix.get("stat", ""))), float(affix.get("value", 0.0))]

func _merge_known(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key): target[key] = source[key]

func serialize() -> Dictionary:
	return {"version": SAVE_VERSION, "settings": settings, "meta": meta,
		"statistics": statistics, "inventory": inventory, "equipment": equipment}

func start_run(tier: int, biome: String) -> void:
	current_run = {
		"tier": tier, "biome": biome, "elapsed": 0.0, "kills": 0, "elite_kills": 0,
		"boss_kills": 0, "damage": 0.0, "highest_crit": 0.0, "damage_taken": 0.0,
		"items": 0, "rarities": {}, "gold": int(meta.starting_gold), "level": 1,
		"xp": 0.0, "rerolls": int(meta.starting_rerolls), "upgrades": [], "tags": {},
		"started_at": Time.get_ticks_msec()
	}
	run_started.emit()

func finish_run(cleared: bool) -> Dictionary:
	if current_run.is_empty(): return {}
	current_run["cleared"] = cleared
	statistics.total_runs += 1
	statistics.total_kills += current_run.kills
	statistics.elite_kills += current_run.elite_kills
	statistics.boss_kills += current_run.boss_kills
	statistics.highest_damage = maxf(statistics.highest_damage, current_run.highest_crit)
	var dps: float = current_run.damage / maxf(current_run.elapsed, 1.0)
	statistics.highest_dps = maxf(statistics.highest_dps, dps)
	if cleared:
		meta.currency += 30 + current_run.tier * 12
		meta.highest_tier = maxi(meta.highest_tier, current_run.tier)
		meta.unlocked_tier = maxi(meta.unlocked_tier, current_run.tier + 1)
		statistics.highest_tier = maxi(statistics.highest_tier, current_run.tier)
		if statistics.fastest_clear <= 0.0 or current_run.elapsed < statistics.fastest_clear:
			statistics.fastest_clear = current_run.elapsed
	var result := current_run.duplicate(true)
	result["dps"] = dps
	result["currency_earned"] = (30 + current_run.tier * 12) if cleared else maxi(5, current_run.kills / 20)
	if not cleared: meta.currency += result.currency_earned
	SaveManager.save_game()
	run_ended.emit(result)
	return result

func register_item(item: Dictionary) -> bool:
	current_run.items = current_run.get("items", 0) + 1
	var rarity: String = item.get("rarity", "Common")
	current_run.rarities[rarity] = current_run.rarities.get(rarity, 0) + 1
	if rarity in ["Legendary", "Mythic"]:
		statistics.legendary_drops += 1
		meta.pity = 0
	else:
		meta.pity += 1
	var salvage_key := "auto_salvage_" + rarity.to_lower()
	if settings.get(salvage_key, false) and rarity in ["Common", "Magic", "Rare"]:
		meta.currency += _salvage_value(item, 0.6)
		inventory_changed.emit()
		return false
	inventory.push_front(item)
	var kept := _enforce_inventory_cap(item.get("uid", ""))
	inventory_changed.emit()
	return kept

func equip_item(item: Dictionary) -> void:
	var slot := equipment_slot_for_item(item)
	var previous: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	_remove_inventory_uid(item.get("uid", ""))
	if not previous.is_empty(): inventory.push_front(previous)
	inventory_changed.emit()

func equipment_slot_for_item(item: Dictionary) -> String:
	var slot := str(item.get("slot", "weapon"))
	if slot != "ring": return slot
	if equipment.ring_1.is_empty(): return "ring_1"
	if equipment.ring_2.is_empty(): return "ring_2"
	var tags := build_tags()
	return "ring_1" if item_score(equipment.ring_1, tags) < item_score(equipment.ring_2, tags) else "ring_2"

func equipped_item_for(item: Dictionary) -> Dictionary:
	return equipment.get(equipment_slot_for_item(item), {})

func salvage_item(item: Dictionary) -> int:
	if item.get("favorite", false): return 0
	var value := _salvage_value(item, 0.8)
	meta.currency += value
	_remove_inventory_uid(item.get("uid", ""))
	inventory_changed.emit()
	return value

func auto_salvage() -> void:
	var keep: Array[Dictionary] = []
	for item in inventory:
		if item.get("favorite", false) or item.get("rarity_index", 0) >= 2: keep.append(item)
		else: meta.currency += _salvage_value(item, 0.5)
	inventory = keep
	inventory_changed.emit()

func _salvage_value(item: Dictionary, multiplier: float) -> int:
	return maxi(1, int(item.get("item_level", 1) * (item.get("rarity_index", 0) + 1) * multiplier) + 1)

func _enforce_inventory_cap(tracked_uid := "") -> bool:
	if inventory.size() <= INVENTORY_CAP: return true
	# The old cap only removed Common/Magic items, so Rare+ inventories could grow
	# without bound. Rank once, keep the strongest/favorited items, then rebuild in
	# the original recent-first order. This is O(n log n), including old oversized saves.
	var ranked: Array[Dictionary] = []
	var tags := build_tags()
	for index in inventory.size():
		var candidate: Dictionary = inventory[index]
		var priority := float(candidate.get("rarity_index", 0)) * 1000000.0 + item_score(candidate, tags)
		if candidate.get("favorite", false): priority += 1000000000.0
		ranked.append({"index": index, "priority": priority})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return a.priority > b.priority)
	var keep_indices := {}
	for index in mini(INVENTORY_CAP, ranked.size()): keep_indices[ranked[index].index] = true
	var trimmed: Array[Dictionary] = []
	var tracked_kept := tracked_uid.is_empty()
	for index in inventory.size():
		var candidate: Dictionary = inventory[index]
		if keep_indices.has(index):
			trimmed.append(candidate)
			if candidate.get("uid", "") == tracked_uid: tracked_kept = true
		else:
			meta.currency += _salvage_value(candidate, 0.6)
	inventory = trimmed
	return tracked_kept

func _remove_inventory_uid(uid: String) -> void:
	for index in range(inventory.size() - 1, -1, -1):
		if inventory[index].get("uid", "") == uid:
			inventory.remove_at(index)
			return

func item_score(item: Dictionary, current_tags: Dictionary = {}) -> float:
	if item.is_empty(): return 0.0
	var score: float = item.get("base_power", 0.0)
	for affix in item.get("affixes", []):
		var tag_weight := 1.0 + minf(float(current_tags.get(affix.get("tag", ""), 0)) * 0.12, 1.0)
		score += float(affix.get("value", 0.0)) * tag_weight
	if not item.get("legendary", {}).is_empty(): score *= 1.55
	return score

func build_tags() -> Dictionary:
	var tags := {}
	for slot in equipment:
		var item: Dictionary = equipment[slot]
		for tag in item.get("tags", []): tags[tag] = tags.get(tag, 0) + 1
		var power: Dictionary = item.get("legendary", {})
		for tag in power.get("tags", []): tags[tag] = tags.get(tag, 0) + 2
	for upgrade in current_run.get("upgrades", []):
		var tag: String = upgrade.get("tag", "")
		if not tag.is_empty(): tags[tag] = tags.get(tag, 0) + 1
	return tags

func stat_total(stat_name: String) -> float:
	var total := 0.0
	for slot in equipment:
		for affix in equipment[slot].get("affixes", []):
			if affix.get("stat", "") == stat_name: total += float(affix.get("value", 0.0))
	for upgrade in current_run.get("upgrades", []):
		if upgrade.get("stat", "") == stat_name: total += float(upgrade.get("value", 0.0))
	return total

func legendary_effects() -> Dictionary:
	var output := {}
	for slot in equipment:
		var power: Dictionary = equipment[slot].get("legendary", {})
		if not power.is_empty(): output[power.effect] = power.value
	for upgrade in current_run.get("upgrades", []):
		var stat: String = upgrade.get("stat", "")
		if stat in ["fifth_lightning", "crit_explode", "frost_shatter", "dash_fire", "kill_split", "lowhealth_speed", "speed_damage", "summon"]:
			output[stat] = upgrade.get("value", 1.0)
	var evolution_map := {
		"storm_god": ["chain", 8.0], "crimson_end": ["bleed_execute", 28.0],
		"white_silence": ["frost_shatter", 8.0], "funeral_sun": ["burn_explode", 180.0],
		"death_company": ["elite_summon", 2.0], "void_lens": ["void_well", 35.0],
		"serpent_world": ["eternal_poison", 3.0], "razor_comet": ["dash_strike", 1.0],
		"furnace_soul": ["barrier_burn", 160.0], "last_eclipse": ["last_stand", 3.0]
	}
	for evolution_id in current_run.get("evolutions", []):
		if evolution_map.has(evolution_id):
			var mapping: Array = evolution_map[evolution_id]
			output[mapping[0]] = mapping[1]
	return output

func apply_settings() -> void:
	TranslationServer.set_locale(str(settings.get("language", "ko")))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps_limit)
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var dimensions: PackedStringArray = str(settings.resolution).split("x")
		if dimensions.size() == 2:
			DisplayServer.window_set_size(Vector2i(dimensions[0].to_int(), dimensions[1].to_int()))
	settings_changed.emit()
