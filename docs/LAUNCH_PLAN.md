# Launch Plan: Google Play and the App Store

Audit of 2026-09-24. Two reviews fed into this plan:
- a code robustness review of save, simulation, lifecycle, UI and content;
- a store-readiness review of export setup, legal, assets and store policies.

Items marked ✅ were fixed in the commit after this plan was written.

## Where the game stands

**Core loop**
- Complete: random and North America maps, 25 colonies, 26 recipes, Founding Fathers, independence and reforms, governors, charters, the market, treasure and Royal Favor.
- Added this round: milestones, relics, the Almanac, specializations and the Ledger.

**Art and audio:** high-density pixel art, period music and CC0 sound effects.

**Tests:** 41 automated tests (sim, game, world, UI smoke), plus a balance bot, a screenshot harness and a map preview tool.

**Privacy:** the game itself collects nothing. The owner chose a free-with-light-ads model plus a US$4.99 Ad-Free purchase (see MONETIZATION.md), so the store privacy forms must declare the AdMob SDK's data collection. Drafts of the privacy, support and landing pages are in `docs/site/`.

## Audit findings

### Code (from the robustness review)

| Severity | Finding | Status |
|---|---|---|
| Critical | Late-game offline catch-up simulates every trip one at a time and stores a record per shipment. With 25 colonies at upgrade level 100 that took 9.7 s and 240 MB on desktop, which would mean a freeze or crash at launch on a phone. | ✅ Trips are now batched per colony per step, with per-step totals. |
| High | The Android back button quits the app (`quit_on_go_back` defaults to true) instead of closing the open sheet. | ✅ |
| High | The top bar overflows 720 px in the late game: Liberty and colonist counts aren't abbreviated, which pushes the settings button off-screen. | ✅ |
| High | Saves rebuild the map from its seed, so any change to content, balance, generator or engine silently changes a saved run's colonies. | ✅ The save now stores each colony's site data and a generator version. |
| High | Two failed saves in a row could wipe progress: the backup is overwritten even when the current file is bad, the save version is never checked, and a NaN value breaks loading. | ✅ |
| Medium | Moving the device clock forward grants repeat offline catch-up and can lock Royal Favor. | ✅ Offline time only beyond the latest time seen; Favor cooldown capped. |
| Medium | The map redraws and pathfinds the Europe lane every frame, there's no FPS cap, and the terrain shader is heavy. | ✅ Lane cached, 60 fps cap, "Map effects: Light" setting. |
| Medium | Touch targets (about 27–37 dp) and small text (about 10 sp) are below mobile guidelines, and there's no bottom safe area. | ✅ Partly: bottom safe area, text +10%, smallest buttons raised to 58–60. Confirm on devices. |
| Low | Numbers above 9.2e18 overflow when converted to integers (Liberty, costs), and `Format.num` runs out of suffixes around 1e36. | ✅ |
| Low | Frame hitches of 1–3 s drop a little production. | ✅ |
| Low | Stray `__pycache__` files, unused art and font files, and dev folders (GUT, tools, tests, docs) would ship in the build. | ✅ Export filters in `export_presets.cfg`; unused font removed. |

**Checked and fine:** every content cross-reference resolves and every effect is handled. Milestone math holds at the edges, and purchase guards are solid. The market isn't affected by clock changes. Pause and resume saves correctly.

### Store readiness

**Blockers**
1. **No export presets.** Create Android (AAB, arm64, target API 36, no permissions) and iOS presets, with filters that exclude `addons/gut`, `test`, `tools`, `docs` and `assets/art`.
2. **Android target API 36.** Required for new apps and updates from 31 Aug 2026.
3. **Closed test.** New personal Play accounts need 12+ testers for 14 consecutive days before production.
4. **Font licenses.** `OFL.txt` files must ship with Libre Baskerville and Almendra. Drop the unused ManufacturingConsent font.
5. **Credits and licenses screen.** Needs Godot's MIT notice (`Engine.get_license_text()`), the fonts, Kenney, GeneralUser GS and the music.
6. **Art provenance.**
   - `assets/art/backgrounds/harbor.png` is AI-generated and carries a Gemini watermark. The shipped crop excludes the watermark, but the terms and the owner's comfort need confirming.
   - `dark_wood.jpg` and `parchment.jpg` are no longer used by the game. They came from the old Unity project with no license, so leave them out of the export or delete them.
7. **iOS.** Requires a Mac with Xcode 26, the $99/yr Apple Developer Program and a privacy manifest (Godot's export options cover it).

**Should**
- Use the standard (non-.NET) export templates. They're smaller and avoid a known 16 KB page-alignment bug.
- App icon: an Android adaptive icon (foreground, background and monochrome layers), plus 512 px and 1024 px store icons.
- Safe areas: the bottom inset for the gesture bar and home indicator.
- Performance: FPS cap and low-processor mode while idle (done), and profiling on a 4-year-old Android phone.
- A privacy policy URL; a one-paragraph static page is enough.
- Age-rating questionnaires: IARC for Play and Apple's 2026 form. Expect Everyone 10+ / PEGI 7–12 because of tobacco, rum and muskets, and historical references to slavery in the lore.
- Store listing assets: feature graphic 1024×500, phone screenshots, short and full descriptions. `tools/shot.sh` can produce the screenshots.

**Nice**
- Localization: strings aren't wrapped in `tr()` yet.
- A text-size setting.
- Cloud save (Play Games or Game Center) or a save export/import code.
- An in-app review prompt.

## Progress (24 Sept 2026)

- **Phase 0 done by Claude:**
  - code fixes
  - OFL license files
  - Credits & Licenses screen
  - export presets (`export_presets.cfg`, local, gitignored) and a setup guide (`docs/EXPORT_SETUP.md`)
  - app and store icons, Android adaptive layers, Play feature graphic (`assets/icons/`)
- **Phase 1 done by Claude:**
  - the Philosophical Society (102 studies)
  - clock protection
  - save code export/import
  - light map-effects setting
- **Phase 0 still open, owner:**
  - package id (placeholder `com.idlepioneer.game`)
  - the credit line in `data/credits.json`
  - the harbor art decision
  - device profiling
- **Phase 1 still open:** device playtests of the first runs.

## Second review (27 Sept 2026) — status

- **Section A fixed:**
  - saves carry their world
  - save failures are shown and retried
  - deep save validation, and saves from newer versions are refused
  - market-boundary pricing
  - Congress cache
  - Back button and interruption handling
  - scrolling dialogs with safe areas
  - Large text option
  - long catch-ups run in slices with progress
  - offline pace explained
- **Monetization part 1 done:**
  - the `Platform` layer with a desktop stand-in
  - "Consult the Almanac" rewarded bonus
  - the between-expeditions interstitial
  - Ad-Free / Restore / version in Settings
- **Monetization part 2 open:** native AdMob, UMP and billing backends. These need a working Android build.
- **Rights:** the Europe banner is now original art made in code, and the AI source was removed.
- **Still the owner's to do:**
  - accounts and package ID
  - the credit line
  - hosting `docs/site`
  - a rented Mac for iOS

## Phases

### Phase 0: technical hardening (3–5 days)
| Task | Who |
|---|---|
| Critical and High code fixes above | Claude ✅ |
| Export presets: package id (e.g. `com.<you>.idlepioneer`, permanent once published), API 36, arm64 AAB, no permissions, export filters | Claude drafts; owner creates in the editor (`export_presets.cfg` is gitignored because it holds signing paths) |
| OFL license files, drop the unused font, Credits and Licenses screen | Claude |
| Bottom safe area, larger touch targets and small text, frame cap | Claude, then test on devices |
| Adaptive icon layers, 512 and 1024 store icons, feature graphic | Claude generates; owner approves |
| Decide on the AI harbor art (keep, or replace with a pixel-art dock scene) and remove the unused Unity textures | Owner decides; Claude executes |
| Profile on a low-end Android phone and an older iPhone | Owner or a tester |

### Phase 1: content complete (1–3 weeks; owner sets scope)
| Task | Who |
|---|---|
| Review the research plan, then build research (60 studies) | Owner reviews; Claude builds |
| Late-game pacing pass with the balance bot through 25 colonies | Claude |
| Remaining Medium and Low code items (clock protection, shader LOD, number overflow) | Claude |
| Save export/import code (cheap insurance without cloud save) | Claude |
| Real-device playtests of the first two runs to tune onboarding | Owner and friends |

### Phase 2: Android closed test (about 3 weeks, mostly the 14-day clock)
| Task | Who |
|---|---|
| Play Console account ($25, identity verification) | Owner |
| Upload keystore: create and back up offline; enroll in Play App Signing | Owner (Claude provides the `keytool` command) |
| Privacy policy page (e.g. GitHub Pages) | Claude drafts; owner hosts |
| Data safety (declare the AdMob SDK's collection), "Contains ads", in-app purchase, IARC questionnaire, target audience (not for children) | Claude drafts answers; owner submits |
| Store listing text, screenshots, feature graphic | Claude; owner approves |
| Recruit 12+ testers, run 14+ days, fix issues, apply for production | Owner; Claude fixes |

### Phase 3: iOS (1–2 weeks, can overlap Phase 2)
| Task | Who |
|---|---|
| Apple Developer Program, a Mac with Xcode 26, bundle id, certificates | Owner |
| iOS export (privacy manifest, icons), archive in Xcode, TestFlight | Owner, using the Mac |
| App Store Connect: App Privacy (AdMob data use), Ad-Free non-consumable, age rating, screenshots, listing, review notes | Claude drafts; owner submits |
| Decide iPhone-only or iPad as well | Owner |

### Phase 4: launch and after
- First Play release goes to the chosen countries all at once (percentage rollouts only apply to later updates), so consider a limited-country launch first; use staged rollouts for updates and watch Android vitals.
- Yearly upkeep: Android target API (each August) and Xcode/SDK (each April).
- Post-launch roadmap: the BACKLOG items (Royal Commissions, Seasons, Frontier events, the Constitution), localization, cloud save.

**Estimate:** about 4–6 weeks to Android production, dominated by the closed-test wait. iOS fits in the same window once a Mac and the Apple account are ready.

## Only the owner can do
- Pay the store fees and complete identity verification.
- Keep the signing keys and certificates safe.
- Host the privacy policy.
- Make the art provenance decision.
- Recruit testers.
- Submit to the stores.
