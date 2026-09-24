# Idle Pioneer

An idle/incremental colonial trade game for mobile, set in a New World
inspired by Sid Meier's *Colonization* (1994). Found colonies along a
New World coast, ship their goods to your capital, sell them to Europe or
craft them into finer wares, invite Founding Fathers to Congress, and when the
colonies are rich and armed, **declare independence** — earning Liberty for
permanent reforms and starting a new expedition.

Godot 4.7, GDScript, portrait 720×1280, GL Compatibility renderer.

## Playing

Double-click **Play Idle Pioneer.cmd** in the project folder to play without opening the editor (edit the Godot path inside it if Godot lives elsewhere).

## Run it

Open the folder in Godot 4.7 and press Play, or:

```bash
"E:/Godot/godot_mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --path .
```

## Tests

```bash
./run_tests.cmd
```

41 GUT tests: the simulation (including step-size independence for offline
catch-up), world generation (determinism, 25 sites covering every raw good,
every route reaching the capital, North America landmarks), commands, save
round-trip and corrupt-save recovery, independence, and a smoke test that
boots the real screen and presses every button.

## Layout

| Path | What |
|---|---|
| `data/content.json` | Goods, colonies, recipes, Founding Fathers, nations, Liberty reforms |
| `data/balance.json` | Every tunable number |
| `scripts/world/` | `WorldMap` (random continent generator, sites, routes) and `NorthAmerica` |
| `assets/shaders/terrain.gdshader` | Renders the map from a per-tile data texture |
| `data/colony_names.json` | Per-nation colony names, in founding order |
| `scripts/core/` | Autoloads: `Content`, `Balance`, `Game` (state, tick, commands, save), `Sfx` |
| `scripts/sim/` | Pure simulation: `RunState`, `MetaState`, `Sim.step()` |
| `scripts/ui/` | Screens, built in code and updated in place |
| `tools/` | Art generators, balance bot, screenshot harness |
| `docs/GAME_DESIGN.md` | The original locked design |
| `docs/DESIGN_NOTES.md` | What was built and where it departs from the design, and why |
| `docs/legacy/` | Planning docs from the earlier prototype |

## Tools

```bash
python tools/gen_sprites.py      # regenerate icons, portraits, settlements, UI frames (needs Pillow)
python tools/gen_decor.py        # regenerate the tree / hill / mountain atlas
"E:/Godot/godot_mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --headless --path . res://tools/balance_bot.tscn -- seed=1 liberty=0 hours=8 map=random
tools/shot.sh map out.png        # screenshot a scripted state (map, zoomout, overview, sheet, found, workshops, europe, congress, nation, tip, fresh, ...; add map=north_america)
```

The balance bot plays a run greedily with the real simulation and prints a
timeline — use it after changing `balance.json` or `content.json`.

## Exporting to Android / iOS

1. The 4.7.2 (.NET) export templates are already installed on this machine
   (Editor → Manage Export Templates).
2. Project → Export → add Android (and/or iOS). Orientation is already set to
   portrait in project settings; `export_presets.cfg` is git-ignored because it
   holds keystore paths.
3. For Android, set up a debug keystore in Editor Settings → Export → Android.

Saving happens every 15 s and whenever the app is backgrounded; progress
continues offline for up to 4 hours.
