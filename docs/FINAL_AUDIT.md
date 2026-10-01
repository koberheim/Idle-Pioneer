# Final Pre-Ship Audit

30 Sept 2026, on `main` at 02bd6c2. Four independent reviews ran: game logic and calculations, pacing, art and UI/UX, and sound. Every finding below was checked against the code, and most were reproduced with numbers or screenshots. The evidence is in the session scratchpad: `uiaudit/`, `pacing/`, `sound/`.

**State of the build:**
- 70/70 tests pass and the research validator passes.
- Live and offline results agree to within 1e-9 at 0.1 s, 1 s and 120 s steps, with Royal Favor and market changes mid-run.
- Saves round-trip losslessly.
- All 147 icons form one consistent 48 px set, and every audio file is licensed and credited.
- A first independence takes about 1.5 to 2 hours of active play on both map types, on every seed tested.

The items below are what is left to do.

---

## 1. Fix before the beta (must)

| # | Area | Problem | Fix |
|---|---|---|---|
| **B1** | Logic | **The militia musket isn't really reserved, and a failed declaration throws away the run.** Staffed Dragoon Kits workshops consume muskets, and so can Jefferson (20), Peter Salem (300), the City charter (30) and five studies. A declaration made just as the stock drops to 0 returns 0 Liberty. The ceremony still says "Independence! +0", and the next expedition replaces the run with nothing paid. Reproduced: with the Dragoons workshop staffed, one tick took the stock from 2 to 0. | Make the reserve untouchable everywhere: workshop claims, and the father, charter and study checks and payments. Have the ceremony abort with a message if the commit fails. |
| **B2** | UI | **The top bar overflows at real phone proportions** (450×900, and with Large text). Late-game numbers ("4.79K/4.80K", "23.4M", "12.2DDc") push the settings button off-screen and break the map buttons and the tab bar. | Show colonists as idle count only past 1K, clip or shrink the labels, make Favor icon-only when space is tight, and test at 450×900. |
| **B3** | UI | **Text is too small and some is too faint.** Body text is about 10–13 sp, and some labels are 14–17 units (8–9 sp). Light parchment-coloured text is used on parchment backgrounds at 1.6:1 contrast: the governors intro, and "Buy" on Europe. Effect lines in green are 3.9:1, the red Reset button 2.0:1, and locked research text 2.3:1. | Minimum 18 units; small/body text to 22/25; Large mode ×1.25–1.3. Choose text colour by background, darken the green to about `#2f6626`, dim only the icon and button on locked cards, and restyle Reset. |
| **B4** | Sound/Ads | **Music keeps playing under ads, and the game is about 10 dB quieter than ads**, so ads will blast. Game music sits around -30 LUFS in game and UI sounds around -35 to -42. | Mute the music bus while an ad shows and tell the ad SDK the app volume. Raise the whole mix about 8–10 dB, and set a volume per sound (see S2). |
| **B5** | Pacing | **Offline play earns well under half of active play** (target 50%; measured 41% early, 26% late). Three causes: treasure is worth about +53% to someone watching the map; once all relics are found, every 4% relic roll becomes an Almanac page (about one free hour per hour on the map); and offline routes still run at full speed. | Treasure pays 45 s of income instead of 90. Once relics are complete, the relic roll pays gold, not pages. Treasure value excludes Royal Favor. Offline route speed also runs at half. |

## 2. Fix before release (should)

### Logic and calculations
- **M1 Very fast colonies lose output in long steps.** Once a colony's round trip drops below one unit's production time, 120 s steps (offline, Almanac, Consult) deliver 25% less, and each step burns 100k loop iterations. Fix: settle that case in closed form, one unit per 1/rate.
- **M2 A blocked workshop hoards its shared goods.** A workshop held up by a different input keeps its claim on its other inputs, which starves its competitors offline (-19% barrels in a test). Fix: limit claims to what the other inputs allow, or release them when the workshop makes nothing.
- **M4 Time away can be lost during a long catch-up.** Time away while a catch-up is still running is ignored, and a save during it marks the unprocessed time as already spent. Fix: save `saved_unix = now - remaining`, and add new gaps to the pending catch-up.
- **M5 Clock exploit within one session.** Within one session, setting the clock forward, back, then forward again repeats a catch-up. Fix: measure gaps from `max(_last_frame_unix, max_seen_unix)`.
- **Low:**
  - Liberty and governor cost integers can overflow (unreachable in practice, but clamp them).
  - "Max" buy fails at extreme budget-to-cost ratios (use logarithms).
  - Number-format edge cases, e.g. "10.00e65" and 999.9999 showing as "1000".
  - A failed store query must never remove Ad-Free; native backends must only report a definite answer.
  - A rewarded ad that finishes with no run, or during the cooldown, pays nothing and says nothing.
  - Catch-up state isn't reset when a new run starts or a save is imported.
  - The platform test leaves `test_platform_save.json` in app data.

### Pacing
- **The middle of the progression runs away.** From reform level 10 to 50, a 4-hour run pays 10–60× the cost of all reforms bought so far. Model estimate: 25 colonies in about 12–18 days at 1 h/day, under a week for heavy players. The goal was "many weeks". Fix: reform cost growth 1.3 → **1.35** (Settlement 1.33 → **1.38**), which gives about 3–5 weeks casual and 1.5–2 weeks heavy.
- **Declaring the moment you reach the gold goal barely helps.** It pays only 9 Liberty (1–2 reform levels), so the second run is as long as the first. Fix: `liberty_base` 9.5 → **15**, plus a hint that Liberty keeps growing if you continue past the goal.
- **"Keep" traps income.** Keeping a good holds its whole surplus unsold, so income can quietly stall (the bot stalled for 75 minutes). Fix: show a warning when goods have piled up, or keep only up to what the workshop needs.
- **Verify after tuning:** confirm the 25-colony estimate with a bot that resets in a loop and buys research. Beyond reform level 60 the current figure is extrapolated.

### Art and UX
- **Continental map:** town names need a parchment halo, "Terra Incognita" and the sea name collide with coastlines, and the map uses only half the frame.
- **The nation-select and Reforms backdrop is low-res:** chunky 16 px blocks on the very first screen a player sees. Use a blurred render of the painted map, or the harbour art.
- **The app icon and feature-graphic flag looks like the Taiwan (Republic of China) flag:** a red field with a navy canton. Swap it for a period pennant or Grand Union stripes. The feature graphic also needs the "Idle Pioneer" title.
- **The tutorial says "a billion gold"** for independence; the real goal is 2.5B. Take the figure from the balance data.
- **The tutorial card covers the map buttons.**
- **Missing tips** for the Ledger and relics, the Society, Consult the Almanac, charters, specializations, governors and reforms. The Europe "Wanted/Glut" row shows unlabeled silhouettes.
- **Wording:** pick "expedition" (not "run") everywhere, and "×" (not "x") for multipliers.
- **Suffixes past "Dc"** are opaque: offer scientific notation in Settings.
- **Touch targets:** the most-tapped buttons (colonist −/+, Sell/Keeping, Choose, ✕) should be at least 64 units; most are 56.
- **Low:**
  - Floating "+gold" overlaps name plates.
  - A one-frame white flash at launch.
  - Back doesn't dismiss the tutorial card and has no "press again to exit".
  - Map colonist badges are unexplained.
  - Safe-area code is duplicated (the research screen lacks the mobile guard).

### Sound
- **S2 Per-sound volumes.** Effects range over 17 dB. Starting trims: found -8, discover -4, deny -3, tab +5, click and coin +3.
- **The independence fanfare** is a chiptune square wave over an orchestral moment, and it doubles the brass in the music. Render a period brass sting, and drop the duplicate.
- **Switching tabs restarts each track** from the top; resume where it left off instead. Fast switching can click.
- **One bell for eight events.** The Founding Father bell also plays for milestones, relics, studies, charters and so on. Give each event its own sound. Silent events that need one: the Ad-Free thank-you, a failed purchase, Consult, market news, and the unlock announcement.
- **iOS:** set the audio session to Ambient with mix-with-others, so the silent switch is respected and podcasts keep playing.
- **Trim the starts of three files:** found.ogg has 19 ms of leading silence; liberty.ogg and father.ogg need fade-ins.
- **Music repetition.** The 2-minute map theme plays about 30 times an hour. Add 2–3 more public-domain tunes (Chester, The White Cockade, Haste to the Wedding…) as a shuffled playlist, with short gaps of silence or ambience between them.

## 3. Owner actions (outside the code)

- **Play Console** account and the permanent package ID.
- **Apple Developer** account, plus a rented cloud Mac.
- **Credit line:** your name or a studio name.
- **Host `docs/site`**, with `app-ads.txt` at the root of your website's domain.
- **Real devices for the beta:** at least one older Android and one iPhone.
- **Closed test:** 15–20 testers for 14 days.

## 4. Suggested order

1. **B1–B5** (about 3–4 days).
2. **The section 2 logic items** (1–2 days) and **the pacing retune with a reset-loop bot check** (1–2 days).
3. **The UI/UX and sound polish items** (3–5 days), in parallel with the native ads and billing work once the Android build exists.
4. **Store screenshots.** Suggested shots: map, colony sheet, workshops, the Europe docks, Congress, the Declaration, research, relics. Capture them at 1080×1920.
