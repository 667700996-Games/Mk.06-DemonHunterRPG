# RIFTFALL

RIFTFALL is a playable pixel horde roguelite action RPG built with Godot 4. One
classless hunter is reshaped by randomized equipment, affixes, legendary powers,
level upgrades, and skill evolutions while cutting through an escalating Greater
Rift. A run moves directly through combat, loot, build growth, elites, a guardian
boss, rewards, the next difficulty, death or victory, persistent upgrades, and an
immediate retry.

The game is original and MIT-licensed. The title art provenance is recorded in
[`docs/ART_PROVENANCE.md`](docs/ART_PROVENANCE.md).

## Play

Requirements: Godot **4.7.2 stable or newer**, macOS or Windows.

1. Open this folder in Godot.
2. Press **F6/Run Project**. The title screen is the default main scene.
3. Choose **Start New Rift**, a tier, and one of the three biomes.

Command line:

```sh
godot --path .
```

Headless startup validation:

```sh
godot --headless --path . --quit-after 5
```

Full integrated gameplay smoke test:

```sh
godot --headless --path . -- --smoke-test
```

700/1,000-enemy CPU stress gate:

```sh
godot --headless --path . -- --stress-test
```

Export presets are included for universal macOS and Windows Desktop builds. Install
the matching Godot export templates, then export from **Project → Export**.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Primary attack | Left mouse | Right trigger / RB |
| Frost nova | Right mouse | Left trigger / LB |
| Dash | Space | A |
| Meteor | Q | X |
| Aegis pulse | E | Y |
| RIFTFALL ultimate | R | B |
| Healing potion | 1 | D-pad down |
| Character and loot | Tab | Back / View |
| Interact / quick equip | F | D-pad up |
| Pause | Esc | Start |

Auto-attack is enabled by default and can be disabled in Settings for manual aim.
Optional auto-potion (at 35% health) and smart auto-barrier toggles are disabled
by default. Frost nova, dash, meteor, and RIFTFALL always remain manual skills.
Controls, cooldowns, danger telegraphs, elite markers, rarity beams, and build
comparisons are visible in play without a separate tutorial.

## Game content

- 1 classless hunter with projectile, melee-tag, elemental, summon, critical,
  low-health, barrier, movement, lucky-hit, and status build paths.
- 12 normal enemy roles with distinct silhouettes and behavior.
- 13 elite affixes; elites roll 1–3 as tiers increase.
- 5 original bosses, each backed by three phase-escalating pattern definitions.
- 3 biomes with independent palettes, props, enemy pools, ambience, and bosses.
- 40 base items, 100 affixes, 30 legendary rule-changing powers, 24 level-up
  upgrades, and 10 tag-driven skill evolutions.
- Greater Rift tiers scale health, damage, density, elite cadence/affix count,
  rewards, XP, and rarity. Ten tiers are exposed initially through progression;
  the internal structure continues beyond Tier 100.
- Smart loot softly favors active build tags. A hidden pity counter improves high
  rarity odds, and comparisons evaluate current tag synergy rather than item level
  alone.

## Architecture

```text
autoload/       Persistent Game, SaveManager, AudioManager, DataRegistry services
data/           Resource-backed content database and record schema
scripts/core/   Main state flow: title, setup, run, results, meta, settings
scripts/world/  Arena director, biome renderer, shrines and cursed events
scripts/entities/ Pooled player, enemy, projectile and pickup actors
scripts/effects/  Pooled impact, damage-number and telegraph effects
scripts/ui/     Scalable commercial-style HUD, menus, inventory and debug kit
tests/          Integrated gameplay smoke harness
assets/         Original project-bound presentation art
```

The arena uses direct, inexpensive horde steering rather than one navigation agent
per enemy. AI decisions are staggered by group and distance. Spatial hashing limits
projectile queries. Enemies, projectiles, pickups, impact VFX, damage numbers, and
danger zones are prewarmed and reused. XP drops are visually represented but
aggregated under heavy kill rates. Damage text is sampled and capped per frame.

Content is stored in `data/content.tres`, a Godot `Resource`, then parsed once by
`DataRegistry`. Combat and UI consume immutable dictionaries through explicit APIs
and signals. New definitions can be added without changing arena behavior.

## Save data

The local save contains settings, meta currency, permanent upgrades, unlocks,
highest tier, equipment, inventory, and lifetime statistics.

- macOS: `~/Library/Application Support/Godot/app_userdata/RIFTFALL/`
- Windows: `%APPDATA%\Godot\app_userdata\RIFTFALL\`

Writes go to a temporary file, the prior save is copied to a backup, and the
temporary file is atomically renamed. A corrupt primary save falls back to backup.

## Debug mode

In editor/debug builds, press **F10** to open the hidden developer hunt kit. It can
toggle god mode, spawn normal/elite/boss enemies and items, add XP/gold, raise the
tier, kill the current horde, launch a 250-enemy stress wave, and show performance
monitors. The menu is never instantiated as user-facing release UI.

## Settings and accessibility

Resolution, fullscreen, VSync, FPS limit, master/music/SFX/UI volume, auto attack,
auto potion, auto barrier, gamepad vibration, screen-shake strength, flash
intensity, damage-number density, and UI scale are saved locally. Critical
gameplay information is communicated by
silhouette, geometry, labels, and animation in addition to color.

The game supports Korean and English from both the title and in-run settings
menus. Korean is the default for new and pre-localization save files; changing
the language rebuilds the current settings screen immediately and is persisted
with the rest of the settings.

## Known limitations

- The repository intentionally contains no copyrighted or license-ambiguous audio
  packs. Music and combat/UI SFX are synthesized at runtime; teams shipping on a
  storefront can replace them through `AudioManager` without changing gameplay.
- Signed/notarized binaries are not committed. Exporting a distributable app needs
  locally installed Godot export templates and the platform owner's signing keys.
- The automated test is deterministic about system flow, not combat balance.
  Difficulty curves and 15–25 minute pacing should continue to be tuned with human
  play sessions on target hardware.

## License

Code and project-authored assets are provided under the root [MIT License](LICENSE).
