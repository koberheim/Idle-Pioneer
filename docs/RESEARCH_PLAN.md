# Research Plan: the American Philosophical Society

*Approved — implemented. The tree lives in `data/research.json` and is checked by `tools/validate_research.py`.*

## Decisions

The four open questions from the draft have been answered:

1. **Unlock:** the Society opens at the 3rd independence (`unlock_after_runs.research = 3`). A first run never sees it.
2. **Timing:** studies finish instantly when paid for. There are no timers.
3. **Repeatables:** kept. Each branch has two "Improved ..." studies that can be bought again and again (`research_repeat_cost_growth` = ×3 cost per level).
4. **Shape:** each branch has a main line from tier 1 to a tier-6 keystone, plus 2–3 optional **side paths** that fork off the main line. Side paths never lock anything out and never need to rejoin: all of them can be completed in a run. There are no either/or studies (`excludes` is always empty).

## Summary

- **What it is:** an in-run research tree. Franklin founded the American Philosophical Society in 1743 "for promoting useful knowledge", which fits the theme.
- **Resets every expedition:** research is earned again each run, the same way workshops and Founding Fathers are.
- **Paid in goods:** every study costs 2–3 kinds of goods; the engine adds gold (`research_gold_seconds`, about 10 minutes of income) and scales the amounts with colonies founded (`research_scale_per_colony`). This gives crafted and luxury goods a second use besides selling them or paying Fathers.
- **Size:** 102 studies in 6 branches (14–18 each), 12 of them repeatable.
- **History:** every study is a real, public-domain event, person, place or invention from before 1800, with a one-line hook (150 characters at most). Where a date is uncertain the hook gives a decade or says "around".

## How it works

- **Tiers** open with colonies founded (enforced by the engine, not the data):

  | Tier | Colonies needed |
  |---|---|
  | 1 | 1 |
  | 2 | 4 |
  | 3 | 8 |
  | 4 | 12 |
  | 5 | 16 |
  | 6 | 20 |

- **Per branch:** a main line (tier 1 start and a tier-1 repeatable, one study each at tiers 2–5 plus a tier-5 repeatable, then the tier-6 keystone) and 2–3 side paths of 3–5 studies each. A side path forks off one main-line study and ends in a strong study of its own.
- **Requirements:** `requires` means all listed studies; `requires_any` (unused for now) means at least one. A requirement is always of a lower tier.
- **Keystones:** each keystone needs the last main-line study of its branch plus one study from another branch, which gives cross-branch goals:
  - Bartram's Garden (Husbandry) needs The Cumberland Gap (Roads)
  - Hopewell Furnace (Forestry) needs The Conestoga Wagon (Roads)
  - The China Trade (Navigation) needs the Bank of North America (Commerce)
  - The Wilderness Road (Roads) needs Selective Breeding (Husbandry)
  - Society for Useful Manufactures (Manufacture) needs The Iron Act (Forestry)
  - The Continental Congress (Commerce) needs Postmaster Franklin (Roads)
- **Effects** are multipliers that plug into the existing Balance functions: `production`, `sell`, `workshop_speed`, `recipe_input`, `speed`, `cargo`, `route_length`, `colonist_bonus`, the cost reducers (`colony_cost`, `colonist_cost`, `father_cost`, `charter_cost`, `workshop_cost`), `market_glut`, `market_wanted`, `favor_duration`, `liberty`, `explore`, `treasure`, `offline_hours`, `workshop_labour` and `extra_relic`. Repeatables compound per level.
- **Early and late:** tiers 1–2 cost raw goods and tier-1 crafted goods (lumber, flour, cloth, rope, leather, salt cod, charcoal), so they open in the first hour of a run and are broadly useful. Tier 3 uses tools, pig iron, barrels, sailcloth, provisions and the like; tiers 4–5 use candles, silverware, rum, cigars, muskets and uniforms; keystones need Merchantmen and/or Dragoons plus a luxury.

## The branches

Costs list goods only; the engine adds gold and scales every amount by colonies founded.

### 1. Husbandry & Agriculture

Fields, seed and livestock: the raw crops and herds of the colonies. Side paths: **A Staple Crops**, **B The Herd**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | Crop Rotation | 1730: Charles 'Turnip' Townshend retired to Norfolk in 1730 and championed a four-field rotation of wheat, turnips, barley and clover. | Grain, tobacco, cotton and sugar cane production x2 | 40 Flour, 30 Lumber |
| 1 | main | Improved Husbandry (repeatable) | 1731: Jethro Tull's book Horse-Hoeing Husbandry (1731) urged farmers to till between drilled rows; it was argued over for decades. | Crop and livestock production x1.25 per level | 30 Flour, 20 Leather |
| 2 | main | The Seed Drill | 1701: Around 1701 Jethro Tull built a horse-drawn seed drill that sowed seed in straight rows instead of scattering it by hand. | Grain production x3 | 60 Flour, 50 Lumber |
| 3 | main | Diversified Farms | 1766: By 1766 George Washington had given up tobacco at Mount Vernon for wheat, and later milled his own flour for market. | Grain, hemp, horse and hide production x2 | 40 Provisions, 30 Barrels |
| 4 | main | Society for Promoting Agriculture | 1785: The Philadelphia Society for Promoting Agriculture, founded in 1785, offered premiums for farm experiments and reports. | Colonists in farm colonies give +175% instead of +100% | 50 Tools, 25 Silverware |
| 5 | main | Mouldboard of Least Resistance | 1794: In 1794 Jefferson worked out a 'mouldboard of least resistance' for the plough and later described it to the Philosophical Society. | Crop and livestock production x2 | 100 Tools, 30 Silverware |
| 5 | main | Improved Seed Stock (repeatable) | 1786: From 1786 George Washington traded letters, seed and farming advice with the English agriculturist Arthur Young. | Crop and livestock production x1.2 per level | 20 Silverware, 15 Rum |
| 6 | main | **Keystone: Bartram's Garden** | 1728: John Bartram planted his garden beside the Schuylkill in 1728; it is the oldest surviving botanic garden in North America. | Every colony's production x2; also needs The Cumberland Gap (Roads & the Frontier) | 6 Merchantman, 40 Silverware |
| 2 | A Staple Crops | Tobacco Inspection Act | 1730: Virginia's Tobacco Inspection Act of 1730 sent every hogshead through public warehouses, where inspectors burned trash leaf. | Tobacco, cured tobacco and cigars sell x2 | 40 Cured Tobacco, 30 Lumber |
| 3 | A Staple Crops | Carolina Indigo | 1744: Eliza Lucas, running her family's South Carolina plantations from age 16, proved indigo as a crop there in the early 1740s. | Indigo production x3 | 40 Dyed Cloth, 30 Barrels |
| 4 | A Staple Crops | Aboiteaux | 1650: From the mid-1600s Acadian farmers on the Bay of Fundy diked the salt marshes, draining them through hinged sluices called aboiteaux. | Marsh crops (indigo, hemp, sugar cane) production x3 | 60 Tools, 20 Candles |
| 5 | A Staple Crops | The Cotton Gin | 1793: Eli Whitney's gin of 1793 stripped seed from short-staple cotton at speed; it also deepened the South's reliance on slavery. | Cotton production x4 | 80 Tools, 20 Silverware |
| 3 | B The Herd | Selective Breeding | 1760: From 1760 Robert Bakewell of Dishley, Leicestershire, bred sheep, cattle and heavy horses to a plan, keeping careful records. | Horse production x3 | 40 Saddles, 30 Provisions |
| 4 | B The Herd | Mission Ranchos | 1769: Spanish missions in Texas and, from 1769, in California grazed great herds of cattle and horses on the open range. | Hide production x3 | 60 Saddles, 15 Silverware |
| 4 | B The Herd | The Narragansett Pacer | 1750: Rhode Island's Narragansett Pacer, a smooth-gaited saddle horse, was prized in the 1700s from New England to the West Indies. | Horses, leather and saddles sell x2 | 25 Rum, 30 Tools |
| 5 | B The Herd | Royal Gift | 1785: In 1785 Charles III of Spain sent George Washington a prize jack donkey, Royal Gift; Mount Vernon's mules followed. | Colonists in horse and hide colonies give +250% instead of +100% | 60 Saddles, 25 Silverware |

### 2. Forestry & Mining

Timber, furs, ore and silver: the wealth of the woods and hills. Side paths: **A The Pineries**, **B The Fur Trade**, **C Silver of New Spain**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | Water Sawmills | 1634: One of the first sawmills in the colonies turned on the Great Works River at Berwick, Maine, in the 1630s. | Timber production x2 | 40 Lumber, 20 Flour |
| 1 | main | Improved Felling (repeatable) | 1750: Over the 1700s colonial smiths gave the felling axe a heavy poll for balance, making the 'American axe'. | Timber, furs, ore and silver production x1.25 per level | 30 Lumber, 30 Charcoal |
| 2 | main | Saugus Iron Works | 1646: Around 1646 the Company of Undertakers began smelting iron at Hammersmith, now Saugus, Massachusetts. | Charcoal Kiln and Blast Furnace work x2 faster | 60 Charcoal, 40 Lumber |
| 3 | main | Cornwall Ore Banks | 1735: Peter Grubb began working the Cornwall ore banks in Pennsylvania in the 1730s; the mine ran until 1973. | Iron ore production x3 | 40 Tools, 30 Pig Iron |
| 4 | main | The Iron Act | 1750: The Iron Act of 1750 let colonial pig and bar iron into Britain duty-free, but banned new slitting mills and steel furnaces. | Pig iron and tools sell x2.5 | 50 Tools, 10 Muskets |
| 5 | main | The Schuyler Engine | 1755: In 1755 Josiah Hornblower set a Newcomen engine pumping the Schuyler copper mine in New Jersey, the first steam engine in North America. | Iron ore and silver production x3 | 80 Tools, 20 Muskets |
| 5 | main | Improved Smelting (repeatable) | 1757: Henry William Stiegel's Elizabeth Furnace in Lancaster County was casting iron stoves by the late 1750s. | Charcoal Kiln, Blast Furnace and Blacksmith x1.2 faster per level | 80 Pig Iron, 15 Rum |
| 6 | main | **Keystone: Hopewell Furnace** | 1771: Mark Bird founded Hopewell Furnace in Pennsylvania in 1771; during the Revolution it cast cannon and shot for the Continental Army. | Timber, furs, iron ore and silver production x3; also needs The Conestoga Wagon (Roads & the Frontier) | 6 Dragoons, 30 Silverware |
| 2 | A The Pineries | The Wind Sawmill | 1594: Cornelis Corneliszoon patented a wind-driven sawmill in Holland in 1594; the Dutch later carried sawmills to New Netherland. | Sawmill works x3 faster | 50 Lumber, 20 Cloth |
| 3 | A The Pineries | Naval Stores Act | 1705: The Naval Stores Act of 1705 paid bounties on colonial tar, pitch, turpentine, hemp and masts for the Royal Navy. | Tar Kiln works x3 faster | 40 Barrels, 20 Provisions |
| 4 | A The Pineries | The King's Broad Arrow | 1691: The 1691 Massachusetts charter reserved the great white pines for Royal Navy masts; surveyors blazed them with a broad arrow. | Timber, lumber and tar sell x2.5 | 50 Tools, 15 Rum |
| 5 | A The Pineries | Live Oak Frames | 1795: The frames of the frigate Constitution were cut from live oak on St. Simons Island, Georgia, in the mid-1790s. | Timber production x4 | 20 Muskets, 25 Rum |
| 2 | B The Fur Trade | Hudson's Bay Company | 1670: Chartered in 1670, the Hudson's Bay Company traded cloth, kettles and tools to Cree and other hunters for beaver pelts. | Fur production x3 | 50 Cloth, 30 Lumber |
| 3 | B The Fur Trade | Fort Orange | 1624: From the Dutch post of Fort Orange, founded in 1624, Albany grew into the fur-trading heart of New York. | Furrier works x3 faster | 30 Dyed Cloth, 30 Tools |
| 4 | B The Fur Trade | Grand Portage | 1779: Montreal's North West Company, formed in 1779, met its canoe brigades each summer at Grand Portage on Lake Superior. | Furs and fur coats sell x3 | 40 Fur Coats, 30 Tools |
| 3 | C Silver of New Spain | The Patio Process | 1554: At Pachuca in 1554 Bartolome de Medina's patio process used mercury to draw silver from ore, powering New Spain's mines. | Silver production x3 | 40 Tools, 30 Provisions |
| 4 | C Silver of New Spain | The Mexico City Mint | 1535: The Mexico City mint, founded in 1535, was the first in the Americas; its silver dollars became the colonies' everyday coin. | Silver and silverware sell x2.5 | 30 Silverware, 30 Tools |
| 5 | C Silver of New Spain | La Valenciana | 1768: Guanajuato's La Valenciana mine, opened in the 1760s, was by the 1790s among the richest silver mines in the world. | Silver production x4 | 80 Tools, 15 Rum |

### 3. Navigation & Shipbuilding

Faster hulls, better charts and fuller holds on the sea routes. Side paths: **A The Fisheries**, **B Coastal Survey**, **C The Carrying Trade**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | The Schooner | 1713: Tradition says Andrew Robinson of Gloucester launched the first schooner in 1713; the handy fore-and-aft rig spread along the coast. | Ships sail x1.5 faster | 40 Lumber, 30 Rope |
| 1 | main | Improved Rigging (repeatable) | 1750: Ropewalks, long sheds where hemp was walked and twisted into cordage, lined Boston's waterfront through the 1700s. | Ships sail x1.2 faster per level | 40 Rope, 20 Tar & Pitch |
| 2 | main | The Reflecting Quadrant | 1731: Thomas Godfrey of Philadelphia and John Hadley of London each devised a reflecting quadrant around 1730-31. | Sea routes count 15% shorter | 40 Lumber, 20 Candles |
| 3 | main | Copper Sheathing | 1761: HMS Alarm was sheathed in copper in 1761 as a trial; the clean hull kept off shipworm and weed and sailed faster. | Ships sail x2 faster | 40 Pig Iron, 30 Sailcloth |
| 4 | main | American-Built Hulls | 1770: By the 1770s perhaps a third of Britain's merchant ships had been built in American yards, of plentiful oak and pine. | Ships carry x2 cargo | 50 Tools, 50 Sailcloth |
| 5 | main | The Lighthouse Act | 1789: The ninth act of the first Congress, in August 1789, put the nation's lighthouses, beacons and buoys under federal care. | Ships sail x2 faster | 80 Candles, 20 Rum |
| 5 | main | Improved Hulls (repeatable) | 1794: Joshua Humphreys designed the long, stoutly built frigates ordered under the Naval Act of 1794, among them Constitution. | Ships carry x1.2 cargo per level | 60 Tools, 15 Rum |
| 6 | main | **Keystone: The China Trade** | 1784: The Empress of China sailed from New York in February 1784, the first American ship to trade at Canton. | Colonies on sea routes produce x3; also needs Bank of North America (Commerce & Statecraft) | 10 Merchantman, 40 Silverware |
| 2 | A The Fisheries | The Grand Banks | 1750: In the mid-1700s Marblehead was among the busiest fishing ports in the colonies, sending its schooners to the Grand Banks. | Cod production x3 | 50 Salt Cod, 30 Rope |
| 3 | A The Fisheries | Nantucket Whaling | 1715: From the 1710s Nantucket whalers hunted sperm whales in deep water; by the 1760s they boiled oil in try-works on deck. | Whale oil production x3 | 40 Barrels, 30 Provisions |
| 4 | A The Fisheries | Spermaceti Chandlers | 1761: In 1761 New England and Philadelphia candle makers formed the United Company of Spermaceti Chandlers to fix prices. | Whale oil and candles sell x2.5 | 50 Candles, 30 Tools |
| 5 | A The Fisheries | Fishing Rights | 1783: John Adams insisted on, and won in the 1783 Treaty of Paris, American fishing rights on the Grand Banks. | Colonies on sea routes produce x2 | 25 Silverware, 25 Rum |
| 3 | B Coastal Survey | Boston Light | 1716: Boston Light on Little Brewster Island, first lit in September 1716, was the first lighthouse in the British colonies. | Ships sail x1.5 faster | 40 Candles, 30 Tools |
| 4 | B Coastal Survey | Chart of the Gulf Stream | 1770: Franklin and his cousin Timothy Folger, a Nantucket captain, charted the Gulf Stream; the chart was printed around 1769-70. | Sea routes count 20% shorter | 40 Candles, 15 Silverware |
| 5 | B Coastal Survey | The Atlantic Neptune | 1777: J.F.W. Des Barres's Atlantic Neptune, charts made for the Admiralty in the 1770s and 80s, mapped the coast in rich detail. | Sea routes count 30% shorter | 60 Candles, 30 Silverware |
| 3 | C The Carrying Trade | Letters of Marque | 1776: From 1776 Congress licensed privateers; armed merchant ships took hundreds of British prizes during the war. | Drifting treasure worth x2 | 40 Sailcloth, 30 Provisions |
| 4 | C The Carrying Trade | The Golden Rock | 1776: Dutch St. Eustatius, the 'Golden Rock', traded with all sides; in 1776 its fort returned the salute of an American ship. | All goods sell x1.3 | 20 Rum, 20 Cigars |
| 5 | C The Carrying Trade | The Grand Turk | 1786: Elias Hasket Derby's ship Grand Turk reached Canton in 1786, opening Salem's rich East India trade. | Ships carry x3 cargo | 30 Rum, 20 Silverware |

### 4. Roads & the Frontier

Wagons, roads, rivers and surveyors: the land routes west. Side paths: **A Rivers & Crossings**, **B The Survey**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | The Boston Post Road | 1673: The first post rider left New York for Boston in January 1673, along the route that became the Boston Post Road. | Wagons travel x1.5 faster | 40 Lumber, 20 Leather |
| 1 | main | Improved Teams (repeatable) | 1750: The heavy Conestoga horse of Lancaster County pulled freight wagons in teams of four to six through the 1700s. | Wagons carry x1.25 cargo per level | 30 Leather, 20 Flour |
| 2 | main | The Great Wagon Road | 1740: From the 1740s settlers took the Great Wagon Road from Philadelphia down the Shenandoah Valley to the Carolina backcountry. | Wagons carry x2 cargo | 60 Lumber, 30 Leather |
| 3 | main | The Conestoga Wagon | 1750: Built in Pennsylvania's Conestoga valley by the mid-1700s, the wagon's boat-shaped bed kept loads from shifting on hills. | Wagons carry x2 cargo | 30 Barrels, 30 Saddles |
| 4 | main | Postmaster Franklin | 1753: Made joint deputy postmaster general for the colonies in 1753, Franklin surveyed the post roads, sped the mails and made the post pay. | Wagons travel x2 faster | 50 Saddles, 30 Tools |
| 5 | main | The Lancaster Turnpike | 1795: The Lancaster Turnpike, chartered in 1792 and finished in 1795, was America's first long stone-surfaced toll road. | Wagons travel x2 faster | 80 Tools, 15 Rum |
| 5 | main | Improved Roadbeds (repeatable) | 1750: Where roads crossed swamp and mud, colonists laid logs side by side to make 'corduroy' roads a loaded wagon could cross. | Wagons travel x1.2 faster per level | 50 Tools, 10 Silverware |
| 6 | main | **Keystone: The Wilderness Road** | 1775: In 1775 Daniel Boone and some thirty axemen marked the Wilderness Road through the Cumberland Gap into Kentucky. | Colonies on land routes produce x3; also needs Selective Breeding (Husbandry & Agriculture) | 8 Dragoons, 50 Fur Coats |
| 2 | A Rivers & Crossings | The Pennypack Bridge | 1697: The stone bridge over Pennypack Creek, built in 1697 at William Penn's urging, still carries traffic in Philadelphia. | Land routes count 15% shorter | 50 Lumber, 20 Rope |
| 3 | A Rivers & Crossings | The Durham Boat | 1750: Durham boats, first built about 1750 near Durham Furnace, Pennsylvania, carried iron and grain down the Delaware. | Wagons travel x1.5 faster | 30 Tools, 30 Pig Iron |
| 4 | A Rivers & Crossings | The Potomac Company | 1785: Washington's Potomac Company, chartered in 1785, cleared the river and cut skirting canals around its falls. | Land routes count 20% shorter | 60 Tools, 15 Rum |
| 5 | A Rivers & Crossings | Ohio Flatboats | 1788: In the late 1780s and 1790s thousands of settlers floated down the Ohio from Pittsburgh on flatboats. | Wagons carry x3 cargo | 80 Provisions, 15 Rum |
| 3 | B The Survey | The Cumberland Gap | 1750: In 1750 Dr. Thomas Walker of the Loyal Land Company passed through the Cumberland Gap and named it. | Scouts reveal x1.5 more of the map | 40 Provisions, 20 Saddles |
| 4 | B The Survey | Mason and Dixon's Line | 1763: Charles Mason and Jeremiah Dixon surveyed the boundary between Pennsylvania and Maryland from 1763 to 1767. | New colonies cost 20% less | 40 Tools, 20 Candles |
| 4 | B The Survey | Rittenhouse's Lines | 1784: In the 1780s David Rittenhouse helped run Pennsylvania's boundary lines, sighting with instruments he had made himself. | Land routes count 15% shorter | 40 Tools, 15 Silverware |
| 5 | B The Survey | The Land Ordinance | 1785: The Land Ordinance of 1785 laid out western lands in six-mile-square townships; Thomas Hutchins led the first survey. | New colonies cost 40% less | 60 Tools, 25 Silverware |

### 5. Manufacture

Mills, looms and forges: faster and thriftier workshops. Side paths: **A The Mill**, **B The Armory**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | Apprenticeships | 1718: In 1718 twelve-year-old Benjamin Franklin was bound apprentice to his brother James, a Boston printer. | All workshops x1.5 faster | 40 Lumber, 30 Flour |
| 1 | main | Improved Benches (repeatable) | 1724: Philadelphia's master builders founded the Carpenters' Company in 1724 and kept a book of prices for their work. | All workshops x1.2 faster per level | 40 Lumber, 20 Leather |
| 2 | main | The Library Company | 1731: Franklin and his Junto founded the Library Company of Philadelphia in 1731 so tradesmen could share costly books. | Workshop upgrades cost 40% less gold | 40 Cloth, 40 Lumber |
| 3 | main | Bethlehem Waterworks | 1754: In 1754 the Moravians of Bethlehem, Pennsylvania, pumped spring water uphill by waterwheel: the colonies' first public waterworks. | All workshops x1.5 faster | 40 Pig Iron, 30 Barrels |
| 4 | main | Report on Manufactures | 1791: Hamilton's Report on Manufactures, sent to Congress in December 1791, urged bounties and support for American industry. | All workshops x2 faster | 50 Tools, 30 Candles |
| 5 | main | Slater Mill | 1793: Samuel Slater, who carried Arkwright's machines in his memory, built Slater Mill at Pawtucket, Rhode Island, in 1793. | Every staffed workshop counts 1 extra colonist | 60 Tools, 15 Uniforms |
| 5 | main | Improved Wares (repeatable) | 1790: Under the Patent Act of 1790, Samuel Hopkins received the first U.S. patent, for a better way of making potash. | Crafted goods sell x1.15 per level | 20 Silverware, 20 Cigars |
| 6 | main | **Keystone: Society for Useful Manufactures** | 1791: Hamilton's Society for Establishing Useful Manufactures, chartered in 1791, founded Paterson, New Jersey, at the Great Falls. | All workshops x2.5 faster; also needs The Iron Act (Forestry & Mining) | 6 Merchantman, 4 Dragoons, 30 Silverware |
| 3 | A The Mill | The Flying Shuttle | 1733: John Kay's flying shuttle, patented in 1733, let one weaver send the shuttle across a broad loom. | Weaver's House works x3 faster | 30 Dyed Cloth, 30 Tools |
| 4 | A The Mill | The Spinning Jenny | 1764: James Hargreaves built his spinning jenny in Lancashire around 1764; one worker could spin eight threads at once. | Cloth needs 1 cotton instead of 2 | 50 Tools, 20 Candles |
| 4 | A The Mill | Homespun | 1768: During the boycotts of 1768-69 'Daughters of Liberty' held spinning bees to make homespun in place of British cloth. | Dyed cloth needs 1 cloth instead of 2 | 40 Tools, 10 Silverware |
| 5 | A The Mill | Beverly Cotton Manufactory | 1788: The Beverly Cotton Manufactory in Massachusetts, begun in 1787, was among America's first cotton mills; Washington toured it in 1789. | Weaver's House, Sail Loft, Dye House and Tailor x3 faster | 15 Uniforms, 20 Silverware |
| 3 | B The Armory | The Pennsylvania Rifle | 1740: By the 1740s German-born gunsmiths in Lancaster County were rifling long hunting guns: the Pennsylvania rifle. | Armory works x3 faster | 40 Pig Iron, 30 Tools |
| 4 | B The Armory | Interchangeable Parts | 1785: In 1785 Jefferson visited Honore Blanc in France, whose musket locks were made from parts that fit any lock. | Muskets need 1 pig iron instead of 2 | 20 Muskets, 40 Tools |
| 4 | B The Armory | Revere's Foundry | 1788: In 1788 Paul Revere opened a foundry in Boston's North End, casting iron and brass and, later, church bells. | Blacksmith, Cooperage and Silversmith x2.5 faster | 20 Silverware, 40 Tools |
| 5 | B The Armory | Springfield Armory | 1795: Springfield, Massachusetts, a Continental arsenal from 1777, began making its own muskets in 1795. | Armory, Saddlery and Cavalry Barracks x3 faster | 40 Muskets, 15 Uniforms |

### 6. Commerce & Statecraft

Markets, credit and assemblies: prices, costs and Liberty. Side paths: **A The Assembly**, **B Paper & Credit**, **C Letters & Learning**.

| Tier | Path | Study | Year / hook | Effect | Cost |
|---|---|---|---|---|---|
| 1 | main | Faneuil Hall | 1742: Peter Faneuil gave Boston a market hall in 1742, with a meeting room upstairs where the town meeting gathered. | All goods sell x1.5 | 40 Lumber, 30 Salt Cod |
| 1 | main | Improved Trade (repeatable) | 1758: Franklin's 'The Way to Wealth' (1758) gathered Poor Richard's sayings on thrift and industry into one speech. | All goods sell x1.1 per level | 30 Flour, 20 Cloth |
| 2 | main | The Pennsylvania Gazette | 1729: Franklin bought the Pennsylvania Gazette in 1729 and filled it with news, essays and merchants' advertisements. | Crafted goods sell x1.5 | 40 Cloth, 20 Candles |
| 3 | main | The London Coffee House | 1754: Printer William Bradford opened the London Coffee House in Philadelphia in 1754; merchants met there daily to trade. | Goods in glut sell at x0.8 instead of x0.6 | 30 Provisions, 40 Cured Tobacco |
| 4 | main | The Buttonwood Agreement | 1792: In May 1792 twenty-four New York brokers signed the Buttonwood Agreement, the root of the New York Stock Exchange. | Wanted goods sell at x2 instead of x1.6 | 20 Silverware, 30 Cigars |
| 5 | main | Bank of North America | 1781: Chartered by Congress in 1781 and opened in January 1782, Robert Morris's Bank of North America was the nation's first bank. | All goods sell x1.75 | 40 Silverware, 20 Rum |
| 5 | main | Improved Statecraft (repeatable) | 1753: Pennsylvania's State House, built 1732-1753, housed the colonial assembly and later the Continental Congress. | Liberty at independence x1.1 per level | 20 Silverware, 10 Uniforms |
| 6 | main | **Keystone: The Continental Congress** | 1774: The First Continental Congress met at Carpenters' Hall, Philadelphia, in September 1774, with delegates from twelve colonies. | Liberty at independence x1.5; also needs Postmaster Franklin (Roads & the Frontier) | 6 Dragoons, 4 Merchantman, 40 Silverware |
| 3 | A The Assembly | The Albany Plan | 1754: At Albany in 1754 Franklin proposed a union of the colonies under a grand council; no colony adopted it. | Colony charters need 30% fewer goods | 30 Provisions, 30 Tools |
| 4 | A The Assembly | The Stamp Act Congress | 1765: In October 1765 delegates from nine colonies met in New York to protest the Stamp Act. | Liberty at independence x1.2 | 30 Candles, 15 Silverware |
| 4 | A The Assembly | The Olive Branch Petition | 1775: In July 1775 Congress sent the king John Dickinson's Olive Branch Petition; George III refused to receive it. | Royal Favor lasts twice as long | 20 Silverware, 20 Cigars |
| 5 | A The Assembly | Non-Importation | 1768: In 1768 Boston merchants agreed to stop importing British goods; other ports followed, until the boycott collapsed in 1770. | Liberty at independence x1.4 | 25 Rum, 10 Uniforms |
| 2 | B Paper & Credit | Bills of Credit | 1690: In 1690 Massachusetts issued paper bills of credit, among the first government paper money in the Western world. | Colonists cost 25% less | 30 Cloth, 30 Flour |
| 3 | B Paper & Credit | The Contributionship | 1752: Franklin helped found the Philadelphia Contributionship in 1752, the colonies' first successful fire insurance company. | Colonies keep working 1 more hour while you are away | 30 Barrels, 30 Provisions |
| 4 | B Paper & Credit | The Mint | 1792: The Coinage Act of 1792 founded the U.S. Mint in Philadelphia, with David Rittenhouse as its first director. | New colonies cost 30% less | 30 Silverware, 30 Tools |
| 3 | C Letters & Learning | Committees of Correspondence | 1772: Boston formed a Committee of Correspondence in 1772 at Samuel Adams's urging; soon the colonies were writing to one another. | Founding Fathers cost 20% less gold | 30 Provisions, 30 Candles |
| 4 | C Letters & Learning | The Goddard Broadside | 1777: In January 1777 Congress had Mary Katherine Goddard of Baltimore print the Declaration with the signers' names. | Founding Fathers cost 25% less gold | 40 Candles, 15 Silverware |
| 5 | C Letters & Learning | Peale's Museum | 1786: Charles Willson Peale opened his museum of portraits and natural history in Philadelphia in 1786. | One extra relic at independence | 30 Silverware, 30 Fur Coats |

## Historical notes and corrections

Hooks from the draft were checked; these changed:

- **Harbors of Refuge** was dropped. It is a 19th-century term (the Delaware Breakwater dates from the 1820s). The sea-route slot went to the Lighthouse Act of 1789, the ninth act of the first Congress.
- **Bank of North America:** chartered by Congress in 1781, but it opened in January 1782; the hook says both.
- **Bartram's Garden:** described as the *oldest surviving* botanic garden in North America, not the first.
- **Townshend:** "Turnip" Townshend (Charles, 2nd Viscount) retired to Norfolk in 1730 and promoted the four-field rotation; he didn't invent it. He is not the Charles Townshend of the 1767 Townshend Acts.
- **Seed drill:** Tull built it around 1701; his book *Horse-Hoeing Husbandry* came out in 1731. Both are used.
- **Spinning jenny:** built around 1764, patented 1770; the hook says "around 1764".
- **Copper sheathing:** HMS *Alarm*, 1761. It kept off shipworm and weed, so it is a speed bonus, not the draft's cargo bonus.
- **Interchangeable parts:** Eli Whitney's 1798 claims are disputed by historians. The hook uses Honoré Blanc, whose musket locks Jefferson saw in France in 1785.
- **The Quadrant:** Hadley (London) and Godfrey (Philadelphia) worked it out independently around 1730–31.
- **The Atlantic Neptune:** issued over the 1770s and 80s rather than in a single year; the hook says so.
- **The cotton gin:** kept, with a plain note that it deepened the South's reliance on slavery.
- **Avoided as too late:** the Schuylkill Permanent Bridge (1805), Bowditch's *Navigator* (1802), Chesapeake bugeyes, Baltimore clippers, Revere's copper rolling mill (1801).

New hooks include the Great Works River sawmill (1630s), Corneliszoon's wind sawmill (1594), Acadian aboiteaux, the Narragansett Pacer, Spanish mission ranchos, Royal Gift (1785), the Cornwall ore banks, the patio process (1554), the Mexico City mint (1535), La Valenciana, the Schuyler mine engine (1755), Marblehead and the Grand Banks, Nantucket whaling, the Spermaceti Chandlers (1761), Franklin and Folger's Gulf Stream chart, St. Eustatius's First Salute (1776), the *Grand Turk* (1786), the Durham boat, the Pennypack bridge (1697), the Potomac Company (1785), the Land Ordinance (1785), the Bethlehem waterworks (1754), the Beverly Cotton Manufactory, homespun and the Daughters of Liberty, Revere's foundry (1788), Springfield Armory, the Olive Branch Petition, the Goddard Broadside (1777), the Buttonwood Agreement (1792), the U.S. Mint (1792) and Peale's Museum (1786).

## Counts and balance

- **Size:** 102 studies: Husbandry 16, Forestry 18, Navigation 18, Roads 16, Manufacture 16, Commerce 18. Each branch has 2 repeatables and 1 keystone.
- **Magnitudes:** ordinary multipliers are ×1.25–×4, with narrow targets getting the larger values. Keystones are ×2–×3 on broad targets (Congress is Liberty ×1.5). Repeatables are ×1.1–×1.25 per level. A fully researched branch is worth very roughly ×20–×200 in its own domain, and the whole tree about 10⁴–10⁶ before repeatables.
- **To check with the balance bot:** stacked sea-route bonuses (speed ×1.5·2·2·1.5 plus route length ×0.85·0.8·0.7), Liberty stacking (×1.2·1.4·1.5 plus the repeatable), and the colony-cost reducers (×0.8·0.6·0.7).
- **Stats:** the Ledger tracks studies completed, per run and all-time.
