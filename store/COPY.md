# Idle Pioneer: store copy

Drafted 1 Oct 2026 for the 1.0 listing. Every feature claim below was checked against `data/content.json`, `data/research.json`, `data/balance.json` and the UI code on that date. If the balance retune changes a number quoted here (offline hours, favor length, ad timing), update the copy to match. The checked numbers are listed in "Facts behind the copy" at the end.

Character counts are exact and include spaces. Trademarked game names (other games, their studios, or their series) appear nowhere in this copy. Keep it that way in any edits, including keywords.

---

## Google Play

### App name: 30 characters max

| Option | Text | Chars |
|---|---|---|
| **Recommended** | `Idle Pioneer: Colonial Tycoon` | 29 |
| Plain | `Idle Pioneer` | 12 |

### Short description: 80 characters max

| Option | Text | Chars |
|---|---|---|
| **Recommended** | `Found colonies, ship goods to Europe, craft fine wares and declare independence.` | 80 |
| Alternative | `Found colonies, trade with Europe, declare independence. An idle colonial sim.` | 78 |

### Full description: 4000 characters max (this one is 2721)

```text
Idle Pioneer is an idle trading game set in the colonial New World, from the first settlements of 1607 to the Declaration of 1776. Found colonies along an untamed coast, ship their goods home by wagon and by sea, craft them into finer wares, and when the colonies are rich and armed, declare independence.

FOUND YOUR COLONIES
• Choose a nation: England, France, Spain, the Netherlands, Portugal or Sweden, each with its own bonus.
• Every expedition brings a freshly drawn continent, or play on a map of North America.
• Settle up to 25 colonies. Timber, furs, tobacco, cod, iron and silver roll in by road and by sea.

BUILD A COLONIAL ECONOMY
• Upgrade each colony's production, cargo and route speed, and pass milestones that double its output.
• 26 workshops turn raw goods into lumber, rope, cloth, tools, rum, muskets and even merchant ships.
• Sell in Europe, where wanted goods fetch more and gluts fetch less, or keep goods for your workshops.
• Grant charters, choose what each town specializes in, and post governors to your best colonies.

CONGRESS AND INDEPENDENCE
• Invite 38 Founding Fathers to Congress: Benjamin Franklin, George Washington, Abigail Adams, Phillis Wheatley, Haym Salomon and many more, each with a bonus of their own.
• When the colonies are rich and the militia is armed, sign the Declaration of Independence with your own hand. The Ledger keeps every signature.
• Earn Liberty and spend it on five permanent Reforms, then begin a new expedition, stronger than before.

A WORLD FULL OF HISTORY
• Collect 30 relics in six sets, from Franklin's kite key to the Old North Church lantern. Each one is a lasting bonus.
• After your third independence the Philosophical Society opens: 102 studies in six branches, each with a true story behind it.
• The Ledger keeps your records, your relics and rare Almanac pages that skip an hour ahead.

PLAY AT YOUR OWN PACE
• Your colonies keep working while you're away, for up to 4 hours, at a gentler pace.
• Royal Favor doubles production for 15 minutes, free, every two hours.
• Hand-made pixel art, a painted map and period music.
• No account needed. Your progress stays on your device, with a save code for backup.
• Large text option.

FAIR, LIGHT ADS
• No banner ads, no energy, and nothing for sale that makes you stronger.
• From your second independence, an ad may play between expeditions, at most once every 30 minutes.
• Optional: watch an ad to Consult the Almanac and skip 30 minutes ahead, once every 4 hours.
• A one-time Ad-Free purchase removes every ad, and lets you Consult the Almanac without watching one. Restore it any time with Restore Purchases.

The New World is waiting. Raise the flag, load the wagons and make history.
```

The description doesn't state the price on purpose. Play shows the local price of the in-app product on the listing, and a fixed "$4.99" would be wrong outside the US. To state it anyway, change the sentence to "A one-time Ad-Free purchase (US$4.99) removes every ad…" (2731 characters).

### Category and tags

- **App category:** Games › **Simulation**. Strategy is the second choice; most idle tycoon games list under Simulation.
- **Tags** (pick up to 5 in Play Console › Store settings): Idle, Tycoon, Business sim (or Economy), Single player, Offline. Add "Pixel" or "Stylized" if your console's tag list offers them.
- **Contains ads:** Yes. **In-app purchases:** Yes (one non-consumable, `ad_free`).
- **Target audience:** 13+ (or 16+). Don't select any under-13 age groups. The ad setup in MONETIZATION.md isn't child-directed, and including children would bring in the Families policy.

### Content rating (IARC questionnaire): suggested answers

Category: **Game**. Answer the questions about what is in the game itself:

| Topic | Answer | Why |
|---|---|---|
| Violence | **No.** No combat, injury or death is shown. | Muskets, Dragoon Kits and Uniforms exist only as trade-good icons crafted in workshops. "Arm the militia" means keeping one musket in the warehouse. Some history text mentions wars and privateers. |
| Fear, horror | No | |
| Sexuality, nudity | No | |
| Language | No profanity | |
| Controlled substances: **alcohol** | **Yes: references, not use.** | Rum and molasses are crafted trade goods, with a line of flavor text. Nobody is shown drinking. |
| Controlled substances: **tobacco** | **Yes: references, not use.** | Tobacco, Cured Tobacco and Cigars are trade goods. Nobody is shown smoking. |
| Drugs | No | |
| Gambling / simulated gambling | **No** | Relics drop at random, but they are never sold and can't be bought. No loot boxes, no casino mechanics. Market prices move on a timer. |
| Crude humor | No | |
| Discrimination / sensitive history | **Mention it if asked**, as historical, educational context. | Flavor and study text names slavery and enslaved labor as historical fact (e.g. sugar, tobacco, indigo, rum, the cotton gin). Nothing is depicted. |
| User interaction / user-generated content | No: no chat, accounts or sharing | |
| Shares location | No (the game itself doesn't) | AdMob derives coarse location from the IP address. That goes in Data safety, not in this questionnaire. |
| Digital purchases | **Yes** | Ad-Free. |
| Ads | **Yes** | |

**Expected result:** ESRB Everyone 10+ (tobacco and alcohol references) or Everyone, PEGI 7 to 12, USK 6 to 12. LAUNCH_PLAN.md expects E10+ / PEGI 7–12.

### Data safety form

Base these answers on Google's current AdMob and Play Billing disclosure guides, and check those pages again when you submit. The game itself collects and sends nothing.

- **Does your app collect or share any of the required user data types?** Yes, through the Google Mobile Ads SDK.
- **Is all user data encrypted in transit?** Yes. Google states that the AdMob SDK uses encryption in transit.
- **Can users request that data be deleted?** You (the developer) hold no user data. Answer per the form's guidance. The privacy policy (`docs/site/privacy.html`) points users to Google's ad settings and controls.
- **Data types (collected and shared, via AdMob):**
  - *Location: approximate location.* Estimated from the IP address. Used for advertising and fraud prevention.
  - *App activity: app interactions* (ads shown, taps, launches). Used for advertising, analytics and fraud prevention.
  - *App info and performance: crash logs and diagnostics.* Used for analytics and fraud prevention.
  - *Device or other IDs: advertising ID / app set ID.* Used for advertising, analytics and fraud prevention.
  - All of it is collected automatically, it is required for the ads to work (not optional), and it isn't linked to an account (the game has none).
- **Purchases:** Google Play handles payment and purchase history. Follow the Play Billing Library's current data-safety note for whether anything needs declaring; at the time of writing Google says billing data handled by Play itself doesn't. **The owner must confirm this.**
- **Advertising ID declaration** (Policy › App content): Yes, the app uses the advertising ID, through AdMob. With `targetSdk` 33+ the AdMob SDK adds the `AD_ID` permission. MONETIZATION.md and the README say "no permissions": that holds for the game's own manifest, but the merged manifest will contain `AD_ID` and `INTERNET` once the AdMob plugin is in.
- **Privacy policy URL:** host `docs/site/privacy.html` first. It already describes AdMob, Play Billing and the StoreKit purchase.

---

## Apple App Store

### Name: 30 characters max

| Option | Text | Chars |
|---|---|---|
| **Recommended** | `Idle Pioneer` | 12 |
| Alternative | `Idle Pioneer: Colonial Tycoon` | 29 |

The recommended short name leaves "colonial", "trade" and "tycoon" to the subtitle. Apple indexes the name, subtitle and keywords together, and repeating a word gains nothing.

### Subtitle: 30 characters max

| Option | Text | Chars |
|---|---|---|
| **Recommended** | `Colonial Trade Tycoon` | 21 |
| Alternative | `Found colonies, win liberty` | 27 |

### Promotional text: 170 characters max (can be changed without a new build)

`Found colonies, ship goods to Europe and craft rum, tools and muskets. Then sign the Declaration of Independence and start again, stronger. No banner ads, ever.`: **160**

### Keywords: 100 characters max, comma-separated, no spaces

`incremental,colony,empire,merchant,history,1776,pixel,offline,clicker,crafting,ships,revolution`: **95**

The keywords leave out words already in the name or subtitle (idle, pioneer, colonial, trade, tycoon), plurals (Apple matches both forms), the word "game", and every trademark or competitor name. If you use the alternative name, add `trade` back in.

### Description: 4000 characters max

Use the Google Play full description above unchanged (**2721** characters). It contains nothing specific to Play. On iOS the purchase is restored with the in-game **Restore purchases** button, which Apple requires and the Settings screen has.

### What's New (version 1.0): 4000 characters max (this one is 315)

```text
The New World opens! Idle Pioneer 1.0:
• Six nations, random maps and North America
• 25 colonies, 26 workshops and the markets of Europe
• 38 Founding Fathers, 30 relics and 102 studies
• Declare independence and earn permanent Reforms
Thank you for playing. Tell us what you would like next from the Support page.
```

App Store Connect doesn't ask for What's New on the very first version. Keep this text for the Play "release notes" (500 characters max: it fits) and for 1.0.1.

### Category

Primary **Games**, with subcategories **Simulation** and **Strategy**.

### Age rating (Apple's 2026 questionnaire): suggested answers

| Item | Answer |
|---|---|
| Cartoon or fantasy violence / realistic violence | None |
| Profanity, crude humor | None |
| Mature or suggestive themes | None |
| Horror / fear | None |
| Medical information | None |
| **Alcohol, tobacco or drug use or references** | **Infrequent/Mild** (trade goods: rum, tobacco, cigars) |
| Sexual content, nudity | None |
| Simulated gambling | None |
| Contests | None |
| Unrestricted web access | No |
| User-generated content, messaging | No |
| In-app purchases | Yes (Ad-Free, non-consumable) |
| Advertising | Yes |

**Expected result:** 9+. Apple may also show 10+ or 13+ depending on how the 2026 form treats alcohol and tobacco references. Accept whichever the form gives.

### App Privacy ("nutrition label") notes

The game collects nothing itself. Declare what the Google Mobile Ads SDK collects, following Google's "Prepare for Apple's App Store data disclosure" page for the SDK version you ship:

- **Data used to track you:** only if you show personalized ads with ATT consent: *Identifiers › Device ID (IDFA)* and *Usage Data › Advertising Data*. MONETIZATION.md leaves tracking off unless you enable it. **The owner decides.** If you never call the ATT prompt, IDFA isn't available and you can answer "not used for tracking".
- **Data linked to you:** none (no accounts).
- **Data not linked to you** (collected by the ad SDK):
  - *Location*: Coarse Location (from the IP address).
  - *Identifiers*: Device ID (IDFV).
  - *Usage Data*: Product Interaction, Advertising Data.
  - *Diagnostics*: Crash Data, Performance Data, Other Diagnostic Data.
  - Purposes: Third-Party Advertising, Analytics.
- **Purchases:** StoreKit purchases are handled by Apple and aren't collected by the developer. Don't declare "Purchase History" unless your own code sends it somewhere, and it doesn't.
- **Privacy manifest:** the Godot iOS export and the AdMob SDK both ship privacy manifests. Check the generated `PrivacyInfo.xcprivacy` in Xcode.

---

## Taglines (alternatives)

1. **Settle the New World. Trade with the Old. Declare your own.** (59)
2. **From a single settlement to a free nation, one shipment at a time.** (66)
3. **Build a colonial trade empire, then sign it all away for Liberty.** (65)

## Screenshot captions (as rendered on the marketing shots)

| # | File | Headline | Subline |
|---|---|---|---|
| 1 | `01_map` | Found Colonies in the New World | Settle a painted coastline and link every colony to your capital by road or sea. |
| 2 | `02_colony` | Grow Every Settlement | Upgrade production, wagons and ships. Post governors, grant charters. |
| 3 | `03_workshops` | Craft Finer Wares | 26 workshops turn timber, iron and cane into lumber, tools, rum and muskets. |
| 4 | `04_europe` | Trade with the Old World | Sell to the markets of Europe as demand rises and falls, or keep goods to craft. |
| 5 | `05_congress` | Convene a Continental Congress | Invite Franklin, Washington, Abigail Adams and dozens more, each with a bonus. |
| 6 | `06_declaration` | Declare Independence! | Start a new expedition and spend your Liberty on permanent Reforms. |
| 7 | `07_society` | Join the Philosophical Society | 102 studies across six branches, each rooted in real colonial history. |
| 8 | `08_ledger` | Collect Relics of History | 30 keepsakes, from Franklin's kite key to the Old North Church lantern. |

Captions are set in `tools/store/build_store.py` (`SHOTS`).

---

## Facts behind the copy (checked 1 Oct 2026)

| Claim | Source |
|---|---|
| 6 nations: England, France, Spain, Netherlands, Portugal, Sweden | `content.json` › nations |
| Random continent each run, or North America | `scripts/world/`, `map=north_america` |
| Up to 25 colonies | `balance.json` `max_colonies` 25 |
| 40 goods (14 raw, 26 crafted); 26 workshops including the Shipyard (Merchantman) | `content.json` › resources, recipes |
| Milestones double output (×2 production and cargo; ×1.5 speed) | `balance.json` milestones |
| Europe's market: "Wanted ×1.6" and "Glut ×0.6", changing every 30 minutes | `market_*` |
| 5 charter ranks, 7 specializations (from the 2nd independence), 3 governor types | `content.json`, `unlock_after_runs` |
| 38 Founding Fathers, including Franklin, Washington, Abigail Adams, Wheatley, Salomon | `content.json` › fathers |
| Independence needs the gold goal plus 1 musket (the militia) | `independence_gold`, `independence_muskets` |
| 5 Reforms: Industry, Navigation, Settlement, Commerce, Manufacture | `liberty_upgrades` |
| 30 relics in 6 sets; "Franklin's Kite Key", "Old North Church Lantern" | `content.json` › relics |
| Philosophical Society: 102 studies, 6 branches, opens after 3 independences | `research.json`, `unlock_after_runs.research` 3 |
| Almanac page skips 1 hour | `almanac_seconds` 3600 |
| Offline: 4 hours at 50% (relics, fathers and studies can add hours) | `offline_cap_hours`, `offline_efficiency` |
| Royal Favor: ×2 for 15 minutes, every 2 hours, free | `favor_*`; MONETIZATION.md |
| Interstitial only between expeditions, from the 2nd independence, 30-minute gap; never for Ad-Free | `interstitial_*`; `main.gd` `_maybe_interstitial` |
| Consult the Almanac: rewarded, 30 minutes, every 4 hours; free for Ad-Free owners | `ad_skip_*`; `main.gd` `_on_consult` |
| Save code export/import, Large text, Restore purchases | Settings in `main.gd` |
| "The year is 1607" | `nation_select.gd` |
