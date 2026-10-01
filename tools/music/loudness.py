"""ITU-R BS.1770 loudness helpers (K-weighting, momentary max, integrated).

Everything is measured "as played": a mono file is counted as dual-mono (the
same signal on left and right), because that is how Godot plays a mono stream,
so a mono file reads ~3 dB louder here than a mono-only meter would show. For stereo
files the numbers match `ffmpeg -i f.ogg -af ebur128 -f null -` to within
~0.2 dB (this module uses a 10 ms hop for the momentary max instead of 100 ms, so it
catches short transients a little better).
"""

from __future__ import annotations

import subprocess

import numpy as np
from scipy.signal import lfilter

SR = 48000

# K-weighting at 48 kHz (BS.1770-4, table 1 and 2).
_SHELF_B = [1.53512485958697, -2.69169618940638, 1.19839281085285]
_SHELF_A = [1.0, -1.69065929318241, 0.73248077421585]
_HP_B = [1.0, -2.0, 1.0]
_HP_A = [1.0, -1.99004745483398, 0.99007225036621]


def load(path: str, ffmpeg: str = "ffmpeg", sr: int = SR) -> np.ndarray:
	"""Decodes any audio file to float64, shape (n, 2), at `sr`. Mono becomes dual-mono."""
	ffprobe = ffmpeg[:-6] + "ffprobe" + ffmpeg[-4:] if ffmpeg.lower().endswith("ffmpeg.exe") else (
		ffmpeg[:-6] + "ffprobe" if ffmpeg.endswith("ffmpeg") else "ffprobe")
	ch = int(subprocess.run([ffprobe, "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
		"-of", "csv=p=0", path], capture_output=True, check=True, text=True).stdout.strip())
	# Decode in the file's own channel layout: ffmpeg's own mono->stereo upmix
	# drops the level by 3 dB, which isn't what Godot does.
	raw = subprocess.run([ffmpeg, "-v", "error", "-i", path, "-f", "f32le", "-ar", str(sr), "-"],
		capture_output=True, check=True).stdout
	x = np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, ch)
	if ch == 1:
		x = np.concatenate([x, x], axis=1)
	return x[:, :2]


def _kweight(x: np.ndarray) -> np.ndarray:
	y = lfilter(_SHELF_B, _SHELF_A, x, axis=0)
	return lfilter(_HP_B, _HP_A, y, axis=0)


def _power(x: np.ndarray, sr: int, win_s: float, hop_s: float, pad: bool) -> np.ndarray:
	"""Mean-square K-weighted power (summed over channels) of each window."""
	if x.ndim == 1:
		x = np.stack([x, x], axis=1)
	if sr != SR:
		raise ValueError("measure at 48 kHz (use load())")
	z = _kweight(x)
	win = int(win_s * sr)
	hop = int(hop_s * sr)
	if pad:
		z = np.concatenate([np.zeros((win, 2)), z, np.zeros((win, 2))])
	if len(z) < win:
		z = np.concatenate([z, np.zeros((win - len(z), 2))])
	sq = (z ** 2).sum(axis=1)
	c = np.concatenate([[0.0], np.cumsum(sq)])
	starts = np.arange(0, len(sq) - win + 1, hop)
	return (c[starts + win] - c[starts]) / win


def _lufs(p):
	return -0.691 + 10 * np.log10(np.maximum(p, 1e-20))


def momentary_max(x: np.ndarray, sr: int = SR) -> float:
	"""Highest momentary loudness (400 ms window, 10 ms hop), LUFS."""
	return float(_lufs(_power(x, sr, 0.4, 0.01, True).max()))


def integrated(x: np.ndarray, sr: int = SR) -> float:
	"""Gated integrated loudness, LUFS."""
	p = _power(x, sr, 0.4, 0.1, False)
	l = _lufs(p)
	p = p[l > -70]
	if len(p) == 0:
		return -70.0
	rel = _lufs(p.mean()) - 10
	p = p[_lufs(p) > rel]
	return float(_lufs(p.mean()))


def peak_db(x: np.ndarray) -> float:
	return float(20 * np.log10(max(np.abs(x).max(), 1e-12)))


def true_peak_db(x: np.ndarray, sr: int = SR) -> float:
	"""4x oversampled peak, dBTP."""
	from scipy.signal import resample_poly
	return peak_db(resample_poly(x, 4, 1, axis=0))
