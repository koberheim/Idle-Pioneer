# Audio plan: ElevenLabs pass

9 Oct 2026, on `main` at 755ab6d. Audits the current sound and music, then lists the new SFX, ambience and
music to generate with ElevenLabs, the small code changes they need, and the generation pipeline.

## 1. Audit: where the audio stands

**The plumbing is in good shape.** Everything goes through `Sfx` (`scripts/core/sfx.gd`), files are found by
id with no code changes, every file is loudness-normalised to its tier (measured today: all 18 SFX within
0.8 LU of target, every track at -16.0 LUFS), ceremonies have their own players, music crossfades and resumes
per context, ads pause everything, and `tools/music/sfx_tools.py normalize` already turns any WAV/MP3 into a
correctly levelled `.ogg`. New files from ElevenLabs drop straight into this pipeline.

**The weak spots are the sources, not the system:**

| # | finding | effect |
|---|---|---|
| A1 | All 7 music tracks are MIDI rendered through the General MIDI soundfont (GeneralUser GS). | They read as "MIDI": thin strings, static velocity, no room. It's the most noticeable quality gap in the game. |
| A2 | 7 of the 18 SFX are FluidSynth stings (`fanfare`, `milestone`, `relic`, `unlock`, `purchase`, plus the musical half of `research` and `consult`). | Same GM timbre as A1. The ceremonies (`fanfare`, `purchase`) are the moments players should feel most. |
| A3 | Kenney stock is reused across unrelated events: `found` = colony founded, workshop built, nation chosen; `discover` = new good, almanac page found; `coin` = selling, shipments, treasure salvage, offline summary; `liberty`, `father` and `market` are all the same Kenney heavy bell. | Events don't have their own identity; the Liberty Bell, the game's climax, sounds like the Congress bell. |
| A4 | Silent moments: signing the Declaration (`independence_overlay.gd`, drawing with your finger makes no sound), the colony sheet sliding up/down (only a generic `click`), appointing a governor, the "While you were away" summary (a coin). | The signature is the emotional peak of a run and it is silent. |
| A5 | No ambience at all. The map playlist has 20–40 s of silence between tracks by design, and Europe/Congress loop one ~2.5 min track forever. | Silence gaps feel empty rather than restful; Europe/Congress repeat ~25×/hour. |
| A6 | `europe` and `congress` must loop seamlessly; generated music won't. | Constrains how we generate them (see §4). |
| A7 | One file per id, so high-frequency sounds (`click`, `coin`, `buy`) repeat identically apart from ±3 % pitch. | Mild ear fatigue in an idle game where these fire constantly. |

Keep as they are: the Kenney `click`, `tab` and `deny` are clean and fit; they get A/B candidates, not a
forced replacement. Keep the public-domain tune tracks in the theme playlist too unless the generated ones
are clearly better: Yankee Doodle and friends carry the period identity that original music won't.

## 2. Licensing (decides the plan tier)

- **Sound effects** are covered by the normal ElevenLabs terms: commercial use on any paid plan. The Free
  plan is non-commercial and needs attribution, so it can't be used for shipping assets.
- **Music** has its own terms ([Eleven Music model-specific terms](https://elevenlabs.io/eleven-music-model-specific-terms)).
  Self-serve plans exclude "Studio Games", defined as any monetised game (ads or sales count), **except an
  "Indie Game"**: under $500k lifetime revenue for the game and under $1M/yr game revenue for the developer.
  Idle Pioneer qualifies as indie today. If it ever crosses those lines, the music needs an Enterprise music
  licence or replacing, so keep the generated tracks as additions rather than deleting the PD versions.
- Recommendation: **Creator plan**. It's the tier secondary sources consistently name for the indie-game
  carve-out, and it gives enough credits to generate 3–4 candidates per asset. The terms page reads as
  if Starter might also qualify, so re-read it at sign-up.
- `CREDITS.md` gets an "ElevenLabs (generated)" section listing each file, model, date and plan.

## 3. Sound effects

Generated with `POST /v1/sound-generation` (model `eleven_text_to_sound_v2`, 0.5–30 s, optional `loop`),
3–4 candidates per id, output `pcm_48000` (lossless; we encode to OGG ourselves). Durations below 0.5 s are
generated at 0.5 s and trimmed by `sfx_tools.py`. Prompt influence 0.5 unless noted (higher = more literal).

### 3a. Replacements (A/B against the current file; keep whichever wins)

| id | tier | dur | prompt |
|---|---|---|---|
| `liberty` | ceremony | 5 s | A single strike of a huge old bronze church bell, deep fundamental with a slightly cracked, buzzing overtone, long natural decay in open air, 18th century town square. No music. |
| `father` | reward | 1.5 s | A wooden gavel struck twice on a desk in a large wooden assembly hall, then a small brass handbell rung once, warm room reverb. |
| `market` | notice | 1.5 s | A ship's brass bell struck twice quickly, ding-ding, on a wooden sailing ship at harbour, light wind. |
| `charter` | reward | 1 s | Melted sealing wax pressed with a brass seal stamp onto thick parchment, soft squish and firm thud, close-up foley. |
| `coin` | UI | 0.6 s | A few gold coins dropped onto a wooden counter, bright clinks, close and dry. |
| `buy` | UI | 0.5 s | A small handful of coins poured into a leather purse, quick and soft. |
| `deny` | UI | 0.5 s | A heavy locked wooden chest lid rattled once against its iron latch, short dull thunk. |
| `click` | UI | 0.5 s | A single light tap of a wooden quill holder on a writing desk, very short, dry, close. |
| `tab` | UI | 0.5 s | A single page of thick old parchment turned quickly, crisp, close. |
| `research` | reward | 1.5 s | A heavy leather-bound book closed firmly, then a harpsichord plays a short bright rising three-note figure. |
| `consult` | reward | 1.7 s | An old almanac opened and a page turned, followed by a soft two-note glockenspiel chime. |
| `found` | reward | 1.2 s | A wooden stake hammered into earth three times with a mallet, then a short bright fife flourish. |
| `discover` | reward | 0.8 s | A wooden crate lid pried open with a creak, then a short bright pizzicato string flourish. |
| `milestone` | reward | 1.6 s | A short ascending glockenspiel chime over a soft harp chord, baroque, bright and celebratory. |
| `relic` | reward | 2 s | A dusty wooden chest creaks open, then a shimmering harp arpeggio blooms into a warm chord. |
| `unlock` | reward | 1.6 s | A quick ascending wooden flute run over pizzicato strings, 18th century chamber style, cheerful. |
| `fanfare` | ceremony | 3 s | A short royal fanfare on natural baroque trumpets and horns with timpani rolls, 18th century court, triumphant ending chord. |
| `purchase` | ceremony | 3 s | A joyful peal of church bells over warm strings and a harpsichord, celebratory, ending on a held chord. |

Musical stings (`fanfare`, `purchase`, `milestone`, `relic`, `unlock`) are where generation is least
predictable; if the SFX model gives mush, try `/v1/music` with `music_length_ms: 3000–5000` and
`force_instrumental`, then trim.

### 3b. New ids (need one-line code changes, listed in §5)

| id | tier | dur | plays when | prompt |
|---|---|---|---|---|
| `quill` (+ `_2`, `_3`) | UI | 0.5 s | each stroke on the Declaration signature pad | A goose-feather quill scratching quickly across rough parchment, one short stroke, close-up. |
| `treasure` | reward | 1.5 s | salvaging a drifting cargo on the map | A waterlogged wooden chest dragged onto a deck and forced open, coins spilling out. |
| `page` | reward | 0.8 s | a page of the Almanac found (was `discover`) | A loose sheet of old paper caught by the wind and snatched from the air, soft rustle, a small bright chime. |
| `workshop` | reward | 1.2 s | a workshop built (was `found`) | A carpenter's saw stroke and two hammer blows on timber in a busy workshop, then silence. |
| `sheet_up` / `sheet_down` | UI | 0.5 s | colony sheet slides open / closed | A large sheet of heavy parchment slid quickly across a wooden table, soft swish. (down: same, slower and lower.) |
| `governor` | reward | 1 s | appointing a governor | A ceremonial sword tapped twice on a wooden table, then a short murmur of approval from a few people. |
| `salute` | ceremony | 4 s | after the Liberty Bell, as the independence music starts | Distant 18th century cannon salute, three booms rolling across a harbour, with cheering crowd far away. |
| `welcome` | reward | 1.5 s | the "While you were away" summary (was `coin`) | A heavy door opening onto a busy colonial street, a rooster crows in the distance, coins jingle in a pocket. |

### 3c. Variants for frequent sounds (A7)

Generate 3 takes each of `click`, `coin`, `buy`, `quill` and ship them as `<id>`, `<id>_2`, `<id>_3`.
`Sfx.play` picks one at random (never the same twice in a row). Same naming as the theme playlist.

## 4. Music and ambience

Generated with `POST /v1/music` (model `music_v2_5` or the newest at generation time),
`force_instrumental: true`, `pcm_48000` out, 3 candidates per track. Original compositions; the prompts
name instrumentation, period and mood, never a real composer's piece or a tune title (that's what gets
outputs blocked or sounds like a cover).

Shared style line appended to every prompt: *"Instrumental, period-authentic 18th century colonial
America, acoustic instruments only, recorded in a warm wooden room, no synths, no modern drums, no vocals,
gentle dynamics, suitable as background music for a relaxing strategy game."*

### 4a. Map playlist (`theme_5` … `theme_9`, ends, not loops)

Target 2:00–2:30 each, each with a clear ending (a composition plan with an explicit final "outro"
section helps).

| id | brief |
|---|---|
| `theme_5` | Fife and snare drum march, unhurried, then joined by a fiddle; optimistic morning in a new settlement. |
| `theme_6` | Solo fiddle air, slow and tender, with a cello drone; dusk over a river valley. |
| `theme_7` | Lively jig on fiddle, wooden flute and bodhrán-style hand drum; a harvest day. |
| `theme_8` | Harpsichord and recorder duet, light and stately, a colonial governor's garden. |
| `theme_9` | Hammered dulcimer and fiddle, mid-tempo, warm and pastoral; frontier homestead. |

If the generated tracks beat the FluidSynth ones, the old ones can be dropped or regenerated in the same
spirit (Yankee Doodle can't be reliably reproduced by the model; keep that one as rendered).

### 4b. Europe and Congress: become playlists (A6)

Generated music won't loop seamlessly, and one loop is the repetition problem anyway. Make `europe` and
`congress` playlists like `theme` (3 tracks each, shorter 5–10 s gaps, ambience fills them):

| id | brief |
|---|---|
| `europe`, `europe_2`, `europe_3` | Three tracks: a bustling 18th century London harbour tune (sea-shanty-flavoured fiddle, wooden flute and hand drum); a stately baroque string quartet; a lilting hornpipe. |
| `congress`, `congress_2`, `congress_3` | Three tracks of baroque chamber music for a solemn assembly hall: a harpsichord-and-strings minuet; a slow processional for organ and strings; a thoughtful string trio. |

### 4c. Independence (one-shot)

`independence`: 30–40 s. Triumphant fife-and-drum march building into full brass, timpani and pealing
bells, ending on a big held chord. Keep the current rendered Yankee Doodle version as the fallback; A/B.

### 4d. Ambience beds (new layer, A5)

Seamless loops from the SFX endpoint with `loop: true`, 30 s (the maximum), 3 candidates each. They play
under the music and through the playlist gaps.

| id | context | prompt |
|---|---|---|
| `amb_newworld` | map, Workshops, Ledger | Gentle coastal wilderness: soft waves on a sandy shore, distant gulls, songbirds in a forest, a far-off axe chopping wood now and then. Calm, no music. |
| `amb_europe` | Europe | 18th century harbour: water lapping against wooden hulls, creaking ropes and rigging, gulls, distant dockside chatter, a far bell. No music. |
| `amb_congress` | Congress | Quiet wooden assembly hall: soft room tone, an old clock ticking slowly, an occasional quill scratch and paper rustle, faint muffled voices. No music. |

Level target: **-26 LUFS integrated in the file**, played at a new `Sfx.AMBIENCE_DB` around -8 dB
(so about -34 in game, ~10 LU under the music).

## 5. Code changes these need (all small, in `sfx.gd` plus call sites)

1. **Variants:** `_load_sfx` also loads `<id>_2` … `<id>_9`; `play` picks one at random, avoiding repeats.
2. **New ids:** add them to the synth table (fallback tones) and call them: `quill` on each pen-down in
   `independence_overlay.gd:_on_pad_input`; `treasure` at `main.gd:144`; `page` at `main.gd:67`;
   `workshop` at `main.gd:47`; `sheet_up/down` in `_open_colony` / `_close_sheet`; `governor` in the
   governor picker; `salute` after `liberty` in `independence_overlay.gd:200`; `welcome` in `_on_offline`.
3. **Playlists:** `PLAYLIST_MUSIC` gains `europe` and `congress`, with a per-context gap
   (`theme` 20–40 s, the others 5–10 s).
4. **Ambience layer:** one looping player per context, crossfaded with the same context switch as music,
   paused by `pause_all`, following the **Music** toggle (it's background, and players muting music for a
   podcast want it gone too). No file → no ambience.
5. **Docs:** `assets/audio/README.md` id tables and `CREDITS.md`.

## 6. Pipeline

- `tools/music/eleven.py` (stdlib only, no extra deps): reads `tools/music/eleven_manifest.json` (one entry
  per id: endpoint, prompt, duration, loop, candidates, seed) and writes candidates to
  `tools/music/out/<id>/<id>_c1.wav` … (gitignored). Skips ids that already have candidates unless
  `--force`, so reruns don't spend credits. Reads `ELEVENLABS_API_KEY` from the environment; the key is
  never written to the repo.
- `tools/music/out/audition.html`: a local page listing every id with its current file and the
  candidates side by side (play buttons, loudness-matched so the louder one doesn't win by default), and
  a pick per id that exports `picks.json`. **You pick by ear**; I can measure loudness, length, onsets,
  peaks and loop-seam clicks, but not taste.
- `eleven.py promote picks.json`: runs `sfx_tools.py normalize` for each pick into `assets/audio/…`,
  checks loop seams for ambience, then `measure` for the whole set.
- Order: a 3-sound smoke test first (`liberty`, `quill`, `amb_newworld`) to confirm quality and real
  credit cost per second, then SFX, then ambience, then music (most expensive) last.

---

## Getting me connected

The plan above uses the **REST API from a script**, not MCP. It's reproducible (prompts live in a
versioned manifest), batches candidates, and feeds the existing normalisation tools. MCP is optional and
only useful for ad-hoc "try a sound" experiments.

1. **Sign up** at <https://elevenlabs.io> and take the **Creator** plan (see §2). Read the music terms page
   once at checkout.
2. **Create a restricted API key**: Settings → API Keys → Create. Enable only *Sound Effects* and *Music*
   (everything else off), and set a **credit limit** on the key (e.g. 60 % of the monthly allowance) so a
   bug can't drain the account.
3. **Store it as a Windows user environment variable**, not in chat and not in the repo. In a PowerShell
   window of your own:

   ```powershell
   [Environment]::SetEnvironmentVariable("ELEVENLABS_API_KEY", "<paste key here>", "User")
   ```

4. **Fully quit and reopen the Claude desktop app** so new sessions inherit the variable.
5. Tell me "key is set". I'll check it's visible (without printing it), write `eleven.py`, the manifest
   and the audition page, and run the 3-sound smoke test.

Optional, ElevenLabs MCP for ad-hoc use: ElevenLabs now hosts its MCP server (the local `elevenlabs-mcp`
package is deprecated). From an interactive `claude` terminal:

```bash
claude mcp add --transport http elevenlabs https://api.elevenlabs.io/v1/mcp
```

then run `/mcp` there to sign in with OAuth. Check the ElevenLabs docs for the current URL first; it was
announced only in the package README.
