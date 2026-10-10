# Audio credits

## Music (`music/`)

`theme` to `theme_4` are original arrangements made for this game by
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

Instruments are period ones: recorder, flute played as a fife, fiddle,
harpsichord, cello, strings, natural-style brass, kettledrums, hand and side
drums. (The earlier rendered `europe` and `congress` tracks, on Greensleeves,
Drunken Sailor, Petzold's Minuet in G and Old Hundredth, were replaced by the
generated tracks below and are in git history.)

### Generated with ElevenLabs Music

| file | generated | what |
|---|---|---|
| `theme_5.ogg` | 9 Oct 2026 | fife and snare march joined by fiddle |
| `theme_6.ogg` | 9 Oct 2026 | slow fiddle air over a cello drone |
| `theme_7.ogg` | 9 Oct 2026 | jig on fiddle, wooden flute and hand drum |
| `theme_8.ogg` | 9 Oct 2026 | harpsichord and recorder duet |
| `theme_9.ogg` | 9 Oct 2026 | hammered dulcimer and fiddle |
| `europe.ogg` | 9 Oct 2026 | harbour tune on fiddle, wooden flute and hand drum |
| `europe_2.ogg` | 9 Oct 2026 | baroque string quartet |
| `europe_3.ogg` | 9 Oct 2026 | sailor's hornpipe on fiddle and flute |
| `congress.ogg` | 9 Oct 2026 | harpsichord-and-strings minuet |
| `congress_2.ogg` | 9 Oct 2026 | slow processional for chamber organ and strings |
| `congress_3.ogg` | 9 Oct 2026 | baroque string trio |
| `independence.ogg` | 9 Oct 2026 | fife-and-drum march into brass, timpani and bells |

All original compositions; prompts are in `tools/music/eleven_manifest.json`.

Made with Eleven Music (`music_v2_5`) on a paid Creator plan. Its terms allow
use in an "Indie Game" (under $500k lifetime revenue for the game and under
$1M a year in game revenue for the developer); a game past those limits needs
an ElevenLabs Enterprise music licence for these tracks, or the tracks
replaced. The previous rendered Yankee Doodle version is in git history.

## Sound effects (`sfx/`) and ambience (`ambience/`)

Generated with ElevenLabs on 9 Oct 2026 with the Sound Effects model
(`eleven_text_to_sound_v2`), on a paid Creator plan, which grants commercial
use of the output. Each file is a pick from 3–5 candidates, then trimmed and
loudness-normalised by `tools/music/sfx_tools.py` (ambience: gain and a light
peak limiter only, so the loop is untouched). The prompt for every id is in
`tools/music/eleven_manifest.json`; request ids and dates are logged by
`tools/music/eleven.py` in `tools/music/out/log.jsonl` (kept locally, not in
the repo).

Files: every id in `sfx/` (including the `_2`/`_3` variants) and
`ambience/amb_newworld.ogg`, `amb_europe.ogg`, `amb_congress.ogg`.

The previous set (Kenney CC0 samples and FluidSynth-rendered stings, built by
`sfx_tools.py build`) is no longer shipped.

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
