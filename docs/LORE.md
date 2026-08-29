# Lore & Theming — Story Bible

Living reference for the game's narrative premise and thematic rules. Update this whenever
story/theming decisions are made so future features (enemies, items, waves, dialogue) stay
consistent. See [docs/IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for pending work and
`docs/systems/*.md` for as-built system behavior.

## Premise (current, subject to expansion)

- The player defends a castle against an escalating dragon invasion.
- **All enemies in the game are dragons**, ranging from small, weak whelps early on to
  massive, ancient wyrms as bosses in later days. There are no goblins, orcs, undead, etc. —
  every enemy reads as "a kind of dragon" (by size, age, or specialization).
- Difficulty/day progression should track dragon "growth": early days = young/small dragons,
  later days = older/bigger/more specialized dragons, with named unique bosses at day gates.

## Enemy Naming Conventions

When adding a new enemy (`data/enemies/*.tres`), pick a name/id that fits the dragon power
curve below instead of a generic fantasy monster name. Prefer descriptive dragon-life-stage or
dragon-role words over reusing "goblin/orc/skeleton"-style names.

| Tier | Theme | Example ids |
|---|---|---|
| Weakest fodder | Newly hatched dragons | `whelp` |
| Fast/agile | Young dragons with bursts of speed or flight dives | `wyrmling` |
| Support casters (short range) | Young dragons with a breath/roar debuff | `hatchling_mystic` |
| Support casters (long range, slower) | Older spellcasting drakes | `drake_warlock` |
| Tanky blockers | Mid-size drakes that clog the path and drop materials | `young_drake` |
| Heavy armour blockers | Bigger, armoured war-drakes | `war_drake` |
| Day-gate bosses | Named ancient/elder wyrms | `elder_wyrm` |

Current roster (see [docs/systems/tower_defense.md](systems/tower_defense.md#enemy-roster-current)
for stats): Whelp, Wyrmling, Hatchling Mystic, Drake Warlock, Young Drake, War Drake, Elder Wyrm.

## Applying This To Other Content

- Enemy drop materials/items can still use elemental/mineral names (e.g. `volatile_core`) —
  those represent dragon scales/organs/hoard materials, not the enemy's own name.
- Boss-gated rewards and quest text (`GameState.castle_objective_text()`) should reference the
  dragon boss by its themed name, not a generic title.
- Future enemy variants (elemental breath types, flight-based movement, hoard-guardian bosses,
  etc.) should stay grounded in "dragon" as a creature type — reskins/subspecies are fine,
  different monster families are not.
