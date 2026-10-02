# Idle Pioneer — Design Notes

`GAME_DESIGN.md` is the original foundation. This file records what the game
actually does now, where it departs from that document, and why. Every number
lives in `data/balance.json` or `data/content.json`.

## The loop

1. **A new world each expedition.** Pick a Crown and a shore: an *Uncharted
   Coast* (a seeded continent with bays, capes, lakes and scattered islands,
   different every time) or *North America* (Labrador to Panama, the Great
   Lakes, Florida, the Caribbean). Unexplored land is blank parchment; each
   colony founded reveals more.
2. **Colonies land where the surveyors find land.** Each run pre-rolls where
   the 25 colonies will go — random, but loosely outward from the capital.
   The player decides *when* to found the next one, not *where*. The site's
   **terrain decides what it produces** (pine forest: timber or furs; hills:
   iron ore, silver near mountains; marsh: indigo; the tropics: sugar...), how
   rich the ground is, and whether its goods go **by wagon or by ship**.
3. **Routes are real.** Wagons follow a path across the terrain (forest,
   marsh and hills are slow); ships sail around the coast. Ships are slower
   but carry far more. Cargo grows almost as fast as distance, so a far colony
   is lumpier rather than much poorer.
4. **Value by settlement order.** Colony *n* is worth about 3.3^n gold a
   second at base, whatever it produces — a late timber camp is simply huge.
   This keeps every terrain worth settling and lets the good matter for
   crafting rather than for raw income. Founding costs grow a little faster
   than value, so each colony takes longer than the last; filling all 25 is a
   weeks-long, many-expedition goal.
5. **Upgrades**: Production / Wagons or Cargo Holds / Roads or Faster Ships
   per colony; buy x1/x10/x100/Max; hold to repeat.
6. **Colonists** are one shared pool: +100% output in a colony, or labour in a
   workshop. That split is the central tension from the original design.
7. **Workshops** turn kept goods into finer ones (chains below). Upgrades
   compound (×1.2 speed per level) so crafting keeps pace with the colonies.
8. **Europe**: every good is either sold on arrival or kept. Prices shift
   every 30 minutes: four goods wanted (×1.6), three in glut (×0.6).
9. **Congress**: 16 Founding Fathers are offered each run (4 per tier) out of
   38, for gold plus kept goods.
10. **Independence** at 2.5B gold earned and a Musket kept in the warehouse (the first one crafted is always set aside for the militia) pays Liberty
    (`15 × (earned / 2.5B)^0.3`, boosted by some Fathers and Sweden).
11. **Liberty** buys compounding **Reforms** (Industry, Navigation,
    Settlement, Commerce, Manufacture — ×1.10–1.15 per level, costs ×1.35 per level, Settlement ×1.38)
    and **Governors**, a permanent roster posted to colonies.

Smaller systems: **Colony Charters** (Township → Free City, paid in crafted
goods, +50% production and cargo each), **drifting treasure** to tap, and
**Royal Favor** (×2 production for 15 minutes every 2 hours, always free and
never tied to ads).

## Pacing

Checked with the reset-loop bot (`tools/campaign/campaign_bot.gd`), which
plays whole careers across expeditions on several map seeds. Founding costs
grow ×(7 + 0.03n) per colony against ×3.3 colony value, and Liberty pays
`(earned / goal)^0.3`. Together these keep the last colonies from becoming a
luck-based wall while Reforms can't run away. Measured on 3 seeds:

| | Colony 10 | Colony 15 | Colony 20 | Colony 25 |
|---|---|---|---|---|
| Nonstop play (active hours) | 2.3–2.6 h | 8.5–8.8 h | 20–22 h | 116–193 h |
| 1 h on / 7 h off (days) | 0.3–0.7 | 2 | 4–6 | 18–26 |

First independence takes about 2.5 hours of active play. Earlier tunings
(step 0.12 and a square-root payout) reached 24 colonies in under a day of
play and then walled at 25 for days to months depending on the seed.

## Rules the simulation keeps

- **Same result at any step size.** Live play ticks every 0.1 s; offline
  catch-up and Almanac pages use 120 s steps. Workshops that want the same good
  hold *claims* on the stock, shared by each workshop's rate of use, so the
  split doesn't depend on step length. Steps are split where Royal Favor ends
  and where the 30-minute market changes.
- **Time away runs at half pace** (`offline_efficiency` 0.5, 4 h cap plus
  relics and studies). Almanac pages run at full pace.
- **Independence is committed the moment the Declaration is signed**, and
  saved at once.
- **Maps:** every site produces a good its terrain (or coast) can yield; if a
  map has nowhere for a needed good, one spare site's tile becomes a fitting
  terrain.

## Systems that open up over time

A first run shows only the core loop. Newer systems appear after successive
independences (`unlock_after_runs` in balance.json), each introduced once by a
"New in the Colonies" note:

| After independence | Opens |
|---|---|
| — | **Milestones**: colony upgrade levels 25, 50, 100, 150, 200, 300, 400, 500 (then every 250) double that track (production and cargo ×2, speed ×1.5); workshop levels double workshop speed. |
| 1st | **The Ledger** tab (statistics and curiosities), **Relics** (30 real colonial artifacts in 6 sets; permanent small bonuses, set bonuses; from treasure 4%, each independence, and new colony-count records at 5/10/15/20/25), **the Almanac** (rare pages that skip an hour when read: one per independence, 1% from treasure, one per new colony record from 10). |
| 2nd | **Specializations**: after its first charter a colony picks one of two (Boomtown, Market Town, Frontier Fort, Post Road, Supply Depot, Deepwater Harbor, Entrepot). |
| 3rd | **The Philosophical Society**: 102 in-run studies in 6 branches (main line, optional side paths, repeatables), paid in goods and gold, reset each expedition. See RESEARCH_PLAN.md. |

Deferred ideas are in BACKLOG.md.

## Production chains (audit)

Every recipe consumes things that plausibly go into it, and every processed
good feeds something further up, except the luxury end products.

| Tier | Good | Made from | Building | Used for |
|---|---|---|---|---|
| Raw | Timber | pine / woodland | — | Lumber, Charcoal, Tar |
| 1 | Lumber | 2 Timber | Sawmill | Tools, Barrels, Muskets, Merchantman, charters |
| 1 | Charcoal | 3 Timber | Charcoal Kiln | Pig Iron (smelting fuel) |
| 1 | Tar & Pitch | 3 Timber | Tar Kiln | Merchantman (naval stores) |
| 1 | Flour | 2 Grain | Gristmill | Provisions |
| 1 | Salt Cod | 2 Cod | Salting House | Provisions |
| 1 | Rope | 2 Hemp | Ropewalk | Merchantman (rigging) |
| 1 | Leather | 2 Hides | Tannery | Saddles, Uniforms |
| 1 | Molasses | 3 Sugar Cane | Boiling House | Rum |
| 1 | Cured Tobacco | 2 Tobacco | Curing Barn | Cigars |
| 1 | Cloth | 2 Cotton | Weaver's House | Sailcloth, Dyed Cloth, Fur Coats |
| 1 | Spermaceti Candles | 2 Whale Oil (sperm whale) | Chandlery | luxury |
| 2 | Pig Iron | 2 Iron Ore + 1 Charcoal | Blast Furnace | Tools, Barrels, Muskets |
| 2 | Provisions | 2 Flour + 2 Salt Cod | Commissary | Merchantman (ship's stores) |
| 2 | Sailcloth | 2 Cloth | Sail Loft | Merchantman |
| 2 | Tools | 1 Pig Iron + 1 Lumber | Blacksmith | Muskets, Merchantman |
| 2 | Barrels | 2 Lumber + 1 Pig Iron (hoops) | Cooperage | Rum |
| 2 | Dyed Cloth | 2 Cloth + 1 Indigo | Dye House | Uniforms |
| 2 | Saddles | 3 Leather | Saddlery | Dragoon Kits |
| 2 | Cigars | 2 Cured Tobacco | Cigar Maker | luxury |
| 2 | Fur Coats | 2 Furs + 1 Cloth | Furrier | luxury |
| 2 | Silverware | 3 Silver | Silversmith | luxury |
| 3 | Rum | 2 Molasses + 1 Barrel | Distillery | luxury |
| 3 | Muskets | 2 Pig Iron + 1 Lumber + 1 Tools | Armory | Dragoon Kits, independence (1 kept) |
| 3 | Uniforms | 2 Dyed Cloth + 1 Leather | Tailor | Dragoon Kits |
| 4 | Merchantman | 40 Lumber, 20 Tar, 20 Rope, 10 Sailcloth, 5 Tools, 10 Provisions | Shipyard | final product |
| 4 | Dragoon Kits | 2 Horses, 2 Saddles, 2 Muskets, 2 Uniforms | Cavalry Barracks | final product |

Sale prices rise roughly 2–3× over the value of the inputs at each step, so
deeper chains pay more. Every map guarantees all 14 raw goods appear among
its 25 colony sites, and iron ore within the first four colonies so the
musket chain is reachable in a first run.

## Founding Fathers

38 real historical figures, all public domain as people; portraits are our
own pixel art. The well-known (Franklin, Jefferson, Washington, both Adamses,
Hamilton, Madison, Paine, Revere, Hancock, Henry, Jay, Lafayette...) sit
alongside figures less often celebrated: Crispus Attucks, Phillis Wheatley,
Haym Salomon, Sybil Ludington, Mary Katherine Goddard, Deborah Sampson, James
Armistead Lafayette, Elizabeth Freeman, Benjamin Banneker, Peter Salem, Nancy
Hart, Mercy Otis Warren, Bernardo de Gálvez, Oliver Pollock and others. Each
run offers four per tier at random.

## What changed from the first version, and why

- **Maps**: fixed map replaced by per-run generation plus North America, per
  direct request (the design doc's "no procedural maps" warning was about the
  original project's fragile runtime placement; this generator is seeded,
  ~80 ms, and covered by tests for route connectivity and resource coverage).
- **Colonies**: from 8 fixed colonies with fixed goods to 25 terrain-driven
  ones. Economic value comes from settlement order so no map is unwinnable.
- **Reforms compound** instead of adding: with additive bonuses the 25-colony
  goal was mathematically out of reach.
- **Pixel density**: the map is rendered by a GPU shader at 16 art pixels per
  tile with relief and animated water; icons are Scale2x-upscaled.
- **Tutorial**: first-run tips, each shown once, can be turned off.

Everything else from the earlier notes still holds: gold not coin; 4-hour
offline cap (+ Franklin / Wilson); the simulation is step-size independent;
Idle Planet Miner inspired the loop but systems are not copied one to one.
