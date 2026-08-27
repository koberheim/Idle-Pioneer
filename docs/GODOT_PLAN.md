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

### Continuous crafting, offline catch-up, and a shipping bug found along the way

Direct request: crafting needs to run continuously in the background (not just an instant click), craft times will grow to hours/days for later recipes, it must keep progressing while the game is closed, and the player needs both a manual "craft one now" action and an auto-craft toggle per recipe.

- **Manual craft stays exactly as it was** — click, get one batch instantly if the ingredients are there. Untouched.
- **New: an auto-craft toggle per recipe.** When on, a background timer (using that recipe's own craft time) produces one batch per completed cycle, for as long as ingredients hold out. Built using the same exact-math catch-up technique already proven for colony production, so a single call can resolve a multi-hour or multi-day gap instantly rather than looping through it second by second.
- **When ingredients run out mid-catch-up, the station pauses rather than losing progress** — the unspent time is handed back to the timer, so once the missing ingredient shows up again, crafting resumes right where it left off instead of waiting out a whole fresh cycle first.
- Both the toggle and the in-progress timer are saved and restored correctly, so a long craft resumes exactly where it was after closing and reopening the game.
- **Not done in this pass:** an actual real-time "keeps running while the app is closed" feature. That requires a live game clock plus reading elapsed real-world time on startup, and nothing in the project drives *any* system (colonies, shipping, crafting) in real time yet — there's no running game loop at all currently, for anything. Crafting (and shipping, below) are now built to handle that correctly whenever that clock gets wired up, but the wiring itself is separate, larger work.
- **Found while building this, and fixed since it's the identical problem:** shipping only ever advanced one leg of one trip per call, so fast-forwarding it through a long gap would have badly under-counted deliveries. Fixed to complete as many full round trips as the elapsed time and available cargo allow, the same way crafting now does.

### The real prestige system (Liberty)

Built docs/GAME_DESIGN.md §8 for real, replacing the earlier unwired "doubloons" placeholder that nothing had ever read or written.

- **Liberty, lifetime Liberty earned, and the three permanent upgrade levels (Industry/Navigation/Settlement) now live in the permanent save layer** and survive a reset - that's the entire point. The old placeholder fields (`doubloons`, an unused generic `meta_upgrades` list) are gone; nothing had wired them up to anything real, so there was no behavior to preserve.
- **The reset gate reads this run's lifetime earnings, not current gold on hand** - a new per-run counter that only ever grows, separate from gold you can spend. Spending doesn't undo progress toward unlocking a reset.
- **Declaring independence pays out Liberty via the documented formula, then wipes the run through the same `new_run()` reset boundary everything else in this codebase already uses** - no separate, duplicate reset logic.
- **All three branches' effects are wired all the way through to where they matter**: Industry boosts colony production (stacking with the existing run-scoped upgrade system, multiplicatively, at the point where a colony reads its rate), Navigation boosts cargo capacity and shipping speed, Settlement discounts colonist and new-colony costs. None of these three is a number that just sits in a menu unconnected to anything - each one visibly changes a real result the same way primitive_tools already proved out for the run-scoped system.
- **Branch costs use the same `base × growth^level` shape every other cost curve in this project already uses**, tuned to land close to the document's example table rather than hardcoding that table verbatim - consistent with the standing instruction to keep every number easily retunable from one place (Balance/the inspector) rather than baked into a lookup table.
- Not yet touched: the rest of §9's save shape (recipes_ever_unlocked, stats, warehouse, routing) - that's task #34's job, not this one's.

### Rest of the save shape: Sell/Reserve routing, run history, "gold" stays "gold"

Closes out §9. One naming decision and one real gameplay decision came up doing this:

- **The document renames "gold" to "coin" throughout - explicitly not adopted.** Direct instruction: keep calling it gold. Every field, comment, and formula in this codebase still says gold; nothing was renamed.
- **Sell vs. Reserve is now a real mechanic, not just a save field.** Every resource arriving at the Capital - whether produced there directly or shipped in - now passes through a single routing decision: sell it immediately for gold, or reserve it in storage for crafting. This is genuinely new behavior, not a rename; a dedicated question was asked before building it, given how much it changes.
- **Default is Reserve, not the document's own stated Sell default** - a deliberate choice, answered directly: goods keep piling up in storage exactly as they did before this system existed, unless the player explicitly marks a specific resource to auto-sell. Nothing about existing play changes unless the player opts in.
- **Run history now has somewhere real to live**: which recipes have ever been crafted at least once, and the best gold total and fastest time across every run, all in the permanent save layer, updated automatically when a run ends. There's no recipe-unlock-gating mechanic yet, so "ever unlocked" is read as "ever crafted" - the closest honest match to what the document means until real recipe gating exists. "Fastest run" is measured by real-world clock time (`started_at_unix` to now), since nothing drives a simulated elapsed-time clock yet - see the continuous-crafting section above.

### The game actually runs now: live simulation driver + offline catch-up

Every subsystem above (colonies, shipping, crafting) had a correct, well-tested `tick(delta)` - but nothing was ever calling them during real play. Opening the game would have shown a static screen; numbers only ever moved inside test code. Two things fixed that together, since the second was the direct payoff of building the first:

- **A live game clock now drives colonies, shipping, and crafting every frame.** Disabled by default until something explicitly starts it (the eventual game screen) - critically, this also means it stays inert during the automated test suite, which runs inside a real (headless) Godot engine that keeps advancing frames of its own accord. Without that guard, the test suite itself would have been silently mutating shared game state on every frame.
- **Shipping never had a live registry at all before this** - Route objects only ever existed inside tests. Built one (self-healing: it notices a colony that needs a route and creates one automatically, so founding order never matters) and, since routes are now genuinely live, gave them real save/load support too - a shipment's in-flight cargo would otherwise have silently vanished on every reload.
- **A fresh run now starts with the Capital already founded automatically** - it's free and always present per the document's own colony table; nothing should have to found it by hand.
- **Reopening the game after time has passed now fast-forwards correctly**, using the save file's own timestamp - capped at a configurable maximum (24 hours by default) so a very long or tampered gap can't produce an unbounded result. This is the direct payoff of building crafting and shipping to handle arbitrarily large time jumps safely - the one big catch-up call simply reuses the same tick methods play already uses, with no separate "offline" code path to keep in sync.

### Founding new colonies (a real action, not just a cost formula)

Found and fixed a real leftover bug while building this: there was already a cost formula for "the next colony," but it was a generic exponential curve from before the real 8-colony table existed (task #26) - it no longer matched any of the colonies' actual individually-priced costs, and nothing outside its own tests ever called it. Replaced it with the real thing: each colony's cost now comes from its own authored price, discounted by Settlement same as before.

- **Founding is a real action now**: spend the colony's real gold cost, and it's registered and simulated immediately - production, shipping, everything from the sections above just starts working for it, with no separate wiring needed.
- **Colonies must be founded in the fixed order the document's table lays out** - you can't skip ahead to a farther, pricier colony before the one before it exists. This wasn't stated outright as a rule; it's a judgment call reusing the same `order` field the colony table already had for distance, rather than inventing a separate "which sites are available" mechanic that isn't in the locked design.

### The first real screens - and reusing the old Unity art

Every system up to this point had only ever been proven through automated tests and console output - there was nothing to actually look at or click. Built real, playable screens for the whole loop: Colonies (found/upgrade/watch shipments), Market (sell/reserve per resource), Crafting (craft one/auto-craft per recipe), and Prestige (this run's upgrade, Declare Independence, the three permanent branches). Plain, functional layouts, not a polished pass - matches the document's own §11 guidance that an early build is allowed to be "ugly."

- **Reused art from the original Unity project where it genuinely fit**, per direct instruction: colony/outpost card art, the ship and wagon icons for shipping status, a harbor background, and the Timber icon (the one resource whose name survived the design pivot). Most of the old game's resource icons don't apply any more - the resource list changed completely when the game was redesigned around the new document - so those still show as plain text rather than force a mismatched icon onto them.
- **Structured so new art drops in without touching code**: `ResourceDef`, `ColonyDef`, and `UpgradeDef` all carry a plain `icon` field (the same pattern `ResourceDef.icon` already had), and every screen reads that field rather than hardcoding a lookup. Replacing any icon later is a matter of pointing that field at a new file in the inspector - never a script change.
- **Found and fixed a real data bug while copying the art over**: several of the source files are JPEGs saved with a `.png` extension (evidently a side effect of past editing in Picasa). Godot's importer picks its decoder from the extension, so those silently failed to import and took the *entire* colony/upgrade record down with them - Db could no longer find a Capital at all. Renamed the affected files to their real extension and confirmed the automated suite - which had been passing the whole time on unrelated content - actually catches this class of problem now too.
- **Not done in this pass**: any visual polish, animation, or a real map screen (still explicitly out of scope for v1 - see §12). This is the smallest thing that's honestly playable, not the final look.

### A real, randomized map, replacing the fixed 8-colony table

Direct request, driven by a real pain point from the original Unity attempt: each run (first game, and every run after a prestige reset) now generates its own map - mostly one continent with scattered islands - instead of walking a fixed, hand-named list of 8 places in a fixed order.

Read `docs/GODOT_MIGRATION_ANALYSIS.md`'s account of what actually broke in Unity before proposing anything here: the old generator was hardcoded and unseeded (one fixed coastline, always exactly 4 islands), placement was brute-force trial-and-error that could silently fail and fall back to a default position, and - called out there as the single biggest missing piece - terrain had no real connection to what a colony produced. Three decisions were confirmed directly before building on that history: what a colony produces still comes from founding order, not terrain (avoids redesigning the whole economy); land vs. sea shipping now comes from real geography instead of a coin flip; and the map is generated once per run and stays fixed across save/reload - only a prestige reset makes a new one.

- **A continent-plus-islands generator**, seeded and reproducible, built on land/water/coastal infrastructure (`MapGrid`, `PlacementRules`) that had been sitting unused since before the design document pivot. Placement (the Capital's starting coastal site, then every colony site after it, at growing but not rigidly increasing distance) works by listing every valid candidate cell and picking randomly among them - never "guess and retry," which is exactly the pattern that produced Unity's silent-fallback bug. If a map genuinely runs out of room, generation stops placing further colonies rather than forcing a bad position.
- **The 8 named colonies became reusable templates, not one-time places.** Each still has its own name, icon, and resource, but a run can found more than 8 colonies - founding cycles back through the 7 non-Capital ones again (shown in the list with a "II", "III", ... suffix so nothing reads as an accidental duplicate) to fill up to 25 sites total, a number that's a single tunable setting, not a hard limit.
- **Cost now comes from one unified formula** (the same `base × growth` shape every other cost curve in this project uses) instead of 8 individually hand-typed prices - fit closely against the real original numbers so the early game's cost feel doesn't change, and extends cleanly to however many colonies a run generates.
- **Land vs. sea shipping is real now**: a colony's site on the generated map determines whether it ships by sea or by wagon, replacing the old random 50/50 roll.
- **Found and fixed a real bug while wiring this up, unrelated to the map itself**: distance now defaults to 0 for a freshly-made colony (real, per-site data, not a stand-in number) - which is correct - but several tests still assumed the old default and broke in a specific, informative way (a shipment "arriving" instantly instead of showing it mid-transit). Fixed by giving those tests real distances explicitly, the same fix already applied everywhere the design realignment touched shipping earlier this session.
- **Generation itself needed a speed pass**: the placement search initially rescanned the whole map for every one of the up to 25 colonies, which was slow enough to visibly drag down the whole automated test suite (every test that starts a run now generates a real map). Precomputing and sorting candidate sites by distance once, then narrowing straight to the relevant range, cut that down substantially.

### Colonists had no screen at all

Found while reviewing what was still missing after the map rework: buying and assigning colonists (docs/GAME_DESIGN.md §4's "central tension of the whole game") had a fully built, tested backend (`Game.colonists`) but no way to touch it from the actual game screen - the Colonies tab covered founding and upgrades, but not the colonist pool sitting right next to them. Added a colonist count/buy row at the top of that tab, and a per-colony assign/unassign control on every founded colony's row.

### Colonists, redesigned: typed, individual, and on a new currency

Direct request, replacing the flat colonist pool above entirely rather than sitting alongside it - confirmed directly before building:

- **A new currency, Influence, separate from gold** - how it's actually meant to be earned is still undecided. Built with a clearly-labeled placeholder earning method (a small fraction of every gold gain also becomes Influence) so recruiting/upgrading/assigning colonists is genuinely testable now rather than blocked on that decision; trivial to rip out and replace with the real design later, since it's one field and one line.
- **Colonists are individual and typed now, not a headcount.** Three types - Resource, Cargo, Speed - matching a colony's own three tracks exactly. Each colonist is recruited on its own (cost grows with how many you own total - no cap, but expensive, as asked for), starts at level 1, and can be upgraded on its own (cost grows with *that colonist's* level, independent of the rest of your roster).
- **A colony has exactly one slot per type** - never two Resource colonists working the same colony. Assigning fills the matching slot only; a second colonist of a type already staffed there is rejected.
- **Each colony's production/cargo/speed formulas now read the level of whichever colonist is actually assigned to that specific slot**, replacing the old flat "+10% per colonist assigned, no matter to what" bonus. An empty slot means no bonus for that track, not broken - a colony still works fine fully unstaffed, unchanged from before.
- **Secondary effects (meant to eventually reach into crafting and beyond, per the request) are a placeholder framework only, on purpose** - a colonist above a certain level implies a nonzero number via one `Balance` formula, but nothing in the game reads it yet. Confirmed directly: real secondary effects aren't designed yet, and this pass shouldn't invent them.
- **The colonist roster lives directly on the save state now** (no separate in-memory registry to remember to clear on a prestige reset, unlike colonies/routes/crafting stations) - swapping in a fresh run already empties it for free, since there's nothing left to hold onto.

### First real UI/UX pass, from testing the actual game in the editor

The typed colonist roster above was the first time the game was actually clicked through in a running Godot window rather than only exercised via tests. Direct, itemized feedback from that session, all fixed together:

- **The 4 tabs (Colonies/Market/Crafting/Prestige) only filled the left half of the screen.** Root cause: `TabContainer`'s stock tab bar sizes each tab button to its label and left-aligns them - there's no built-in "stretch tabs evenly" option. Replaced the `TabContainer` entirely with 4 plain `Button`s in a `ButtonGroup`, each `SIZE_EXPAND_FILL`, driving visibility on a sibling `Control` holding the four panels - same one-tab-visible-at-a-time behavior, but the buttons now actually split the bar evenly.
- **Crafting was a single column; asked for two, with a placeholder sprite per recipe** (real recipe art doesn't exist yet). `CraftingPanel` now builds a `GridContainer` with 2 columns. Added `RecipeDef.icon` (matching the pattern already on `ResourceDef`/`ColonyDef`/`UpgradeDef`) for when real art exists; until then, unset icons render as a flat-colored square keyed off the recipe's id (stable and visually distinct per recipe, obviously a placeholder rather than a broken image).
- **Most of the interface was dark-brown text on a gray background, unreadable - including the gold count, which was technically present but invisible.** Root cause: `ui_theme.tres` set a dark-brown `Label` font color intended for a light background, but defined no `Panel`/`PanelContainer` style at all, so every panel (top bar, every row) fell back to Godot's default dark panel and the text had almost no contrast against it. Fixed by adding a light parchment-tone `Panel`/`PanelContainer` style to the theme - resolves both the general contrast complaint and the invisible gold/liberty display at once, since they share the same `TopBar` panel.
- **Found along the way, not separately reported:** colony icons in `ColoniesPanel` were rendering visibly stretched/distorted in tall rows (a founded colony's row, with its 3 colonist slots and 3 upgrade buttons, is much taller than the icon). The icon `TextureRect` had no vertical size flag, so the `HBoxContainer` stretched it to match the row's full height before the fixed-size texture got scaled into that stretched space. Fixed by pinning the icon to `SIZE_SHRINK_CENTER` vertically.
- Verified visually, not just by test count: captured a real (non-headless, real OpenGL) screenshot of the running game before and after - headless mode's dummy renderer produces no real pixels, so this is the first time in the project a UI complaint was confirmed by actually looking at rendered output rather than reading layout properties. Useful enough as a technique that it's worth reaching for again for future UI work.
- Explicit scoping instruction from this same feedback pass, still in effect: **no real visual map/colony-sprite rendering is in scope right now** - the interface stays list-based until asked for otherwise. Not a new decision - `GAME_DESIGN.md` already ruled this out for v1 (see the top of this section) - just reconfirmed directly.

### Phase 7 — Feel

With Phases 1-6 (skeleton, one colony, colonists/buildings, colonies/transport, crafting, prestige) all built and tested, this is `GAME_DESIGN.md` §11's last phase - making the numbers and moments actually read well, not new mechanics. Sound is the one item in §11's list explicitly deferred (direct instruction: "we'll wait on that") - no audio assets exist in the project yet, and nothing else here depends on it.

- **Number formatting.** Every panel was printing raw floats (`Gold: 842000000.0`) - exactly the "£1200000, not £1.2M" problem §11 calls out by name. Added `Format.number()` (`scripts/core/format.gd`, a stateless static utility - no Balance-style autoload needed, nothing here depends on `balance.tres`): abbreviates at 1000+ with a K/M/B/T/Qa/Qi suffix, keeps whole numbers below that, and an optional `decimals` argument preserves the handful of call sites that showed fractional amounts (Market stock, Influence, colonist costs) before this. Wired into every currency-scale display: gold, Liberty, Influence, all gold/Influence/Liberty costs, resource stock and sale price. Rates/distances/percentages (production rate, cargo, round-trip seconds) were left as raw decimals - they're not currency-scale and stay small for the life of a run.
- **Shipment-arrival notifications.** `Route` already had a `delivered` signal (emitted at `_arrive_at_hub()`) that nothing was listening to. `Routes` now forwards it as `shipment_delivered(colony, cargo)` - a bare `Route` doesn't know its own colony's display name, so `Routes` (which owns the origin/route mapping) is what has to attach that context, not `Route` itself. `MainScreen` listens and pushes a one-line message ("Cape Harbour delivered: 12 Timber") into a new `NotificationBar` - a small toast strip that queues messages and shows one at a time for a few seconds, then hides entirely rather than sitting there as a permanent log (the rest of the interface already shows live state every refresh; this is only for "something just happened" moments a 0.25s poll would otherwise blow past silently).
- **Offline-progress summary.** The offline catch-up math (`SaveSystem._apply_offline_catch_up`) was already correct and tested - it just applied silently on load, with nothing telling the player what they came back to. `SaveSystem` now measures `Game.economy.gold` before/after the catch-up tick and emits `offline_progress_applied(elapsed_seconds, gold_earned)`; `MainScreen` connects to it *before* calling `SaveSystem.load()` (the signal fires synchronously from inside `load()`, so connecting any later would miss it) and pushes a longer-lived toast ("Welcome back! Earned 1.2K gold while away (2h 15m)") - skipped entirely when `gold_earned` is zero, so reloading seconds after saving (the common case while developing) doesn't announce nothing.
- **A real Independence sequence.** Declaring Independence wiped the whole run on a single click with no confirmation - risky for the most destructive action in the game, and not the "sequence" §11 asks for. `PrestigePanel` now arms a confirmation step first (`_declare_armed`, a field on the panel rather than a local var, since the panel rebuilds from scratch on every 0.25s refresh and a local would reset itself before the player could ever click Confirm) showing an explicit warning and Confirm/Cancel buttons before the real `declare_independence()` call fires. `Prestige` already had a `declared_independence(liberty_awarded)` signal nothing listened to (same shape as the shipment-delivered gap above) - `MainScreen` now connects it to a celebratory toast on the actual reset.
- Same visual-verification approach as the earlier UI pass: real (non-headless) screenshots confirmed the notification bar collapses cleanly when empty (no layout gap), and a manual verify script that fast-forwards `Game.run.lifetime_gold_earned_this_run` past the 2-billion-gold prestige gate (unreachable in a quick manual playthrough) confirmed both the armed-confirmation screen and the post-declare toast render correctly.

### A real map, direct request - reversing the "list view ships v1" scoping

`GAME_DESIGN.md` §12 explicitly ruled out "any real map rendering" for v1, and the earlier UI pass (see above) reconfirmed that directly. This is a deliberate reversal of that, requested directly, not a misreading of the doc - the underlying data was already there and unused: `MapGrid`/`MapGenerator` build a real seeded terrain grid and place every colony slot on it at `Game.new_run()` time (rework task: randomized map), but nothing had ever drawn a single pixel of it - only `PlacementRules`/colony-slot placement ever read it.

- **`MapView` (`scripts/ui/map_view.gd`)** - a plain `Control` that parses `Game.run.map` back into a `MapGrid` (cached by `Game.run` object identity, not rebuilt every 0.25s refresh - the map only changes on a fresh run or a prestige reset) and draws it with `_draw()`: one `draw_rect()` per terrain cell (deep water / shallow water / land / coast, four flat colors), one `draw_circle()` per colony slot (gold = Capital, green = founded, blue = the next slot buyable in sequence, gray = locked/not yet reachable). Deliberately not one node per cell - the grid is up to 60x60, and nothing here needs per-cell animation. Tapping a marker (`_gui_input`, with a hit radius wider than the drawn dot - a fingertip isn't a mouse cursor) emits `slot_selected(slot_index)`; `MainScreen` opens the Colonies tab in response. Cell scaling is non-uniform (`size.x/width`, `size.y/height` independently) rather than fit-to-square-and-center - the grid is square (60x60) but the screen is a tall portrait rectangle, and centering a square would have letterboxed large empty bands above and below it. Confirmed by screenshot before landing on this: the square-fit version really did leave dead gray bars top and bottom.
- **The whole screen layout changed to carry it**, direct request: the map is the permanent full-screen background: layer, not a tab of its own. The 4 tabs collapse to a plain strip pinned to the screen's bottom edge; tapping one slides a content sheet up over the map to cover ~45% of the screen (tapping the same tab again slides it back down - `ButtonGroup.allow_unpress = true` makes that possible, since a normal button group can't deselect down to nothing on its own). `MainScreen`'s `Root` VBoxContainer became a plain `Control` with manually-positioned overlay children, since a `VBoxContainer` can't have one child (the map) sized full-screen while another (the sheet) floats on top of it rather than pushing it around - `TopBar`/`NotificationBar` still use ordinary top-anchored positioning (they never move), but `SheetPanel`/`TabBarPanel` are positioned every frame the sheet is animating, by a small `_layout_sheet()` that keeps the tab strip pinned to the bottom edge and grows the sheet upward from directly above it. The open/close motion is a `Tween.tween_method()` over the sheet's height (0 -> ~45% of screen height), not a hand-rolled per-frame lerp.
- The sheet starts closed on boot (full map, nothing selected) - a deliberate change from before, where the Colonies tab was open by default.
- Verified the same way as every other UI change this session: real (non-headless) screenshots at each state - closed, open, and closed-again after tapping the same tab twice - confirmed the map fills edge-to-edge with no gray letterboxing, the sheet slides correctly, and the tab strip never moves.
- **Not done in this pass, left for later polish**: tapping a colony marker only opens the Colonies tab, it doesn't scroll to or highlight that specific colony's row in the list below; there's no zoom/pan (the whole 60x60 grid always renders at once); and colony markers use flat colored dots, not the existing Unity colony/outpost card art (`assets/art/`) - a fancier pass was explicitly deferred in favor of this simpler one for the first attempt.

### Second playtest pass - selling, discovery, and a full navigation rework

Direct, itemized feedback from actually playing with the new map, same format as the two passes above:

- **Gold wasn't increasing at all.** Root cause: the Capital's Timber production was routing to RESERVE by default (an earlier pass this session had deliberately flipped away from the design doc's own SELL default - see the first "DESIGN REALIGNMENT" correction above), so a fresh colony piled goods into inventory instead of selling them, and nothing ever touched gold. Reversed back to SELL-by-default (`Routing.mode_for()`), matching `GAME_DESIGN.md` exactly - a fresh colony visibly earning gold reads as correct, "nothing sells until you opt in" reads as a bug, even though both are defensible defaults in the abstract.
- **A run-scoped Discoveries system, new** (`scripts/sim/discoveries.gd`, `Game.discoveries`) - direct request: Market and Crafting should only list what the player has actually encountered, in the order encountered, not the full authored content table up front. A resource is discovered the moment it's first delivered to the Capital (`Routing.deliver()` - the single choke point every resource entering the central economy already passes through, produced there directly or shipped in) or first crafted; a recipe is discovered the moment every one of its inputs has been discovered. Two new `RunState` arrays (`discovered_resources`, `discovered_recipes`), reset each run like everything else in that half of the save - deliberately separate from `MetaState.recipes_ever_unlocked`, which is a permanent, cross-run "ever crafted" stat, not a run's current visibility state.
- **Unsettled colonies are hidden entirely now** - not shown as "Locked" - in both `ColoniesPanel`'s row list and `MapView`'s markers, direct request. Only a founded colony or the single next-one-in-sequence (with its Found button/marker) ever renders; everything further down the sequence is invisible until it's actually reachable.
- **A new Colonists tab, replacing Prestige's old tab slot** (`scripts/ui/colonists_panel.gd`) - direct request: colonist recruiting/upgrading/assigning moved out of `ColoniesPanel` entirely into its own tab (recruit-by-type buttons, then one row per owned colonist with an Upgrade button and either "Assign to <colony>" buttons for an idle colonist or an "Unassign" button for an assigned one). `ColoniesPanel` keeps only a read-only per-slot summary line (`Resource: level 2  Cargo: empty  Speed: empty`) so a colony's row still tells the whole story without a tab switch.
- **Market split into two sub-tabs** - Raw Materials and Crafted Goods, direct request (previously one undifferentiated list mixing both). `Db.is_crafted_resource()` classifies a resource by whether any recipe names it as an output; both sub-tabs share the same Sell/Reserve/Sell All row shape. Also now driven by `Game.discoveries` in discovery order, hiding anything not yet discovered - directly addresses the complaint that Timber (produced from the very first tick) was sorting near the bottom of an alphabetic/authoring-order list.
- **Crafting's 2-column grid no longer needs horizontal scrolling.** Root cause: `GridContainer` sizes each column to its widest cell's minimum size, and a recipe row's description label had no cap on that - one long line silently widened its whole column past half the screen. Fixed by capping `custom_minimum_size.x = 0` on both the row and its label and turning on `autowrap_mode` (word-wrap) on the label, plus disabling the outer `ScrollContainer`'s horizontal scroll mode outright as a hard guarantee rather than a hope. Also now driven by `Game.discoveries.discovered_recipes()` in discovery order, same as Market.
- **A 5th tab, Discoveries, added as a placeholder** (`scripts/ui/discoveries_panel.gd`) - direct request, reserved for a future upgrade tree, no content designed yet. Same "present and obviously a stub" spirit as Balance's colonist-secondary-effect placeholder.
- **Prestige and Save moved out of the tab strip into a top-right menu popup** (`MenuPopup`, opened by a new "Menu" button replacing the old inline Save button in `TopBar`) - direct request, the way a typical app's overflow menu works. `PrestigePanel`'s own script/content is unchanged, only where it's instantiated moved; its labels picked up `autowrap_mode` since the popup (340px) is narrower than the full-width tab sheet it used to live in - without that, several lines were clipped at the popup's edge rather than wrapping.
- Verified the same way as every UI change this session: a manual verify script fast-forwarded the simulation and forced enough gold/inventory/crafting to exercise every changed surface at once, then took a real (non-headless) screenshot of each - closed map, Colonies (no Locked rows), Colonists, Market's both sub-tabs, Crafting's grid, the Discoveries placeholder, and the Menu popup - catching one real bug along the way (the popup text-clipping above) before it shipped.

### Map polish - the follow-ups deferred from the first map pass

- **Tap-to-scroll**: tapping a colony marker used to just open the Colonies tab generically; `ColoniesPanel.scroll_to_slot()` (a `slot_index -> row` map rebuilt every `refresh()`, `ScrollContainer.ensure_control_visible()`) now scrolls straight to that colony's row too.
- **Zoom/pan**: `MapView` now supports mouse-wheel/pinch zoom (1x-4x, zoom-to-cursor - the point under the cursor stays put rather than the view always zooming toward the top-left) and drag-to-pan, clamped so the grid can never be panned past its own edges. A single `_zoom` factor and `_pan` pixel offset, applied uniformly in `_draw()` and in tap hit-testing - there's no `Camera2D` involved, this is 2D `Control` drawing, not a world scene. A press has to move past a small threshold before it counts as a pan rather than a tap, so clicking a marker still works.
- **Real art on markers**: colony markers now draw each tier's actual `ColonyDef.icon` (the same art `ColoniesPanel`'s rows already use), with the gold/green/blue color-coding surviving as a ring around the icon rather than the icon's fill color; a tier with no icon still falls back to the old flat dot.

### Offline play - closing the one real gap left

The live simulation clock and offline catch-up (see "The game actually runs now," above) were already built and correctly tested well before this - opening the game after time away already fast-forwards colonies, shipping, and crafting through exactly however long the save's `saved_at_unix` timestamp says was missed. What was still missing wasn't the simulation, it was making sure that timestamp is trustworthy in every way the app can stop running, not just a clean desktop quit.

- `MainScreen` only ever saved on `NOTIFICATION_WM_CLOSE_REQUEST` (desktop window close) plus a 30-second periodic autosave. Backgrounding the app - switching apps on mobile, the OS suspending or later killing it without ever calling back in - never fires that notification, leaving up to 30 seconds of staleness on the one timestamp offline catch-up depends on.
- Now also saves immediately on `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED` - between the three, every way the app actually stops running is covered, not just a graceful quit.
- Verified directly (not screenshot-based, since there's no visual surface to check): a manual script called `_notification()` with each value on a live `MainScreen` and confirmed a save file existed afterward.

### Nations - a feature `GAME_DESIGN.md` predates entirely

Direct request: the player picks one of 6 nations at the start of a run, each with a unique bonus. Recovered from the original Unity project rather than designed fresh - `Assets/01_Scripts/NationalityData.cs` (a ScriptableObject with 6 multiplier fields: ship speed, wagon speed, colony cost, gold sell, extraction rate, Liberty generation) and its 6 authored assets under `Assets/03_Data/Nationalities/` (Dutch, English, French, Italian, Portuguese, Spanish) already had this exact mechanic designed, just never really built. Worth citing honestly for anyone tracing this back to the source: only one of the six bonuses (Dutch, extraction rate) was ever wired into Unity gameplay at all, and even that one was dead code in practice - `ColonyProduction.cs` checked `chosenNationality.nationalityName == "Dutch"` directly rather than reading the multiplier field generically, and `nationalityName` was left blank in every asset, so the check could never actually pass. The other five nations' bonuses existed only as unread data. This rebuild wires all six for real, using the multiplier fields themselves rather than a name string.

- **`NationDef`** (`scripts/data/nation_def.gd`) carries the same 6 multiplier fields as the original `NationalityData`, each defaulting to 1.0 (neutral) - every real nation sets exactly one away from 1.0, matching the original data exactly. `Db` loads `data/nations/*.tres` the same directory-scan way as every other content type (`Db.nation(id)`, `Db.all_nations()`).
- **`RunState.nation_id`** - the chosen nation, fixed for the run's whole lifetime same as `map_id`, persisted and restored on save/load. Defaults to empty ("no nation chosen") rather than any real nation - `Game.new_run()`'s own doc explains why: every existing caller (every test in this suite included) calls it without a nation and must see exactly the neutral behavior it always has. `Game.current_nation()` and six `Game.nation_*_multiplier()` convenience methods (mirroring how `Prestige` already exposes `cost_discount_multiplier()`, `speed_multiplier()`, etc. rather than raw fields) treat "no nation" as 1.0 across the board.
- **Wired into the exact systems the bonuses describe**: `Colony.production_rate()` (extraction), `Colony.round_trip_seconds()` (ship speed for a sea route, wagon speed for a land one - picked by `route_type`, so an English bonus does nothing for a land route and a Portuguese one does nothing for a sea route), `Colonies.found()`'s cost (and its matching display in `ColoniesPanel`), `Economy.sell_value()` (gold-sell - the first *actual* gold-sale multiplier this project has had; `sell_value()`'s own doc comment previously explained in detail why no such multiplier existed yet), and `Prestige.projected_liberty_payout()` (applied to the payout itself, not to lifetime gold earned beforehand - a bonus to what Independence pays out, not a claim the run earned more).
- **`NationSelectPanel`** - a full-screen overlay shown once, before a fresh run's very first frame, only when no save exists yet (loading an existing save skips it entirely, same as the map). Reuses the "`MainScreen` owns every overlay" convention from `NotificationBar`/`MenuPopup`/the sliding sheet rather than a separate scene, so `Main.tscn`'s own structure - and the "revert to clean baseline" pattern every manual verify script in this session depends on - stays untouched. Each of the 6 buttons is colored with that nation's own `NationDef.color` and shows its bonus in plain language; picking one calls `Game.new_run()` for the first time, so the bonus is live from frame one, not applied retroactively.
- **A real bug caught by this pass, not by inspection**: `Discoveries.discovered_resources()`/`discovered_recipes()` returned a bare `[]` when no run existed yet - an untyped empty array literal where the function is declared to return `Array[StringName]`, a runtime type error in Godot, not a silently-working empty array. Never reached before, since every existing caller only ever ran after `Game.new_run()` had already been called - the nation-picker screen is the first code path in the project where `MainScreen.refresh_all()` legitimately runs with no active run yet. Caught by the same real (non-headless) screenshot verification process used all session, not by reading the code - the manual verify script's console output showed the actual Godot error.
- Verified the same way as every UI change this session: real screenshots of the picker (all 6 nations, correct colors and bonus text) and of the moment just after choosing one (picker gone, normal game screen, `Game.run.nation_id` and the matching multiplier both confirmed live) - plus 14 new GUT tests covering every multiplier's wiring against hand-computed expected values, not just "a number changed."
- **Corrected in the very next round of feedback**: Italian swapped out for Swedish, same +15% Liberty bonus, direct request - Italy hadn't formed as a nation yet during the actual colonial era this game is set in, so it never should have been on the list at all. The Unity project's own asset really was named "Italian" (see the citation above, which is accurate history of what that source data contained) - this is a correction to this project's content, not a misreading of the source.

### Third playtest pass - responsiveness, and more direct UI feedback

- **Menu button pinned to the actual top-right corner.** It was inside `TopBarRow`, an `HBoxContainer` with center alignment - it sat wherever the Gold/Liberty labels' combined width happened to push it, not the corner. A spacer `Control` with `SIZE_EXPAND_FILL` between the labels and the button now pushes it all the way to the right edge, the way a corner menu button is expected to behave.
- **A real, reported responsiveness bug, root-caused rather than papered over**: "clicking responsiveness seems hit or miss," worst on Market's Sell/Reserve buttons. Every panel in this project rebuilds its buttons from scratch on every `refresh()` (`queue_free()` the old ones, create new ones - a deliberate simplicity choice made early and documented in every panel's class doc). `MainScreen` was calling `refresh_all()` - and therefore rebuilding *every* panel, including four the player can't even see behind the closed sheet - every 0.25 seconds. A click's press and release don't have to land in the same engine frame; if a rebuild lands between them, the release is delivered to a brand-new `Button` node that never received the press, and Godot never fires `pressed` for either one. At 4 rebuilds a second across every panel, this was common enough to notice. Mitigated two ways: the periodic tick raised to 1.0s (still reads as "live" for an idle game) and now only rebuilds whichever *one* panel is actually open (`_active_page`), not all five - opening a tab or the menu popup refreshes it immediately instead, so nothing shown is ever stale. This doesn't mathematically eliminate the race, only makes it several times rarer; a fully race-proof fix would mean diffing each panel's rows in place instead of rebuilding them, a larger change than this pass's scope.
- **Colony upgrade buttons show their current level now** ("Production Lv 2 / +25% (51g)", not just "Production +25% (40g)") - direct request; the bonus percentage alone didn't say whether this colony's first upgrade or its tenth was about to be bought.
- **The three upgrade buttons moved from a full-width row under a colony's stats to a stacked column on the right side of its row** - direct request, a more compact layout that reads more like a sidebar of actions than a fourth line of text.
- **Market's Sell/Reserve pair replaced with a single Auto Sell on/off toggle** - direct request: "not intuitive on whether it is selling or reserving," two separate-looking buttons for what's really one boolean. Now one button, always reading "Auto Sell: ON" or "Auto Sell: OFF"; ON gets a distinct green fill plus a border that pulses in and out (a looped `Tween` on the `StyleBoxFlat`'s `border_color` alpha) so an active toggle reads as visibly "live" at a glance, not just a difference in text. "Sell All" is unchanged - still a manual one-off dump regardless of the toggle's state.

---

### Fourth playtest pass - a real bug in Auto Sell, and a visual pass

- **Auto Sell did nothing for crafted goods - a real, reported bug, not a UI nit.** `Crafting.craft_recipe()` added its output straight to `Game.inventory` and never touched `Game.routing` at all, so a crafted good (Planks, in the report) had no way to ever get sold automatically - it piled up in inventory regardless of what the Market toggle said, while raw resources (which *do* flow through `Routing.deliver()`, whether produced at the Capital or shipped in) always respected it correctly. Fixed by routing crafted output through `Routing.deliver()` too, the same choke point everything else entering the economy already goes through - `Routing.deliver()` already calls `Game.discoveries.discover_resource()` itself, so `craft_recipe()`'s separate call to that was removed as redundant. This is the same class of bug as the very first item in the second playtest pass (gold not increasing) - a system that looked wired up in the UI but was never actually connected to the mechanism the UI claimed to control. A new regression test (`test_craft_output_respects_auto_sell_when_routed_to_sell`) crafts something with the resource routed to SELL and asserts gold increased and nothing was stockpiled. Every other crafting test in the suite crafts a good specifically *to* consume it in a later step or assert on its stock - all of those needed `Game.routing.set_mode(id, Game.routing.RESERVE)` added to their setup now that SELL is the default (five test files, mirroring the exact same fallout pattern the original SELL-default change caused in the second playtest pass).
- **A crisper font, direct request** - "I like the font but it's not sharp enough... not larger, just crisper." Almendra is a calligraphic display face - fine for a title, not built for body text at 22px. Downloaded Libre Baskerville (Google Fonts, OFL-licensed, `assets/fonts/LibreBaskerville-Regular.ttf`) - a serif specifically designed for on-screen reading, still period-appropriate, and swapped it in as the theme's one `default_font`. Almendra's font file stays in the project, unused (same "don't delete art that might come back" convention as the dormant map code and unused Unity assets).
- **Less brown across the board, direct request** - buttons (previously a saturated brown matching the panel border almost exactly) recolored to a deep teal family instead; panel borders and body text desaturated rather than left fully brown. Parchment panel backgrounds were left alone - the complaint was about everything *else* being brown too, not the panels themselves, and the warm parchment now has something to actually contrast against.
- **Nation-picker colors muted, direct request** - "too bold... slightly more muted tones of each of the national colors." Each of the 5 saturated flag-derived colors (Dutch orange, English red, French navy, Spanish gold, Swedish blue) blended toward a neutral warm gray; Portuguese was already muted and left alone.
- **A real layout bug caught by this same visual pass, not separately reported**: the font swap (and possibly just seeing the real layout under real text for the first time) pushed the stacked upgrade buttons from the previous pass past the screen's right edge - text was silently cut off rather than wrapped, the exact "GridContainer sizes to its widest cell" problem already fixed once for Crafting's grid, showing up again here since the fix wasn't generalized at the time. Fixed the same way: a fixed `custom_minimum_size.x` on each upgrade button plus `autowrap_mode`, so a long line grows the button taller instead of wider; added `autowrap_mode` defensively to the colony stats/status/colonist-summary labels in the same row while already there.
- Verified the same way as every visual change this session: real screenshots of the nation picker (muted colors), the map/Colonies tab (teal buttons, crisp font, no more overflow), and Crafting (console-confirmed both Planks and Lumber sold correctly instead of stockpiling) - plus a new GUT regression test for the actual reported bug, not just the UI symptom.

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
