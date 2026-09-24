# Sound effects

Every sound has a synthesised fallback built at startup by
`scripts/core/sfx.gd` (chiptune-style square/triangle tones and a bell). Most
ids now have a recorded CC0 sample here instead (see `../CREDITS.md`); only
`fanfare` is still synthesised.

To replace one with a real recording, drop a file named after its id into this
folder (`.ogg`, `.wav` or `.mp3`). It is used instead of the synthesised version
automatically - no code changes.

| id | plays when |
|---|---|
| `click` | most button presses |
| `tab` | switching tabs |
| `buy` | any successful purchase |
| `deny` | a purchase or action that can't be afforded |
| `coin` | selling goods, shipments landing, offline summary |
| `found` | founding a colony, building a workshop, choosing a nation |
| `father` | a Founding Father joins Congress |
| `discover` | a new good reaches the capital for the first time |
| `liberty` | the seal is pressed on the Declaration |
| `fanfare` | independence is declared |
