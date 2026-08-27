# Sound effects

Drop a `.ogg`, `.wav`, or `.mp3` file in here and it's picked up automatically
the next time the game boots (`Audio._scan_audio_dir()`, `scripts/core/audio.gd`)
— no code changes needed. The file's **name without its extension** becomes its
id, e.g. `click.ogg` becomes `&"click"`, played via `Audio.play_sfx(&"click")`.

Until a matching file exists, `Audio.play_sfx()` for that id is a silent
no-op — nothing crashes or logs an error, the sound just doesn't play yet.

## Ids the game already calls, waiting for a file

| id | filename to add | fires when |
|---|---|---|
| `click` | `click.ogg` | any button anywhere is pressed (wired globally - see `Audio._on_node_added`) |
| `found_colony` | `found_colony.ogg` | a new colony is founded (`Colonies.founded`) |
| `declare_independence` | `declare_independence.ogg` | the player declares independence (`Prestige.declared_independence`) |
| `shipment_delivered` | `shipment_delivered.ogg` | a shipment arrives at the Capital (`Routes.shipment_delivered`) |

Adding more event sounds later is the same two steps: drop the file, then
add one `Audio.play_sfx(&"your_id")` call at the relevant point in code
(most event hooks already live in `scripts/ui/main_screen.gd`, next to the
matching notification-toast call).
