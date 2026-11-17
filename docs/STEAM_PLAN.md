# Steam Desktop Plan: Landscape Redesign and Steam Release

Written 2026-11-16. Nothing in this plan has been built yet.

## 1. Goals and decisions

**Goal:** release Idle Pioneer on Steam for Windows (and Linux / Steam Deck) with a proper landscape layout, while the mobile version keeps shipping from the same code.

**Recommended business model (owner to confirm):**
- Premium, **US$4.99**, the same as the mobile Ad-Free price.
- No ads and no in-game store on Steam. The Steam build behaves as if Ad-Free is owned.
- A launch discount of 10–20% is normal and helps the first week.
- Optional later: a free demo (first expedition) to build wishlists before launch, and a small cosmetic or supporter DLC if the game finds an audience.

**Platforms:**
- Windows 64-bit: primary.
- Linux 64-bit: cheap to add with Godot. It enables Steam Deck without Proton.
- macOS: out of scope. There's no Mac for signing and notarization (same reason as iOS).

**Decisions the owner needs to make** (each one also appears in its phase):

| # | Decision | Recommendation |
|---|---|---|
| D1 | Price and model | Premium $4.99 |
| D2 | Demo before launch? | Yes, if launching through Next Fest |
| D3 | Linux / Steam Deck at launch? | Yes for Linux. For Deck, aim for "Playable", not "Verified" |
| D4 | Full controller support at launch? | No. Touchscreen and trackpad on Deck first, gamepad focus navigation as a later update |
| D5 | Achievements at launch? | Yes, about 25 |
| D6 | Trailer: made by the owner, or commissioned? | Owner capture plus simple edit, using the screenshot harness for clean shots |

## 2. Preserving the mobile version

Done on 2026-11-16:
- **Tag `mobile-v1.0.0`** (annotated) on commit `56da8ad`. This is a permanent, exact snapshot of the mobile-ready build.
- **Branch `release/mobile-1.0`** from that tag. Store-submission fixes for the first Android and iOS release go here if `main` is mid-redesign.

Both are local only until pushed (`git push origin mobile-v1.0.0 release/mobile-1.0`).

**Ongoing strategy: one codebase, not a fork.**
- Steam work happens on a `steam` branch and merges into `main` at the end of each phase. A phase merges only once the mobile build is unchanged (see the portrait regression check in section 10).
- Platform differences live behind feature tags and the `Platform` layer, never in a separate copy of the game. That way content, balance and bug fixes reach both versions at once.
- Mobile hotfixes made on `release/mobile-1.0` get cherry-picked back to `main`.

## 3. Platform architecture

What's there today: `Platform` (an autoload) picks a backend at startup, in `scripts/core/platform.gd`. Desktop currently gets `DesktopBackend`. That's a **developer stand-in**: it shows fake "test ads" and hands out Ad-Free for free. **It must never ship to Steam.**

### 3.1 The `steam` feature tag
- Add custom feature tag `steam` to the new Windows and Linux export presets.
- Branch on `OS.has_feature("steam")`, never on `OS.get_name()`, so a non-Steam desktop build (itch.io later, say) is still possible.

### 3.2 SteamBackend
New file `scripts/core/steam_backend.gd`, which extends `PlatformBackend`:
- `store_available()` returns `false`.
- At start it reports Ad-Free as owned (`purchase_result.emit("ad_free", true, "")`).
- `ads_allowed()`, `rewarded_ready()` and `interstitial_ready()` all return `false`.
- `privacy_options_required()` returns `false`.

`Platform._make_backend()` then follows this order:
1. `steam` feature present: use `SteamBackend`.
2. Otherwise `mobile`: same as today.
3. Otherwise, in an exported release desktop build with no `steam` tag: use the bare `PlatformBackend`, with no store and no ads. This is the same safety rule the mobile code already has.
4. Otherwise (editor, tests): `DesktopBackend`.

**Effects that already work, since the code checks `Platform.is_ad_free()`:**
- Almanac "Consult" skips the ad.
- No interstitial between expeditions.
- Settings shows "Ad-Free: thank you!".

**Small follow-ups:**
- Hide the Ad-Free button and "Restore purchases" entirely on Steam, rather than showing "thank you". Gate them on a new `Platform.has_store_ui()`.
- Hide the "· test ads" version suffix on Steam.
- Entitlement file: Steam never writes `entitlements.cfg`. Ad-Free on Steam isn't stored at all; it's simply true.

### 3.3 Mobile code kept out of the desktop build
- Windows and Linux export filters exclude `addons/admob/*`, `addons/GodotGooglePlayBilling/*`, `android/*`, `ios/*` and `scripts/core/mobile_backend.gd`.
- `mobile_backend.gd` is already loaded by path only when the AdMob singleton exists, so excluding it is safe.
- Add a check script, `tools/steam/check_build.py`, in the spirit of `tools/store/check_aab.py`. It fails the build if a desktop pack contains AdMob, billing or `desktop_backend.gd` resources.

### 3.4 Touch wording
There are about 12 "tap" strings in `game.gd`, `advisor.gd`, `buy_button.gd`, `continental_map.gd`, `main.gd` and `tutorial.gd`. Route them through one helper, `UI.verb_tap()`, which returns "Tap" or "Click" (plus "tapping" and "clicking"). Do the same for "Back" in the exit toast, which should read "Esc" on desktop.

## 4. Display, window and rendering

### 4.1 Base resolution (needs a 1-day spike first)
- **Today:** a 720×1280 portrait viewport with `canvas_items` stretch and `expand` aspect. The UI is sized for that: body text 24 px, tab buttons 104 px tall, top-bar gold text 34 px.
- **Desktop proposal:** override for `.pc` in `project.godot` to a **1920×1080 base viewport**, keeping `canvas_items` and `expand`.
  - UI pixel sizes then read at about the same physical size on a 1080p monitor as on a phone. A landscape screen 1080 logical px tall gives a little less height than the phone's 1280 but far more width.
  - `expand` makes 16:10 (Steam Deck 1280×800, many laptops) and ultrawide simply show more room.
- **Spike task:** try 1920×1080 against 1600×900 at 1280×720, 1920×1080, 2560×1440 and 1280×800. Pick the one where the existing cards and text read best. If text is too small at 1280×720, the existing "Text & buttons: Large" setting (×1.15) already helps.
- **Window defaults:**
  - Start at 1600×900 windowed or the last-used size, resizable.
  - Minimum window size 1024×640.
  - Remove the 450×900 window override for `.pc`.
- Orientation settings are ignored on desktop. They stay as they are for mobile.

### 4.2 Pixel art at desktop scales
- The default texture filter is `nearest`, and the sprites are pixel art at about 2× density (Graveyard Keeper style).
  - At non-integer scales (1440p, 1366×768), nearest filtering can shimmer while panning the map.
  - Check this during the spike. If it shows, use linear filtering with mipmaps for the map only. The continental map and buttons already do this. Keep UI frames and icons crisp.
- Fonts are TTF (Libre Baskerville, Almendra, symbols) and scale cleanly.
- 4K: check the terrain shader cost at 3840×2160. The existing "Map effects: Light" and the 60 fps cap give a fallback.

### 4.3 Desktop display settings
Add a "Display" group to Settings, shown on desktop only:
- Window mode: Windowed, Borderless fullscreen, Fullscreen.
- V-Sync on or off.
- Frame cap: 30, 60, 120, 144, or unlimited. Today the cap is tied to "Map effects".
- Remember window size, position and mode between sessions. Store this in a small `user://display.cfg`, not in the save.
- **F11 and Alt+Enter** toggle fullscreen.

### 4.4 Background and unfocused behavior
- **Today:** `Game` saves on focus-out and close. Offline catch-up runs on `NOTIFICATION_APPLICATION_RESUMED`, which is mobile-only. On desktop the game simply keeps running while minimized, which is correct for an idle game.
- **Add:** while the window is unfocused or minimized, drop to about 10 fps and mute or duck music (as an option, on by default). The simulation is time-based, so it stays correct.
- **Check:** a frame hitch while minimized must not drop production. The launch audit fixed this; re-test on desktop.
- **Autosave:** keep save-on-focus-out. Also autosave every 60 s on desktop, because players kill the process or shut down the PC with the game open.

## 5. Landscape redesign

The UI is built entirely in GDScript. `scenes/Main.tscn` is a stub; `scripts/ui/main.gd` builds the shell. The layout is mostly containers, which is what makes this feasible.

### 5.1 Layout switch
- Add `UI.is_wide(ctl)`: true when the viewport aspect ratio is at least 1.2. Recompute it on `size_changed`.
- Desktop builds are always wide; phones are always portrait. Keeping it aspect-based rather than platform-based means:
  - the editor can test both layouts by resizing the window;
  - tablets in landscape could use it later.
- **Rule:** portrait code paths stay as they are today. Every wide change is an `if UI.is_wide()` branch or a separate layout function, so the mobile layout can't regress.
- Changing modes while the game is running (resizing the window across the threshold) rebuilds the shell layout but keeps the pages. Desktop windows resize constantly, so this must work.

### 5.2 Target layout (1920×1080)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ TOP BAR: gold + income | Royal Favor | colonists | Liberty | market | ⚙      │
├──────┬───────────────────────────────────────────────┬───────────────────────┤
│ NAV  │                                               │  COLONY PANEL         │
│ RAIL │              MAP (fills the space)            │  (docked, ~560 px)    │
│      │                                               │  shown when a colony  │
│ Map  │                                     [zoom]    │  is selected; the map │
│ Work │                                     [chart]   │  shrinks to make room │
│ Euro │                                     [almanac] │                       │
│ Cong │                                               │                       │
│ Ledg │   advisor ──────────────                      │                       │
├──────┴───────────────────────────────────────────────┴───────────────────────┤
│ (no bottom nav in wide mode)                          toasts: top-right stack │
└──────────────────────────────────────────────────────────────────────────────┘
```

Other tabs replace the map area with their page, and the nav rail stays.

### 5.3 Work breakdown

#### L1. Shell (`main.gd`, about 3–4 days)
- `_build_nav()` gets a vertical-rail variant: five buttons stacked, each with icon and label, about 120 px wide. The Congress gold glow and Ledger unlock logic are unchanged.
- **Top bar:** with the extra width, add the room the phone lacks:
  - the full income line;
  - the market's "in demand" goods (now only shown as a toast);
  - the Favor timer as text.
- Content area: an `HBoxContainer` of nav rail, page area and colony panel.
- **Re-anchor the overlays:**
  - Toasts become a top-right stack, about 520 px wide.
  - The tutorial moves to the top-left of the map area.
  - The save banner moves below the top bar.
  - Replace the hard-coded offsets (`104`, `118`, `120` + safe area) with values computed from the top bar's actual height. Mobile benefits from this too.
- **Advisor:** anchored to the bottom of the map area, capped at about 900 px wide and centered.

#### L2. Colony panel (`colony_sheet.gd`, `main.gd`, about 3–4 days)
This is the biggest single piece.
- Wide mode docks the sheet on the right instead of sliding it up from the bottom.
  - It slides in from the right: the existing `_animate_sheet` tween with an x offset instead of y.
  - Its height is the full content height, with internal scroll.
- `ColonySheet.fit()` gets a width-driven variant. Its fixed minimum widths (150, 220, 120 px buttons) fit comfortably in 560 px.
- **The map shrinks** while the panel is open, instead of being covered.
  - `map_view.center_on_colony(id, animate, frac_y)` gets a horizontal-fraction twin, so the selected colony is centered in the visible part of the map.
  - The map's button column (zoom, chart, almanac) follows the map's right edge.
- **Esc or a right-click** on the map closes the panel. Clicking another colony switches it.
- **Optional, for later:** the panel can stay docked with a "pin" toggle, so a desktop player can watch one colony while managing another.

#### L3. Tab pages (about 3–5 days)
`Page` is the shared base (`page.gd`), so most of the work happens there:
- **Content width cap:** the list column is limited to about 1100 px and centered. This alone stops cards stretching across the screen, and fixes all four pages in about half a day.
- **Optional two-column flow:** `Page.list` becomes a `GridContainer`-style flow in wide mode for pages whose cards are independent:
  - **Workshops** (`workshops_page.gd`): workshop cards in 2–3 columns. The Research entry becomes a prominent header card.
  - **Europe** (`europe_page.gd`): market prices table on the left, ships and shipping on the right.
  - **Congress** (`congress_page.gd`): Founding Fathers in a grid, with the independence panel pinned at the top.
  - **Ledger** (`ledger_page.gd`): stats in two columns, relics in a wider grid. Almanac pages and governors (`governor_roster.gd`) are side by side.
- `upgrade_row.gd` and `buy_button.gd` (190×70 minimum) need a check that they don't stretch oddly inside wider cards.

#### L4. Full-screen overlays and modals (about 2–3 days)

| Screen | File | Wide-mode change |
|---|---|---|
| Nation select | `nation_select.gd` | Nation cards in a row or grid instead of a stacked list, plus a large flag and description panel |
| Independence ceremony | `independence_overlay.gd` | Panel centered with max width. Signature drawing already handles the mouse. Check the canvas size |
| Research (Philosophical Society) | `research_screen.gd` | The six branches gain the most from width: show them as columns instead of tabs |
| Continental map | `continental_map.gd` | Already fits to available size. Check the close button position (bottom-center today) |
| Credits | `credits_screen.gd` | Width cap |
| Modals | `modal.gd` | The width cap (620 px) and height limit (62% of the viewport) already work. Consider raising the height limit to 75% on desktop |
| Catch-up screen, offline report | `main.gd` | Fine as they are (centered panels) |

#### L5. Desktop-native interaction (about 3–4 days)
- **Hover feedback:** buttons and cards get a hover style. `UI.frame` already has `hover` style slots that mostly repeat `normal`; give them a lighter variant. Add hover on map colonies, with a highlight and a tooltip showing name, resource and output.
- **Tooltips:** a themed tooltip panel. Today tooltips use the default Godot style. Add them to stat icons in the top bar, upgrade rows, relics, fathers and research nodes.
- **Keyboard:**
  - **Esc** runs the same "close the top thing" logic as Android Back. Move the body of `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` into a `close_top()` function and call it from both. On the home screen, Esc opens Settings or a "Quit?" modal instead of the "press again to leave" toast.
  - **1–5** switch tabs; **Space** recenters the map on the capital.
  - **F** petitions Royal Favor (still confirmed in the modal).
  - **Shift-click** or **Ctrl-click** on buy buttons for ×10 or max, matching `buy_amount_selector.gd`.
- **Mouse:**
  - Wheel zoom (×1.12 per notch, toward the cursor) and left-drag pan already work in `map_view.gd`'s `_gui_input`. Tune the feel, and add middle- or right-drag pan.
  - Edge-pan is optional.
  - Hold-to-buy in `buy_button.gd` should work with a held mouse button. Verify it.
- **A Quit button** in Settings on desktop. Phones never need one.

#### L6. Art for wide screens (about 2–4 days, plus owner review)
- **The world is portrait-shaped.** `WorldMap` is 64×96 tiles of 24 px, so 1536×2304 px. `min_zoom()` is `size.x / 1536`, which means a wide map area can never zoom out past filling the width.
  - At 1920×1080 with the rail and colony panel open, the map area is about 1240×950. Minimum zoom is about 0.8, showing about 1550×1190 world px, roughly half the map's height. With the panel closed (about 1800 wide), minimum zoom is about 1.17 and only about a third of the height shows.
  - It's playable: the player pans vertically, as on the phone. But it loses the "see my whole empire" view that a big monitor should give.
  - **Options:**
    - (a) Allow zooming out past the width and frame the map with sea and parchment margins. This is cheap, about 1–2 days, and recommended for launch.
    - (b) Use the continental map (`continental_map.gd`) as the desktop overview.
    - (c) A wider world generator for desktop. **Not recommended**: saves store site data and a generator version, so a different world shape would split saves and save codes between mobile and Steam.
  - Also check the map's sprite pixel scale at zoom 0.8–1.2 for shimmer (section 4.2).
- UI frames are 9-slice styles, which stretch fine, but check wide panels for visible texture repetition.
- New art: a themed nav-rail background and possibly a parchment edge for the docked panel.

**Landscape total: about 2.5–4 weeks** of focused work, or 3–5 weeks including review rounds with the owner.

## 6. Steam integration

### 6.1 Steamworks and GodotSteam
- **Owner tasks:**
  - Steamworks partner account, $100 app fee per game (recoupable after $1,000 gross).
  - Tax interview and bank details.
  - These take a few days to clear, so start early.
- **Library:** GodotSteam as a GDExtension (no custom engine build). Pick the release that matches Godot 4.7.2. If none matches yet, pin the newest compatible one and record that in `docs/EXPORT_SETUP.md`.
- Add a new autoload `SteamService`, loaded only with the `steam` feature:
  - `Steam.steamInitEx()` at startup.
  - `restartAppIfNecessary(app_id)` in release builds.
  - Callbacks run each frame.
  - The game must still run if Steam isn't running (offline mode). Achievements then queue up and sync later; Steam's local cache handles this.
- `steam_appid.txt` is for development only. It's in the export exclude list and never shipped.

### 6.2 Achievements (about 2 days, plus Steamworks setup)
- Map the existing game events to about 25 achievements:
  - first colony founded;
  - first workshop;
  - first independence;
  - independence under N hours;
  - all 25 colonies;
  - each relic set complete;
  - all Founding Fathers;
  - each specialization used;
  - first Almanac page read;
  - Liberty milestones;
  - a few flavor ones from the Ledger stats (the "oxen" kind).
- Wire them off the existing signals (`colony_founded`, `father_joined`, `milestone_reached`, `relic_found`, independence) in `SteamService`. Game code doesn't call Steam directly.
- **Retroactive unlocks:** at startup, unlock anything the save already qualifies for. This covers imported save codes and pre-release testers.
- Achievement icons, 64×64 locked and unlocked: about 50 small images. Generate them in the existing icon style with `tools/gen_sprites.py`, then have the owner review.

### 6.3 Steam Cloud saves (about 1 day)
- Use **Auto-Cloud**, configured in Steamworks with no code needed. Point it at the save folder and sync only `save.json` and `save.json.bak`. Leave out `display.cfg`, `entitlements.cfg` and `desktop_store.cfg`.
- **Save location:** turn on `use_custom_user_dir` for `.pc` only, as "Idle Pioneer". The path is then `%APPDATA%\Idle Pioneer` instead of `%APPDATA%\Godot\app_userdata\Idle Pioneer`, so a player can find it. Use a feature override so phone storage paths don't change.
- **Conflicts:** Steam's own conflict dialog handles two PCs. The save already carries `version`, and `SaveIO.read` refuses saves from a newer version without overwriting them. Keep that behavior.
- **Save codes** keep working, and they work across platforms. A mobile player can move a save to Steam and back. Ad-Free stays separate from saves, by design.

### 6.4 Optional extras
- **Rich Presence** (about half a day): "Governing 12 colonies · Expedition 4".
- **Overlay:** verify the Steam overlay draws with the GL Compatibility renderer on Windows and Linux. Check this in the first Steam build.
- **Steam timer and Deck suspend:** on resume, apply offline catch-up. The `NOTIFICATION_APPLICATION_RESUMED` path is mobile-only today. On desktop, detect a long gap between frames (over 60 s, from suspend or sleep) and run `_catch_up`.

## 7. Steam Deck and controllers

**What helps:** the Deck has a touchscreen, and `map_view.gd` already handles touch, drag and pinch. In the default desktop configuration the trackpad acts as a mouse.

**What hurts:** every button is `focus_mode = FOCUS_NONE`, so there's no gamepad focus navigation at all.

- **Target "Playable" at launch:**
  - The layout fits 1280×800, since 16:10 gets the extra height.
  - Text is legible on a 7" screen. Check `SIZE_MIN` (18 px) at Deck scale; the Large UI toggle may need to be the default on Deck. Detect the Deck with the `SteamDeck` environment variable or GodotSteam's `isSteamRunningOnSteamDeck()`.
  - Ship a recommended Steam Input layout: trackpad mouse, triggers for click, a button for Esc, bumpers to switch tabs.
  - The on-screen keyboard isn't needed except for save codes, which use the clipboard. On Deck, add a "Show keyboard" prompt or rely on the Steam keyboard.
- **Later update, about 1–2 weeks: full gamepad support.**
  - Turn on focus, with a visible focus style in the theme. The `font_focus_color` hook already exists.
  - Focus neighbors on the nav rail, cards and modals.
  - Stick-pan and trigger-zoom on the map.
  - Button glyph hints.
  - This unlocks "Verified", which helps Deck visibility.

## 8. Store page, marketing and compliance

### 8.1 Store page (owner and Claude, about 3–5 days, can run in parallel with sections 4–7)
- **Capsule art:** header, small, main, vertical, and library capsule/hero/logo.
  - Check sizes against the current Steamworks "Graphical Assets" page, because they change.
  - Generate drafts from the existing art pipeline. Capsule art matters more than anything else on the page, so consider commissioning the main capsule.
- **Screenshots:** at least 5 at 1920×1080. Extend `tools/shot.gd` so it renders landscape scenes headlessly at 1920×1080. It already does this for the phone store shots.
- **Trailer:** 30–60 s of the core loop.
- **Copy:** adapt `store/COPY.md` for Steam (longer description, feature list, tags).
  - Tags: Idle, Incremental, Strategy, Simulation, Historical, Pixel Graphics, Casual, Singleplayer.
  - Remove ad and IAP language.
- Content survey, age rating questionnaire, and system requirements. Those are low: GL Compatibility, roughly 2 GB RAM, and any GPU from the last 10 years.
- **"Coming Soon" page:** live as early as possible, at least 2 weeks before release (Steam requires it). Every day it's up collects wishlists.

### 8.2 Launch timing
- Steam's review takes a few business days each for the store page and for the build. Both must pass before release.
- **Next Fest** (if D2 = yes) needs a demo build and a registration window, months ahead. Check the Steamworks events calendar once the account exists.

### 8.3 Licensing and legal
- **Music:** the ElevenLabs Eleven Music licence covers an "Indie Game" under $500k lifetime game revenue and $1M/yr. Steam revenue counts toward that, together with mobile. Fine for now; keep an eye on it.
- **Fonts** (OFL) and **SFX/ambience:** commercial use is fine. Keep `assets/audio/CREDITS.md` and the in-game Credits screen in the Steam build.
- **GodotSteam** (MIT) and the **Steamworks SDK** (redistribution allowed under the Steamworks agreement): add them to Credits & Licenses.
- **Privacy policy:**
  - The Steam build collects nothing itself.
  - Update `docs/site/privacy.html` with a Steam section: no ads, no analytics; Steam's own data handling applies.
  - The policy link in Settings stays.
- **EULA:** Steam's default subscriber agreement is enough.

## 9. Build and release pipeline (about 2–3 days)

- **Export presets:**
  - "Windows (Steam)": x86_64, feature tag `steam`, `.ico` icon from `assets/icons/app_icon_1024.png`, and export filters per section 3.3.
  - "Linux (Steam)": the same.
- **Version:** shared `application/config/version`, so Steam and mobile release numbers stay in step.
- **`tools/steam/build_steam.cmd`:** headless export of both presets with the standard Godot 4.7.2 install on E:, then `check_build.py`, then staging into `build/steam/{windows,linux}`.
- **SteamPipe upload:**
  - `tools/steam/app_build.vdf` and depot VDFs, run with `steamcmd`.
  - The owner logs into steamcmd themselves (password and Steam Guard). Uploads go to a `beta` branch first; the owner promotes them to `default` in Steamworks.
- **Code signing:** not required for Steam. SmartScreen warnings mostly don't apply to Steam launches.
- **Crash logs:** Godot writes logs to `user://logs`. Add a "Open log folder" button in Settings on desktop so support requests can include them.

## 10. Testing and QA

- **Portrait regression check (protects mobile):**
  - Extend `test/unit/test_ui_smoke.gd` to build the UI at 720×1280 and 1920×1080. It must assert no errors and no overflowing controls in both.
  - Before each phase merges to `main`, render the existing phone screenshots with `tools/shot.gd` and compare them with the `mobile-v1.0.0` tag's shots. They must match, or any change must be intended.
- **Resolution matrix:** 1280×720, 1366×768, 1920×1080, 2560×1440, 3440×1440 (ultrawide), 3840×2160, 1280×800 (Deck). Also check window resizing across the wide/portrait threshold.
- **Platform tests** (`test_platform.gd`), with new cases:
  - The `steam` feature gives SteamBackend, Ad-Free owned and no ads.
  - A release desktop build without `steam` never gives DesktopBackend.
  - No store UI on Steam.
- **Achievement tests:** retroactive unlock logic, against a mocked `SteamService`.
- **Playtest:** one full expedition through independence on desktop, using mouse and keyboard only. Then a second one on a Deck, or a 1280×800 window with a controller in Steam Input's desktop mode.
- **Performance:** check the terrain shader at 4K, unfocused fps, and offline catch-up after a long PC sleep. The `test_perf.gd` baselines stay green.
- **Steam beta:** build on the `beta` branch with a handful of Steam keys for testers before launch.

## 11. Phases and schedule

Estimates assume focused development with Claude; owner review rounds are included where noted. The phases are roughly sequential. The store page work (P6) runs in parallel from P1 onward.

| Phase | Contents | Estimate | Owner tasks |
|---|---|---|---|
| **P0 Setup** | `steam` branch, export presets, base-resolution spike (4.1), D1–D6 decisions | 1–2 days | Decide D1–D6; open Steamworks account |
| **P1 Platform** | SteamBackend, store UI gating, mobile code exclusion, `check_build.py`, touch wording, Esc/Back unification | 2–3 days | — |
| **P2 Display** | Window modes, display settings, frame cap, unfocused behavior, autosave, sleep catch-up, custom user dir | 2–3 days | — |
| **P3 Landscape shell and colony panel** | L1 + L2 | 1.5–2 weeks | Review layout screenshots |
| **P4 Pages and overlays** | L3 + L4 | 1–1.5 weeks | Review |
| **P5 Desktop polish** | L5 + L6, hover and tooltips, shortcuts, wide art | 1–1.5 weeks | Review art |
| **P6 Store page** | Capsules, screenshots, copy, "Coming Soon" page live | 3–5 days, in parallel | Approve art and copy; submit the page for review |
| **P7 Steam features** | GodotSteam, achievements and icons, Cloud, Rich Presence, overlay check | 4–6 days | Configure achievements and Cloud in Steamworks (Claude prepares the lists) |
| **P8 Deck pass** | 1280×800 fit, Deck detection, Steam Input layout | 2–3 days | Test on a Deck if available |
| **P9 Release** | Build pipeline, SteamPipe, beta branch, full QA matrix, Steam build review | 3–5 days | steamcmd login, beta testers, press Release |
| **Later** | Full gamepad support (Verified), demo build, pinned colony panel, DLC | 1–3 weeks | — |

**Total to launch: about 7–10 weeks**, of which about 5–7 weeks is development. The rest is review rounds, Steam's review times and the required 2-week "Coming Soon" period, which mostly overlap with development.

## 12. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Landscape changes break the phone layout | Mobile regression | Wide-only branches, portrait screenshot diff against `mobile-v1.0.0`, smoke tests at both sizes |
| GodotSteam has no release for Godot 4.7.2 | Blocks P7 | Check in P0; if it's missing, pin the nearest version or stay on Godot 4.7.x for both builds |
| Pixel shimmer at non-integer scales | Looks cheap on 1440p | Spike in P0; linear-with-mipmaps for the map |
| Portrait-shaped world in a landscape view | Only a strip of the map is visible; it feels cramped on a big monitor | Zoom out past the width with framed margins (L6 option a); don't change the world generator, which would split saves between platforms |
| Steam audiences review "mobile port" harshly | Low review score | The landscape layout, desktop interaction and no ads are what this plan is for; get beta feedback before launch |
| Low wishlists at launch | Weak visibility | "Coming Soon" page early, demo and Next Fest (D2), devlog posts |
| DesktopBackend ships by accident | Free Ad-Free and fake ads in a paid game | Backend selection rule (3.2) plus `check_build.py` |
| Music licence threshold | Licence breach at scale | Track combined revenue; it's far off for now |
