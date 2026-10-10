# Audio

All sound goes through the `Sfx` autoload (`scripts/core/sfx.gd`).

## Replacing a sound or a track

Drop a file named after the id into the right folder. It's picked up
automatically, with no code changes:

- sound effects: `assets/audio/sfx/<id>.ogg` (or `.wav` / `.mp3`)
- music: `assets/audio/music/<id>.ogg` (or `.wav` / `.mp3`)

`.ogg` is preferred and wins if more than one exists. Then **normalise it** so
it sits at the right level next to everything else (the game plays every file
at 0 dB; the level lives in the file):

```sh
# sound effect: normalised to its id's target below, trimmed, written as sfx/<id>.ogg
python tools/music/sfx_tools.py --ffmpeg ffmpeg normalize new_coin.wav --id coin

# music: normalised to -16 LUFS integrated, written as music/<id>.ogg
python tools/music/sfx_tools.py --ffmpeg ffmpeg normalize new_tune.wav --id theme_5 --music

# check everything
python tools/music/sfx_tools.py --ffmpeg ffmpeg measure
```

Then open the project in Godot (or run `--headless --import`) so the new file
gets imported. If you normalise by hand (e.g. in an audio editor or ElevenLabs
export settings), aim for the numbers below.

### Loudness targets

Measured with ITU-R BS.1770 (LUFS) **as played**: a mono file counts as
dual-mono, because Godot plays it at full level on both channels, so it reads
3 dB louder than a mono-only meter shows. To check by hand with ffmpeg, take
the highest `M:` value printed by
`ffmpeg -nostats -i f.ogg -af "apad=pad_dur=0.5,pan=stereo|c0=c0|c1=c0,ebur128" -f null -`
for a mono file (drop the `pan=...,` part for stereo); for music read the
`I:` (integrated) line of the summary. Peaks: no higher than -1 dBTP.

| kind | target | measure |
|---|---|---|
| UI sounds | **-24 LUFS** | momentary max (400 ms) |
| notices (market news) | **-22 LUFS** | momentary max |
| rewards | **-20 LUFS** | momentary max |
| ceremonies | **-18 LUFS** | momentary max |
| music (every track) | **-16 LUFS** | integrated |
| ambience beds | **-26 LUFS** | integrated |

In game, music plays at `Sfx.MUSIC_DB` (-7 dB), i.e. around -23 LUFS, under
the rewards and ceremonies and level with the UI clicks (whose transients cut
through). Sound effects play at `Sfx.SFX_DB` (0 dB). `Sfx.TRIM_DB` can nudge a
single id by a few dB for quick listening tests, but re-normalising the file
keeps this table true.

Very short, spiky sounds may not reach their target under the -1 dBTP ceiling;
`sfx_tools.py` limits up to 3 dB of peaks and otherwise leaves them as loud as
it can (it prints a note).

## Sound effect ids

Unknown ids are ignored (a warning in debug builds). Every id also has a small
synthesised fallback in `sfx.gd`, used only when no file exists.

| id | level | plays when | takes |
|---|---|---|---|
| `click` | UI -24 | most button presses (pitch varies ±3%) | 3 |
| `tab` | UI -24 | switching tabs (pitch varies) | 1 |
| `buy` | UI -24 | a successful purchase (pitch varies) | 3 |
| `coin` | UI -24 | selling goods, shipments landing (pitch varies) | 3 |
| `deny` | UI -24 | something that can't be afforded or done (pitch varies) | 1 |
| `quill` | UI -24 | each stroke when signing the Declaration (pitch varies) | 3 |
| `sheet_up` / `sheet_down` | UI -24 | the colony sheet slides open / closed | 1 |
| `market` | notice -22 | market news (ship's bell, two strikes) | 1 |
| `found` | reward -20 | founding a colony, choosing a nation | 1 |
| `workshop` | reward -20 | a workshop built | 1 |
| `discover` | reward -20 | a new good reaches the capital for the first time | 1 |
| `page` | reward -20 | a page of the Almanac found | 1 |
| `treasure` | reward -20 | salvaging a drifting cargo on the map | 1 |
| `welcome` | reward -20 | the "While You Were Away" summary | 1 |
| `father` | reward -20 | a Founding Father joins Congress (gavel and handbell) | 1 |
| `governor` | reward -20 | a governor posted to a colony | 1 |
| `milestone` | reward -20 | a milestone reached | 1 |
| `relic` | reward -20 | a relic found | 1 |
| `research` | reward -20 | research completed | 1 |
| `charter` | reward -20 | a charter sealed (wax seal) | 1 |
| `unlock` | reward -20 | "New in the Colonies" | 1 |
| `consult` | reward -20 | Consult the Almanac (rewarded ad) | 1 |
| `liberty` | ceremony -18 | the seal is pressed on the Declaration (great bronze bell) | 1 |
| `salute` | ceremony -18 | cannon salute as the independence music starts | 1 |
| `fanfare` | ceremony -18 | Royal Favor | 1 |
| `purchase` | ceremony -18 | thank-you after buying Ad-Free | 1 |

Every shipped sound effect was generated with ElevenLabs (see `CREDITS.md`).
Extra takes are `<id>_2.ogg`, `<id>_3.ogg` … (up to `_9`): `Sfx.play` picks one
at random, never the same twice in a row, and they share their id's loudness
target. `sfx_tools.py build` rebuilds the *previous* Kenney/FluidSynth set and
would overwrite these files; it's kept only for reference.

Ceremonies (`liberty`, `salute`, `fanfare`, `purchase`) play on their own players so a
burst of clicks can't cut them off.

## Music ids

`Sfx.set_music_context(id)` crossfades to a context; a context you come back
to resumes where it left off.

| id | plays | how |
|---|---|---|
| `theme`, `theme_2` … `theme_9` | New World map, Workshops, Ledger | a **playlist**: every `theme*` file that exists, shuffled, each played once, with 20–40 s between tracks |
| `europe`, `europe_2` … `europe_9` | Europe tab | a playlist, 5–10 s between tracks |
| `congress`, `congress_2` … `congress_9` | Congress tab | a playlist, 5–10 s between tracks |
| `independence` | once, when the Declaration is signed, then back to the previous context | one-shot |

To add a track, add e.g. `theme_6.ogg` or `europe_4.ogg` (up to `_9`): it
joins its playlist automatically. Playlist tracks should end, not loop; the
ambience bed fills the gaps between them (`Sfx.PLAYLIST_GAP`). A context that
isn't a playlist loops its one file, which must then be seamless at the loop
point (loops are set in code, not in the import settings).

## Ambience ids

Looping beds under the music, in `assets/audio/ambience/<id>.ogg`. They keep
playing through the silences between playlist tracks, crossfade with the
music context, start at a random point, follow the **Music** toggle and pause
for ads. A context without a file just has no bed. Played at
`Sfx.AMBIENCE_DB` (-8 dB), about 10 LU under the music. Files must loop
seamlessly; normalise with `--ambience`, which only changes gain (plus a
light peak limiter) so the loop point isn't moved.

| id | context |
|---|---|
| `amb_newworld` | `theme` (New World map, Workshops, Ledger) |
| `amb_europe` | `europe` |
| `amb_congress` | `congress` |

A one-shot context (`independence`) keeps whichever bed was playing.

## Generating with ElevenLabs

`tools/music/eleven.py` generates candidates from the prompts in
`tools/music/eleven_manifest.json` (needs `ELEVENLABS_API_KEY`), writes a
loudness-matched listening page (`tools/music/out/audition.html`) and promotes
the picks through `sfx_tools.py`. The plan is `docs/AUDIO_PLAN.md`.

`Sfx.pause_all()` / `Sfx.resume_all()` silence everything while an ad plays
(music pauses where it is and continues afterwards). The Music and Sound
toggles in Settings (`Game.meta.music_on` / `sfx_on`) are respected.

## Where the files come from

See `CREDITS.md`. Music is made by `tools/music/compose.py` (MIDI → FluidSynth
→ OGG). Sound effects and ambience are generated by `tools/music/eleven.py`
from the prompts in `tools/music/eleven_manifest.json`.
