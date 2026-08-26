# Colonial Idle — Game Design Specification

**Engine:** Godot 4.x
**Genre:** Idle / incremental with prestige
**Reference:** *Idle Planet Miner*, reskinned as colonial-era Atlantic trade
**Status:** Design locked. Ready for implementation.

---

## 1. One-Paragraph Summary

The player founds a coastal colony in the New World, extracts a raw resource, and ships it home to Europe for currency. Currency buys new colonies farther afield, each producing a more valuable resource. Raw goods can be sold as-is or reserved and crafted into finished products worth far more. Colonists are a scarce shared pool split between extraction and crafting. When accumulated wealth crosses a threshold, the player **Declares Independence** — wiping the run in exchange for **Liberty**, a permanent currency that buys upgrades making the next run faster.

---

## 2. Core Loop

```
Colonies produce raw goods (idle, continuous)
        ↓
Transport links carry goods inward to the Capital (batched, timed)
        ↓
Capital warehouse holds everything that has arrived
        ↓
Each resource is routed: SELL (auto-converts to coin) or RESERVE (held for crafting)
        ↓
Crafting screen consumes reserved goods → finished products → sold for more coin
        ↓
Coin buys: new colonies, colonists, building levels, transport upgrades
        ↓
Lifetime earnings cross threshold → DECLARE INDEPENDENCE
        ↓
Run wipes. Liberty earned. Permanent upgrades purchased. Repeat, faster.
```

---

## 3. Locked Design Decisions

| Decision | Choice |
|---|---|
| Production model | Pure idle. No tapping required. |
| Offline progress | Capped at 4 hours real time. |
| Colony management | Colonists (assignable) **and** building levels (coin-bought). |
| Selling | Auto-sell at Capital, per-resource Sell/Reserve toggle, manual "Sell All" available. |
| Prices | Fixed base price per good. Only prestige upgrades multiply value. |
| Storage | Unlimited. |
| Colony acquisition | Bought with coin, escalating cost, fixed order. |
| Run variety | Each colony rolls **land route** or **sea route** at run start. |
| Topology | Hub and spoke. All colonies ship to the Capital. Capital sells to Europe. |
| Crafting location | Abstract crafting screen. Inputs must have physically arrived at the Capital. |
| Recipe depth | Mixed — early recipes are 1-step, late recipes chain 2-3 deep. |
| Crafting speed | Staffed colonists × workshop level. |
| Prestige gate | Lifetime earnings threshold. |
| Prestige payout | Scales off lifetime coin earned that run. |
| Reset scope | Full wipe. Only permanent upgrades survive. |
| Permanent upgrades | Production multipliers, transport speed/cargo, cheaper colonies & colonists. |
| Target run length | 2–4 hours for the first run. |
| v1 scope | 8 colonies, 10 recipes. |

---

## 4. The Central Tension

**Every colonist is either producing raw goods or converting them.**

Staff the plantations and tobacco piles up with nobody to roll it into cigars. Staff the workshops and they starve waiting on inputs. Each new colony that comes online shifts the correct ratio, forcing the player to rebalance.

Secondary tension: **Sell vs. Reserve.** Every barrel reserved for crafting is coin you are not earning right now, in exchange for more coin later. Reserved goods also don't consume cargo space, so reserving relieves transport pressure.

Tertiary tension: **Transport is a bottleneck.** A colony can out-produce its route. When it does, goods accumulate at the colony and the correct purchase is a wagon or ship upgrade, not another colonist.

---

## 5. Colonies

Eight colonies. Fixed order and fixed resource. Only the route type varies per run.

| # | Colony | Resource | Base £/unit | Distance | Cost to Found |
|---|---|---|---|---|---|
| 1 | Tidewater Landing *(Capital)* | Timber | 1 | 0 | Free (start) |
| 2 | Cape Harbour | Cod | 4 | 1 | £250 |
| 3 | Chesapeake Fields | Tobacco | 14 | 2 | £3,000 |
| 4 | Carolina Flats | Cotton | 45 | 3 | £40,000 |
| 5 | Ironworks Hollow | Iron Ore | 150 | 4 | £500,000 |
| 6 | Indigo Reach | Indigo | 480 | 5 | £6,500,000 |
| 7 | Sugar Isle | Sugar Cane | 1,600 | 6 | £85,000,000 |
| 8 | Northern Traces | Furs | 5,200 | 7 | £1,100,000,000 |

**Founding cost curve:** roughly ×13 per colony. Tune against playtest, but keep the ratio consistent so the pacing feels regular.

### Route Type (the per-run variable)

At run start, each non-Capital colony rolls land or sea, 50/50.

| | Land Route | Sea Route |
|---|---|---|
| Cargo capacity | 20 units × level | 50 units × level |
| Round trip time | `distance × 12s` | `distance × 22s` |
| Feel | Steady trickle, smooth income | Lumpy, large deposits |
| Throughput at distance 3 | 20 / 36s = 0.56/s | 50 / 66s = 0.76/s |

Sea routes have higher raw throughput but worse responsiveness — you wait longer for the first shipment and a full hold sits idle mid-voyage. Land routes suit crafting chains that need a steady input feed. **This is the only source of run-to-run variety, and it is deliberately small.** No procedural map generation. No terrain. A boolean per colony.

---

## 6. Formulas

Keep every one of these in a single `Balance` autoload so tuning never requires touching logic.

### Production
```
colony_rate = base_rate
            × colonists_assigned
            × (1 + 0.25 × building_level)
            × prestige_production_multiplier
```
`base_rate` = 1.0 units/sec for all colonies. Value differentiation comes from price, not speed.

### Transport
```
cargo_capacity  = route_base_cargo × (1 + 0.5 × transport_level) × prestige_cargo_mult
round_trip_time = distance × route_time_factor / prestige_speed_mult
```
A shipment departs when the hold is full **or** 30 seconds have elapsed with cargo aboard, whichever comes first. This prevents a slow early colony from never delivering.

### Crafting
```
craft_time_per_unit = recipe_base_time / (colonists_staffed × (1 + 0.3 × workshop_level))
```
Crafting halts when inputs are unavailable and resumes automatically.

### Costs
```
colonist_cost      = 25 × 1.15^(colonists_owned)  × prestige_colonist_discount
building_cost      = 40 × 1.13^(current_level)
transport_cost     = 60 × 1.16^(current_level)
workshop_cost      = 100 × 1.14^(current_level)
colony_cost        = table above × prestige_colony_discount
```

### Prestige
```
Gate:    lifetime_coin_this_run >= £2,000,000,000
Payout:  liberty = floor( 6 × sqrt( lifetime_coin_this_run / 2e9 ) )
```
First-run payout lands at 6 Liberty. Doubling earnings gives ~8.5, so the curve rewards pushing past the gate but with diminishing returns — the player is nudged to reset rather than grind.

---

## 7. Resources & Recipes

### Raw Goods
Timber (£1), Cod (£4), Tobacco (£14), Cotton (£45), Iron Ore (£150), Indigo (£480), Sugar Cane (£1,600), Furs (£5,200)

### Recipes (10)

| # | Product | Inputs | Base Time | Sale £ | Input £ | Margin |
|---|---|---|---|---|---|---|
| 1 | Planks | 2 Timber | 2.0s | £4 | £2 | ×2.0 |
| 2 | Salt Cod | 3 Cod | 2.5s | £18 | £12 | ×1.5 |
| 3 | Cigars | 3 Tobacco | 3.0s | £70 | £42 | ×1.7 |
| 4 | Cloth | 3 Cotton | 3.0s | £230 | £135 | ×1.7 |
| 5 | Pig Iron | 2 Iron Ore | 3.5s | £520 | £300 | ×1.7 |
| 6 | Barrels | 2 Planks + 1 Pig Iron | 5.0s | £1,400 | £528 | ×2.7 |
| 7 | Dyed Cloth | 2 Cloth + 2 Indigo | 5.5s | £2,700 | £1,420 | ×1.9 |
| 8 | Tools | 3 Pig Iron + 1 Planks | 6.0s | £4,800 | £1,564 | ×3.1 |
| 9 | Rum | 4 Sugar Cane + 1 Barrels | 7.0s | £14,000 | £7,800 | ×1.8 |
| 10 | **Muskets** | 2 Tools + 2 Planks | 9.0s | £38,000 | £9,608 | ×4.0 |

Recipes 1–5 are single-step and unlock alongside their source colony. Recipes 6–10 consume crafted components, so they force the player to reserve *finished* goods rather than selling them — the first genuinely interesting economic decision in the game.

**Muskets are the final good.** Thematically, arming the colonies is what makes independence possible. Consider gating the Declare Independence button on having crafted at least one Musket in addition to the earnings threshold — it gives the finale a narrative beat instead of a number crossing a line.

---

## 8. Prestige: Declaring Independence

### Presentation
A dedicated screen, unlocked once the threshold is met. Show projected Liberty, what will be lost, what will be kept, and require a confirmation. This is the emotional peak of the loop — give it a moment. Text, a seal, a signature animation. Do not make it a grey button in a settings menu.

### Upgrade Tree

Three branches. Costs escalate `base × 1.8^level`.

**Industry** — *the colonies grow productive*
| Level | Effect | Liberty |
|---|---|---|
| 1–10 | +15% production rate per level (additive) | 3, 5, 9, 17, 30, 55, 99, 178, 320, 576 |

**Navigation** — *the sea lanes open*
| Level | Effect | Liberty |
|---|---|---|
| 1–8 | +12% transport speed **and** +12% cargo per level | 4, 7, 13, 23, 42, 76, 137, 246 |

**Settlement** — *word of the New World spreads*
| Level | Effect | Liberty |
|---|---|---|
| 1–8 | −7% colonist and colony cost per level (multiplicative, floors at −60%) | 5, 9, 16, 29, 52, 94, 169, 305 |

First reset (~6 Liberty) buys Industry 1 and Navigation 1, or Settlement 1. Meaningful but not transformative — correct for a first prestige.

---

## 9. Save Structure

**This is the architectural decision that cannot be retrofitted. Build it this way from the first commit.**

```json
{
  "version": 1,
  "meta": {
    "liberty": 0,
    "lifetime_liberty_earned": 0,
    "upgrades": { "industry": 0, "navigation": 0, "settlement": 0 },
    "runs_completed": 0,
    "recipes_ever_unlocked": [],
    "stats": { "best_run_coin": 0, "fastest_run_seconds": 0 }
  },
  "run": {
    "started_at_unix": 0,
    "coin": 0,
    "lifetime_coin_this_run": 0,
    "colonists_owned": 0,
    "colonies": [
      {
        "id": "tidewater_landing",
        "founded": true,
        "route_type": "land",
        "colonists": 0,
        "building_level": 0,
        "transport_level": 0,
        "local_stock": 0.0,
        "cargo_in_transit": 0.0,
        "transit_timer": 0.0
      }
    ],
    "warehouse": { "timber": 0.0, "cod": 0.0 },
    "routing": { "timber": "sell", "tobacco": "reserve" },
    "workshops": [
      { "recipe_id": "planks", "unlocked": true, "colonists": 0, "level": 0, "progress": 0.0 }
    ]
  },
  "last_seen_unix": 0
}
```

**Declaring Independence deletes `run` entirely and regenerates it from defaults.** `meta` is never touched except to add Liberty and increment counters. Never let a field live in the wrong object — if you find yourself wanting a run value to persist, it belongs in `meta` and needs a design decision, not a hack.

---

## 10. Godot Implementation Notes

### Architecture
- **`GameState`** (autoload) — owns the save dictionary, nothing else touches it directly
- **`Simulation`** (autoload) — the tick loop, pure logic, no node references
- **`Balance`** (autoload) — every constant and formula from §6
- **`ContentDB`** (autoload) — loads colony and recipe definitions from `res://data/*.json`

Keep static content (colony table, recipe table) in JSON files, not hardcoded. You will retune these dozens of times, and editing JSON doesn't require a recompile or risk breaking logic.

### Tick Loop
Run the simulation on a fixed accumulator, independent of frame rate:

```gdscript
const TICK := 0.1
var _accum := 0.0

func _process(delta: float) -> void:
    _accum += delta
    while _accum >= TICK:
        _accum -= TICK
        Simulation.step(TICK)
```

UI reads state and redraws; UI never mutates state except through explicit command functions.

### Offline Catch-Up
On load, compute `elapsed = min(now - last_seen_unix, 14400)` (4 hours). Because transport is batched, an analytic solution is fiddly — just step the same simulation coarsely:

```gdscript
var remaining := elapsed
while remaining > 0.0:
    var step := min(remaining, 5.0)
    Simulation.step(step)
    remaining -= step
```
At 5-second steps, 4 hours is 2,880 iterations. Trivial. Then show a summary popup: goods produced, coin earned, shipments landed.

**Verify:** the simulation must be correct at any step size. Write a test that runs 3,600 × 1s steps and 720 × 5s steps and asserts both produce the same coin within a small epsilon. If they diverge, something in the sim depends on tick count rather than elapsed time — find it before building anything on top.

### Screens
1. **Colony Map** — list or simple map of colonies, each showing resource, rate, colonists, stock, and route status
2. **Colony Detail** — assign colonists, buy building levels, buy transport levels
3. **Crafting** — recipe list, staff and upgrade, live input availability
4. **Market** — warehouse contents, Sell/Reserve toggles, prices, Sell All
5. **Independence** — progress toward threshold, projected Liberty, the button
6. **Upgrades** — the three-branch permanent tree

A list-based colony view is entirely sufficient for v1. A pretty map is a later polish pass, not a prerequisite.

---

## 11. Build Order

Each phase should end with the game running and zero errors. Do not start a phase before the previous one is stable.

**Phase 1 — Skeleton**
Project setup, the four autoloads, save/load to `user://`, the tick loop, and the step-size equivalence test. No gameplay. Prove the save round-trips and the clock is correct.

**Phase 2 — One Colony**
Capital only. Timber production, warehouse accumulation, auto-sell, coin counter. Ugly UI. This is the smallest thing that is recognizably the game.

**Phase 3 — Colonists & Buildings**
Buy colonists, assign them, buy building levels. Cost curves live. Verify the numbers feel right before adding anything else — if the first 10 minutes are boring here, more content will not fix it.

**Phase 4 — Colonies & Transport**
Found colonies 2–8. Route type rolls at run start. Batched shipments with cargo and timers. Transport upgrades. Offline catch-up.

**Phase 5 — Crafting**
Sell/Reserve routing. Crafting screen, all 10 recipes, staffing, workshop levels. Component chains.

**Phase 6 — Prestige**
Threshold detection, Independence screen, Liberty formula, wipe-and-rebuild, the upgrade tree. Test the wipe hard — it is the most dangerous code in the project.

**Phase 7 — Feel**
Number formatting (£1.2M, not £1200000), notifications when shipments land, offline summary, a real Independence sequence, sound, save-corruption handling.

---

## 12. Deliberately Out of Scope for v1

- Procedural map generation *(the reason the original project stalled — do not revisit)*
- Fluctuating prices or market simulation
- Colonist types, specializations, or individual identities
- Historical events, random events, or narrative beyond the Independence beat
- Multiple simultaneous save slots
- Any real map rendering — a list view ships v1

---

## 13. Open Questions

1. **Does the Capital produce?** Currently yes (Timber, distance 0, instant delivery). Alternative: it's purely a hub and the player's first *producing* colony is #2. Hub-only is thematically tidier; producing is a gentler tutorial.
2. **Should Muskets gate independence** in addition to the earnings threshold? Recommended — see §7.
3. **Colonist cap?** Currently unbounded, limited only by cost. A soft cap per colony would add placement decisions but also friction. Suggest leaving uncapped for v1.
4. **Do reserved goods still ship?** Currently yes — routing is applied at the Capital, so goods must arrive before being reserved. Confirm this is intended; the alternative (reserve at the colony, skip transport) would trivialize the transport bottleneck.
