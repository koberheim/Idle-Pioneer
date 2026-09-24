# Audio credits

## Music (`music/`)

All four tracks are original arrangements made for this game by
`tools/music/compose.py` (MIDI written in Python, rendered with FluidSynth). The
melodies are public-domain tunes, written out from the traditional tunes, not
copied from recordings or anyone else's arrangement or MIDI file.

| file | tunes | origin |
|---|---|---|
| `theme.ogg` | Yankee Doodle; Soldier's Joy | trad., American colonies c. 1755-75; trad. fiddle reel, 18th c. (British Isles / colonies) |
| `europe.ogg` | Greensleeves; Drunken Sailor | trad. English, 16th c.; trad. sea song, tune 18th c. or older |
| `congress.ogg` | Minuet in G (BWV Anh. 114); Old Hundredth | Christian Petzold, 1725; Louis Bourgeois, Genevan Psalter, 1551 |
| `independence.ogg` | Yankee Doodle (fife-and-drum march with brass fanfare) | trad., c. 1755-75 |

Rendering tools (not shipped, not in the repo):

- **FluidSynth 2.6.1**, win10-x64 build. Source:
  https://github.com/FluidSynth/fluidsynth/releases/download/v2.6.1/fluidsynth-v2.6.1-win10-x64-cpp11.zip
  License: LGPL-2.1 (used only as a tool; nothing from it is distributed).
- **GeneralUser GS 2.0.3** SoundFont by S. Christian Collins. Source:
  https://github.com/mrbumpy409/GeneralUser-GS (`GeneralUser-GS.sf2`),
  https://www.schristiancollins.com
  License: GeneralUser GS License v2.0 - may be used without restriction for
  music creation, private or commercial
  (https://github.com/mrbumpy409/GeneralUser-GS/blob/main/documentation/LICENSE.txt).

## Sound effects (`sfx/`)

From Kenney (www.kenney.nl), **CC0 1.0** (public domain,
http://creativecommons.org/publicdomain/zero/1.0/). Credit is not required but
given gladly. Samples were trimmed, faded and peak-normalised to -3 dBFS.

| file | Kenney pack | source sample | pack URL |
|---|---|---|---|
| `click.ogg` | Impact Sounds | `impactWood_light_002.ogg` | https://kenney.nl/assets/impact-sounds |
| `tab.ogg` | RPG Audio | `bookFlip3.ogg` | https://kenney.nl/assets/rpg-audio |
| `buy.ogg` | RPG Audio | `handleCoins2.ogg` | https://kenney.nl/assets/rpg-audio |
| `coin.ogg` | RPG Audio | `handleCoins.ogg` | https://kenney.nl/assets/rpg-audio |
| `deny.ogg` | Interface Sounds | `error_006.ogg` | https://kenney.nl/assets/interface-sounds |
| `found.ogg` | Music Jingles | `jingles_PIZZI10.ogg` | https://kenney.nl/assets/music-jingles |
| `discover.ogg` | Music Jingles | `jingles_PIZZI04.ogg` | https://kenney.nl/assets/music-jingles |
| `father.ogg` | Impact Sounds | `impactBell_heavy_000.ogg` | https://kenney.nl/assets/impact-sounds |
| `liberty.ogg` | Impact Sounds | `impactBell_heavy_001.ogg` | https://kenney.nl/assets/impact-sounds |

Also downloaded and reviewed, but no sample used: Kenney "UI Audio"
(https://kenney.nl/assets/ui-audio) and "Casino Audio"
(https://kenney.nl/assets/casino-audio), both CC0.

`fanfare` has no file and is still synthesised by `scripts/core/sfx.gd`.
