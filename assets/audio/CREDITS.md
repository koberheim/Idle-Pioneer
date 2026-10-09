# Audio credits

## Music (`music/`)

All tracks are original arrangements made for this game by
`tools/music/compose.py` (MIDI written in Python, rendered with FluidSynth). The
melodies are public-domain tunes, written out from the traditional tunes (the
newer theme tunes checked against traditional session settings of the tune),
not copied from recordings or anyone else's arrangement or MIDI file. Harmony,
instrumentation and form are original. Every track is normalised to -16 LUFS.

| file | tunes | origin |
|---|---|---|
| `theme.ogg` | Yankee Doodle; Soldier's Joy | trad., American colonies c. 1755-75; trad. fiddle reel, 18th c. (British Isles / colonies) |
| `theme_2.ogg` | Haste to the Wedding | trad. jig, England/Ireland, first printed 1767 |
| `theme_3.ogg` | The White Cockade | trad. Scottish march, 18th c. (a fife tune of the American Revolution) |
| `theme_4.ogg` | Lilliburlero | English, 1688; tune attributed to Henry Purcell (1659-1695) |
| `europe.ogg` | Greensleeves; Drunken Sailor | trad. English, 16th c.; trad. sea song, tune 18th c. or older |
| `congress.ogg` | Minuet in G (BWV Anh. 114); Old Hundredth | Christian Petzold, 1725; Louis Bourgeois, Genevan Psalter, 1551 |
| `independence.ogg` | Yankee Doodle (fife-and-drum march with brass fanfare) | trad., c. 1755-75 |

Instruments are period ones: recorder, flute played as a fife, fiddle,
harpsichord, cello, strings, natural-style brass, kettledrums, hand and side
drums. (`theme` and `europe` were re-rendered without the nylon guitar,
accordion and acoustic bass of the first version.)

## Sound effects (`sfx/`)

Built by `tools/music/sfx_tools.py build`: trimmed (under 2 ms before the
onset, with a 1.5 ms fade-in), faded out and loudness-normalised per id (see
`README.md`).

### From Kenney (www.kenney.nl), CC0 1.0

Public domain (http://creativecommons.org/publicdomain/zero/1.0/). Credit is
not required but given gladly.

| file | Kenney pack | source sample(s) | pack URL |
|---|---|---|---|
| `click.ogg` | Impact Sounds | `impactWood_light_002.ogg` | https://kenney.nl/assets/impact-sounds |
| `tab.ogg` | RPG Audio | `bookFlip3.ogg` | https://kenney.nl/assets/rpg-audio |
| `buy.ogg` | RPG Audio | `handleCoins2.ogg` | https://kenney.nl/assets/rpg-audio |
| `coin.ogg` | RPG Audio | `handleCoins.ogg` | https://kenney.nl/assets/rpg-audio |
| `deny.ogg` | Interface Sounds | `error_006.ogg` | https://kenney.nl/assets/interface-sounds |
| `found.ogg` | Music Jingles | `jingles_PIZZI10.ogg` | https://kenney.nl/assets/music-jingles |
| `discover.ogg` | Music Jingles | `jingles_PIZZI04.ogg` | https://kenney.nl/assets/music-jingles |
| `father.ogg` | Impact Sounds | `impactBell_heavy_000.ogg` | https://kenney.nl/assets/impact-sounds |
| `market.ogg` | Impact Sounds | `impactBell_heavy_003.ogg`, struck twice | https://kenney.nl/assets/impact-sounds |
| `charter.ogg` | Impact Sounds; RPG Audio | `impactWood_heavy_002.ogg` + `dropLeather.ogg` | https://kenney.nl/assets/impact-sounds, https://kenney.nl/assets/rpg-audio |
| `research.ogg` | RPG Audio (+ rendered) | `bookFlip1.ogg` + an original harpsichord figure (see below) | https://kenney.nl/assets/rpg-audio |
| `consult.ogg` | RPG Audio (+ rendered) | `bookOpen.ogg` + `bookFlip2.ogg` + an original glockenspiel chime (see below) | https://kenney.nl/assets/rpg-audio |

Also downloaded and reviewed, but no sample used: Kenney "UI Audio"
(https://kenney.nl/assets/ui-audio) and "Casino Audio"
(https://kenney.nl/assets/casino-audio), both CC0.

### Rendered stings (original)

Short original phrases written for this game in `tools/music/compose.py`
(`STINGS`) and rendered with FluidSynth and the GeneralUser GS SoundFont, like
the music. No existing tune is quoted.

| file | what |
|---|---|
| `fanfare.ogg` | trumpets, horns, trombone, kettledrums and side drum, about 3 s |
| `milestone.ogg` | ascending glockenspiel chime over a harp chord |
| `relic.ogg` | harp arpeggio blooming into a chord, pizzicato strings |
| `unlock.ogg` | flute run over pizzicato strings and harp |
| `purchase.ogg` | church-bell peal over strings, harpsichord and kettledrums |
| (in `research.ogg`) | harpsichord figure |
| (in `consult.ogg`) | two-note glockenspiel chime |

### Generated with ElevenLabs

Made with the ElevenLabs Sound Effects model (`eleven_text_to_sound_v2`) on a
paid Creator plan, which grants commercial use of the output. Prompts are in
`tools/music/eleven_manifest.json`; generation details (date, request id) are
logged by `tools/music/eleven.py` in `tools/music/out/log.jsonl`.

| file | generated | what |
|---|---|---|
| `sfx/liberty.ogg` | 9 Oct 2026 | a great bronze bell, single strike, open air |
| `sfx/quill.ogg` | 9 Oct 2026 | a quill stroke on parchment |
| `ambience/amb_newworld.ogg` | 9 Oct 2026 | coastal wilderness loop: waves, gulls, songbirds, distant axe |

## Tools (not shipped, not in the repo)

- **FluidSynth 2.6.1**, win10-x64 build. Source:
  https://github.com/FluidSynth/fluidsynth/releases/download/v2.6.1/fluidsynth-v2.6.1-win10-x64-cpp11.zip
  License: LGPL-2.1 (used only as a tool; nothing from it is distributed).
- **GeneralUser GS 2.0.3** SoundFont by S. Christian Collins. Source:
  https://github.com/mrbumpy409/GeneralUser-GS (`GeneralUser-GS.sf2`),
  https://www.schristiancollins.com
  License: GeneralUser GS License v2.0 - may be used without restriction for
  music creation, private or commercial
  (https://github.com/mrbumpy409/GeneralUser-GS/blob/main/documentation/LICENSE.txt).
- **ffmpeg** with libvorbis, for decoding, measuring and encoding.
