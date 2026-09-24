"""Composes Idle Pioneer's music as MIDI and renders it to OGG.

Every tune here is a public-domain melody from the 18th century or earlier,
written out from the traditional tune and arranged here (harmony, instruments,
form are original to this script). Nothing is sampled from recordings.

  theme         Yankee Doodle (trad., c. 1755-1775) + Soldier's Joy (trad. fiddle
                reel, 18th c.) - recorder, fiddle, nylon guitar, soft hand drum.
  europe        Greensleeves (English, 16th c.) + Drunken Sailor (trad. sea song,
                tune 18th c. or older) - accordion, fiddle, bass, soft drum.
  congress      Minuet in G (Christian Petzold, 1725) + Old Hundredth (Louis
                Bourgeois, Genevan Psalter, 1551) - harpsichord and strings.
  independence  Yankee Doodle as a fife-and-drum march with a brass fanfare
                (one-shot, not looped).

Usage:
  python tools/music/compose.py --fluidsynth PATH/fluidsynth.exe \
      --soundfont PATH/GeneralUser-GS.sf2 [--ffmpeg ffmpeg] \
      [--work DIR] [--out assets/audio/music] [--only theme,europe]

Needs: mido, numpy, scipy (pip install mido numpy scipy), FluidSynth and ffmpeg
(with libvorbis) on disk. Looping tracks wrap their reverb tail onto the start
so the loop seam is seamless without a fade.
"""

from __future__ import annotations

import argparse
import os
import random
import subprocess
import tempfile
import sys

import mido
import numpy as np
from scipy.io import wavfile

TPB = 480
SR = 44100
DRUMS = 9

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi_of(name: str) -> int:
	"""'C#5' -> 73. C4 = 60."""
	pc = NOTE_PC[name[0]]
	i = 1
	while i < len(name) and name[i] in "#b":
		pc += 1 if name[i] == "#" else -1
		i += 1
	return pc + 12 * (int(name[i:]) + 1)


def parse(s: str) -> list[tuple[int | None, float]]:
	"""'D4:.5 D4 E4 r:1' -> [(62, .5), (62, .5), (64, .5), (None, 1)].
	A duration carries over to following tokens until changed; '|' is ignored."""
	out = []
	dur = 1.0
	for tok in s.split():
		if tok == "|":
			continue
		if ":" in tok:
			name, d = tok.split(":")
			dur = float(d)
		else:
			name = tok
		out.append((None if name == "r" else midi_of(name), dur))
	return out


def length(notes) -> float:
	return sum(d for _, d in notes)


# --- Chords ---------------------------------------------------------------------

QUALITIES = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10]}


def chord_pcs(name: str) -> tuple[int, list[int]]:
	root = NOTE_PC[name[0]]
	i = 1
	if i < len(name) and name[i] in "#b":
		root += 1 if name[i] == "#" else -1
		i += 1
	q = QUALITIES[name[i:]]
	return root % 12, [(root + x) % 12 for x in q]


def chord_spans(s: str, start: float) -> list[tuple[float, float, str]]:
	"""'D:2 A:2' -> [(start, start+2, 'D'), ...]"""
	out = []
	t = start
	dur = 4.0
	for tok in s.split():
		if tok == "|":
			continue
		if ":" in tok:
			name, d = tok.split(":")
			dur = float(d)
		else:
			name = tok
		out.append((t, t + dur, name))
		t += dur
	return out


def tones_in(name: str, lo: int, hi: int) -> list[int]:
	_, pcs = chord_pcs(name)
	return [n for n in range(lo, hi + 1) if n % 12 in pcs]


def root_in(name: str, lo: int) -> int:
	root, _ = chord_pcs(name)
	n = lo
	while n % 12 != root:
		n += 1
	return n


def fifth_in(name: str, lo: int) -> int:
	root, pcs = chord_pcs(name)
	fifth = (root + 7) % 12
	n = lo
	while n % 12 != fifth:
		n += 1
	return n


class Song:
	def __init__(self, bpm: float, seed: int) -> None:
		self.bpm = bpm
		self.events: list[tuple[float, float, int, int, int]] = []  # start, dur, note, vel, ch
		self.programs: dict[int, int] = {}
		self.mix: dict[int, tuple[int, int, int]] = {}  # ch -> (volume, pan, reverb)
		self.rng = random.Random(seed)

	def channel(self, ch: int, program: int, volume: int = 100, pan: int = 64, reverb: int = 50) -> None:
		self.programs[ch] = program
		self.mix[ch] = (volume, pan, reverb)

	def note(self, t: float, dur: float, n: int, vel: int, ch: int) -> None:
		self.events.append((t, dur, n, vel, ch))

	def melody(self, s, t: float, ch: int, vel: int = 80, shift: int = 0, legato: float = 0.92,
			accent: bool = True) -> float:
		notes = parse(s) if isinstance(s, str) else s
		for n, d in notes:
			if n is not None:
				v = vel
				if accent:
					# Lean on strong beats a little.
					if abs(t - round(t)) < 1e-6 and int(round(t)) % 2 == 0:
						v += 6
					elif abs(t - round(t)) > 1e-6:
						v -= 5
				self.note(t, d * legato, n + shift, v, ch)
			t += d
		return t

	def pattern(self, spans, bar: float, steps, ch: int, vel: int) -> None:
		"""steps: list of (offset in bar, kind, dur, vel delta, lo, hi, count).
		kind: root | fifth | chord | alt (root, then fifth on the next bar)."""
		if not spans:
			return
		t0 = spans[0][0]
		t_end = spans[-1][1]
		b = 0
		bt = t0
		while bt < t_end - 1e-6:
			for off, kind, dur, dv, lo, hi, count in steps:
				t = bt + off
				if t >= t_end - 1e-6:
					continue
				name = next(n for (a, e, n) in spans if a - 1e-6 <= t < e - 1e-6)
				if kind == "root" or (kind == "alt" and b % 2 == 0):
					self.note(t, dur, root_in(name, lo), vel + dv, ch)
				elif kind == "fifth" or kind == "alt":
					self.note(t, dur, fifth_in(name, lo), vel + dv, ch)
				elif kind == "chord":
					tones = tones_in(name, lo, hi)[:count]
					for k, n in enumerate(tones):
						self.note(t + k * 0.02, dur, n, vel + dv - 4 * k, ch)
			bt += bar
			b += 1

	def pad(self, spans, ch: int, vel: int, lo: int, hi: int, count: int = 3) -> None:
		for a, e, name in spans:
			for n in tones_in(name, lo, hi)[:count]:
				self.note(a, (e - a) * 0.98, n, vel, ch)

	def write(self, path: str, total_beats: float, tail_beats: float = 6.0) -> None:
		mid = mido.MidiFile(type=1, ticks_per_beat=TPB)
		meta = mido.MidiTrack()
		meta.append(mido.MetaMessage("set_tempo", tempo=int(60_000_000 / self.bpm), time=0))
		# A dummy event past the end keeps FluidSynth rendering the reverb tail.
		meta.append(mido.MetaMessage("marker", text="end", time=int((total_beats + tail_beats) * TPB)))
		mid.tracks.append(meta)
		for ch in sorted(set(e[4] for e in self.events) | set(self.programs)):
			tr = mido.MidiTrack()
			abs_msgs = []
			volume, pan, reverb = self.mix.get(ch, (100, 64, 50))
			if ch != DRUMS:
				abs_msgs.append((0, 0, mido.Message("program_change", channel=ch, program=self.programs.get(ch, 0))))
			abs_msgs.append((0, 0, mido.Message("control_change", channel=ch, control=7, value=volume)))
			abs_msgs.append((0, 0, mido.Message("control_change", channel=ch, control=10, value=pan)))
			abs_msgs.append((0, 0, mido.Message("control_change", channel=ch, control=91, value=reverb)))
			abs_msgs.append((0, 0, mido.Message("control_change", channel=ch, control=93, value=0)))
			jitter = 2.0 if ch == DRUMS else 5.0
			for t, dur, n, vel, c in self.events:
				if c != ch:
					continue
				on = int(round(t * TPB + (self.rng.gauss(0, jitter) if t > 0 else 0)))
				on = max(0, on)
				off = max(on + 10, int(round((t + dur) * TPB)))
				v = max(1, min(127, int(vel + self.rng.randint(-6, 6))))
				abs_msgs.append((on, 2, mido.Message("note_on", channel=ch, note=n, velocity=v)))
				abs_msgs.append((off, 1, mido.Message("note_off", channel=ch, note=n, velocity=0)))
			abs_msgs.sort(key=lambda x: (x[0], x[1]))
			last = 0
			for tick, _, msg in abs_msgs:
				tr.append(msg.copy(time=tick - last))
				last = tick
			mid.tracks.append(tr)
		mid.save(path)


# --- Tunes (melodies written from the traditional tunes) ------------------------

# Yankee Doodle in D, 2/4 counted in quarter beats.
YD_VERSE = ("D4:.5 D4 E4 F#4 D4 F#4 E4 A3 | D4 D4 E4 F#4 D4:1 C#4:1 | "
	"D4:.5 D4 E4 F#4 G4 F#4 E4 D4 | C#4 A3 B3 C#4 D4:1 D4:1")
YD_CHORUS = ("B4:.75 C#5:.25 B4:.5 A4 B4 C#5 D5:1 | A4:.75 B4:.25 A4:.5 G4 F#4:1 A4:1 | "
	"B4:.75 C#5:.25 B4:.5 A4 B4 C#5 D5 B4 | A4 D5 C#5 E5 D5:1 D5:1")
YD_VERSE_CH = "D:2 A:2 D:2 A:2 D:2 G:2 A:2 D:2"
YD_CHORUS_CH = "G:2 D:2 A:2 D:2 G:2 D:2 A:2 D:2"

# Soldier's Joy in D (reel), eighth notes.
SJ_A = ("D5:.5 C#5 D5 B4 A4 F#4 D4 F#4 | G4 F#4 G4 A4 B4 A4 G4 F#4 | "
	"E4 D4 E4 F#4 G4 F#4 G4 A4 | B4 A4 G4 F#4 E4:1 A4:.3333 B4:.3333 C#5:.3334 | "
	"D5:.5 C#5 D5 B4 A4 F#4 D4 F#4 | G4 F#4 G4 A4 B4 A4 G4 F#4 | "
	"E4 F#4 G4 A4 B4 G4 E4 C#4 | D4:1 F#4:1 D4:1 r:1")
SJ_A_CH = "D:4 G:4 A:4 G:2 A:2 D:4 G:4 A:4 D:4"
SJ_B = ("A5:.5 F#5 D5 F#5 A5 F#5 D5 F#5 | G5 B5 E5 G5 G5 B5 E5 G5 | "
	"A5 F#5 D5 F#5 A5 F#5 D5 F#5 | G5 E5 C#5 D5 E5:1 F#5:.5 G5:.5 | "
	"A5:.5 F#5 D5 F#5 A5 F#5 D5 F#5 | G5 B5 E5 G5 G5 B5 E5 G5 | "
	"A5 F#5 G5 E5 F#5 D5 E5 C#5 | D5:1 F#5:1 D5:1 r:1")
SJ_B_CH = "D:4 Em:4 D:4 A:4 D:4 Em:4 D:2 A:2 D:4"

# Greensleeves in A (dorian-inflected minor), 6/8 counted in quarter beats.
GS_VERSE = ("C5:1 D5:.5 E5:.75 F#5:.25 E5:.5 | D5:1 B4:.5 G4:.75 A4:.25 B4:.5 | "
	"C5:1 A4:.5 A4:.75 G#4:.25 A4:.5 | B4:1 G#4:.5 E4:1 A4:.5 | "
	"C5:1 D5:.5 E5:.75 F#5:.25 E5:.5 | D5:1 B4:.5 G4:.75 A4:.25 B4:.5 | "
	"C5:.75 B4:.25 A4:.5 G#4:.75 F#4:.25 G#4:.5 | A4:3")
GS_CHORUS = ("G5:1.5 G5:.75 F#5:.25 E5:.5 | D5:1 B4:.5 G4:.75 A4:.25 B4:.5 | "
	"C5:1 A4:.5 A4:.75 G#4:.25 A4:.5 | B4:1 G#4:.5 E4:1.5 | "
	"G5:1.5 G5:.75 F#5:.25 E5:.5 | D5:1 B4:.5 G4:.75 A4:.25 B4:.5 | "
	"C5:.75 B4:.25 A4:.5 G#4:.75 F#4:.25 G#4:.5 | A4:3")
GS_VERSE_CH = "Am:3 G:3 Am:3 E:3 Am:3 G:3 Am:1.5 E:1.5 Am:3"
GS_CHORUS_CH = "C:3 G:3 Am:3 E:3 C:3 G:3 Am:1.5 E:1.5 Am:3"

# Drunken Sailor in D dorian, 4/4.
DS_VERSE = ("A4:1 A4:.5 A4:.5 A4:1 A4:.5 A4:.5 | A4:1 D4 F4 A4 | "
	"G4:1 G4:.5 G4:.5 G4:1 G4:.5 G4:.5 | G4:1 C4 E4 G4 | "
	"A4:1 A4:.5 A4:.5 A4:1 A4:.5 A4:.5 | A4:1 B4 C5 D5 | C5 A4 G4 E4 | D4:2 D4:2")
DS_CHORUS = ("A4:2 A4:2 | A4:1 D4 F4 A4 | G4:2 G4:2 | G4:1 C4 E4 G4 | "
	"A4:2 A4:2 | A4:1 B4 C5 D5 | C5 A4 G4 E4 | D4:2 D4:2")
DS_CH = "Dm:4 Dm:4 C:4 C:4 Dm:4 Dm:4 Am:2 C:2 Dm:4"

# Minuet in G (Petzold, 1725), 3/4.
MIN_A = ("D5:1 G4:.5 A4 B4 C5 | D5:1 G4 G4 | E5:1 C5:.5 D5 E5 F#5 | G5:1 G4 G4 | "
	"C5:1 D5:.5 C5 B4 A4 | B4:1 C5:.5 B4 A4 G4 | F#4:1 G4:.5 A4 B4 G4 | A4:3 | "
	"D5:1 G4:.5 A4 B4 C5 | D5:1 G4 G4 | E5:1 C5:.5 D5 E5 F#5 | G5:1 G4 G4 | "
	"C5:1 D5:.5 C5 B4 A4 | B4:1 C5:.5 B4 A4 G4 | A4:1 B4:.5 A4 G4 F#4 | G4:3")
MIN_A_CH = "G:3 G:3 C:3 G:3 Am:3 G:3 D:3 D:3 G:3 G:3 C:3 G:3 Am:3 G:3 D:3 G:3"
MIN_B = ("B5:1 G5:.5 A5 B5 G5 | A5:1 D5:.5 E5 F#5 D5 | G5:1 E5:.5 F#5 G5 D5 | "
	"C#5:1 B4:.5 C#5 A4:1 | A4:.5 B4 C#5 D5 E5 F#5 | G5:1 F#5 E5 | F#5:1 A4 C#5 | D5:3 | "
	"D5:1 G4:.5 F#4 G4:1 | E5:1 G4:.5 F#4 G4:1 | D5:1 C5 B4 | A4:.5 G4 F#4 G4 A4:1 | "
	"D4:.5 E4 F#4 G4 A4 B4 | C5:1 B4 A4 | B4:.5 D5 G4:1 F#4:1 | G4:3")
MIN_B_CH = "G:3 D:3 Em:3 A:3 A:3 Em:1 A:2 D:1 A:2 D:3 G:3 C:3 G:3 D:3 D:3 Am:3 G:2 D:1 G:3"

# Old Hundredth (Bourgeois, 1551), with a chord per melody note.
OLD100 = [
	("G4 G4 F#4 E4 D4 G4 A4 B4", "G Em D C G C D G"),
	("B4 B4 B4 A4 G4 C5 B4 A4", "G Em G D Em C G D"),
	("G4 A4 B4 A4 G4 E4 F#4 G4", "G D G D Em C D G"),
	("D5 B4 G4 A4 C5 B4 A4 G4", "G G Em D Am G D G"),
]

D_MAJOR = [2, 4, 6, 7, 9, 11, 1]


def diatonic(notes, steps: int, scale=D_MAJOR):
	"""Shift a melody by scale steps (e.g. +2 = a third above)."""
	ladder = [n for n in range(24, 108) if n % 12 in scale]
	out = []
	for n, d in notes:
		if n is None:
			out.append((None, d))
			continue
		i = max(k for k, m in enumerate(ladder) if m <= n)
		out.append((ladder[i + steps], d))
	return out


# --- Arrangements ---------------------------------------------------------------

def theme() -> tuple[Song, float, bool]:
	s = Song(84, 1)
	REC, FID, GTR, FLU = 0, 1, 2, 3
	s.channel(REC, 74, 96, 50, 60)   # recorder
	s.channel(FID, 40, 92, 80, 60)   # violin (fiddle)
	s.channel(GTR, 24, 100, 64, 45)  # nylon guitar
	s.channel(FLU, 73, 84, 44, 60)   # flute
	s.channel(DRUMS, 0, 84, 64, 30)

	guitar = [
		(0.0, "alt", 0.95, 0, 40, 0, 0), (0.5, "chord", 0.45, -12, 55, 67, 3),
		(1.0, "chord", 0.45, -8, 55, 67, 3), (1.5, "chord", 0.45, -14, 55, 67, 3),
	]
	hand_drum = [(0.0, 64, 34), (1.0, 63, 18), (1.5, 63, 14)]

	def drum(t0: float, t1: float) -> None:
		t = t0
		while t < t1 - 1e-6:
			for off, n, v in hand_drum:
				s.note(t + off, 0.3, n, v, DRUMS)
			t += 2.0

	t = 0.0
	# Intro: guitar alone.
	s.pattern(chord_spans("D:4 G:2 A:2", t), 2.0, guitar, GTR, 58)
	t += 8
	# Yankee Doodle: recorder, gently.
	s.pattern(chord_spans(YD_VERSE_CH + " " + YD_CHORUS_CH, t), 2.0, guitar, GTR, 58)
	s.melody(YD_VERSE, t, REC, 68, 12)
	s.melody(YD_CHORUS, t + 16, REC, 70, 12)
	t += 32
	# Yankee Doodle again: fiddle leads, flute a third above in the chorus.
	s.pattern(chord_spans(YD_VERSE_CH + " " + YD_CHORUS_CH, t), 2.0, guitar, GTR, 60)
	drum(t, t + 32)
	s.melody(YD_VERSE, t, FID, 70, 12)
	s.melody(YD_CHORUS, t + 16, FID, 72, 12)
	s.melody(diatonic(parse(YD_CHORUS), 2), t + 16, FLU, 52, 12)
	t += 32
	# Soldier's Joy A: fiddle.
	s.pattern(chord_spans(SJ_A_CH, t), 2.0, guitar, GTR, 60)
	drum(t, t + 32)
	s.melody(SJ_A, t, FID, 72)
	t += 32
	# Soldier's Joy B: flute leads, fiddle an octave below.
	s.pattern(chord_spans(SJ_B_CH, t), 2.0, guitar, GTR, 60)
	drum(t, t + 32)
	s.melody(SJ_B, t, FLU, 66)
	s.melody(SJ_B, t, FID, 58, -12)
	t += 32
	# Soldier's Joy A again: recorder an octave up with fiddle.
	s.pattern(chord_spans(SJ_A_CH, t), 2.0, guitar, GTR, 58)
	drum(t, t + 28)
	s.melody(SJ_A, t, REC, 60, 12)
	s.melody(SJ_A, t, FID, 56)
	t += 32
	# Coda: settles back to the guitar vamp, ending on A to lead into the intro.
	s.pattern(chord_spans("D:4 G:2 A:2", t), 2.0, guitar, GTR, 56)
	s.melody("F#5:2 E5:2 D5:2 C#5:2", t, REC, 50)
	t += 8
	return s, t, True


def europe() -> tuple[Song, float, bool]:
	s = Song(96, 2)
	ACC, FID, BAS = 0, 1, 2
	s.channel(ACC, 21, 106, 52, 55)   # accordion
	s.channel(FID, 40, 90, 78, 60)   # violin (fiddle)
	s.channel(BAS, 32, 80, 64, 30)   # acoustic bass
	s.channel(DRUMS, 0, 64, 64, 30)

	six8_bass = [(0.0, "root", 1.3, 0, 40, 0, 0), (1.5, "fifth", 1.3, -8, 40, 0, 0)]
	six8_acc = [
		(0.5, "chord", 0.45, -10, 57, 69, 3), (1.0, "chord", 0.45, -14, 57, 69, 3),
		(2.0, "chord", 0.45, -10, 57, 69, 3), (2.5, "chord", 0.45, -14, 57, 69, 3),
	]
	four_bass = [(0.0, "root", 0.9, 0, 38, 0, 0), (2.0, "fifth", 0.9, -8, 38, 0, 0)]
	four_acc = [(1.0, "chord", 0.5, -10, 57, 69, 3), (3.0, "chord", 0.5, -12, 57, 69, 3)]

	def gs(t: float, verse: bool, lead: str) -> float:
		spans = chord_spans(GS_VERSE_CH if verse else GS_CHORUS_CH, t)
		s.pattern(spans, 3.0, six8_bass, BAS, 70)
		s.pattern(spans, 3.0, six8_acc, ACC, 46)
		mel = GS_VERSE if verse else GS_CHORUS
		if lead in ("acc", "both"):
			s.melody(mel, t, ACC, 70)
		if lead in ("fid", "both"):
			s.melody(mel, t, FID, 70 if lead == "fid" else 60, 12 if lead == "both" else 0)
		return t + 24

	def ds(t: float, verse: bool, lead: str, drums: bool) -> float:
		spans = chord_spans(DS_CH, t)
		s.pattern(spans, 4.0, four_bass, BAS, 70)
		s.pattern(spans, 4.0, four_acc, ACC, 44)
		mel = DS_VERSE if verse else DS_CHORUS
		if lead in ("acc", "both"):
			s.melody(mel, t, ACC, 70)
		if lead in ("fid", "both"):
			s.melody(mel, t, FID, 70 if lead == "fid" else 60, 12 if lead == "both" else 0)
		if drums:
			for b in range(8):
				s.note(t + b * 4, 0.4, 45, 40, DRUMS)
				s.note(t + b * 4 + 2, 0.4, 45, 30, DRUMS)
				s.note(t + b * 4 + 3.5, 0.3, 45, 18, DRUMS)
		return t + 32

	t = 0.0
	# Intro bar of accompaniment; the melody's pickup falls on its last eighth.
	s.pattern(chord_spans("Am:3", t), 3.0, six8_bass, BAS, 64)
	s.pattern(chord_spans("Am:3", t), 3.0, six8_acc, ACC, 42)
	s.melody("A4:.5", 2.5, ACC, 64)
	t = 3.0
	t = gs(t, True, "acc")
	t = gs(t, False, "fid")
	s.melody("A4:.5", t - 0.5, FID, 60)
	t = gs(t, True, "fid")
	t = gs(t, False, "both")
	t = ds(t, True, "acc", False)
	t = ds(t, False, "fid", True)
	t = ds(t, True, "fid", True)
	t = ds(t, False, "both", True)
	return s, t, True


def congress() -> tuple[Song, float, bool]:
	s = Song(100, 3)
	HRH, HLH, STR, VLN, CEL = 0, 1, 2, 3, 4
	s.channel(HRH, 6, 104, 58, 50)    # harpsichord, right hand
	s.channel(HLH, 6, 84, 70, 50)    # harpsichord, left hand
	s.channel(STR, 48, 66, 64, 70)   # string ensemble
	s.channel(VLN, 40, 80, 46, 65)   # violin
	s.channel(CEL, 42, 70, 84, 60)   # cello

	lh = [(0.0, "root", 0.95, 0, 43, 0, 0), (1.0, "chord", 0.45, -14, 55, 66, 3),
		(2.0, "chord", 0.45, -16, 55, 66, 3)]
	cello = [(0.0, "root", 2.8, 0, 36, 0, 0)]

	def minuet(t: float, part: str, full: bool) -> float:
		mel, ch = (MIN_A, MIN_A_CH) if part == "A" else (MIN_B, MIN_B_CH)
		spans = chord_spans(ch, t)
		s.pattern(spans, 3.0, lh, HLH, 62)
		s.melody(mel, t, HRH, 72)
		if full:
			s.melody(mel, t, VLN, 58, legato=0.98, accent=False)
			s.pattern(spans, 3.0, cello, CEL, 52)
			s.pad(spans, STR, 34, 55, 67)
		return t + 48

	t = 0.0
	t = minuet(t, "A", False)
	t = minuet(t, "A", True)
	t = minuet(t, "B", False)
	t = minuet(t, "B", True)
	# Old Hundredth as a string chorale with harpsichord continuo.
	for mel, chords in OLD100:
		notes = parse(mel)
		names = chords.split()
		for i, ((n, _), name) in enumerate(zip(notes, names)):
			d = 4.0 if i == len(notes) - 1 else 2.0
			s.note(t, d * 0.97, n, 64, VLN)
			inner = [m for m in tones_in(name, 52, n - 3)][-2:]
			for m in inner:
				s.note(t, d * 0.97, m, 44, STR)
			s.note(t, d * 0.97, root_in(name, 36), 56, CEL)
			for k, m in enumerate(tones_in(name, 50, 64)[:3]):
				s.note(t + k * 0.08, d * 0.5, m, 44 - k * 4, HLH)
			t += d
	return s, t, True


def independence() -> tuple[Song, float, bool]:
	s = Song(116, 4)
	PIC, FLU, TPT, HRN = 0, 1, 2, 3
	s.channel(PIC, 72, 80, 56, 45)   # piccolo as the fife
	s.channel(FLU, 73, 86, 70, 45)   # flute, second fife
	s.channel(TPT, 56, 88, 60, 55)   # trumpet
	s.channel(HRN, 60, 70, 72, 60)   # french horn
	s.channel(DRUMS, 0, 74, 64, 35)

	def snare_bar(t: float, v: int = 62) -> None:
		for off, dv in [(0.0, 18), (0.5, 0), (0.75, -8), (1.0, 12), (1.5, 0)]:
			s.note(t + off, 0.2, 38, v + dv, DRUMS)
		s.note(t, 0.4, 36, v + 6, DRUMS)

	def roll(t: float, beats: float, v0: int, v1: int) -> None:
		steps = int(beats * 8)
		for i in range(steps):
			s.note(t + i / 8, 0.1, 38, int(v0 + (v1 - v0) * i / steps), DRUMS)

	t = 0.0
	# Fanfare.
	fan1 = "A4:.5 A4:.5 A4:.5 D5:1.5 r:1"
	fan2 = "F#5:.5 F#5:.5 F#5:.5 A5:1.5 r:1"
	s.melody(fan1, t, TPT, 84)
	s.melody(diatonic(parse(fan1), -2), t, HRN, 70)
	s.melody(fan2, t + 4, TPT, 90)
	s.melody(diatonic(parse(fan2), -2), t + 4, HRN, 74)
	s.note(t, 0.5, 36, 80, DRUMS)
	s.note(t + 4, 0.5, 36, 84, DRUMS)
	roll(t + 6, 2, 40, 80)
	t += 8
	# Fife and drum: Yankee Doodle.
	for part in (YD_VERSE, YD_CHORUS):
		s.melody(part, t, PIC, 70, 12)
		s.melody(diatonic(parse(part), -2), t, FLU, 56, 12)
		for b in range(8):
			snare_bar(t + b * 2)
		t += 16
	# Chorus once more with the brass.
	s.melody(YD_CHORUS, t, PIC, 72, 12)
	s.melody(YD_CHORUS, t, TPT, 76)
	s.melody(diatonic(parse(YD_CHORUS), -2), t, HRN, 64)
	for b in range(8):
		snare_bar(t + b * 2, 70)
	t += 16
	# Final cadence: a held D major chord over a drum roll.
	for n, ch, v in [(74, PIC, 70), (66, FLU, 60), (62, TPT, 80), (69, TPT, 72), (54, HRN, 70), (50, HRN, 70)]:
		s.note(t, 4.0, n, v, ch)
	roll(t, 3.5, 50, 86)
	s.note(t + 3.5, 0.5, 36, 92, DRUMS)
	s.note(t + 3.5, 0.3, 38, 96, DRUMS)
	t += 4
	return s, t, False


SONGS = {"theme": theme, "europe": europe, "congress": congress, "independence": independence}


# --- Rendering ------------------------------------------------------------------

def render(fluidsynth: str, soundfont: str, mid: str, wav: str) -> None:
	cmd = [
		fluidsynth, "-ni", "-q",
		"-r", str(SR), "-g", "0.5", "-R", "1", "-C", "0",
		"-o", "synth.reverb.room-size=0.55",
		"-o", "synth.reverb.damp=0.4",
		"-o", "synth.reverb.width=0.8",
		"-o", "synth.reverb.level=0.45",
		"-F", wav, soundfont, mid,
	]
	subprocess.run(cmd, check=True)


def db(x: float) -> float:
	return 20 * np.log10(max(x, 1e-12))


def finish(wav_in: str, wav_out: str, beats: float, bpm: float, loop: bool) -> dict:
	sr, data = wavfile.read(wav_in)
	assert sr == SR, sr
	x = data.astype(np.float64)
	if data.dtype == np.int16:
		x /= 32768.0
	if x.ndim == 1:
		x = np.stack([x, x], axis=1)
	n = int(round(beats * 60.0 / bpm * SR))
	if loop:
		tail = x[n:]
		out = x[:n].copy()
		k = min(len(tail), n)
		out[:k] += tail[:k]
	else:
		# Trim trailing silence, then a short fade on whatever is left.
		env = np.abs(x).max(axis=1)
		last = np.nonzero(env > 10 ** (-60 / 20))[0]
		end = min(len(x), (last[-1] if len(last) else n) + int(0.1 * SR))
		out = x[:end].copy()
		f = min(int(0.6 * SR), len(out))
		out[-f:] *= np.linspace(1, 0, f)[:, None]
	rms = float(np.sqrt(np.mean(out ** 2)))
	peak = float(np.abs(out).max())
	gain = min(10 ** (-19 / 20) / rms, 10 ** (-3 / 20) / peak)
	out *= gain
	wavfile.write(wav_out, SR, (np.clip(out, -1, 1) * 32767).astype(np.int16))
	# Stats.
	win = int(0.1 * SR)
	frames = len(out) // win
	w_rms = np.sqrt(np.mean(out[: frames * win].reshape(frames, win, 2) ** 2, axis=(1, 2)))
	silent = w_rms < 10 ** (-50 / 20)
	run = best = 0
	for sflag in silent[: frames - (0 if loop else 10)]:
		run = run + 1 if sflag else 0
		best = max(best, run)
	half = int(0.5 * SR)
	return {
		"seconds": len(out) / SR,
		"peak_db": db(float(np.abs(out).max())),
		"rms_db": db(float(np.sqrt(np.mean(out ** 2)))),
		"longest_silence_s": best * 0.1,
		"seam_jump": float(np.abs(out[-1] - out[0]).max()) if loop else None,
		"seam_rms_db": (db(float(np.sqrt(np.mean(out[-half:] ** 2)))), db(float(np.sqrt(np.mean(out[:half] ** 2))))) if loop else None,
	}


def encode(ffmpeg: str, wav: str, ogg: str) -> None:
	subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3",
		"-ar", str(SR), "-ac", "2", ogg], check=True)


def main() -> int:
	here = os.path.dirname(os.path.abspath(__file__))
	root = os.path.normpath(os.path.join(here, "..", ".."))
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--fluidsynth", required=True)
	ap.add_argument("--soundfont", required=True)
	ap.add_argument("--ffmpeg", default="ffmpeg")
	ap.add_argument("--work", default=os.path.join(tempfile.gettempdir(), "idle_pioneer_music"))
	ap.add_argument("--out", default=os.path.join(root, "assets", "audio", "music"))
	ap.add_argument("--only", default="")
	a = ap.parse_args()
	os.makedirs(a.work, exist_ok=True)
	os.makedirs(a.out, exist_ok=True)
	names = [n for n in a.only.split(",") if n] or list(SONGS)
	for name in names:
		song, beats, loop = SONGS[name]()
		mid = os.path.join(a.work, name + ".mid")
		raw = os.path.join(a.work, name + "_raw.wav")
		wav = os.path.join(a.work, name + ".wav")
		ogg = os.path.join(a.out, name + ".ogg")
		song.write(mid, beats)
		render(a.fluidsynth, a.soundfont, mid, raw)
		stats = finish(raw, wav, beats, song.bpm, loop)
		encode(a.ffmpeg, wav, ogg)
		stats["kb"] = os.path.getsize(ogg) / 1024
		print(name, {k: (round(v, 2) if isinstance(v, float) else v) for k, v in stats.items()})
	return 0


if __name__ == "__main__":
	sys.exit(main())
