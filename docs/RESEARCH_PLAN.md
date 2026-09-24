# Research Plan: the American Philosophical Society

*Draft for review. Nothing here is built yet.*

## Summary

- **What it is:** an in-run research tree. Franklin founded the American Philosophical Society in 1743 "for promoting useful knowledge", which fits the theme.
- **Resets every expedition:** research is earned again each run, the same way workshops and Founding Fathers are.
- **Paid in goods:** mostly crafted goods, plus some gold. This gives crafted and luxury goods a second use besides selling them or paying Fathers.
- **Size:** 60 studies in 6 branches, 10 studies per branch, arranged in 5 tiers.
- **When it appears:** the Society opens from the 3rd independence onward (`unlock_after_runs.research = 3`). A first run never sees it.

## How it works

- **Where:** a "Society" section at the top of the Workshops tab, or its own screen reached from there. I'd rather not add a sixth tab.
- **What a study costs:** a bundle of goods plus some gold. Costs scale with the colony tier you've reached, like charters do, so late studies need late goods. It completes instantly, so there are no timers to wait on. Research is a place to spend goods, not a clock.
- **Prerequisites:** each study needs the study before it in its branch. Higher tiers also need a number of founded colonies, so the tree unfolds as the run grows:

  | Tier | Colonies needed |
  |---|---|
  | 1 | 1 |
  | 2 | 4 |
  | 3 | 8 |
  | 4 | 12 |
  | 5 | 16 |

- **Keystones:** each branch's capstone at tier 5 needs studies from another branch too, which gives cross-branch goals.
- **Repeatable studies:** most tiers have one "Improved ..." study that can be bought again at ×3 cost each time, for players who run a single expedition for weeks.
- **Effects:** all are multipliers that plug into the existing Balance functions (production, cargo, speed, workshop speed, prices, costs). The design stays one formula per stat.

### Unlocking it: alternatives, pick one

1. **Successive runs (recommended):** it opens at the 3rd independence. This is simple and matches the other unlocks.
2. **A Liberty reform:** a one-time reform called "Enlightenment" at Congress costs Liberty and opens the Society for good.
3. **A governor type:** "Scholar" governors, posted to the capital, open the Society and cut study costs by rank.

(2) and (3) can be layered on top of (1) later.

## The branches

Costs below list the goods; every study also costs gold equal to about 10 minutes of the income expected at that tier. "Tier" means the prerequisite tier above.

### 1. Husbandry and Agriculture (raw crops and livestock)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Crop Rotation | Townshend's four-field system, 1730s | Grain, tobacco, cotton and sugar production ×2 | Flour, Lumber |
| 2 | Seed Drill | Jethro Tull, 1701 | Grain production ×3 | Tools, Flour |
| 3 | Improved Husbandry (repeatable) | | All crop production ×1.5 per level | Provisions |
| 4 | Selective Breeding | Robert Bakewell, 1760s | Horses and hides production ×3 | Saddles, Flour |
| 5 | Indigo Culture | Eliza Lucas Pinckney, 1740s | Indigo production ×3 | Dyed Cloth |
| 6 | Tobacco Inspection Acts | Virginia, 1730 | Tobacco and Cured Tobacco sell ×1.5 | Cured Tobacco, Barrels |
| 7 | The Cotton Gin | Eli Whitney, 1793 | Cotton production ×4 | Tools, Pig Iron |
| 8 | Agricultural Society | Philadelphia Society for Promoting Agriculture, 1785 | Colonists in crop colonies give +150% instead of +100% | Cloth, Provisions |
| 9 | Improved Husbandry II (repeatable) | | Livestock production ×1.5 per level | Leather, Saddles |
| 10 | **Keystone: Bartram's Garden** | North America's first botanic garden, 1728 | Every raw good ×2; needs Harbors of Refuge (Navigation 6) | Silverware, Provisions |

### 2. Forestry and Mining (timber, furs, ore, silver)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Sawpits and Water Saws | Colonial sawmills, 1630s onward | Timber production ×2 | Lumber |
| 2 | Charcoal Hearths | | Charcoal Kiln needs 2 Timber instead of 3 | Lumber, Tools |
| 3 | Improved Felling (repeatable) | | Timber and furs ×1.5 per level | Tools |
| 4 | Beaver Trade Posts | Hudson's Bay and French trade routes | Furs production ×3 | Cloth, Tools |
| 5 | Blast Furnace | Colonial ironworks such as Saugus, 1646 | Iron ore production ×3 | Pig Iron, Charcoal |
| 6 | Assay Office | | Silver sells ×1.5 | Silverware |
| 7 | Naval Stores Act | 1705 bounties on tar and pitch | Tar Kiln works ×3 faster | Tar, Rope |
| 8 | Deep Mining | | Iron and silver production ×3 | Tools, Barrels |
| 9 | Improved Smelting (repeatable) | | Bloomery works ×1.5 faster per level | Pig Iron |
| 10 | **Keystone: The Iron Plantation** | Hopewell Furnace, 1771 | Pig Iron, Tools and Muskets sell ×2; needs Interchangeable Parts (Manufacture 8) | Muskets, Tools |

### 3. Navigation and Shipbuilding (sea routes)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Coastal Pilots | | Sea routes ×1.5 faster | Rope |
| 2 | Copper Sheathing | Royal Navy, 1761 | Ship cargo ×2 | Pig Iron, Tar |
| 3 | Improved Rigging (repeatable) | | Ships ×1.25 faster per level | Rope, Sailcloth |
| 4 | The Quadrant | Godfrey and Hadley, 1730 | Ship cargo ×2 | Tools, Silverware |
| 5 | Lighthouses | Boston Light, 1716 | Sea round trips ×1.5 faster | Lumber, Candles |
| 6 | Harbors of Refuge | | Sea colonies' goods pile-up limit doubled | Lumber, Rope |
| 7 | Fast Schooners | Marblehead and Gloucester schooners | Ships ×2 faster | Sailcloth, Lumber |
| 8 | Sea Charts | Des Barres, *The Atlantic Neptune*, 1777 | Sea routes count 25% shorter | Candles, Cloth |
| 9 | Improved Hulls (repeatable) | | Ship cargo ×1.5 per level | Tar, Lumber |
| 10 | **Keystone: The China Trade** | *Empress of China*, 1784 | Every sea colony ×2 production; Europe's wanted goods sell ×2.2 instead of ×1.6; needs Bills of Exchange (Commerce 5) | Merchantman |

### 4. Roads and the Frontier (land routes)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Blazed Trails | | Wagons ×1.5 faster | Lumber |
| 2 | Corduroy Roads | Logs laid across mud | Marsh and forest cost less to cross | Lumber, Timber |
| 3 | Improved Wagons (repeatable) | | Wagon cargo ×1.5 per level | Lumber, Pig Iron |
| 4 | The Conestoga Wagon | 1750s | Wagon cargo ×2 | Barrels, Leather |
| 5 | Post Roads | Boston Post Road; Franklin as Postmaster | Wagons ×2 faster | Tools, Saddles |
| 6 | Ferries and Bridges | | Land routes count 25% shorter | Lumber, Rope |
| 7 | The Great Wagon Road | Philadelphia to the backcountry | Every land colony +50% production | Provisions, Leather |
| 8 | Turnpikes | Lancaster Turnpike, 1795 | Wagons ×2 faster | Pig Iron, Tools |
| 9 | Improved Teams (repeatable) | | Wagons ×1.25 faster per level | Horses, Saddles |
| 10 | **Keystone: The Wilderness Road** | Daniel Boone, 1775 | Every land colony ×2 production and explore radius +25%; needs Agricultural Society (Husbandry 8) | Dragoons |

### 5. Manufacture (workshops)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Apprenticeships | | All workshops ×1.25 faster | Lumber, Flour |
| 2 | Guild Standards | | Crafted goods sell ×1.2 | Cloth, Tools |
| 3 | Improved Benches (repeatable) | | All workshops ×1.2 faster per level | Tools |
| 4 | The Flying Shuttle | John Kay, 1733 | Weaver's House and Sail Loft ×3 faster | Cloth, Tools |
| 5 | Spinning Jenny | Hargreaves, 1764 | Cloth needs 1 Cotton instead of 2 | Cloth, Pig Iron |
| 6 | Cooper's Guild | | Barrels need 1 Lumber instead of 2 | Barrels, Tools |
| 7 | Water-Powered Mills | Slater Mill, 1793 | Every workshop with 5 or more colonists works ×1.5 faster | Lumber, Pig Iron, Tools |
| 8 | Interchangeable Parts | Eli Whitney's muskets, 1798 | Armory and Blacksmith ×3 faster | Muskets, Tools |
| 9 | Improved Workshops II (repeatable) | | Every crafted good sells ×1.2 per level | Candles, Cigars |
| 10 | **Keystone: The Manufactory** | | Each workshop gets one free colonist of labour; needs Crop Rotation, Sawpits and Blazed Trails | Merchantman, Dragoons |

### 6. Commerce and Statecraft (money, colonists, Congress)

| # | Study | Historical hook | Effect | Cost |
|---|---|---|---|---|
| 1 | Coffee House Exchange | London Coffee House, Philadelphia, 1754 | Market gluts sell at ×0.8 instead of ×0.6 | Flour, Rum |
| 2 | Printing Press | Franklin and Hall, 1748 | Founding Fathers cost 25% less gold | Candles, Cloth |
| 3 | Improved Trade (repeatable) | | All sale prices ×1.15 per level | Rum, Cigars |
| 4 | Land Office | | Colonies cost 25% less | Silverware, Lumber |
| 5 | Bills of Exchange | | Warehouse goods count toward Father and charter costs at ×1.25 | Silverware |
| 6 | Emigration Societies | | Colonists cost 25% less | Provisions, Cloth |
| 7 | Bank of North America | Robert Morris, 1781 | Held gold earns 1% of income per minute, capped at 1 hour of income | Silverware, Rum |
| 8 | Committees of Correspondence | 1772 | Royal Favor lasts twice as long | Candles, Silverware |
| 9 | Improved Statecraft (repeatable) | | Liberty at independence ×1.1 per level | Muskets, Uniforms |
| 10 | **Keystone: The Continental Congress** | 1774 | Liberty at independence ×1.5 and a guaranteed extra relic; needs Assay Office (Forestry 6) | Uniforms, Dragoons, Silverware |

## Counts and balance

- **Size:** 60 studies. 12 of them are repeatable, so dedicated players always have a place to spend.
- **Early and late:** tiers 1–2 use only Lumber, Flour, Cloth and Tools, so they're open by the second hour of a run. Keystones need the finished goods (Merchantman, Dragoons) that only long runs produce.
- **Balance approach:** I'd expect a completed tree to multiply income by about 10⁴–10⁶, similar to a few Liberty reform levels. The bot will be extended to buy studies so pacing can be checked. The target is still first independence in about 3 hours and 25 colonies over weeks.
- **Stats:** the Ledger tracks studies completed, per run and all-time.

## Questions for you

1. Is unlocking at the 3rd independence fine, or would you prefer the Liberty reform or Scholar governor route?
2. Should studies be instant when paid for, or take a short real-time study period (1–30 minutes)? I recommend instant.
3. Keep the repeatable "Improved ..." studies?
4. Any historical figures or inventions you'd like added? The list stays within public-domain history before 1800.
