# Idle Pioneer — Design Notes (rebuild)

`GAME_DESIGN.md` is still the foundation. This file records what the rebuild
actually implements, where it deliberately departs from that document, and why.
Every number mentioned here lives in `data/balance.json` or `data/content.json`.

## Why the prototype was rebuilt

The earlier Godot build (still on `main`, and in git history) had a solid
simulation core and good tests, but had drifted a long way from the locked
design and from a shippable mobile game:

- **Runtime procedural map generation** — the one thing `GAME_DESIGN.md` §12
  says not to revisit, because it's what stalled the original Unity project.
- **Placeholder systems in the core loop** — an "Influence" currency with no
  designed way to earn it, colonist "secondary effects" that did nothing, a
  25-slot colony list that recycled the 8 colonies with "II", "III" suffixes.
- **The central tension was gone** — colonists no longer split between
  producing and crafting; crafting was a manual "craft one" button.
- **A UI that dropped taps** — every panel destroyed and rebuilt its buttons
  on a timer, so a tap whose press and release straddled a rebuild was lost.
  On mobile that's a fundamental problem, not a polish item.
- ~8,500 lines, many carrying paragraph-long history comments, made each change
  slow.

Kept from the old build: the fonts, nation data and bonuses, the per-nation
colony names (`data/colony_names.json`), the Europe harbor painting (now
pixelated), the atomic save pattern, and GUT.

## The loop, as built

1. **Colonies** (8, founded in a fixed order) produce one raw good each.
   Each has three upgrade tracks — Production, Cargo (wagons / holds), and
   Speed (roads / faster ships). This follows the direction given after the
   design doc: three independent per-colony tracks, and colonies produce at a
   base rate even with nobody assigned.
2. **Routes**: each colony rolls a land or sea site at the start of a run
   (the doc's per-run variety, made visible: the two candidate sites are real
   places on a fixed, hand-tuned map). Wagons and ships shuttle continuously,
   loading whatever is waiting. Cargo grows with distance as fast as travel
   time does, so distance makes deliveries lumpier, not slower on average —
   otherwise a freshly founded far colony couldn't ship even its base output.
3. **Capital warehouse**: each good is either sold on arrival or kept.
4. **Workshops** (10 recipes, 1–3 step chains) are built with gold, staffed by
   colonists, and upgraded for speed. Staffing a workshop automatically keeps
   its inputs. Crafted goods can feed further recipes.
5. **Colonists** are one shared pool recruited at the Docks (cost ×1.15 each).
   Each one assigned to a colony adds +100% output; in a workshop it adds
   crafting speed. This is the doc's central tension, restored.
6. **Founding Fathers** (12) join Congress for gold plus kept goods and give
   run-long bonuses. This is new — it's the Idle Planet Miner "projects" layer,
   borrowed from Colonization's Continental Congress, and it gives kept goods
   and crafting chains a purpose beyond resale.
7. **Declaring Independence** requires 1B gold earned this run *and* at least
   one Musket crafted (the doc's recommended narrative gate). It pays
   `floor(6 × sqrt(earned / 1B))` Liberty, wipes the run, and returns to the
   nation picker.
8. **Liberty Reforms** (permanent): Industry, Navigation, Settlement from the
   doc, plus **Commerce** (+10% sale price per level), since the doc says only
   prestige upgrades should raise prices but defined none that did.

## Other deliberate choices

- **Nations** (6) are picked at the start of *every* run, so prestige also
  means a fresh strategic choice. Italy was already replaced by Sweden.
- **Gold, not coin** — kept, per earlier direction.
- **Independence gate is 1B** (doc: 2B) and late colony costs were lowered
  (sugar 15M, furs 150M), tuned with `tools/balance_bot.tscn` so a first run
  lands around 2.5–4 hours for a reasonable player, per the doc's target.
- **Recipe times are ¼ of the doc's** so a staffed workshop is worth about as
  much as putting that colonist in a colony; at the doc's times crafting
  never paid off.
- **Offline progress** is capped at 4 hours (+4 with Benjamin Franklin), and
  the simulation is step-size independent (tested: 0.1s, 1s, 5s steps and one
  600s step agree within 1–2%).
- **Buy x1 / x10 / x100 / Max**, and holding a buy button repeats it.
- **Advisor**: one context hint at a time (tap to jump there), so the first
  session teaches itself.

## Art direction

Colonial frontier subject matter (the 1994 Colonization overland map, docks of
Europe, Continental Congress) rendered with Graveyard Keeper-like pixel
density: a finer 2× pixel scale, organic coastlines, lit trees and hills with
soft drop shadows, depth-graded water with an animated glint shader, and icons
with colour-tinted outlines and rim lighting. All sprites are generated from
code in `tools/` so they can be edited and regenerated consistently.
