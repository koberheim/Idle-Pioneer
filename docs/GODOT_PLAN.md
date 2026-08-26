# Idle Pioneer — Godot 4 Rebuild: Architecture & Task Backlog

**Session B: architecture and planning only. No gameplay code written.**

Companion to [`GODOT_MIGRATION_ANALYSIS.md`](./GODOT_MIGRATION_ANALYSIS.md) (Session A), which is the evidence base for everything here. Where this document cites the Unity project, the citation traces back to that analysis.

`docs/DESIGN.md` does not exist in this repo. The design intent used here is reconstructed in Phase 2 of the analysis, drawn from `Assets/DOCS_GAME_DESIGN.md.txt`, `RESEARCH_TREE_DESIGN.md`, `RESEARCH_SYSTEM_SETUP.md`, and the code itself.

---

## ⚠ DESIGN REALIGNMENT (later in the project) — read this before anything below

A full, locked design document arrived after most of Phases 1–8 below were already built and tested: **[`docs/GAME_DESIGN.md`](./GAME_DESIGN.md)**, "Colonial Idle." It is now **the authoritative game design**. Everything below it in this file is the *original* plan, built from Unity-archaeology and reasonable inference before that document existed. Most of it still holds up. Some of it doesn't, and the parts that don't are called out explicitly here rather than silently rewritten in place, so the history of *why* is preserved.

### What's confirmed correct by the new document (no change needed)

- **The two-tier save split** (a permanent part that survives a reset, and a resettable part that doesn't) — `GAME_DESIGN.md` §9 mandates exactly this shape and calls it "the architectural decision that cannot be retrofitted. Build it this way from the first commit." That's precisely what Phase 6 below argued for and what was already built. No change to the *approach* — only to the specific fields inside each half (see below).
- **The exact-math approach to catching up idle production after time away** (task P1's `ProductionCycle`) is not just compatible with `GAME_DESIGN.md` §10's offline catch-up requirement — it's strictly better than the coarse-stepping fallback the document describes, and already satisfies the document's own correctness requirement ("the simulation must be correct at any step size") by construction, since it uses division instead of a loop.
- **Saving to a temp file and swapping it in**, ids stored as text names rather than numbers, and recipes able to consume other recipes' outputs (already true of the recipe system as built, though never exercised) all carry forward unchanged.
- All foundational tooling (project setup, git, the automated test harness) is completely unaffected.

### What conflicts and needs rework

1. **The land/water map system does not exist in the new design, and building it further should stop.** `GAME_DESIGN.md` explicitly lists "Procedural map generation" under "Deliberately Out of Scope for v1" with the note *"the reason the original project stalled — do not revisit."* It also rules out "any real map rendering" for v1 — a plain list is the whole interface. Instead, land vs. sea is a coin-flip rolled per colony at the start of a run (§5, "Route Type"), not a real place derived from geography. This directly supersedes Phase 5 below and tasks M1–M3/M5 in Phase 8, all of which were built and fully tested against a hand-drawn coastline map. That work is not wrong, and it stays in the project's history — it's just no longer the direction. See the open question at the end of this section for what to do with it.
2. **Colonies are a fixed, named table of exactly eight, in a fixed order, each with one specific resource, price, and one-time unlock cost** (§5) — not a flexible, freely-placed system. The existing colony/region data model was built for the old flexible approach and needs to be rebuilt around this table.
3. **Colonists are an entirely new concept, not built at all yet.** In the new design, colonists are a single shared, limited workforce the player assigns either to gathering raw goods or to crafting — and that trade-off is called out as *the* central tension of the whole game (§4). Nothing like this exists in the project yet; it's not a tweak, it's a new mechanic.
4. **Shipping rules are different and more specific — and simplified further by explicit direction after this section was first written.** `GAME_DESIGN.md` §6 specifies a shipment departs once its cargo hold is full, or after 30 seconds, whichever comes first. That was then simplified in conversation: transports simply cycle back and forth continuously, with no waiting and no 30-second timeout at all — each time one is at a colony, it loads whatever's ready up to its maximum capacity and immediately heads out. This is closer in shape to the old distance-and-two-leg-journey model than the rest of this list suggests, and reuses more of it than expected: same continuous-loop structure, just re-driven by the design doc's `cargo_capacity`/`round_trip_time` formulas (transport level, distance, and a per-colony land/sea roll) instead of a real map.
5. **Crafting needs to run continuously and automatically**, the same way production does — staffed by colonists, sped up by workshop upgrades, and pausing/resuming itself when ingredients run out (§6). What was built instead is an on-demand "craft one batch right now" action, closer to a button press than a running process.
6. **The prestige system needs real, specific content**, not just the general framework that exists today. `GAME_DESIGN.md` names the permanent currency "Liberty," gives an exact payout formula, and specifies three named upgrade paths (Industry, Navigation, Settlement) each with their own per-level costs and effects (§8) — replacing the one generic placeholder upgrade built so far. Worth noting: Liberty is exactly the mechanic flagged as the most likely (but never-built) prestige gate in the original Unity project archaeology — this document confirms that guess.
7. **The save file's actual contents need to match the new shape** in `GAME_DESIGN.md` §9 — coin instead of gold, colonists, workshops, per-colony shipping status, and so on. The two-tier *structure* is right (see above); the fields inside it are not yet.

### Open question this raises

The items above touch a meaningful fraction of what was already built and tested (roughly the whole "Production" task block, most of the game-state and save work, and all of the map work). Before any of it gets reworked, the person running this project needs to decide: rebuild the affected pieces in place keeping what still fits, treat this as a bigger reset of the gameplay layer, and what to do with the now-unused map code (keep as dormant reference, or remove it). That conversation happened outside this document — check the session log around the point this section was added for the decision that was made, since a future session picking this file up cold won't have seen it otherwise.

**Decided:** rebuild in place, keeping what fits. The map code stays in the project, untouched and unused (not deleted).

**Shipping, simplified further:** transports don't wait for a full hold or a timer at all — they cycle continuously, loading whatever's ready up to capacity the moment they're back at their origin, and immediately departing again.

### A real correction to the document, given directly in conversation — colony upgrades and colonists

This isn't a simplification of something the document already said; it's a deliberate change to the document's own model, given explicitly, and it should be treated as the current source of truth over §4/§6's wording wherever the two disagree:

- **A colony has three separate, per-colony upgrade tracks, each bought with gold independently: production rate, cargo size, and transport speed.** This replaces the document's single "building_level" (production only) and single "transport_level" (cargo and speed bundled together) with three independent levels.
- **Each colony has its own base value for all three** — not a single shared constant across all eight. Founding a colony gives it working production and shipping immediately, at its base rate, with zero colonists assigned. This directly overturns §4's "every colonist is either producing or converting" framing taken literally (an unstaffed colony is no longer a colony producing *nothing* — it's a colony producing at its unboosted base rate).
- **Colonists assigned to a colony boost all three tracks together** (production, cargo, and speed) — not just production. The exact colonist-to-bonus formula is explicitly left as a placeholder ("we'll develop later") — built as a single, clearly-labeled, easy-to-retune number in Balance, not a real design decision yet.
- **Land vs. sea (the per-colony roll) is scoped down to affect only travel time**, not cargo capacity, now that cargo has its own dedicated per-colony base-and-upgrade track. This is a judgment call made to resolve an otherwise-unspecified interaction, not something said outright — flagged here so it can be revisited.

---

## Environment (verified this session)

| Thing | Status |
|---|---|
| Godot 4.6.2 stable (standard) | `D:\Godot_v4.6.2-stable_win64.exe` ✅ |
| Godot 4.6.2 stable (.NET/mono) | `D:\Godot_mono\Godot_v4.6.2-stable_mono_win64\` ✅ |
| .NET SDK | 10.0.400 ✅ |
| Godot project location | **`E:\Godot\Idle Pioneer\`** — scaffolded this session |
| Unity project (reference, read-only) | `E:\Unity\Projects\Idle Pioneer\` |

The Unity project stays untouched as a reference and asset source. This plan document lives in the Unity repo (`docs/`) because that is where you asked for it; consider copying `docs/` into the Godot project once work starts, so the plan travels with the code.

### What was scaffolded (structure only — no scripts, no systems)

```
E:\Godot\Idle Pioneer\
├── project.godot          # name, GL Compatibility renderer, 720x1280 portrait, strict GDScript warnings
├── .gitignore             # .godot/, export_presets.cfg, mono leftovers
├── scenes/
│   ├── Main.tscn          # empty Node, set as main scene
│   ├── ui/                # one .tscn per screen (Phase 4)
│   └── world/
├── scripts/
│   ├── core/              # autoloads, save system
│   ├── data/              # Resource definition classes
│   ├── sim/               # inventory, production, economy, crafting
│   ├── map/               # MapGrid, placement rules, map view
│   └── ui/
├── data/                  # .tres content: resources/ recipes/ regions/ upgrades/ maps/
├── assets/                # art/ fonts/  (ported from Unity — see Phase 10)
├── test/                  # unit/ helpers/  (GUT — see Phase 9)
└── addons/                # GUT installs here
```

Three `project.godot` choices worth knowing you can reverse in one line:

- **`gl_compatibility` renderer.** Widest hardware support, no Vulkan driver surprises, and it enables a web export later. A 2D idle game needs nothing from `forward_plus` or `mobile`. Change if you later want 2D lights/normal maps at scale.
- **720×1280 portrait**, windowed at 540×960 for desktop dev. Inferred from the Unity scene's `BottomDashboard` sliding up from the bottom edge — that is a portrait-phone layout. If the target is actually desktop landscape, this is one line.
- **Strict GDScript warnings on** (`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`). This makes GDScript behave much more like a typed language and catches the single most common novice error class — typos in property/method names — at edit time instead of runtime. Strongly recommend leaving these on.

---

# PHASE 3 — Language decision

## ✅ DECIDED: **100% GDScript. No C#, no split.**

> **Decision criterion changed from the original ask.** You reframed the question: not "easiest for a novice to hand-debug," but *"whichever produces the best final product and is best suited for continuing development,"* given that **I (Claude) write all the code.** That genuinely weakens argument #2 below — you are not the one reading Godot tutorials at 11pm. It does not flip the conclusion, because arguments #1, #3, #4, and especially the **new mobile-export point** below are about the shape of the project and the shape of *my* development loop, not about your fluency. I re-ran the decision against the new criterion rather than just keeping the old answer, and it still comes out GDScript — now more decisively, because two facts locked in by your other answers (mobile export confirmed, animated travel confirmed as a final-version requirement) both cut further in GDScript's favor.

### The reasoning, re-derived for "best final product + best for continued development"

**1. The prize for using C# is small, independent of who's typing.** The analysis classified the "pure logic, portable as-is" tier and found it thin: 8 enums and ~9 algorithm fragments (`ColonyProduction.TickProduction`'s cycle accumulator, `EconomyManager`'s `base × mult^n`, `ResearchManager.GetProductionMultiplier`'s stacking, the cargo-sort, Bresenham, the Perlin coastline). None are standalone — every one is embedded in a MonoBehaviour and uses `Mathf`, `Vector2Int`, or `Random`. Nothing copies across untouched. Total genuine salvage: roughly 200-300 lines of math, ported by hand either way. This was never a strong argument for C#; it's unchanged by who's coding.

**2. Mobile export is now confirmed (your answer to Q4), and that is the strongest point in this section.** Godot's C# support is built on .NET, and shipping .NET to iOS requires full ahead-of-time (NativeAOT) compilation — JIT is not allowed on iOS. In practice this has meant: larger app binaries, longer and more fragile export builds, a smaller pool of people who have actually shipped it (so less prior art for me to draw on when an export breaks), and periodic breakage across Godot point releases as the .NET/iOS toolchain shifts underneath it. GDScript export to iOS and Android is the well-trodden, first-class path with none of that risk. **For a project with a confirmed mobile target, this alone is close to decisive.**

**3. Animated travel as a confirmed final-version requirement (your answer to Q3) adds gameplay-tick-rate, per-frame `Node2D` work — exactly the kind of code that benefits from Godot's own engine-level optimizations (`Tween`, `PathFollow2D`, node pooling) more than from a faster host language.** The place the original Unity project was actually slow was algorithmic (a 3-million-cell grid rasterised over 30 frames, fixed in Phase 5), not language-bound. A modest number of colonies and vehicles animating per frame is well inside what GDScript handles natively; Godot's own engine, not the scripting language, does the per-frame transform/draw work either way.

**4. "Best suited for continuing development" favors the path with fewer moving parts for *me* to reason about across sessions.** I do not retain state between sessions except what's written to disk — `docs/GODOT_PLAN.md`, `docs/CONVENTIONS.md`, and the code itself are my memory. A single-language codebase with no build step, no marshalling boundary, and no C#/GDScript interop contract to keep consistent is meaningfully less for a fresh session (mine or a future contributor's) to get wrong. GDScript's lack of a compile step also means every change is testable by running the scene immediately — valuable for me the same way it would be for a human, because it shortens the verify-loop in every task in Phase 8.

**5. Everything Godot-shaped is more natural in GDScript.** `@export`, `@onready`, `signal`/`await`, `class_name`, `%UniqueName` — in C# these are attributes and generated glue with extra ceremony (e.g. exported `Godot.Collections.Array` vs `List<T>`). Phase 4's architecture leans hard on Resources, signals, and exports.

**6. Tooling.** GUT (Phase 9) is GDScript-native. The standard Godot build (`D:\Godot_v4.6.2-stable_win64.exe`) is a single executable with no SDK dependency — one less thing to keep synchronized across the desktop-dev / mobile-export boundary.

### Why not a split (GDScript UI + C# simulation)?

Still rejected, and the mobile-export point strengthens the rejection: a split project means C# assembly reload quirks in the editor, a marshalling/type-mapping boundary at every call between the two languages, **and** the iOS NativeAOT risk from point 2 above — because as soon as *any* C# ships in the project, the mobile export inherits .NET's AOT constraints even if 95% of the codebase is GDScript. A split earns its keep when you have a genuinely heavy simulation and an existing, clean, engine-free C# codebase to lean on. This project has neither.

### The honest counter-argument

C# gives real static typing, IDE refactoring, and roughly 3-10× raw execution speed on hot loops — genuine advantages for "best final product" in the abstract. Weighed against a confirmed mobile target and a confirmed future animation system, the export risk and complexity tax outweigh them here. Mitigations for what C# would have bought:

- **Typing:** GDScript is statically typed when written that way (`var gold: float`, `func sell(id: StringName, n: int) -> void`). The strict warnings enabled in `project.godot` (`untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`) turn most of C#'s compile-time safety into an editor-time warning instead. This is now a **hard rule**, not a suggestion: every declaration in this codebase is typed.
- **Speed:** covered above — the historical slow part was algorithmic, and animated colonies/vehicles are within GDScript's normal working set for a game of this genre and scale.

**Revisit trigger (write it down, then forget it):** if profiling ever shows GDScript simulation is the bottleneck *and* the fix is not algorithmic, a single GDExtension (C++ or Rust, not C#, to sidestep the mobile-AOT problem entirely) for that one hot path is the escape hatch — without converting the project or accepting the iOS export risk. Do not pay that cost speculatively.

### Consequence

**Use the standard Godot build (`D:\Godot_v4.6.2-stable_win64.exe`), not the mono build, for all development.** The `.gitignore` already excludes `.mono/`, `*.csproj`, and `*.sln` so a stray mono-editor open does not pollute the repo.

---

# PHASE 4 — Unity → Godot architecture mapping

## 4.1 The headline mapping table

| Unity concept | Godot 4 replacement | Notes for this project |
|---|---|---|
| `ScriptableObject` | `class_name XDef extends Resource` + `.tres` files | 8 SO types in the Unity project (§B1 of analysis). See 4.2. |
| Prefab (`.prefab`) | Scene (`.tscn`), instanced via `PackedScene.instantiate()` | Reference via `@export var scene: PackedScene`, or `preload()` for fixed ones. |
| `Instantiate(prefab, parent)` | `var n = scene.instantiate(); parent.add_child(n)` | |
| `Destroy(go)` | `node.queue_free()` | |
| `Awake()` | `_init()` (no tree) / `_enter_tree()` | |
| `Start()` | `_ready()` | Children are `_ready()` **before** parents — opposite of Unity intuition. |
| `Update(dt)` | `_process(delta: float)` | |
| `FixedUpdate()` | `_physics_process(delta)` | This project has no physics; you will not need it. |
| `OnDestroy()` | `_exit_tree()` / `NOTIFICATION_PREDELETE` | |
| `OnEnable`/`OnDisable` | `visibility_changed` signal, or `tree_entered`/`tree_exited` | Replaces the subscribe/unsubscribe dance in `ResourceTabManager`, `RecipeTabManager`, `ResearchTabManager`. |
| `OnApplicationQuit` | `NOTIFICATION_WM_CLOSE_REQUEST` (+ `get_tree().auto_accept_quit = false`) | Save-on-exit hook. |
| `OnApplicationPause` | `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` | Mobile save/offline hook. |
| `Action<T>` / UnityEvent | `signal changed(id: StringName, total: float)` + `emit()` / `connect()` | **Auto-disconnects when either node is freed.** This deletes an entire bug class the Unity code was defending against. |
| Static `Instance` singleton | **Autoload** — sparingly. See 4.3. | Unity had 9. We will have 3. |
| Canvas / uGUI screen | One `.tscn` per screen, root `Control` | See 4.4. |
| `VerticalLayoutGroup` etc. | `VBoxContainer` / `HBoxContainer` / `GridContainer` / `MarginContainer` | |
| `ScrollRect` | `ScrollContainer` | |
| `TextMeshProUGUI` | `Label` (+ `LabelSettings`) or `RichTextLabel` | `.ttf` fonts import directly; TMP `*SDF.asset` atlases are discarded. |
| Inspector-dragged references | `%UniqueName` (scene-unique node access) or `@export` | Kills the failure mode `Editor/RecipeRowPrefabValidator.cs` existed to catch. |
| Coroutine + `yield return null` | `await get_tree().process_frame` | |
| `WaitForSeconds(t)` / `Invoke("F", t)` | `await get_tree().create_timer(t).timeout` | |
| Coroutine used for animation | **`create_tween()`** — not `await` | Correct target for `DashboardController.SlidePanel` and `NationalityButton.FadeOutPanel`. |
| `PlayerPrefs` | JSON save file (game data) / `ConfigFile` (options) | See 4.5. |
| Unity Input System (`Mouse.current…`) | InputMap actions + `_unhandled_input(event)` | `.inputactions` file is the untouched Unity template — discard entirely. |
| `Camera.orthographicSize` | `Camera2D.zoom` | |
| `Texture2D` + `SetPixels32` + `RawImage` | `Image` → `ImageTexture` → `TextureRect`, or `TileMapLayer` | See Phase 5. |
| `SpriteRenderer.flipX` | `Sprite2D.flip_h` | |
| Manual z-ordering (`z = -10f` hack) | `z_index` / `y_sort_enabled` | |
| Animator `.controller` (button states) | `Theme` + `StyleBox` per button state | No animation needed; `SellButton_Controller.controller` becomes theme data. |
| Object pooling (`ColonyStorageUI`) | **Delete it.** Instance and `queue_free()` freely. | Godot `Control` churn is cheap. Re-add only if profiled. |
| `AddComponent<Image>()` at runtime | Build it into the `.tscn` | `ColonyView` added `Image`+`Button` at runtime; that becomes scene structure. |
| Editor windows (`MenuItem`, `AssetDatabase`) | `@tool` script / `EditorPlugin`, or an offline `godot --headless --script` converter | The 4 Unity generators become at most one throwaway converter. |
| `ColonyController` registry list | Explicit `Array` on the owning node (preferred), or node groups | Groups (`add_to_group`) exist, but an explicit typed array is easier to inspect and debug. |

## 4.2 ScriptableObjects → Resources

```
scripts/data/resource_def.gd     class_name ResourceDef  extends Resource
scripts/data/recipe_def.gd       class_name RecipeDef    extends Resource
scripts/data/region_def.gd       class_name RegionDef    extends Resource
scripts/data/upgrade_def.gd      class_name UpgradeDef   extends Resource
```

Each gets `@export` fields mirroring the Unity SO (analysis §B1), plus one thing the Unity version lacked:

> **Every definition carries an explicit `@export var id: StringName`.**

This is the single most important structural fix carried over from the archaeology. The Unity data broke in two ways that a string id prevents:

- `effectType: 17` in the research `.asset` files was a raw **enum ordinal**. Reordering the enum silently re-pointed every asset at a different effect — and in fact `Research_TradingPosts` ended up as `Custom` instead of `UnlockAutoSell` (analysis §B4).
- Cross-references were `{fileID, guid}` pairs, opaque and unreadable.

Rule, enforced everywhere: **saves and cross-references store `id` strings. Never enum ordinals, never resource paths, never array indices.**

Data lives in `data/<kind>/<id>.tres`. A `Db` autoload scans those folders at boot, indexes by `id`, and fails loudly on a duplicate or missing id — so a typo is a startup error, not a silent `null` three hours later (the Unity failure mode where 48 of 50 resources had `resourceIcon: {fileID: 0}` and nobody noticed).

## 4.3 Singletons → Autoloads, used sparingly

The Unity project had **nine** singleton managers, and the coupling that caused is visible everywhere. We use **three autoloads**, with subsystems as *child nodes* of one of them rather than as separate globals:

```
Db          (Node)  — static content registry. Read-only after boot.
                      Db.resource(id), Db.recipe(id), Db.region(id), Db.upgrade(id)

Game        (Node)  — the running game. Owns state and the signals for it.
  ├─ Economy       (Node)  gold, doubloons, sell()
  ├─ Inventory     (Node)  central resource stock
  ├─ Colonies      (Node)  active colonies, production ticking
  └─ Progression   (Node)  upgrades / research state

SaveSystem  (Node)  — serialise/deserialise Game to JSON. Nothing else touches the disk.
```

Accessed as `Game.economy.gold`, `Game.inventory.add(&"timber", 5)`. You get separation of concerns without nine globals, and the whole run state is under one node — which is exactly what makes `new_run()` (Phase 6) a one-liner.

**No `EventBus`.** Signals live on the object that owns the state (`Game.inventory.changed`). A global signal bus is tempting but becomes an untraceable dumping ground; with three autoloads you do not need one.

## 4.4 Canvas/uGUI → Control scenes

One `.tscn` per screen under `scenes/ui/`, each rooted at a `Control`. UI reads state and connects to signals; **UI never owns simulation state.** The Unity project blurred this badly — `EconomyManager` held both the colony-cost formula and the `TextMeshProUGUI` references.

Concrete replacements for what exists in `SampleScene.unity`:

| Unity | Godot |
|---|---|
| `BottomDashboard` + `DashboardController.SlidePanel` coroutine | `Control` + `create_tween().tween_property(...)` with `TRANS_CUBIC` |
| Tab panels + `SetActive(i == tabIndex)` | `TabContainer` |
| `ResourceRow_Prefab` instanced into a container | `ResourceRow.tscn` instanced into a `VBoxContainer` |
| `ResearchGrid` with rotated `Image` connection lines | Custom `Control` with `_draw()` + `draw_line()` (or `GraphEdit`) |
| `ColonyStorageUI` runtime `HorizontalLayoutGroup` construction | `GridContainer` authored in the editor |
| TMP outline via material properties | `LabelSettings.outline_size` / `outline_color`, set once in a `Theme` |

One `Theme` resource in `assets/` centralises fonts and colours — replacing the per-component styling and the `Editor/FontUpdater.cs` bulk-swap tool.

## 4.5 Save/load → **plain JSON, versioned**

### PROPOSED: JSON via `FileAccess` + `JSON.stringify` / `JSON.parse_string`. Not `ResourceSaver`.

`ResourceSaver`/`ResourceLoader` looks attractive because your data is already Resources. Reject it for save games:

- A saved `.tres` is bound to the **script path and field layout** of the class that wrote it. Rename a script, move a file, or rename a field, and old saves break — with no hook to fix them up.
- There is **no migration point**. You cannot express "if `save_version < 3`, rename this field."
- `ResourceLoader` on a file the user could edit or swap can instantiate scripts. It is the wrong tool for untrusted input.
- You cannot read it when debugging.

JSON gives you all four in exchange for writing `to_dict()` / `from_dict()` by hand — which is a genuine cost, and worth it.

```gdscript
{
  "save_version": 1,
  "meta": { ... },     # persists across prestige — see Phase 6
  "run":  { ... }      # wiped on prestige; null if no run in progress
}
```

Rules:
- `save_version` is an integer, bumped whenever the shape changes, with a migration chain (`_migrate_1_to_2(d)`, `_migrate_2_to_3(d)`, …) applied in order on load.
- **Atomic write**: write to `user://save.json.tmp`, then rename over `user://save.json`. A crash mid-write must never destroy an existing save.
- All content references are `id` strings.
- `ConfigFile` at `user://settings.cfg` for volume/language/etc. — settings only, never game state.

## 4.6 Coroutines → `await`, and when not to use it

| Unity | Godot |
|---|---|
| `yield return null` | `await get_tree().process_frame` |
| `yield return new WaitForEndOfFrame()` | `await get_tree().process_frame` |
| `yield return new WaitForSeconds(t)` | `await get_tree().create_timer(t).timeout` |
| `Invoke("F", 0.2f)` | `await get_tree().create_timer(0.2).timeout` then call |
| Repeating `Update` timer accumulator | A `Timer` node with `timeout` connected |
| Coroutine that lerps a value over time | **`create_tween()`** |

Two cautions worth internalising early, because both bite novices:

- **After an `await`, the node may have been freed.** Guard with `if not is_instance_valid(self): return`.
- Prefer `Timer` nodes and `Tween` over hand-rolled `_process` accumulators. The Unity code had three separate hand-rolled timers (`ResourceManager.autoSellTimer`, `IdleManager.timer`, `ColonyStorageUI`'s `Time.frameCount % 30`); all three become `Timer` nodes.

---

# PHASE 5 — The land/water data layer

## Design principle: the grid is data. Rendering is a separate consumer of that data.

The Unity `MapManager` fused four concerns into one 521-line class: generation, the grid itself, rendering to a `Texture2D`, and route/trail logic. That fusion is why the grid was 2,000×1,500 — it was sized to be a *picture*, and the simulation was forced to inherit the picture's resolution, costing a 3,000,000-element allocation and 30 frames of startup.

We split it into four pieces, three of which are headless:

```
scripts/map/map_grid.gd         class_name MapGrid       extends RefCounted   # DATA
scripts/map/map_loader.gd       class_name MapLoader                          # authoring → MapGrid
scripts/map/placement_rules.gd  class_name PlacementRules                     # queries over a MapGrid
scripts/map/map_view.gd         (Node2D)                                      # the only piece that draws
scripts/map/map_generator.gd    class_name MapGenerator                       # Phase 8+ / post-MVP
```

## 5.1 `MapGrid` — the data layer

```gdscript
class_name MapGrid extends RefCounted

enum Terrain { DEEP_WATER = 0, SHALLOW_WATER = 1, LAND = 2, COAST = 3 }

var width: int
var height: int
var seed: int                     # 0 for hand-authored maps
var terrain: PackedByteArray      # width*height, one Terrain per cell
var deposits: PackedByteArray     # width*height, index into `deposit_palette`; 0 = none
var deposit_palette: Array[StringName]   # e.g. [&"", &"timber", &"clay"]

func in_bounds(c: Vector2i) -> bool
func get_terrain(c: Vector2i) -> Terrain
func set_terrain(c: Vector2i, t: Terrain) -> void
func is_land(c: Vector2i) -> bool       # LAND or COAST
func is_water(c: Vector2i) -> bool      # DEEP_WATER or SHALLOW_WATER
func is_coast(c: Vector2i) -> bool
func neighbours4(c: Vector2i) -> Array[Vector2i]
func deposit_at(c: Vector2i) -> StringName
func to_dict() -> Dictionary            # PackedByteArray → base64 for JSON
static func from_dict(d: Dictionary) -> MapGrid
```

Notes on the choices:

- **`Terrain` mirrors the Unity `TileType` enum exactly** (`DeepSea, ShallowSea, Land, Coast`) — that four-way vocabulary is the one piece of the Unity map design that was clearly right, because `Coast` being distinct from `Land` is what lets a colony be ship-servable.
- **`PackedByteArray`, not `Array`.** Compact, contiguous, and serialises to base64 in one call. Directly mirrors the Unity `byte[] grid`.
- **`deposits` is a parallel layer.** This is the answer to open question #5 in the analysis ("should terrain determine what a colony produces?"). In Unity it did not — production came from a hardcoded `switch (colonyNum)` in `ColonySpawner`. Having the layer present from day one, even if the MVP only uses two deposit types, is what makes procedural maps meaningful later. **This is the one piece of forward-looking structure I think is worth building before it is strictly needed**, because retrofitting it means touching every colony and region.
- `RefCounted`, not `Resource`. It is runtime state that gets saved as JSON, not authored content. (Authored *maps* are a separate file format — see `MapLoader`.)

## 5.2 `MapLoader` — hand-authored maps, ASCII

MVP maps are hand-authored, per Phase 7. The most editable format is ASCII, stored in a small `.tres` or plain text file under `data/maps/`:

```
# data/maps/mvp_coast.txt
. . . . ~ ~ + # # #
. . . ~ ~ + # # # #
. . ~ ~ + # # # T #
. . . ~ ~ + # C # #
```
`.` deep water · `~` shallow · `+` coast · `#` land · plus deposit letters (`T` timber, `C` clay).

You can read it, diff it in git, and edit it in Notepad. `MapLoader.from_ascii(text) -> MapGrid` parses it; a matching `MapGrid.to_ascii()` makes test failures legible.

## 5.3 `PlacementRules` — pure queries, no state

```gdscript
class_name PlacementRules

enum RouteKind { LAND, SEA }

static func is_valid_colony_site(g: MapGrid, c: Vector2i) -> bool
static func coastal_sites(g: MapGrid) -> Array[Vector2i]
static func route_kind(g: MapGrid, from: Vector2i, to: Vector2i) -> RouteKind
static func route_distance(g: MapGrid, from: Vector2i, to: Vector2i) -> float
```

`route_kind` is the rule that makes the land/water layer matter to gameplay: **both endpoints coastal → SEA (fast, high capacity); otherwise LAND (slow, low capacity).** This replaces the Unity heuristic `useShip = isWaterAccess && gridDistance >= 250f`, which combined with `TransportVehicle.CanReachColony`'s hardcoded `distance < 20f` meant wagons could effectively never reach anything.

## 5.4 Can this be built and tested with zero visuals?

**Yes — confirmed, and that is the point of the split.** All three headless pieces are plain classes with no `Node`, no scene, no texture. A GUT test builds a grid from an ASCII literal and asserts against it:

```gdscript
func test_coast_is_land_adjacent_to_water() -> void:
    var g := MapLoader.from_ascii("""
        . ~ + #
        . ~ + #
    """)
    assert_true(g.is_coast(Vector2i(2, 0)))
    assert_true(g.is_land(Vector2i(2, 0)))     # coast counts as land
    assert_false(g.is_water(Vector2i(2, 0)))

func test_two_coastal_sites_route_by_sea() -> void:
    ...
    assert_eq(PlacementRules.route_kind(g, a, b), PlacementRules.RouteKind.SEA)
```

`MapGrid.to_ascii()` printed into a failure message means you can *see* the map in the test output. There is no art dependency anywhere in tasks **M1–M3**; only **M4** (`MapView`) touches rendering, and it can ship as flat coloured `ColorRect`s.

## 5.5 Grid size

**MVP: a hand-authored grid around 32×24.** Not 2,000×1,500.

Cell count should be set by how many *meaningful placement decisions* exist, not by how many pixels you want on screen. ~768 cells is plenty for a dozen regions and reads clearly as a coastline. Visual richness comes later from the renderer (tiles, decoration, shaders), not from simulation resolution. If procedural generation later wants 128×96, that is still 12,000 cells — 250× smaller than Unity's grid, and instant.

---

# PHASE 6 — Prestige / rebirth: resolved

## The evidence is not ambiguous. The original design unambiguously implied a prestige/rebirth loop.

Six independent pieces of evidence, all CONFIRMED in the analysis, from four different documents plus the code:

1. `Assets/DOCS_GAME_DESIGN.md.txt`, in the four-line core-logic summary: *"Prestige System: 'Declare Independence' resets progress for Doubloons."*
2. `PrestigeManager.DeclareIndependence()` exists and does exactly that: award Doubloons → `PerformReset()`.
3. The Doubloon reward is **permanent and global**: `GetGlobalProductionMultiplier() = 1 + 0.1 × doubloons`, and it is consumed on **every production tick** (`ColonyProduction.cs:126-129`). This is not a vestigial field; it is wired into the core loop.
4. `ResearchManager.ResetAllResearch()` exists specifically to clear the tree, and `RESEARCH_SYSTEM_SETUP.md:200-208` documents when to call it: *"When the player prestiges (Declares Independence), call `ResearchManager.Instance.ResetAllResearch()`."*
5. Doubloons were **deliberately excluded** from research costs — `RESEARCH_TREE_DESIGN.md:484`: *"No Doubloons (reserved for meta-progression system)."* Someone consciously reserved the currency for a second layer.
6. `RESEARCH_TREE_DESIGN.md`, "Meta-Progression Synergy": *"Doubloons spent on permanent account-wide upgrades (separate from research)… Research tree resets on prestige but permanent upgrades persist."*

And the corroborating negative: `ResearchManager.Start()` disables research saving with the comment *"Research progress is NOT saved between sessions until prestige system is implemented. Each playthrough starts fresh — research is temporary progression."* The author knew research was run-scoped and was waiting on prestige to define the boundary.

**Conclusion: two-layer progression was the intent. Build the two-tier save from day one.** I am not presenting this as a coin-flip, because the evidence does not support one.

## What *is* genuinely open (and does not block the save shape)

Three sub-decisions, none of which need answering before save code is written:

- **What gates Declaring Independence?** The Unity project points at **Liberty** — `NationalityData.libertyGenerationMultiplier` exists on all six nationalities with no producer, no storage, and no consumer anywhere in the codebase, and "Declare Independence" is the *Colonization* mechanic that Liberty drives. But it is 100% unbuilt. Alternatives: lifetime gold, colony count, or a capstone research node. **PROPOSED: defer. Post-MVP.**
- **What is the Doubloon payout formula?** Currently `return 10;` with the comment *"Later this can be based on lifetime gold or assets."* **PROPOSED: defer**, but have `meta.lifetime_gold_earned` accumulating from day one so whatever formula you pick has data to work with.
- **Does the map regenerate per run?** `MapManager.GenerateMap()` runs unconditionally in `Awake()` with no seed, so *de facto* yes, but nothing records the seed. **PROPOSED: store `run.map_seed` from day one** even while maps are hand-authored (seed `0` = authored map id). Costs one field now; retrofitting reproducible maps later is painful, and it unlocks daily-challenge and shareable-seed features for free.

## Save-structure consequences — both options, so you can overrule me

### Option A — per-run state only, no prestige layer

```json
{ "save_version": 1, "gold": 1200.0, "inventory": {...}, "colonies": [...] }
```

- Simplest possible thing. One flat dict.
- **Consequence:** there is no reset boundary, so nothing stops a system from parking permanent state next to run state. Every subsystem is free to read and write one global blob.
- **Cost to add prestige later:** you must audit every field in the save and classify it run vs. permanent, then find every place that assumed persistence. Recoverable, but it is exactly the kind of retrofit that produces "why did my doubloons reset" bugs.

### Option B — two-tier: permanent meta over resettable run state ✅ **RECOMMENDED**

```json
{
  "save_version": 1,
  "meta": {
    "doubloons": 0,
    "meta_upgrades": [],
    "lifetime_gold_earned": 0.0,
    "runs_completed": 0
  },
  "run": {
    "map_seed": 0,
    "map_id": "mvp_coast",
    "elapsed_seconds": 0.0,
    "gold": 100.0,
    "inventory": { "timber": 12.0 },
    "colonies": [ ... ],
    "upgrades_purchased": [ "primitive_tools" ]
  }
}
```

- Prestige becomes: `save.run = null` → `Game.new_run()`. Correct by construction, because the boundary is structural rather than remembered.
- `run: null` is also the legitimate "no run in progress" state, which you need anyway for a main menu.
- **Cost now: essentially zero.** It is two dictionaries instead of one, decided once.

**Even if you are undecided about prestige, Option B is the safe default** — it costs nothing today and removes an expensive migration later. That is why I am recommending it as an architecture decision rather than parking it behind a design decision.

**MVP does not need a working prestige button** (Phase 7 excludes it). It needs the *save shape*. Those are different, and conflating them is how MVPs bloat.

---

# PHASE 7 — MVP scope: the smallest playable vertical slice

## The goal

One complete loop the player can actually play, end to end, with every architectural seam exercised at least once — and nothing else. If a system does not appear in this list, it is not in the MVP.

## In scope

| Element | MVP content |
|---|---|
| **Map** | One hand-authored ~32×24 ASCII grid (`data/maps/mvp_coast.txt`) with a coastline and one small island. No procedural generation. |
| **Regions** | ~6 hand-authored `RegionDef` `.tres` files, each pinned to a grid cell, each tagged coastal or inland, each with a deposit. |
| **Resources** | **3** — `timber`, `clay` (raw), `lumber` (processed). |
| **Production chain** | Colonies on a timber deposit produce timber; on a clay deposit, clay. One shared cycle timer per colony. |
| **Processing step** | **1 recipe** — `2 timber → 1 lumber`. Mirrors the real `Lumber_Recipe.asset`. Manual button; auto-craft is post-MVP. |
| **Economy** | Sell any resource for gold at `base_value`. Manual sell button. |
| **Upgrade** | **1** — `primitive_tools`: +25% global production for 50 gold. Proves the multiplier chain end to end. The data structure holds many; the MVP authors one. |
| **Expansion decision** | Found a new colony at exponentially rising gold cost, choosing from 2-3 offered valid sites that differ in **deposit** and **coastal vs. inland**. |
| **Transport** | **Abstract, not animated, for MVP — but confirmed as a final-version requirement, so the `Route` API (task P3) is shaped now to make animation additive later.** A route is a *duration*: sea routes (both ends coastal) are fast/high-capacity, land routes slow/low-capacity. No vehicle sprites, no trail rendering yet. `Route` exposes `progress: float` (0-1) and `current_world_position()` (interpolated from the endpoints' region cells) even though nothing reads them today — that is the seam a future `VehicleView` node subscribes to. This mirrors the same "build the seam, not the feature" call as the two-tier save and the map's `deposits` layer (Phase 10, rule 5's stated exceptions). |
| **Hub** | The starting coastal colony. Produces straight into central inventory; all others deliver to it. Matches the confirmed Unity design. |
| **Offline progress** | On load, elapsed wall-clock → batch production tick, capped (e.g. 8h). Cheap given the cycle-catchup formula, and it is the defining feature of the genre. |
| **Save/load** | Two-tier JSON (Phase 6 Option B), versioned, atomic write, working round-trip. |
| **UI** | **One screen.** Map panel (flat coloured cells) + resource list + selected-colony panel + upgrade button + found-colony flow. |

### Why this shape

The expansion decision is the load-bearing part. Offering sites that differ in *both* deposit and coastal-vs-inland is what makes the land/water layer a gameplay system rather than decoration — and it is precisely what the Unity build never achieved, because production came from `switch (colonyNum)` and terrain only picked a spawn tile. If you can look at two sites and think *"the inland one has clay but the route is slow"*, the MVP has succeeded.

## Explicitly out of scope (Phase 8+ / polish)

Procedural map generation · map art and visual variety · **animated vehicles and wagon-trail rendering** (the `Route` seam for this is built now per above — the *view* that consumes it is not) · the 6-path/63-node research tree · nationalities · prestige button and meta-upgrade tree · Liberty · auto-sell / auto-craft / auto-collect / auto-expand · the colony-type ladder (Outpost→Provincial Capital) · the full 50-resource ladder · governors and motherland panels · audio · the retro-dither shader.

## Definition of "MVP done"

You can launch the game, watch a colony produce timber, sell it, buy the upgrade and *see production speed up*, found a second colony choosing between a coastal timber site and an inland clay site, watch clay arrive more slowly because the route is overland, craft lumber, sell it for more, quit, reopen, and find your progress intact plus the resources that accumulated while you were away.

---

# PHASE 8 — Task backlog

## How to read this

- Tasks are grouped into blocks (`F` foundation, `D` data, `G` game state, `R` resources, `P` production, `S` save/load, `U` UI, `M` map, `V` MVP loop).
- **🔴 BLOCKED — DO NOT START** means a prerequisite is unfinished. Starting these early is how you end up building systems nothing calls — the dominant failure mode of the Unity project (10 `ResearchManager` methods with zero callers; `ColonyTypeData` and `GameConfigData` entirely unwired).
- **🟢 READY** means all prerequisites are done or the task has none.

## Dependency graph

```
F1 (done) ──> F2 ──> F3 ──> F4 ──┬──> D1 ──> D2 ──> D4 ──> D5 ──┬──> R1 ──> R2 ──> P1 ──> P2 ──> P3 ──> P4
                                 │                              │                                     │
                                 │                              └──> G1 ──> G2 ──> G3 ────────────────┤
                                 │                                                                    │
                                 └──> M1 ──> M2 ──> M3 ──> M5 ───────────────────────────────────────┤
                                            (headless, no deps on D/G/R — can run in parallel)        │
                                                                                                      v
                                                                             P5 ──> S1 ──> S2 ──> S3 ──┐
                                                                                                       │
                                                       U1 ──> U2 ──┬──> U3 ──> U4 ──> U5 ──> U6 <──────┤
                                                                   └──> M4                             │
                                                                                                       v
                                                                                        V1 ──> V2 ──> V3
```

**Parallelism worth knowing:** the `M` block (land/water layer) is entirely headless and depends only on `F4`. If you want variety in your working days, `M1–M3` can be done any time after the foundation, interleaved with the `D`/`R`/`P` spine. `U1` (theme + fonts) likewise has no logic dependencies.

---

## Block F — Foundation

### F1 — Scaffold the Godot project ✅ **DONE (this session)**

**Goal:** A Godot 4.6 project that opens cleanly with a sensible folder structure and settings.
**Context:** Location `E:\Godot\Idle Pioneer\`, chosen by you. Structure and settings documented at the top of this file.
**Implementation:** Done — `project.godot`, `.gitignore`, `scenes/Main.tscn`, folder tree with `.gitkeep`s.
**Files affected:** as scaffolded.
**Acceptance criteria:** Project opens in Godot 4.6.2 with zero errors; `Main.tscn` is the main scene.
**Godot verification:** Open `D:\Godot_v4.6.2-stable_win64.exe` → import `E:\Godot\Idle Pioneer\project.godot` → editor opens, no errors in the Output panel. Press **F5** → a blank window appears at 540×960 and closes cleanly.
**Regression risks:** None.
**Definition of done:** Editor opens, F5 runs, `git init` performed and the scaffold committed.

> ⚠ **The Godot project is not yet under version control.** Do this as the very first action of the next session: `git init`, commit the scaffold. Do not accumulate work outside git.

---

### F2 — Install GUT and get one test running 🟢 **READY**

**Goal:** A working automated test harness that runs headless from the command line.
**Context:** Phase 9 splits verification into automated logic tests and manual scene checks. Everything downstream assumes tests exist, so this comes first — before any logic is written.
**Implementation:** Install GUT (AssetLib → "GUT" → download into `addons/gut/`), enable it in Project Settings → Plugins. Add `test/unit/test_smoke.gd` with a single trivially-passing assertion. Create a `run_tests.cmd` at the project root wrapping the headless invocation.
**Files affected:** `addons/gut/**`, `project.godot` (plugin enable), `test/unit/test_smoke.gd`, `run_tests.cmd`.
**Acceptance criteria:** `run_tests.cmd` exits 0 and reports 1 passing test. A deliberately broken assertion makes it exit non-zero.
**Godot verification:** GUT panel appears at the bottom of the editor; "Run All" shows 1/1 green. Then run `run_tests.cmd` from a terminal and confirm the same result headless.
**Regression risks:** GUT version must match Godot 4.6; if AssetLib offers a 3.x build, take the 9.x+ line for Godot 4.
**Definition of done:** Both editor and command-line runs pass; committed.

---

### F3 — Conventions and ID registry 🔴 **BLOCKED on F2**

**Goal:** Write down the naming/typing/id conventions once, so they are not re-litigated in every later task.
**Context:** The Unity project's worst data bug was storing an enum ordinal (`effectType: 17`) that silently re-pointed when the enum changed. Conventions are the cheap prevention.
**Implementation:** `docs/CONVENTIONS.md` in the Godot project: snake_case files, PascalCase `class_name`, `StringName` ids (`&"timber"`), always-typed declarations, signals past-tense (`resource_changed`), one class per file, `_private` prefix. Add `scripts/core/ids.gd` only if a compile-time-checked id list proves useful — otherwise rely on `Db` failing loudly.
**Files affected:** `docs/CONVENTIONS.md`.
**Acceptance criteria:** Document exists and covers naming, typing, ids, signals, file layout.
**Godot verification:** N/A (documentation).
**Regression risks:** None.
**Definition of done:** Committed; referenced from the top of `GODOT_PLAN.md`.

---

### F4 — Autoload skeleton 🔴 **BLOCKED on F3**

**Goal:** The three autoloads exist, are registered, and the game boots to a blank screen with no errors.
**Context:** Phase 4.3 — `Db`, `Game` (with `Economy`/`Inventory`/`Colonies`/`Progression` child nodes), `SaveSystem`. Skeleton only: no logic.
**Implementation:** Create `scripts/core/db.gd`, `game.gd`, `save_system.gd` and the four subsystem scripts under `scripts/sim/`. `Game._ready()` adds its four children. Register the three autoloads in Project Settings.
**Files affected:** `scripts/core/*.gd`, `scripts/sim/*.gd`, `project.godot`.
**Acceptance criteria:** `Game.economy`, `Game.inventory`, `Game.colonies`, `Game.progression` are all non-null after boot. No errors or warnings.
**Godot verification:** F5 → blank window, Output panel clean. Open the **Remote** scene tree while running and confirm `/root/Db`, `/root/Game` (with 4 children), `/root/SaveSystem`.
**Regression risks:** Autoload *order* matters — `Db` must load before `Game`. Set it explicitly.
**Definition of done:** Boots clean, remote tree verified, committed.

---

## Block D — Data layer

### D1 — `ResourceDef` 🔴 **BLOCKED on F4**

**Goal:** The Resource class that replaces Unity's `ResourceData` ScriptableObject.
**Context:** Analysis §B1. Unity fields: `resourceName`, `resourceIcon`, `category`, `baseValue`, `isTradeGood`, `description`. We add `id`.
**Implementation:** `scripts/data/resource_def.gd` — `class_name ResourceDef extends Resource`, `@export` for `id: StringName`, `display_name: String`, `icon: Texture2D`, `category: Category` (enum), `base_value: float`, `is_processed: bool`, `description: String`.
**Files affected:** `scripts/data/resource_def.gd`.
**Acceptance criteria:** Right-click in FileSystem → **New Resource** offers `ResourceDef`. A saved `.tres` round-trips its fields.
**Godot verification:** Create a throwaway `test.tres` in the editor, set fields, reopen it, confirm values persisted. Delete it afterwards.
**Regression risks:** Do not reuse Unity's `isTradeGood` naming ambiguity — `is_processed` is clearer. Keep the `Category` enum but note that **no Unity resource asset ever had a category set** (§B2), so all 50 must be re-tagged; the MVP's 3 are tagged by hand.
**Definition of done:** Class exists, editor-creatable, round-trips, committed.

---

### D2 — `RecipeDef` 🔴 **BLOCKED on D1**

**Goal:** The Resource class replacing Unity's `RecipeData`.
**Context:** Analysis §B1/§B2 — note 7 of 10 Unity recipes shipped with `inputs: []`, i.e. free money. Validation matters.
**Implementation:** `scripts/data/recipe_def.gd` — `id`, `display_name`, `inputs: Array[Dictionary]` (or a small `IngredientDef` Resource) of `{id, amount}`, `output_id: StringName`, `output_amount: int`, `craft_seconds: float`. Add a `is_valid() -> bool` that rejects empty inputs.
**Files affected:** `scripts/data/recipe_def.gd`.
**Acceptance criteria:** Editor-creatable; `is_valid()` returns false for empty inputs.
**Godot verification:** Create a test `.tres`, leave inputs empty, confirm `is_valid()` is false in a GUT test.
**Regression risks:** Exported `Array[Dictionary]` is awkward in the inspector; a nested `IngredientDef` Resource is nicer to author. Decide during the task, do not over-think it.
**Definition of done:** Class + validation + one GUT test, committed.

---

### D3 — `RegionDef` and `UpgradeDef` 🔴 **BLOCKED on D1**

**Goal:** The two remaining MVP definition types.
**Context:** `RegionDef` is the MVP's hand-authored placement unit (Phase 7). `UpgradeDef` replaces `ResearchData`, drastically simplified — one effect type for now, structured to hold more.
**Implementation:** `RegionDef`: `id`, `display_name`, `cell: Vector2i`, `deposit_id: StringName`, `base_cycle_seconds: float`, `is_coastal: bool` (derived from the grid at load, not authored twice). `UpgradeDef`: `id`, `display_name`, `description`, `gold_cost: int`, `resource_costs`, `prerequisite_ids: Array[StringName]`, `effect: Effect` (enum), `magnitude: float`.
**Files affected:** `scripts/data/region_def.gd`, `scripts/data/upgrade_def.gd`.
**Acceptance criteria:** Both editor-creatable and round-trip.
**Godot verification:** Create one `.tres` of each in the editor, confirm the inspector shows sensible controls.
**Regression risks:** **Do not store the effect as a bare int in the `.tres` and then reorder the enum** — that is exactly the `effectType: 17` bug. Prefer a `StringName` effect key, or freeze the enum order and document it.
**Definition of done:** Both classes, committed.

---

### D4 — `Db` content registry 🔴 **BLOCKED on D2, D3**

**Goal:** All `.tres` definitions load at boot and are retrievable by id, with loud failure on bad data.
**Context:** Phase 4.2. Unity had no equivalent — references were guid pairs, and 48 of 50 resources silently had a null icon.
**Implementation:** `Db._ready()` scans `res://data/resources/`, `recipes/`, `regions/`, `upgrades/` via `DirAccess`, loads each `.tres`, indexes by `id`. `push_error` + fail on: duplicate id, empty id, id not matching filename. Expose `resource(id)`, `recipe(id)`, `region(id)`, `upgrade(id)`, `all_resources()`, and a `validate() -> Array[String]` returning problems.
**Files affected:** `scripts/core/db.gd`, `test/unit/test_db.gd`.
**Acceptance criteria:** With MVP data present, `Db.resource(&"timber")` returns a `ResourceDef`. `Db.resource(&"nonexistent")` pushes an error and returns null. A deliberately duplicated id fails boot loudly.
**Godot verification:** F5 → Output shows e.g. `Db: loaded 3 resources, 1 recipe, 6 regions, 1 upgrade`. Temporarily duplicate an id, confirm a visible error, then revert.
**Regression risks:** Exported-build path handling differs from the editor — use `ResourceLoader`-friendly paths, and remember `.tres` becomes `.res` in exports if you enable that. Test an export before shipping, not before MVP.
**Definition of done:** Registry works, validation fires, tests pass, committed.

---

### D5 — Author the MVP data 🔴 **BLOCKED on D4**

**Goal:** The actual content for the vertical slice exists as `.tres` files.
**Context:** Phase 7 — 3 resources, 1 recipe, ~6 regions, 1 upgrade. Values seeded from the real Unity data where sensible (`Timber` base value 1; `2 Timber → 1 Lumber`).
**Implementation:** Author by hand in the Godot editor. `timber` (1g), `clay` (1g), `lumber` (processed, ~5g — **not** Unity's 50, which made a 25× arbitrage). `lumber_recipe`. Six regions across the MVP map, mixed coastal/inland, mixed deposits. `primitive_tools` (+25% global, 50g).
**Files affected:** `data/resources/*.tres`, `data/recipes/*.tres`, `data/regions/*.tres`, `data/upgrades/*.tres`.
**Acceptance criteria:** `Db.validate()` returns an empty problem list.
**Godot verification:** F5 → Db load counts match expectations, no errors.
**Regression risks:** Balance is a guess at this stage and *should* be — do not spend time tuning before the loop runs (task V3).
**Definition of done:** Data authored, validation clean, committed.

---

## Block G — Game state

### G1 — `RunState` 🔴 **BLOCKED on F4**

**Goal:** A plain data object holding everything that a prestige would wipe, with dictionary round-tripping.
**Context:** Phase 6 Option B. The `run` half of the save.
**Implementation:** `scripts/core/run_state.gd` — `map_id`, `map_seed`, `elapsed_seconds`, `gold`, `inventory: Dictionary` (`StringName → float`), `colonies: Array`, `upgrades_purchased: Array[StringName]`, `colonies_founded: int`. `to_dict()` / `static from_dict()`.
**Files affected:** `scripts/core/run_state.gd`, `test/unit/test_run_state.gd`.
**Acceptance criteria:** `RunState.from_dict(s.to_dict())` is field-equal to `s`.
**Godot verification:** GUT round-trip test green.
**Regression risks:** JSON has no integer type — everything comes back as `float`. Cast explicitly in `from_dict()`. This *will* bite you; handle it here, once.
**Definition of done:** Round-trip test passes, committed.

---

### G2 — `MetaState` 🔴 **BLOCKED on G1**

**Goal:** The permanent layer that survives prestige.
**Context:** Phase 6 Option B, evidence items 3, 5, 6.
**Implementation:** `scripts/core/meta_state.gd` — `doubloons: int`, `meta_upgrades: Array[StringName]`, `lifetime_gold_earned: float`, `runs_completed: int`. `to_dict()` / `from_dict()`. **`lifetime_gold_earned` accumulates from day one** even though nothing reads it yet, so the eventual prestige formula has history.
**Files affected:** `scripts/core/meta_state.gd`, `test/unit/test_meta_state.gd`.
**Acceptance criteria:** Round-trips; defaults are sane for a first launch.
**Godot verification:** GUT green.
**Regression risks:** Resist adding fields "just in case" beyond `lifetime_gold_earned` — that one has a documented purpose; speculative fields do not.
**Definition of done:** Round-trip test passes, committed.

---

### G3 — Wire state into `Game` 🔴 **BLOCKED on G2**

**Goal:** `Game` owns a `MetaState` and an optional `RunState`, and can start a fresh run.
**Context:** Phase 4.3 + Phase 6. `new_run()` is the future prestige reset, exercised now for "New Game".
**Implementation:** `Game.meta`, `Game.run` (nullable), `Game.new_run(map_id)`, `Game.has_run() -> bool`. Signals: `run_started`, `run_ended`.
**Files affected:** `scripts/core/game.gd`, `test/unit/test_game.gd`.
**Acceptance criteria:** `new_run()` twice produces independent state; `meta` is untouched across both.
**Godot verification:** F5, then in the editor's Debugger → Evaluate, inspect `Game.run` before and after.
**Regression risks:** Subsystem nodes must *read* `Game.run`, never cache a copy of it — a cached reference survives `new_run()` and becomes the classic "prestige didn't reset X" bug.
**Definition of done:** Test proves meta survives two runs, committed.

---

## Block R — Resource system

### R1 — `Inventory` 🔴 **BLOCKED on G3, D4**

**Goal:** Central resource stock with add/remove/query and a change signal.
**Context:** Replaces `ResourceManager`'s inventory half. Unity used `double`; GDScript `float` is already 64-bit, so precision carries over for free.
**Implementation:** `scripts/sim/inventory.gd` — `add(id, amount)`, `try_remove(id, amount) -> bool`, `get_amount(id) -> float`, `has(id, amount) -> bool`, `all() -> Dictionary`. Signal `changed(id: StringName, total: float, delta: float)`. Reads/writes `Game.run.inventory`.
**Files affected:** `scripts/sim/inventory.gd`, `test/unit/test_inventory.gd`.
**Acceptance criteria:** Add/remove arithmetic correct; `try_remove` returns false and mutates nothing when short; signal fires with correct delta; unknown id is a loud error, not a silent zero.
**Godot verification:** GUT green (aim ~8 assertions).
**Regression risks:** Do not let float drift produce `-0.0000001` stock. Clamp at zero on removal.
**Definition of done:** Tests green, committed.

---

### R2 — `Economy` 🔴 **BLOCKED on R1**

**Goal:** Gold, plus selling resources for gold at `base_value` through a multiplier hook.
**Context:** Replaces `ResourceManager`'s currency half plus `EconomyManager`'s cost curve. Note the Unity build shipped with `gold = 100 // TEST … REVERT TO 0 FOR RELEASE` — start at 0 and add a debug toggle instead.
**Implementation:** `scripts/sim/economy.gd` — `gold` (via `Game.run`), `add_gold`, `try_spend(amount) -> bool`, `sell(id, amount)`, `sell_value(id, amount) -> float` applying the progression multiplier, `next_colony_cost() -> float` = `base × mult^founded`. Signal `gold_changed(total)`. Increments `Game.meta.lifetime_gold_earned`.
**Files affected:** `scripts/sim/economy.gd`, `test/unit/test_economy.gd`.
**Acceptance criteria:** Selling removes stock and adds the right gold; `try_spend` is atomic; cost curve matches `100 × 2.5^n`; `lifetime_gold_earned` accumulates.
**Godot verification:** GUT green.
**Regression risks:** `sell()` must go through `Inventory.try_remove` — never mutate the dictionary directly, or the `changed` signal is skipped and the UI silently desyncs.
**Definition of done:** Tests green, committed.

---

## Block P — Production

### P1 — `ProductionCycle` 🔴 **BLOCKED on F2** *(logic only — no other deps)*

**Goal:** The pure timer/accumulator that converts elapsed time into completed cycles, including large catch-up batches.
**Context:** This is the single most valuable algorithm salvaged from Unity (`ColonyProduction.TickProduction`, analysis §A2): accumulate, `floor(t / cycle)`, `t %= cycle`. It must be correct for both a 16ms frame and an 8-hour offline batch.
**Implementation:** `scripts/sim/production_cycle.gd` — `class_name ProductionCycle extends RefCounted`, with `cycle_seconds`, `accumulated`, and `advance(delta: float) -> int` returning completed cycles.
**Files affected:** `scripts/sim/production_cycle.gd`, `test/unit/test_production_cycle.gd`.
**Acceptance criteria:** 0.5s at 1s cycle → 0 cycles, 0.5 retained. 2.5s → 2 cycles, 0.5 retained. 28800s at 1s → 28800 cycles in one call, no loop, no hang. Zero/negative delta is safe. Cycle time changing mid-flight does not corrupt the accumulator.
**Godot verification:** GUT green; specifically confirm the 8-hour test completes in milliseconds (the Unity build *disabled offline progress entirely* because this calculation froze — see analysis §E3).
**Regression risks:** The catch-up must be arithmetic, never a `while` loop. That is exactly the Unity freeze.
**Definition of done:** Tests green including the 8-hour case, committed.

---

### P2 — `Colony` runtime object 🔴 **BLOCKED on P1, R1, D5**

**Goal:** A colony that sits on a region, produces its deposit resource on a cycle, and holds local stock.
**Context:** Replaces `ColonyProduction`. The Hub (`is_hub`) deposits straight to central inventory; others accumulate locally awaiting a route.
**Implementation:** `scripts/sim/colony.gd` — `region_id`, `is_hub`, `local_stock: Dictionary`, a `ProductionCycle`, `tick(delta)`, `collect() -> Dictionary`. Production amount = `cycles × Progression.production_multiplier()`.
**Files affected:** `scripts/sim/colony.gd`, `test/unit/test_colony.gd`.
**Acceptance criteria:** Hub production lands in central inventory; non-hub lands in `local_stock`; `collect()` empties and returns it.
**Godot verification:** GUT green.
**Regression risks:** Unity gave **every** resource in `producedResources` the *same* full amount, so a 3-resource colony produced 3× throughput free (analysis §4). MVP colonies produce **one** resource; if that ever changes, divide or cost it explicitly.
**Definition of done:** Tests green, committed.

---

### P3 — `Route` (abstract transport) 🔴 **BLOCKED on P2, M3**

**Goal:** Deliver a colony's local stock to the Hub after a duration determined by land vs. sea — with a `progress`/position seam a future animated-vehicle view can subscribe to without changing this class.
**Context:** Phase 7 — duration only, no sprites, for MVP. **Animated travel is a confirmed final-version requirement (your answer to Q3)**, so this task builds the seam now rather than bolting it on later: exposing continuous progress and interpolated position costs nothing extra to compute (the duration math already tracks elapsed/total), but retrofitting it after `TransportManager`-equivalent code exists elsewhere would mean touching every caller. This is where the land/water layer earns its keep.
**Implementation:** `scripts/sim/route.gd` — built from `PlacementRules.route_kind()` + `route_distance()`; sea = faster and higher capacity, land = slower and lower. A cycle: wait → collect (highest `base_value` first, up to capacity — the salvaged Unity sort) → travel → deposit to Hub. Expose `progress: float` (0-1 through the current leg) and `current_world_position() -> Vector2` (linear interpolation between the two endpoint cells' world positions — no path-following yet, that's Phase 8+). Signal `delivered(cargo)`. **Do not add a sprite, a `Node2D`, or anything visual in this task** — `progress`/`current_world_position()` are plain data other code can read; a `VehicleView` that draws them is a separate, later task, deliberately not scheduled here.
**Files affected:** `scripts/sim/route.gd`, `test/unit/test_route.gd`.
**Acceptance criteria:** A sea route delivers strictly sooner than a land route of the same distance; capacity caps a load; cargo prefers higher-value resources; `progress` climbs monotonically from 0 to 1 across a leg and resets on the next; `current_world_position()` lies on the straight line between endpoints at the expected fraction.
**Godot verification:** GUT green.
**Regression risks:** Unity's `CanReachColony` hardcoded `distance < 20f` in a space where distances were in the hundreds, so wagons could reach nothing. **Assert on real MVP map distances**, not invented ones. Resist the urge to build the visual layer here just because the seam is tempting — that scope belongs to a Phase 8+ `VehicleView` task.
**Definition of done:** Tests green including the progress/position assertions, committed.

---

### P4 — `Crafting` 🔴 **BLOCKED on P2, D5**

**Goal:** Execute a `RecipeDef`: consume inputs, produce output.
**Context:** Replaces `RecipeData.CanCraft`/`Craft`, with the Unity mistake fixed — an empty-input recipe must be impossible, not free money.
**Implementation:** `scripts/sim/crafting.gd` — `can_craft(recipe_id) -> bool` (rejects invalid recipes), `craft(recipe_id) -> bool` (atomic: verify all, then consume, then produce).
**Files affected:** `scripts/sim/crafting.gd`, `test/unit/test_crafting.gd`.
**Acceptance criteria:** `2 timber → 1 lumber` works; fails cleanly at 1 timber; **an empty-input recipe is rejected**; a partial failure consumes nothing.
**Godot verification:** GUT green.
**Regression risks:** Atomicity — verify everything before consuming anything.
**Definition of done:** Tests green including the empty-input guard, committed.

---

### P5 — `Progression` (upgrades) 🔴 **BLOCKED on P2, R2, D5**

**Goal:** Purchase upgrades and have their effects actually multiply production.
**Context:** **This task carries the most important lesson from the archaeology.** Unity wrote `GetProductionMultiplier`, `GetColonyCostMultiplier`, `GetCraftingTimeMultiplier`, `GetMaxCraftingSlots` and six more — and **none of them had a single caller** (analysis §E3). Four of eighteen effect types did anything. A multiplier that nothing reads is not a feature.
**Implementation:** `scripts/sim/progression.gd` — `can_purchase(id)`, `purchase(id)`, `is_purchased(id)`, `production_multiplier() -> float` (multiplicative stacking, per analysis §4). Signal `upgrade_purchased(id)`.
**Files affected:** `scripts/sim/progression.gd`, `test/unit/test_progression.gd`.
**Acceptance criteria:** Purchasing `primitive_tools` deducts 50 gold and makes `production_multiplier()` return 1.25; stacking two upgrades multiplies (1.25 × 1.2 = 1.5); double-purchase is rejected.
**Godot verification:** GUT green **plus** a manual check: a test asserting that `Colony.tick()` output actually increases after purchase. That assertion is the guard against repeating the Unity mistake.
**Regression risks:** The whole point. **Do not close this task until a test proves a colony's output changes.**
**Definition of done:** Multiplier applied *and demonstrated to affect production*, committed.

---

## Block S — Save / load

### S1 — JSON save/load 🔴 **BLOCKED on G3, P5**

**Goal:** Two-tier versioned save written atomically to `user://save.json`, restoring a session exactly.
**Context:** Phase 4.5 + Phase 6 Option B. There is nothing to inherit from Unity — it had three `PlayerPrefs` keys, two disabled.
**Implementation:** `scripts/core/save_system.gd` — `save()`, `load() -> bool`, `has_save()`, `delete_save()`. Write `.tmp` then rename. `{save_version, meta, run}`.
**Files affected:** `scripts/core/save_system.gd`, `test/unit/test_save_system.gd`.
**Acceptance criteria:** Save then load reproduces gold, inventory, colonies, upgrades exactly. Missing file → clean first-launch. Corrupt JSON → error and clean state, never a crash.
**Godot verification:** F5, accumulate resources, quit, relaunch, confirm state restored. Open `user://save.json` (Project → Open User Data Folder) and **read it** — it should be legible. Then corrupt it by hand and confirm graceful recovery.
**Regression risks:** JSON returns all numbers as float (see G1). `Vector2i` is not JSON-native — store as `[x, y]`. `PackedByteArray` needs base64.
**Definition of done:** Round-trip test + manual quit/relaunch verified + corruption handled, committed.

---

### S2 — Migration chain 🔴 **BLOCKED on S1**

**Goal:** Prove the version-migration mechanism works before you need it.
**Context:** The entire justification for JSON over `ResourceSaver` (Phase 4.5). An untested migration path is not a migration path.
**Implementation:** In `SaveSystem`, dispatch on `save_version` through ordered `_migrate_N_to_N1(d) -> Dictionary` functions. Add a real v1→v2 (e.g. rename a field) to exercise it end to end.
**Files affected:** `scripts/core/save_system.gd`, `test/unit/test_save_migration.gd`.
**Acceptance criteria:** A hand-written v1 JSON fixture loads correctly under v2. A future/unknown version refuses to load with a clear message rather than corrupting.
**Godot verification:** GUT green; fixture files under `test/helpers/`.
**Regression risks:** Migrations must be pure dictionary transforms — never call live game code, which changes underneath them.
**Definition of done:** Fixture-based migration test passes, committed.

---

### S3 — Offline progress 🔴 **BLOCKED on S1, P1**

**Goal:** Time passed while the game was closed converts into production on load.
**Context:** Genre-defining, and Unity **disabled it** because the calculation froze (§E3). P1's arithmetic catch-up is what makes it safe here.
**Implementation:** Store `last_saved_unix` in `meta`. On load, `elapsed = clamp(now - last_saved, 0, MAX_OFFLINE)`, then one batched tick. Cap at 8h initially. Return a summary for a "while you were away" panel (UI later).
**Files affected:** `scripts/core/save_system.gd`, `scripts/sim/colonies.gd`, `test/unit/test_offline.gd`.
**Acceptance criteria:** 8h offline yields exactly the same total as 8h of real ticking (within float tolerance) and completes in milliseconds. Clock moving backwards yields zero, never negative.
**Godot verification:** GUT green. Manual: save, edit `last_saved_unix` back by 3600 in the JSON, relaunch, confirm a plausible bulk gain.
**Regression risks:** **Test the clock-skew case.** Players change device clocks; a negative elapsed must not mint resources.
**Definition of done:** Tests green including skew, manual check done, committed.

---

## Block M — Land/water layer *(headless; only needs F4)*

### M1 — `MapGrid` 🟢 **READY after F4** *(can run in parallel with D/G/R)*

**Goal:** The grid data structure with terrain + deposit layers and accessors, fully headless.
**Context:** Phase 5.1.
**Implementation:** `scripts/map/map_grid.gd` per the Phase 5.1 sketch, backed by `PackedByteArray`, with `to_dict`/`from_dict` (base64) and `to_ascii()` for debugging.
**Files affected:** `scripts/map/map_grid.gd`, `test/unit/test_map_grid.gd`.
**Acceptance criteria:** Bounds checks safe on all four edges; `is_land` true for both `LAND` and `COAST`; round-trip preserves both layers.
**Godot verification:** GUT green. Print `to_ascii()` in the test output and eyeball it.
**Regression risks:** Index arithmetic `y * width + x` — test the corners explicitly. Out-of-bounds must return `DEEP_WATER`, never crash (matching the Unity behaviour, which was correct).
**Definition of done:** Tests green, ASCII dump legible, committed.

---

### M2 — ASCII map authoring + loader 🔴 **BLOCKED on M1**

**Goal:** Author maps as readable text and load them into a `MapGrid`.
**Context:** Phase 5.2 — MVP maps are hand-authored (Phase 7).
**Implementation:** `scripts/map/map_loader.gd` — `from_ascii(text) -> MapGrid`, `from_file(path)`. Legend: `.` deep, `~` shallow, `+` coast, `#` land, letters = deposits on land.
**Files affected:** `scripts/map/map_loader.gd`, `data/maps/mvp_coast.txt`, `test/unit/test_map_loader.gd`.
**Acceptance criteria:** `from_ascii(g.to_ascii())` reproduces `g`. Ragged rows or unknown characters produce a clear error, not a silent bad map.
**Godot verification:** GUT green; open `data/maps/mvp_coast.txt` and confirm it looks like a coastline.
**Regression risks:** Whitespace/indentation in multiline literals — strip consistently and test it.
**Definition of done:** Round-trip test green, MVP map authored, committed.

---

### M3 — `PlacementRules` 🔴 **BLOCKED on M2**

**Goal:** The queries that make terrain affect gameplay.
**Context:** Phase 5.3.
**Implementation:** `scripts/map/placement_rules.gd` — `is_valid_colony_site`, `coastal_sites`, `route_kind`, `route_distance`. Static functions, no state.
**Files affected:** `scripts/map/placement_rules.gd`, `test/unit/test_placement_rules.gd`.
**Acceptance criteria:** Water cells are never valid sites; both-ends-coastal → `SEA`; any inland end → `LAND`; distances are symmetric.
**Godot verification:** GUT green against the real `mvp_coast` map, not just toy grids.
**Regression risks:** See P3 — Unity's thresholds were calibrated against the wrong coordinate space. Assert using real map distances.
**Definition of done:** Tests green against the MVP map, committed.

---

### M4 — `MapView` rendering 🔴 **BLOCKED on M3, U2**

**Goal:** Draw a `MapGrid` on screen, placeholder-quality.
**Context:** The *only* piece of the map system that touches rendering — the whole reason for the Phase 5 split.
**Implementation:** `scenes/world/MapView.tscn` + `scripts/map/map_view.gd`, a `Control` using `_draw()` with `draw_rect()` per cell, colours mirroring Unity's (land `35,115,35`; coast `205,185,115`; shallow `50,100,160`; deep `15,30,80`). Emits `cell_clicked(cell)`.
**Files affected:** `scenes/world/MapView.tscn`, `scripts/map/map_view.gd`.
**Acceptance criteria:** Grid renders recognisably; clicking a cell reports the right coordinate.
**Godot verification:** F5 → the map is visible and looks like a coastline. Click cells around the edges and corners and confirm the reported coordinates are right.
**Regression risks:** Do **not** rebuild the Unity approach of rasterising the grid into one big `Image`. At 32×24, per-cell `draw_rect` is trivially fast and far easier to debug. Revisit only if the grid grows by orders of magnitude.
**Definition of done:** Map visible, clicks map to correct cells, committed.

---

### M5 — Bind regions to grid cells 🔴 **BLOCKED on M3, D5**

**Goal:** Validate that every `RegionDef` sits on a legal cell and derive `is_coastal` from the grid.
**Context:** Prevents authored data drifting out of sync with the map — the class of bug that produced Unity's mis-tagged `Vehicle_Ship` (`transportType: Wagon`).
**Implementation:** Extend `Db.validate()` to check each `RegionDef.cell` is in bounds and `is_valid_colony_site`. Derive `is_coastal` at load rather than authoring it twice.
**Files affected:** `scripts/core/db.gd`, `test/unit/test_region_binding.gd`.
**Acceptance criteria:** A region placed on water fails validation with a clear message naming the region and cell.
**Godot verification:** Temporarily move a region onto water, F5, confirm a loud error, revert.
**Regression risks:** None — this task exists to *create* a guard rail.
**Definition of done:** Validation catches bad placement, committed.

---

## Block U — UI

### U1 — Theme and fonts 🟢 **READY after F4** *(no logic deps)*

**Goal:** One `Theme` resource with the ported fonts and a consistent parchment/wood palette.
**Context:** Phase 4.4. Reuse `Almendra-Regular.ttf` and `ManufacturingConsent-Regular.ttf` from the Unity project (analysis §D2) — they import directly. Discard the TMP `*SDF.asset` atlases.
**Implementation:** Copy the two `.ttf` files into `assets/fonts/`. Build `assets/ui_theme.tres` with default font, sizes, and `StyleBox`es for `Button` normal/hover/pressed/disabled — which is also what replaces the Unity `SellButton_Controller.controller` Animator.
**Files affected:** `assets/fonts/*.ttf`, `assets/ui_theme.tres`.
**Acceptance criteria:** A test `Button` and `Label` pick up the theme with no per-node styling.
**Godot verification:** Drop a Button and Label into a scratch scene, assign the theme, confirm the look. Delete the scratch scene.
**Regression risks:** Check the fonts' licences before shipping — Almendra and Manufacturing Consent are open-licence Google Fonts, but confirm and record it.
**Definition of done:** Theme applied and legible, committed.

---

### U2 — Main screen skeleton 🔴 **BLOCKED on U1, F4**

**Goal:** The single MVP screen's layout, with placeholder content and no logic.
**Context:** Phase 7 — one screen. Layout only, so later tasks fill panels rather than restructuring.
**Implementation:** `scenes/ui/MainScreen.tscn` — root `Control`, `VBoxContainer`: top bar (gold), centre (map area), bottom (`TabContainer`: Resources / Colony / Upgrades). Placeholder labels. Set as a child of `Main.tscn`.
**Files affected:** `scenes/ui/MainScreen.tscn`, `scenes/Main.tscn`.
**Acceptance criteria:** Layout holds at 720×1280 and at a resized window; nothing overlaps or clips.
**Godot verification:** F5, resize the window from tiny to large, confirm the layout adapts. Check the tabs switch.
**Regression risks:** Anchors/containers are the #1 novice pain point — use containers, not manual anchoring, and let them do the work.
**Definition of done:** Layout stable at multiple sizes, committed.

---

### U3 — Resource list panel 🔴 **BLOCKED on U2, R2**

**Goal:** Live resource list with sell buttons, driven by signals.
**Context:** Replaces `ResourceTabManager` + `ResourceRowView`.
**Implementation:** `scenes/ui/ResourceRow.tscn` (icon, name, amount, Sell). `scenes/ui/ResourcePanel.tscn` instances rows into a `VBoxContainer`, connects `Inventory.changed`, creates a row on first sight of a resource.
**Files affected:** `scenes/ui/ResourceRow.tscn`, `scenes/ui/ResourcePanel.tscn`, `scripts/ui/*.gd`.
**Acceptance criteria:** Amounts update live; Sell removes stock and adds gold; rows appear as resources are first acquired.
**Godot verification:** F5, wait for production, watch the number climb, press Sell, watch gold rise and stock fall.
**Regression risks:** Do not poll in `_process` — connect the signal. (Unity's `ColonyStorageUI` polled on `Time.frameCount % 30`; that is the pattern being retired.)
**Definition of done:** Live updates + sell verified in-game, committed.

---

### U4 — Colony panel 🔴 **BLOCKED on U3, P3**

**Goal:** Inspect a colony: what it produces, its local stock, its route status.
**Context:** Replaces `ColonyStorageUI` (530 lines of runtime layout construction) with an editor-authored scene.
**Implementation:** `scenes/ui/ColonyPanel.tscn` — name, region, produced resource, cycle progress (`ProgressBar`), local stock, route kind + ETA. Populated on `MapView.cell_clicked`.
**Files affected:** `scenes/ui/ColonyPanel.tscn`, `scripts/ui/colony_panel.gd`.
**Acceptance criteria:** Clicking a colony shows its data; the progress bar advances; route kind reads LAND or SEA correctly.
**Godot verification:** F5, click both a coastal and an inland colony, confirm the route kinds differ.
**Regression risks:** No runtime layout construction — build it in the editor.
**Definition of done:** Both colony kinds inspect correctly, committed.

---

### U5 — Upgrade panel 🔴 **BLOCKED on U3, P5**

**Goal:** Show the upgrade, its cost, and let it be bought.
**Context:** One upgrade in the MVP (Phase 7); the panel is a list so more can be added without rework.
**Implementation:** `scenes/ui/UpgradeRow.tscn` + `UpgradePanel.tscn`. Button disabled when unaffordable or already owned; connects `Economy.gold_changed` and `Progression.upgrade_purchased`.
**Files affected:** `scenes/ui/Upgrade*.tscn`, `scripts/ui/upgrade_panel.gd`.
**Acceptance criteria:** Button enables exactly at 50 gold; purchase deducts and marks owned; **production visibly speeds up**.
**Godot verification:** F5, note the production rate, buy the upgrade, confirm the rate rises. This is the in-game proof for P5.
**Regression risks:** The Unity failure exactly — a purchasable upgrade with no observable effect. Verify by watching, not by reading code.
**Definition of done:** Purchase changes observable production, committed.

---

### U6 — Found-colony flow 🔴 **BLOCKED on U4, U5, M5**

**Goal:** The expansion decision — pick from offered sites that meaningfully differ.
**Context:** The load-bearing decision of the MVP (Phase 7).
**Implementation:** A "Found Colony" button showing `Economy.next_colony_cost()`. On click, offer 2-3 unoccupied valid regions showing deposit, cycle time, and route kind. Selecting one spends gold and creates the colony + route.
**Files affected:** `scenes/ui/FoundColonyDialog.tscn`, `scripts/ui/found_colony_dialog.gd`.
**Acceptance criteria:** Button disabled when unaffordable; offered sites are always valid and unoccupied; the choice is visible on the map afterwards; cost rises for the next one.
**Godot verification:** F5, earn gold, found a colony, pick the inland clay site, confirm it appears, produces clay, and delivers more slowly than the coastal one.
**Regression risks:** Offering an already-occupied or invalid site. Assert against `Db.validate()`'s rules.
**Definition of done:** Full expansion decision playable, committed.

---

## Block V — MVP loop

### V1 — Boot to playable 🔴 **BLOCKED on U6, S1**

**Goal:** Launch → load-or-new-run → Hub placed → production running → UI live.
**Context:** First moment the whole thing is a game.
**Implementation:** `Main.tscn` boot sequence: `Db` loads → `SaveSystem.load()` or `Game.new_run("mvp_coast")` → place Hub on a coastal site → show `MainScreen`.
**Files affected:** `scenes/Main.tscn`, `scripts/core/game.gd`.
**Acceptance criteria:** Cold launch produces a playable state in under a second, no errors.
**Godot verification:** Delete `user://save.json`, F5, confirm a clean new game. F5 again, confirm it resumes.
**Regression risks:** Autoload ordering and `_ready()` ordering (children before parents). Do the boot sequence explicitly, not implicitly.
**Definition of done:** Both cold and warm boot verified, committed.

---

### V2 — Full loop end to end 🔴 **BLOCKED on V1**

**Goal:** Every MVP element connected: produce → deliver → sell → upgrade → expand → craft → sell.
**Context:** Phase 7's "definition of done".
**Implementation:** Integration wiring and gap-filling only. No new systems.
**Files affected:** wiring across `scripts/` and `scenes/ui/`.
**Acceptance criteria:** The full Phase 7 walkthrough completes without a restart or an error.
**Godot verification:** Play the entire Phase 7 "MVP done" paragraph start to finish, then quit and relaunch and confirm the state survived.
**Regression risks:** This is where signal-wiring gaps surface. Watch the Output panel throughout.
**Definition of done:** Full walkthrough completes clean, committed and tagged `mvp-loop`.

---

### V3 — Balance and feel pass 🔴 **BLOCKED on V2**

**Goal:** Make the first ten minutes feel deliberate rather than arbitrary.
**Context:** Deliberately last. Balancing before the loop runs is wasted work — and Unity's placeholder numbers (every trade good at 50, `2 timber → 1 lumber` at a 25× markup) show what happens when values are set in isolation.
**Implementation:** Tune cycle times, base values, upgrade cost/magnitude, colony cost curve, route speeds. Record the reasoning per number.
**Files affected:** `data/**/*.tres`.
**Acceptance criteria:** First colony within ~30s; the upgrade is a real decision, not automatic; the second colony lands around 3-5 minutes; crafting lumber beats selling raw timber but not absurdly.
**Godot verification:** Play ten minutes without touching code. Note where it drags.
**Regression risks:** Data-only changes should not need code edits. If one does, that number was hardcoded and belongs in a `.tres` — fix that instead.
**Definition of done:** Ten-minute session feels intentional; numbers documented; committed.

---

# PHASE 9 — Testing strategy

## Recommendation: **GUT (Godot Unit Test)** for logic, manual in-editor checks for scenes

**Why GUT over GdUnit4:** both are good and both support Godot 4. GUT is simpler, GDScript-native (aligning with Phase 3), has a straightforward editor panel and a one-line headless CLI, and has the larger body of community examples. GdUnit4 is more featureful (scene runners, fuzzing, richer assertions) but is more to learn. For a solo novice project, **GUT's smaller surface is the feature.** Revisit only if you find yourself wanting scene-level integration testing badly enough to pay the learning cost.

```
"D:\Godot_v4.6.2-stable_win64.exe" --headless --path "E:\Godot\Idle Pioneer" ^
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

Wrapped in `run_tests.cmd` (task F2) so it is one command.

## The split — mirroring the Unity plan

### Automated (GUT) — anything that is arithmetic or data transformation

| Area | Tasks | Why automated |
|---|---|---|
| Inventory arithmetic | R1 | Off-by-one and float drift are invisible by eye |
| Economy: sell value, cost curve | R2 | `100 × 2.5^n` must be exact |
| **Production cycle catch-up** | P1 | **Highest-value test in the suite** — this is what Unity got wrong badly enough to disable offline progress |
| Crafting atomicity | P4 | Partial consumption is a silent save-corrupter |
| Upgrade multiplier stacking | P5 | Multiplicative vs additive is easy to get wrong and hard to see |
| Save round-trip + migration | S1, S2 | Regressions here destroy player data |
| Offline progress + clock skew | S3 | You cannot manually test an 8-hour absence |
| MapGrid indexing, bounds | M1 | Corner cases are exactly where `y*w+x` breaks |
| Placement rules, route kind | M3 | Terrain logic is pure and cheap to assert |

**Target: every task in blocks R, P, S, and M ships with tests. That is the contract.**

### Manual in-editor — anything visual, spatial, or about feel

| Area | How |
|---|---|
| Scene layout | F5, resize small→large, check no clipping or overlap |
| Signal wiring | Watch values update live; keep the Output panel visible |
| Map rendering | Eyeball the coastline; click edges and corners |
| UI state | Buttons enable/disable at the right thresholds |
| **Upgrade effect** | Watch production speed change after purchase (U5) |
| Save/load | Actually quit and relaunch — not just call `load()` |
| Feel | Play ten minutes (V3) |

**Do not write automated tests for `Control` layout.** Brittle, low value, and a classic novice time sink.

## Working discipline

1. **Bug in logic → failing test first, then the fix.** The test is the proof it is fixed and stays fixed.
2. **Bug in a scene → written checklist entry**, re-run on every touch of that scene.
3. **Run `run_tests.cmd` before every commit.** It takes seconds.
4. `MapGrid.to_ascii()` in failure output — seeing the map beats reading coordinates.
5. **Never mark a task done on a green test alone.** Every task above has a "Godot verification" line for exactly this reason: the Unity project compiled perfectly and shipped ten methods nobody called.

---

# PHASE 10 — Ground rules for implementation sessions

Carried forward, plus the lessons the archaeology paid for.

### The rules

1. **Never blindly rewrite. Explain why first.** If I propose replacing something that works, I state what is wrong with it and what changes for you. If the reason is "I'd have written it differently", that is not a reason.

2. **The project stays playable at every milestone.** After each task, the game still runs. No multi-task stretches where nothing works. If a change must break things temporarily, it is scoped to one task and fixed inside it.

3. **Fix foundations before symptoms.** If a UI bug traces to a bad data model, the data model gets fixed. The Unity project is full of symptom fixes — `GetMainlandCoast`'s 5,000-attempt rejection loop with the comment *"CRITICAL FIX"* is a workaround for map generation that put islands where the mainland should be.

4. **Data-driven over hardcoded near-duplicates.** New content = a new `.tres`, not a new `if`. Concrete anti-pattern to avoid: `ColonySpawner.GetResourcesForColony(int num)`, a hardcoded `switch` for colonies 1-4 with a `default` fallback.

5. **Do not over-engineer. This is a solo indie project.** No abstract factories, no dependency-injection container, no event bus, no ECS. Three autoloads. Plain classes. If a pattern needs a diagram to explain, it is probably wrong here. **Exception, stated deliberately:** the two-tier save (Phase 6), the `deposits` map layer (Phase 5), and `Route`'s `progress`/`current_world_position()` seam (Phase 7 — animated travel is a confirmed final-version requirement) are built before they are strictly needed, because retrofitting any of the three is expensive and all three are cheap now. Those are the only three.

6. **Preserve and reuse portable assets.** From the Unity project: 25 PNG/JPG images and 2 TTF fonts import directly. **There is no audio at all** — the Unity `AudioClip` slots were never filled. TMP SDF atlases, `.mat` materials, the Animator controller, and `RetroDither.shader` (CG) do not transfer; the shader's *intent* is re-expressible in Godot shading language later.

7. **Verify by running the scene, not by compiling.** Every task has a "Godot verification" step. A green test suite and a clean parse are necessary, not sufficient.

### Added from the archaeology

8. **No system ships without a caller and a visible effect.** This is the single most valuable lesson from the Unity project, where `ResearchManager` had ten public methods with zero callers, `ColonyTypeData` was fully authored and entirely unwired, and `GameConfigData` was written as "replaces hardcoded magic numbers" while having no instance and no references. **Definition of done includes: something calls this, and you can see it in the game.**

9. **Ids are strings. Always.** Never persist enum ordinals, resource paths, or array indices. `effectType: 17` silently meaning `Custom` instead of `UnlockAutoSell` is the bug this rule prevents.

10. **No `// TEST:` values in committed code.** The Unity build shipped `gold = 100; // TEST … REVERT TO 0 FOR RELEASE`. Debug conveniences go behind an explicit debug flag, not a comment.

11. **If a feature gets disabled to work around a performance problem, fix the algorithm.** Offline progress was switched off with *"TODO: Optimize bulk production calculation before enabling"* and never came back. A disabled feature is a deleted feature.

12. **One task at a time, committed when done.** Each task in Phase 8 is independently testable on purpose. Do not batch.

---

# Recommended first 5 tasks

Ordered so that each ends with something demonstrable, and so the test harness exists before the first line of logic.

| # | Task | Why this, why now |
|---|---|---|
| **1** | **F2 — Install GUT, one passing test, `run_tests.cmd`** | The harness must exist before any logic, or tests become "later" and then never. Ends with a green run from both the editor and the command line. Also: **`git init` and commit the scaffold first** — it is not yet under version control. |
| **2** | **F3 — Conventions doc** | Twenty minutes that prevent weeks of inconsistency. Locks in `StringName` ids and always-typed declarations *before* there is code to retrofit. |
| **3** | **F4 — Autoload skeleton** | `Db` / `Game` (+4 subsystems) / `SaveSystem` registered and booting clean. Every later task attaches to this. Verified by inspecting the live remote scene tree. |
| **4** | **D1 + D4 — `ResourceDef` and the `Db` registry** | The first real architecture decision made concrete: ScriptableObject → Resource, with the string-id discipline and loud validation that Unity lacked. Ends with `Db: loaded N resources` in the Output panel. |
| **5** | **M1 — `MapGrid` (headless)** | Phase 5's central claim — that the land/water layer is testable with zero visuals — proven immediately rather than assumed. It is dependency-free, it is the most interesting part of the design, and it ends with an ASCII coastline printed in the test output. |

After these five you will have: version control, a working test harness, a booting project with its architecture skeleton in place, the data pattern established end to end, and the land/water layer proven headless. That is the foundation the entire Phase 8 backlog stands on — and the point from which `R1` (Inventory) starts the game systems proper.

---

## Decisions — locked

| # | Question | Decision | Consequence recorded at |
|---|---|---|---|
| 1 | Language | **GDScript-only**, re-derived (not just carried forward) against "best product + best for continued development, Claude coding" — mobile export risk and the confirmed animated-travel system both reinforced the conclusion | Phase 3 |
| 2 | Prestige save shape | **Two-tier (Option B)**, from day one | Phase 6 |
| 3 | MVP transport | **Abstract duration for MVP; animated travel confirmed for final version** — `Route` (task P3) now exposes a `progress`/position seam so the future visual layer is additive, not a rewrite | Phase 7, task P3 |
| 4 | Screen shape | **Portrait, standard mobile UI** — 720×1280 setting in `project.godot` confirmed correct as scaffolded | Phase 3 setup notes |
| 5 | Where to start | **Recommended first 5 tasks approved** — executing below | Phase 8 |

Implementation starts now, in this session, in `E:\Godot\Idle Pioneer\`.
