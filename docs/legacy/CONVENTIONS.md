# Conventions

Written once (task F3) so it doesn't get re-litigated in every later task. This document is
itself the memory that carries architecture decisions across sessions — see
`docs/GODOT_PLAN.md` Phase 10, rule 4 ("prefer data-driven design") and the archaeology in
`docs/GODOT_MIGRATION_ANALYSIS.md`, whose §B4 and §E3 findings motivate several rules below.

## Language

**GDScript only.** No C#. See `docs/GODOT_PLAN.md` Phase 3 for the full reasoning
(mobile export risk, animated-travel system, single-language debugging surface).

## Files and naming

- One class per file. Filename is `snake_case`, matches the class conceptually
  (`resource_def.gd` → `class_name ResourceDef`).
- `class_name` declarations are `PascalCase`.
- Scene files (`.tscn`) are `PascalCase` to match their root node (`MainScreen.tscn`).
- Folders are `snake_case`, already laid out under `scripts/`, `scenes/`, `data/`, `test/`
  (see the tree in `docs/GODOT_PLAN.md`'s "What was scaffolded" section).
- Test files mirror the file under test: `scripts/sim/inventory.gd` → `test/unit/test_inventory.gd`.

## Typing — always, no exceptions

Every `var`, function parameter, and return type is explicitly typed.

```gdscript
# Yes
var gold: float = 0.0
func sell(id: StringName, amount: float) -> bool:

# No
var gold = 0.0
func sell(id, amount):
```

`project.godot` has `untyped_declaration`, `unsafe_property_access`, and
`unsafe_method_access` warnings turned on specifically to catch violations of this rule.
**Do not silence these warnings by adding `@warning_ignore` — fix the type instead.**
This is GDScript's substitute for the compile-time safety a statically-typed language
would give for free; see Phase 3's counter-argument section for why this matters more
here than in a typical GDScript project.

## Content and cross-reference IDs — always `StringName`, never an index or ordinal

**This is the single most important rule in this document.** The Unity migration
analysis (`docs/GODOT_MIGRATION_ANALYSIS.md` §B4) found that Unity's research data
stored `effectType` as a raw enum ordinal (`effectType: 17`), and that a single enum
reorder silently re-pointed `Research_TradingPosts` from "unlock auto-sell" to
`Custom` — a bug nobody caught because nothing made the mismatch visible.

Rules, without exception:

- Every content definition (`ResourceDef`, `RecipeDef`, `RegionDef`, `UpgradeDef`, …) has
  an explicit `@export var id: StringName`.
- Every cross-reference between definitions, and every reference from save data back into
  content, stores that `id` — never an enum ordinal, never an `Array` index, never a
  `res://` resource path baked into JSON.
- If an effect or category needs to vary, prefer a `StringName` key over a bare `int` enum
  serialized to disk. A `Dictionary` lookup that fails loudly beats an enum ordinal that
  silently means something else after a refactor.
- `Db` (task F4/D4) indexes everything by `id` and **fails loudly** — `push_error` plus a
  null return, or a hard validation failure at boot — on a duplicate, missing, or malformed
  id. A missing icon or an empty field should be visible at boot, not discovered by a
  player three sessions later (as happened with 48 of 50 Unity resources shipping with no
  icon, per the analysis §B2).

## Signals

- Declared with a typed payload: `signal resource_changed(id: StringName, total: float, delta: float)`.
- Named in **past tense** for "this happened" (`gold_changed`, `upgrade_purchased`,
  `run_started`) — not `on_gold_changed` (that naming belongs to the *handler*, not the
  signal) and not imperative (`change_gold`, which reads like a command).
- No global `EventBus` autoload. Signals live on the object that owns the state they
  describe (`Game.economy.gold_changed`, not a generic bus everything dumps into). See
  `docs/GODOT_PLAN.md` Phase 4.3 for why.
- Godot signals auto-disconnect when either endpoint is freed — do not hand-write
  `_exit_tree` disconnect boilerplate defensively "just in case." If you find yourself
  writing that, something else is wrong (a stale reference being held elsewhere).

## Autoloads

Exactly three: `Db`, `Game` (with `Economy`/`Inventory`/`Colonies`/`Progression` as child
nodes), `SaveSystem`. See `docs/GODOT_PLAN.md` Phase 4.3. Do not add a fourth without
updating that section first — the whole point of three is that it stayed small on purpose.

## No system without a caller

`docs/GODOT_PLAN.md` Phase 10, rule 8, restated here because it's easy to forget mid-task:
**a system does not count as done because it compiles and has a green test.** It's done
when something in the actual game calls it and the effect is visible when you run the
scene. The Unity project shipped ten `ResearchManager` methods with zero callers and a
fully-authored, entirely-unwired `ColonyTypeData` (analysis §E3) — this is the failure
mode that rule exists to prevent.

## Comments

Match the root `CLAUDE.md`-equivalent guidance already in force for this project: default
to no comments; write one only when it explains a non-obvious **why** (a hidden constraint,
a workaround, a subtlety a future reader would trip on) — never a restatement of what the
code already says through good naming. The one deliberate exception already in the repo is
the dated patch note in `addons/gut/gut_loader.gd`, which documents *why* vendored code was
changed — that's the right shape for a vendor patch, not for our own code.

## File layout reference

See the tree under "What was scaffolded" in `docs/GODOT_PLAN.md` — not duplicated here to
avoid the two documents drifting apart.
