"""Generates candidate sounds and music with ElevenLabs, lays them out for
listening, and promotes the picks into assets/audio through sfx_tools.py.

Prompts live in eleven_manifest.json (one item per sound id); the plan behind
them is docs/AUDIO_PLAN.md. Candidates go to tools/music/out/<id>/ (not in
the repo). The API key is read from the ELEVENLABS_API_KEY environment
variable and never written anywhere.

  # generate the missing candidates for some ids (or every item if none given)
  python tools/music/eleven.py gen liberty quill amb_newworld
  python tools/music/eleven.py gen --kind sfx          # every sfx item
  python tools/music/eleven.py gen coin --n 2 --force  # 2 more takes of coin

  # write out/audition.html: current file and every candidate, loudness-matched
  python tools/music/eleven.py audition

  # normalise the picks exported from the audition page into assets/audio
  python tools/music/eleven.py promote tools/music/out/picks.json

Generating again never overwrites a candidate: new takes are numbered on.
"""

from __future__ import annotations

import argparse
import glob
import html
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
MANIFEST = os.path.join(HERE, "eleven_manifest.json")
OUT = os.path.join(HERE, "out")
API = "https://api.elevenlabs.io/v1"
SFX_MODEL = "eleven_text_to_sound_v2"
MUSIC_MODEL = "music_v2_5"
DEFAULT_N = {"sfx": 4, "amb": 3, "music": 3}
DEFAULT_INFLUENCE = 0.5


def load_manifest() -> dict:
	with open(MANIFEST, encoding="utf-8") as f:
		return json.load(f)


def candidates(i: str) -> list[str]:
	return sorted(glob.glob(os.path.join(OUT, i, i + "_c*.mp3")),
		key=lambda p: int(p.rsplit("_c", 1)[1].split(".")[0]))


def current_file(item: dict) -> str | None:
	d = {"music": "music", "amb": "ambience"}.get(item["kind"], "sfx")
	for ext in ("ogg", "wav", "mp3"):
		p = os.path.join(ROOT, "assets", "audio", d, item["id"] + "." + ext)
		if os.path.exists(p):
			return p
	return None


def post(path: str, body: dict, fmt: str, key: str) -> tuple[bytes, dict]:
	req = urllib.request.Request(API + path + "?output_format=" + fmt, data=json.dumps(body).encode(),
		headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
	with urllib.request.urlopen(req, timeout=600) as r:
		return r.read(), dict(r.headers)


def request_body(item: dict, style: str) -> tuple[str, dict]:
	if item["kind"] == "music":
		prompt = item["prompt"] + " " + style
		return "/music", {"prompt": prompt, "music_length_ms": int(item["length_ms"]),
			"model_id": item.get("model", MUSIC_MODEL), "force_instrumental": True}
	return "/sound-generation", {"text": item["prompt"], "duration_seconds": float(item["duration"]),
		"prompt_influence": float(item.get("influence", DEFAULT_INFLUENCE)),
		"loop": item["kind"] == "amb", "model_id": SFX_MODEL}


def cmd_gen(a) -> int:
	key = os.environ.get("ELEVENLABS_API_KEY", "")
	if not key:
		print("ELEVENLABS_API_KEY is not set (see docs/AUDIO_PLAN.md, 'Getting me connected').")
		return 1
	m = load_manifest()
	items = [it for it in m["items"] if (not a.ids or it["id"] in a.ids) and (not a.kind or it["kind"] == a.kind)]
	unknown = set(a.ids) - {it["id"] for it in m["items"]}
	if unknown:
		print("not in the manifest: " + ", ".join(sorted(unknown)))
		return 1
	os.makedirs(OUT, exist_ok=True)
	# Keep Godot from importing (and exporting) the candidates.
	open(os.path.join(OUT, ".gdignore"), "a").close()
	log = open(os.path.join(OUT, "log.jsonl"), "a", encoding="utf-8")
	failed = 0
	for it in items:
		have = candidates(it["id"])
		want = a.n if a.n else int(it.get("n", DEFAULT_N[it["kind"]]))
		todo = want if a.force else max(0, want - len(have))
		if todo == 0:
			print("%-14s %d candidate(s) already, skipped" % (it["id"], len(have)))
			continue
		os.makedirs(os.path.join(OUT, it["id"]), exist_ok=True)
		path, body = request_body(it, m["music_style"])
		nxt = len(have) + 1
		for _ in range(todo):
			dest = os.path.join(OUT, it["id"], "%s_c%d.mp3" % (it["id"], nxt))
			t0 = time.time()
			try:
				data, headers = post(path, body, a.format, key)
			except urllib.error.HTTPError as e:
				print("%-14s FAILED %d: %s" % (it["id"], e.code, e.read().decode(errors="replace")[:400]))
				failed += 1
				break
			with open(dest, "wb") as f:
				f.write(data)
			cost = headers.get("character-cost") or headers.get("Character-Cost") or "?"
			print("%-14s c%d  %5.1f s  %4d KB  cost %s" % (it["id"], nxt, time.time() - t0, len(data) // 1024, cost))
			log.write(json.dumps({"id": it["id"], "file": os.path.basename(dest), "time": time.strftime("%Y-%m-%d %H:%M:%S"),
				"endpoint": path, "body": body, "format": a.format, "cost": cost,
				"request_id": headers.get("request-id") or headers.get("Request-Id")}) + "\n")
			log.flush()
			nxt += 1
	log.close()
	return 1 if failed else 0


def _level(path: str, kind: str, ffmpeg: str) -> float:
	sys.path.insert(0, HERE)
	import loudness
	x = loudness.load(path, ffmpeg)
	return loudness.momentary_max(x) if kind == "sfx" else loudness.integrated(x)


def cmd_audition(a) -> int:
	m = load_manifest()
	rows = []
	for it in m["items"]:
		cands = candidates(it["id"])
		if not cands:
			continue
		files = ([("current", current_file(it))] if current_file(it) else []) + \
			[("c" + c.rsplit("_c", 1)[1].split(".")[0], c) for c in cands]
		levels = [_level(p, it["kind"], a.ffmpeg) for _, p in files]
		quietest = min(levels)
		multi = int(it.get("n", 1)) >= 5
		cells = []
		for (name, p), lv in zip(files, levels):
			rel = os.path.relpath(p, OUT).replace("\\", "/")
			vol = 10 ** ((quietest - lv) / 20)
			inp = '<input type="%s" name="%s" value="%s">' % ("checkbox" if multi else "radio", it["id"], name)
			cells.append('<label class="c">%s <b>%s</b> <audio controls preload="none" src="%s" data-vol="%.3f"></audio>'
				'<small>%.1f LUFS</small></label>' % (inp, name, html.escape(rel), vol, lv))
		rows.append('<section><h2>%s <small>%s%s</small></h2><p>%s</p>%s</section>' % (it["id"], it["kind"],
			" &middot; pick up to 3 (variants)" if multi else "", html.escape(it["prompt"]), "".join(cells)))
	page = PAGE.replace("{{ROWS}}", "\n".join(rows) or "<p>No candidates yet: run <code>eleven.py gen</code>.</p>")
	dest = os.path.join(OUT, "audition.html")
	os.makedirs(OUT, exist_ok=True)
	with open(dest, "w", encoding="utf-8") as f:
		f.write(page)
	print(dest)
	return 0


def cmd_promote(a) -> int:
	with open(a.picks, encoding="utf-8") as f:
		picks: dict = json.load(f)
	items = {it["id"]: it for it in load_manifest()["items"]}
	tools = os.path.join(HERE, "sfx_tools.py")
	for i, pick in picks.items():
		names = [p for p in (pick if isinstance(pick, list) else [pick]) if p != "current"]
		if not names:
			continue
		it = items[i]
		for k, name in enumerate(names):
			src = os.path.join(OUT, i, "%s_%s.mp3" % (i, name))
			dest_id = i if k == 0 else "%s_%d" % (i, k + 1)
			cmd = [sys.executable, tools, "--ffmpeg", a.ffmpeg, "normalize", src, "--id", dest_id]
			if "max_limit" in it:
				cmd += ["--max-limit", str(it["max_limit"])]
			if it["kind"] in ("music", "amb"):
				cmd += ["--music", "--trim-lead"] if it["kind"] == "music" else ["--ambience"]
			subprocess.run(cmd, check=True)
	return 0


PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Idle Pioneer audition</title>
<style>
:root { --bg:#f6f1e7; --ink:#2b2118; --soft:#7a6a58; --line:#d9cdb8; --accent:#8a3b1e; }
@media (prefers-color-scheme: dark) { :root { --bg:#1c1814; --ink:#efe6d6; --soft:#a8998a; --line:#3a3229; --accent:#e08a5a; } }
body { background:var(--bg); color:var(--ink); font:15px/1.45 Georgia, serif; margin:0 auto; max-width:1000px; padding:16px; }
header { position:sticky; top:0; background:var(--bg); padding:8px 0; border-bottom:1px solid var(--line); display:flex; gap:12px; align-items:center; flex-wrap:wrap; }
button { font:inherit; padding:6px 14px; border:1px solid var(--accent); color:var(--accent); background:none; border-radius:6px; cursor:pointer; }
section { border-bottom:1px solid var(--line); padding:12px 0; }
h2 { margin:0 0 4px; font-size:18px; } h2 small, small, p { color:var(--soft); font-size:13px; }
p { margin:0 0 8px; }
.c { display:flex; align-items:center; gap:8px; margin:4px 0; flex-wrap:wrap; }
audio { height:32px; max-width:100%; }
</style></head><body>
<header><b>Pick one per sound</b> <span style="color:var(--soft)">Playback is loudness-matched. "current" is what ships now.</span>
<button id="export">Export picks.json</button></header>
{{ROWS}}
<script>
const KEY = "ip-audition-picks";
let saved = {}; try { saved = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
document.querySelectorAll("audio").forEach(a => {
  a.volume = Math.min(1, parseFloat(a.dataset.vol));
  a.addEventListener("play", () => document.querySelectorAll("audio").forEach(o => { if (o !== a) o.pause(); }));
});
document.querySelectorAll("input").forEach(i => {
  const v = saved[i.name];
  i.checked = Array.isArray(v) ? v.includes(i.value) : v === i.value;
  i.addEventListener("change", () => { try { localStorage.setItem(KEY, JSON.stringify(picks())); } catch (e) {} });
});
function picks() {
  const out = {};
  document.querySelectorAll("input:checked").forEach(i => {
    if (i.type === "checkbox") (out[i.name] = out[i.name] || []).push(i.value); else out[i.name] = i.value;
  });
  return out;
}
document.getElementById("export").onclick = () => {
  const b = new Blob([JSON.stringify(picks(), null, 1)], {type: "application/json"});
  const l = document.createElement("a"); l.href = URL.createObjectURL(b); l.download = "picks.json"; l.click();
};
</script></body></html>
"""


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--ffmpeg", default="ffmpeg")
	sub = ap.add_subparsers(dest="cmd", required=True)
	g = sub.add_parser("gen")
	g.add_argument("ids", nargs="*")
	g.add_argument("--kind", choices=["sfx", "amb", "music"])
	g.add_argument("--n", type=int, default=0, help="candidates wanted per id (default: the item's n, or 4/3/3)")
	g.add_argument("--force", action="store_true", help="generate --n more even if candidates exist")
	g.add_argument("--format", default="mp3_44100_192")
	sub.add_parser("audition")
	p = sub.add_parser("promote")
	p.add_argument("picks")
	a = ap.parse_args()
	return {"gen": cmd_gen, "audition": cmd_audition, "promote": cmd_promote}[a.cmd](a)


if __name__ == "__main__":
	sys.exit(main())
