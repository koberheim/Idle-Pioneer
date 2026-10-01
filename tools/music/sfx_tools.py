"""Builds, loudness-normalises and measures Idle Pioneer's sound effects.

Every file in assets/audio/sfx is normalised *in the file* to the loudness its
id should have in the game (TARGETS below, also listed in
assets/audio/README.md), so the game plays all of them at 0 dB and a
replacement only has to hit the same number:

  # measure everything (sfx: momentary max; music: integrated)
  python tools/music/sfx_tools.py measure

  # after dropping a new file in (e.g. an ElevenLabs export), normalise it to its
  # id's target and write assets/audio/sfx/<id>.ogg
  python tools/music/sfx_tools.py normalize path/to/coin_new.wav --id coin
  python tools/music/sfx_tools.py normalize assets/audio/sfx/coin.ogg      # id from the name

  # music: normalise to -16 LUFS integrated and write assets/audio/music/<id>.ogg
  python tools/music/sfx_tools.py normalize my_tune.wav --id theme_5 --music

  # rebuild the shipped set from the Kenney CC0 packs + FluidSynth stings
  python tools/music/sfx_tools.py build --kenney DIR --fluidsynth EXE --soundfont SF2

Loudness is BS.1770 K-weighted, measured as played (mono counts as dual-mono);
see loudness.py. Peaks are held at or below PEAK_CEILING dBTP (a light limiter
takes off up to MAX_LIMIT_DB of transient peaks); if a sound still can't reach
its target (very spiky sounds) it is left as loud as that allows and a note is
printed.

Needs numpy, scipy, mido and ffmpeg (with libvorbis); `build` also needs
FluidSynth and the GeneralUser GS SoundFont (see assets/audio/CREDITS.md).
"""

from __future__ import annotations

import argparse
import glob
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import loudness  # noqa: E402
from loudness import SR  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")

UI = -24.0
REWARD = -20.0
NOTICE = -22.0
CEREMONY = -18.0
# Momentary-max loudness (LUFS, as played) each sfx id is normalised to.
TARGETS = {
	"click": UI, "tab": UI, "buy": UI, "coin": UI, "deny": UI,
	"market": NOTICE,
	"found": REWARD, "discover": REWARD, "father": REWARD, "milestone": REWARD,
	"relic": REWARD, "research": REWARD, "charter": REWARD, "unlock": REWARD,
	"consult": REWARD,
	"liberty": CEREMONY, "fanfare": CEREMONY, "purchase": CEREMONY,
}
DEFAULT_TARGET = REWARD
MUSIC_LUFS = -16.0  # integrated; must match compose.MUSIC_LUFS
PEAK_CEILING = -1.0  # dBTP
FADE_IN_S = 0.0015


# --- Helpers ----------------------------------------------------------------------

def _mono(x: np.ndarray) -> np.ndarray:
	return x.mean(axis=1) if x.ndim == 2 else x


def _stereo(x: np.ndarray) -> np.ndarray:
	return np.stack([x, x], axis=1) if x.ndim == 1 else x


def trim(x: np.ndarray, max_s: float, start_db: float = -40.0, end_db: float = -50.0,
		preroll_s: float = 0.001, fade_out_s: float = 0.03) -> np.ndarray:
	"""Cuts leading silence (keeps `preroll_s` before the onset, then a short
	fade-in so the cut can't click), trailing silence below `end_db` relative to
	the peak, caps the length and fades the end."""
	env = np.abs(_stereo(x)).max(axis=1)
	pk = env.max()
	on = np.nonzero(env > pk * 10 ** (start_db / 20))[0]
	off = np.nonzero(env > pk * 10 ** (end_db / 20))[0]
	a = max(0, on[0] - int(preroll_s * SR))
	b = min(len(x), off[-1] + 1, a + int(max_s * SR))
	y = x[a:b].copy()
	fi = min(int(FADE_IN_S * SR), len(y) // 4)
	ramp = np.linspace(0.0, 1.0, fi)
	y[:fi] *= ramp if y.ndim == 1 else ramp[:, None]
	fo = min(int(fade_out_s * SR), len(y) // 4)
	ramp = np.linspace(1.0, 0.0, fo)
	y[-fo:] *= ramp if y.ndim == 1 else ramp[:, None]
	return y


def lead_ms(x: np.ndarray) -> float:
	env = np.abs(_stereo(x)).max(axis=1)
	return float(np.nonzero(env > env.max() * 10 ** (-40 / 20))[0][0] / SR * 1000)


def mix(*layers) -> np.ndarray:
	"""layers: (signal, offset seconds, gain dB). Returns stereo."""
	n = max(int(off * SR) + len(sig) for sig, off, _ in layers)
	out = np.zeros((n, 2))
	for sig, off, g in layers:
		i = int(off * SR)
		out[i:i + len(sig)] += _stereo(sig) * 10 ** (g / 20)
	return out


MAX_LIMIT_DB = 3.0  # at most this much peak limiting to reach a target


def limit(x: np.ndarray, ceiling_db: float) -> np.ndarray:
	"""A small look-ahead peak limiter (3 ms look-ahead, 60 ms release)."""
	from scipy.ndimage import minimum_filter1d
	st = _stereo(x)
	env = np.abs(st).max(axis=1)
	c = 10 ** (ceiling_db / 20)
	g = np.minimum(1.0, c / np.maximum(env, 1e-9))
	look = int(0.003 * SR)
	g = minimum_filter1d(g, size=2 * look + 1)
	rel = np.exp(-1.0 / (0.06 * SR))
	out = np.empty_like(g)
	cur = 1.0
	for n, v in enumerate(g):
		cur = v if v < cur else v + (cur - v) * rel
		out[n] = cur
	return x * (out if x.ndim == 1 else out[:, None])


def normalise_sfx(x: np.ndarray, target: float) -> tuple[np.ndarray, float, bool]:
	"""Gain to `target` momentary max. Peaks above the true-peak ceiling are
	limited by up to MAX_LIMIT_DB; beyond that the target is given up on."""
	limited = False
	y = x
	total = 0.0
	for _ in range(3):
		gain = target - loudness.momentary_max(_stereo(y))
		tp = loudness.true_peak_db(_stereo(y)) + gain
		over = tp - PEAK_CEILING
		if over > MAX_LIMIT_DB:
			gain -= over - MAX_LIMIT_DB
			over = MAX_LIMIT_DB
			limited = True
		y = y * 10 ** (gain / 20)
		total += gain
		if over > 0:
			y = limit(y, PEAK_CEILING - 0.5)
		if abs(loudness.momentary_max(_stereo(y)) - target) < 0.2 or limited:
			break
	return y, total, limited


def write_ogg(x: np.ndarray, path: str, ffmpeg: str, quality: int = 4) -> None:
	tmp = os.path.join(tempfile.gettempdir(), "ip_sfx_tmp.wav")
	wavfile.write(tmp, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
	subprocess.run([ffmpeg, "-y", "-v", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
	os.remove(tmp)


def is_mono_source(path: str, ffmpeg: str) -> bool:
	x = loudness.load(path, ffmpeg)
	return bool(np.allclose(x[:, 0], x[:, 1]))


# --- Commands -----------------------------------------------------------------------

def cmd_measure(a) -> int:
	print("SFX (momentary max as played; in game = file level, Sfx trims are 0 unless set in sfx.gd)")
	print("%-12s %7s %7s %7s %6s %7s %6s" % ("id", "M max", "target", "diff", "TP", "len s", "lead"))
	for f in sorted(glob.glob(os.path.join(SFX_DIR, "*.*"))):
		if f.endswith((".import", ".md")):
			continue
		i = os.path.splitext(os.path.basename(f))[0]
		x = loudness.load(f, a.ffmpeg)
		m = loudness.momentary_max(x)
		t = TARGETS.get(i, DEFAULT_TARGET)
		print("%-12s %7.1f %7.1f %+7.1f %6.1f %7.2f %5.1fms" % (i, m, t, m - t, loudness.true_peak_db(x),
			len(x) / SR, lead_ms(x)))
	print()
	print("Music (integrated; in game add Sfx.MUSIC_DB)")
	for f in sorted(glob.glob(os.path.join(MUSIC_DIR, "*.*"))):
		if f.endswith((".import", ".md")):
			continue
		x = loudness.load(f, a.ffmpeg)
		print("%-14s I %6.1f  M max %6.1f  peak %5.1f  %6.1f s  %5d KB" % (os.path.basename(f),
			loudness.integrated(x), loudness.momentary_max(x), loudness.peak_db(x), len(x) / SR,
			os.path.getsize(f) // 1024))
	return 0


def cmd_normalize(a) -> int:
	for src in a.files:
		i = a.id or os.path.splitext(os.path.basename(src))[0]
		x = loudness.load(src, a.ffmpeg)
		mono = bool(np.allclose(x[:, 0], x[:, 1]))
		if a.music:
			lufs = loudness.integrated(x)
			gain = min(MUSIC_LUFS - lufs, -1.5 - loudness.true_peak_db(x))
			out = os.path.join(MUSIC_DIR, i + ".ogg")
			y = x * 10 ** (gain / 20)
			write_ogg(y, out, a.ffmpeg, 3)
			print("%s: %.1f -> %.1f LUFS integrated -> %s" % (i, lufs, lufs + gain, out))
			continue
		target = TARGETS.get(i, DEFAULT_TARGET)
		if i not in TARGETS:
			print("note: '%s' is not a known id; using the reward level %.0f LUFS" % (i, target))
		y = x[:, 0] if mono else x
		if not a.keep_silence:
			y = trim(y, max_s=10.0, end_db=-60.0, fade_out_s=0.01)
		before = loudness.momentary_max(_stereo(y))
		y, gain, limited = normalise_sfx(y, target)
		out = os.path.join(SFX_DIR, i + ".ogg")
		write_ogg(y, out, a.ffmpeg)
		after = loudness.momentary_max(loudness.load(out, a.ffmpeg))
		print("%s: %.1f -> %.1f LUFS (target %.0f)%s -> %s" % (i, before, after, target,
			"  [peak-limited]" if limited else "", out))
	return 0


# Recorded samples from the Kenney CC0 packs: id -> (pack/file, max seconds).
KENNEY = {
	"click": ("kenney_impact-sounds/Audio/impactWood_light_002.ogg", 0.25),
	"tab": ("kenney_rpg-audio/Audio/bookFlip3.ogg", 0.3),
	"buy": ("kenney_rpg-audio/Audio/handleCoins2.ogg", 0.4),
	"coin": ("kenney_rpg-audio/Audio/handleCoins.ogg", 0.7),
	"deny": ("kenney_interface-sounds/Audio/error_006.ogg", 0.4),
	"found": ("kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI10.ogg", 1.2),
	"discover": ("kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI04.ogg", 1.0),
	"father": ("kenney_impact-sounds/Audio/impactBell_heavy_000.ogg", 1.6),
	"liberty": ("kenney_impact-sounds/Audio/impactBell_heavy_001.ogg", 2.0),
}
STING_MAX_S = {"fanfare": 3.0, "milestone": 1.6, "relic": 2.0, "unlock": 1.6, "purchase": 2.8,
	"consult_chime": 1.6, "research_chime": 1.4}


def cmd_build(a) -> int:
	import compose
	os.makedirs(a.work, exist_ok=True)
	k = lambda p: loudness.load(os.path.join(a.kenney, p), a.ffmpeg)[:, 0]  # Kenney files are mono
	built: dict[str, np.ndarray] = {}

	for i, (src, max_s) in KENNEY.items():
		built[i] = trim(k(src), max_s)

	stings: dict[str, np.ndarray] = {}
	for name, fn in compose.STINGS.items():
		song, beats = fn()
		mid = os.path.join(a.work, "sting_" + name + ".mid")
		raw = os.path.join(a.work, "sting_" + name + ".wav")
		song.write(mid, beats, tail_beats=4.0)
		compose.render(a.fluidsynth, a.soundfont, mid, raw)
		x = loudness.load(raw, a.ffmpeg)
		stings[name] = trim(x, STING_MAX_S[name], end_db=-55.0, fade_out_s=0.25)
	for name in ("fanfare", "milestone", "relic", "unlock", "purchase"):
		built[name] = stings[name]

	# Ship's bell struck twice ("two bells") for market news; the NOTICE target
	# keeps it softer than the rewards.
	bell = trim(k("kenney_impact-sounds/Audio/impactBell_heavy_003.ogg"), 0.65, fade_out_s=0.2)
	built["market"] = mix((bell, 0.0, 0.0), (bell, 0.32, -2.5))
	# Wax seal: a leather drop on a heavy wooden thud.
	built["charter"] = trim(mix(
		(trim(k("kenney_impact-sounds/Audio/impactWood_heavy_002.ogg"), 0.31), 0.0, 0.0),
		(trim(k("kenney_rpg-audio/Audio/dropLeather.ogg"), 0.42), 0.005, -3.0)), 0.6)
	# Research: a page turned, then a quiet harpsichord figure.
	built["research"] = trim(mix((trim(k("kenney_rpg-audio/Audio/bookFlip1.ogg"), 0.7), 0.0, -5.0),
		(stings["research_chime"], 0.18, 0.0)), 2.0)
	# Consult the Almanac: the book opened, a page turned, a soft chime.
	built["consult"] = trim(mix((trim(k("kenney_rpg-audio/Audio/bookOpen.ogg"), 0.2), 0.0, -7.0),
		(trim(k("kenney_rpg-audio/Audio/bookFlip2.ogg"), 0.45), 0.1, -5.0),
		(stings["consult_chime"], 0.28, 0.0)), 2.0)

	print("%-10s %7s %7s %6s %6s %s" % ("id", "before", "after", "gain", "len", "note"))
	for i in TARGETS:
		x = built[i]
		before = loudness.momentary_max(_stereo(x))
		y, gain, limited = normalise_sfx(x, TARGETS[i])
		out = os.path.join(SFX_DIR, i + ".ogg")
		write_ogg(y, out, a.ffmpeg)
		after = loudness.momentary_max(loudness.load(out, a.ffmpeg))
		print("%-10s %7.1f %7.1f %+6.1f %5.2fs %s" % (i, before, after, gain, len(y) / SR,
			"peak-limited" if limited else ""))
	return 0


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--ffmpeg", default="ffmpeg")
	sub = ap.add_subparsers(dest="cmd", required=True)
	sub.add_parser("measure")
	n = sub.add_parser("normalize")
	n.add_argument("files", nargs="+")
	n.add_argument("--id", default="", help="sound id to write (default: the file name)")
	n.add_argument("--music", action="store_true", help="normalise as music (integrated loudness)")
	n.add_argument("--keep-silence", action="store_true", help="don't trim leading/trailing silence")
	b = sub.add_parser("build")
	b.add_argument("--kenney", required=True, help="folder holding the unzipped kenney_* packs")
	b.add_argument("--fluidsynth", required=True)
	b.add_argument("--soundfont", required=True)
	b.add_argument("--work", default=os.path.join(tempfile.gettempdir(), "idle_pioneer_sfx"))
	a = ap.parse_args()
	return {"measure": cmd_measure, "normalize": cmd_normalize, "build": cmd_build}[a.cmd](a)


if __name__ == "__main__":
	sys.exit(main())
