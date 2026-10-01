# Sound effects

One file per sound id, named `<id>.ogg` (or `.wav` / `.mp3`). Each file is
loudness-normalised to its id's target, and the game plays it at 0 dB.

The full id list, what each one plays for, the loudness targets and how to
normalise a replacement are in `../README.md`; sources and licenses are in
`../CREDITS.md`. Rebuild the shipped set with `tools/music/sfx_tools.py build`.
