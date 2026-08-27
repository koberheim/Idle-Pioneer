# Music

Drop a `.ogg`, `.wav`, or `.mp3` file in here and it's picked up automatically
the next time the game boots (`Audio._scan_audio_dir()`, `scripts/core/audio.gd`)
— no code changes needed. The file's **name without its extension** becomes
its id, e.g. `ambient.ogg` becomes `&"ambient"`, played via
`Audio.play_music(&"ambient")`. It loops automatically (replays on
`AudioStreamPlayer.finished`, regardless of format).

Until a matching file exists, `Audio.play_music()` for that id is a silent
no-op — nothing crashes or logs an error, the track just doesn't play yet.

## Ids the game already calls, waiting for a file

| id | filename to add | fires when |
|---|---|---|
| `ambient` | `ambient.ogg` | a run starts or resumes (`MainScreen._start_run()`) |

Only one track plays at a time. A later pass could swap tracks by game
state (e.g. a different track once Independence is declared) by calling
`Audio.play_music()` with a different id at the relevant point.
