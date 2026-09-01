class_name ContentDatabase
extends Resource

## Compact Resource-backed records. Each entry is pipe-delimited and parsed by
## DataRegistry into immutable dictionaries at boot. Designers can add content
## here without touching combat code.
@export var enemies: PackedStringArray
@export var bosses: PackedStringArray
@export var biomes: PackedStringArray
@export var base_items: PackedStringArray
@export var affixes: PackedStringArray
@export var legendary_powers: PackedStringArray
@export var upgrades: PackedStringArray
@export var evolutions: PackedStringArray

