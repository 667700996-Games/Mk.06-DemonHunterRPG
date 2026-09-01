extends Node

signal settings_changed
signal meta_changed
signal run_started
signal run_ended(result: Dictionary)
signal inventory_changed

const SAVE_VERSION := 1
const SLOTS := ["weapon", "head", "chest", "gloves", "boots", "amulet", "ring_1", "ring_2"]

var settings := {
	"fullscreen": false, "vsync": true, "fps_limit": 120, "master_volume": 0.8,
	"music_volume": 0.6, "sfx_volume": 0.8, "ui_volume": 0.8, "screen_shake": 0.75,
	"damage_numbers": 0.75, "flash_intensity": 0.7, "auto_attack": true,
	"gamepad_vibration": true, "ui_scale": 1.0, "hold_to_attack": true
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
	var saved_equipment: Dictionary = data.get("equipment", {})
	for slot in SLOTS: equipment[slot] = saved_equipment.get(slot, {})
	apply_settings()

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

func register_item(item: Dictionary) -> void:
	inventory.push_front(item)
	current_run.items = current_run.get("items", 0) + 1
	var rarity: String = item.get("rarity", "Common")
	current_run.rarities[rarity] = current_run.rarities.get(rarity, 0) + 1
	if rarity in ["Legendary", "Mythic"]:
		statistics.legendary_drops += 1
		meta.pity = 0
	else:
		meta.pity += 1
	if inventory.size() > 80: auto_salvage()
	inventory_changed.emit()

func equip_item(item: Dictionary) -> void:
	var slot: String = item.get("slot", "weapon")
	if slot == "ring":
		slot = "ring_1" if equipment.ring_1.is_empty() else "ring_2"
	var previous: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	_remove_inventory_uid(item.get("uid", ""))
	if not previous.is_empty(): inventory.push_front(previous)
	inventory_changed.emit()

func salvage_item(item: Dictionary) -> int:
	if item.get("favorite", false): return 0
	var value := int(item.get("item_level", 1) * (item.get("rarity_index", 0) + 1) * 0.8) + 1
	meta.currency += value
	_remove_inventory_uid(item.get("uid", ""))
	inventory_changed.emit()
	return value

func auto_salvage() -> void:
	var keep: Array[Dictionary] = []
	for item in inventory:
		if item.get("favorite", false) or item.get("rarity_index", 0) >= 2: keep.append(item)
		else: meta.currency += maxi(1, int(item.get("item_level", 1) * 0.5))
	inventory = keep

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
	return output

func apply_settings() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps_limit)
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()

