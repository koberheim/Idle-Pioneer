# Idle Pioneer: store marketing package

Everything here is generated from the real game, except `COPY.md`, which is written by hand. Rebuild it all with:

```bash
python tools/store/build_store.py                 # renders, composes, copies icons, checks sizes (about 4 minutes)
python tools/store/build_store.py --skip-render   # recompose captions only (needs a previous render)
python tools/store/build_store.py --only 01_map,08_ledger
python tools/store/build_store.py --ipad          # also adds ipad_13/ (2064x2752); see "iPad" below
```

The script needs Python 3 with Pillow, and the Godot 4.7.2 console exe. The path is set at the top of the script; override it with the `GODOT` environment variable. Godot opens a borderless window for a few seconds per shot. Don't click into it.

**How it works:**
- `tools/shot.gd` gained `store_*` scenarios. They seed a believable late-game expedition: the 5th, English, random map seed 7, 11 colonies, 2.47B gold, 18.6B earned this expedition, a dozen or more workshops running, 7 Founding Fathers seated, 16 studies, 18 of 30 relics, and 4 governors posted. Tips are switched off and the world is paused for the final frame, so no floating "+gold" text or advisor cards appear in the shot.
- It renders each shot with `winsize=WxH`: a borderless window at the exact pixel size, even one taller than the monitor.
- Every run uses its own scratch save, `user://store_shot_<pid>.json`, which is deleted afterwards. **It never reads or writes `save.json`**, its `.bak`, or `entitlements.cfg`. `shot.gd` also refuses a `save=` name starting with "save".
- Every render runs with `clipcheck=1`. Any clipped, overflowing or off-screen label in view is printed at the end of the build. The final build reported none.
- The "marketing" versions are a second render at the inset size (no resampling, so the pixel art stays crisp). It sits in a dark frame with a gold rule on the game's dark-wood panel art, under a caption banner built from the game's parchment panel (`assets/sprites/ui/panel.png`, 9-sliced). The headline is set in Almendra and the subline in Libre Baskerville, the game's own two fonts.
- `store/.gdignore` keeps Godot from importing this folder as game assets, which also keeps it out of the exported app.

## Files

All PNGs are 24-bit RGB with no alpha channel. Each screenshot is 0.5 to 1.3 MB, well under both stores' limits.

### Screenshots: marketing versions (caption banner + framed game), upload these

| Folder | Size (px) | Store slot |
|---|---|---|
| `google_play_phone/01_map.png` … `08_ledger.png` (8 files) | 1080 × 1920 | Google Play › Phone screenshots (2–8 allowed; 9:16) |
| `iphone_6.9/01_map.png` … `08_ledger.png` (8 files) | 1290 × 2796 | App Store › iPhone 6.9" display (also accepted for 6.7") |
| `iphone_6.5/01_map.png` … `08_ledger.png` (8 files) | 1242 × 2688 | App Store › iPhone 6.5" display (only needed if 6.9" isn't supplied; Apple scales 6.9" down otherwise) |

### Screenshots: raw game, no caption (the same shots full-bleed, at true device resolution)

| Folder | Size (px) | Use |
|---|---|---|
| `raw/google_play_phone/*.png` (8) | 1080 × 1920 | Play phone screenshots, if you prefer uncaptioned shots; press kit |
| `raw/iphone_6.9/*.png` (8) | 1290 × 2796 | App Store 6.9", uncaptioned alternative |
| `raw/iphone_6.5/*.png` (8) | 1242 × 2688 | App Store 6.5", uncaptioned alternative |

### The eight shots, in story order

| # | File | Shows | Caption |
|---|---|---|---|
| 1 | `01_map` | The painted New World map: 11 colonies, roads and sea lanes, wagons and a ship, the next site flagged | Found Colonies in the New World |
| 2 | `02_colony` | Cuper's Cove colony sheet: production, wagons and roads, colonists, governor, Royal Charter | Grow Every Settlement |
| 3 | `03_workshops` | Workshops: the Philosophical Society entry, Sawmill and Charcoal Kiln staffed | Craft Finer Wares |
| 4 | `04_europe` | The Docks of Europe: the harbor banner, recruiting, Wanted/Glut prices, the warehouse | Trade with the Old World |
| 5 | `05_congress` | Continental Congress: Declaration ready (gold goal met, militia armed), Founding Fathers serving | Convene a Continental Congress |
| 6 | `06_declaration` | The Declaration of Independence, signed and sealed: "Independence! +42 Liberty" | Declare Independence! |
| 7 | `07_society` | The Philosophical Society, Husbandry & Agriculture branch, with dated historical studies | Join the Philosophical Society |
| 8 | `08_ledger` | The Ledger: Almanac pages and the relic sets, 18 of 30 found | Collect Relics of History |

### Icons and feature graphic

| File | Size (px) | Store slot | Source |
|---|---|---|---|
| `icon_512.png` | 512 × 512 | Google Play › App icon (32-bit PNG allowed; this one is opaque RGB) | `assets/icons/app_icon_512.png` (`tools/gen_app_icons.py`) |
| `icon_1024_app_store.png` | 1024 × 1024 | App Store icon (must be opaque, no rounded corners: it is) | `assets/icons/app_icon_1024.png` |
| `feature_graphic_1024x500.png` | 1024 × 500 | Google Play › Feature graphic | `assets/icons/feature_graphic_1024x500.png` (`tools/gen_app_icons.py`) |

The feature graphic already has the "Idle Pioneer" wordmark. Its flags are plain cream period pennants, with small red streamers on the ship mastheads, and nothing resembles the red-field, navy-canton flag that FINAL_AUDIT.md flagged. It came out of the final-audit fixes and was used as-is.

### Text

| File | What |
|---|---|
| `COPY.md` | Every listing field for Play and the App Store, with character counts. Also: rating questionnaire answers, Data safety and App Privacy notes, taglines, screenshot captions, and the source of every fact quoted. |
| `README.md` | This file. |

## iPad

The iOS export preset (`export_presets.cfg`, local and git-ignored) has `application/targeted_device_family=0`, which means **iPhone only**. As things stand, the App Store needs no iPad screenshots, so none are included. If the owner switches the preset to iPhone & iPad, run the build with `--ipad` to add `ipad_13/` and `raw/ipad_13/` at 2064 × 2752. A test render at that size lays out correctly: the game widens to 960 logical units, and everything fits.

Google Play: the game isn't restricted to phones. Tablet screenshots (7" and 10") are optional, and Play falls back to the phone shots.

## Notes

- The numbers in the shots depend on the current `data/balance.json`. After a balance retune, rebuild so the gold and Liberty figures match the game. The scene itself is fixed by the seed.
- Europe's Wanted/Glut row can show different goods from build to build. The market rotates with the clock, and either way is genuine.
- Change captions in `SHOTS` in `tools/store/build_store.py`, then run with `--skip-render`.
