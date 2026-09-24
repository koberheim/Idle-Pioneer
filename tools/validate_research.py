#!/usr/bin/env python3
"""Validates data/research.json against data/content.json and the icon folder.

Structure rules (per branch):
  - 14-18 studies; exactly 2 repeatables (values 1.1-1.5); no "excludes".
  - A main line (path "") that covers tiers 1-6, ending in exactly one tier-6
    keystone on the main line. The keystone requires a main-line study of its
    own branch plus exactly one study from another branch.
  - 2-3 optional side paths ("a", "b", "c", named in the branch's path_* fields),
    each 3-5 studies, forking off a main-line study and otherwise requiring only
    studies of the same path.
  - Every requirement is of a strictly lower tier; every study is reachable.

Run:  python tools/validate_research.py
Exit code 0 on success, 1 if any check fails.
"""
import json, os, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESEARCH = os.path.join(ROOT, "data", "research.json")
CONTENT = os.path.join(ROOT, "data", "content.json")
ICONS = os.path.join(ROOT, "assets", "sprites", "icons")

BRANCH_IDS = ["husbandry", "forestry", "navigation", "roads", "manufacture", "commerce"]
SIDE_PATHS = ["a", "b", "c"]
MAX_HOOK = 150
MAX_YEAR = 1800

# effect type -> (target kind, value rule)
EFFECTS = {
	"production": ("raw_or_scope", "gt1"),
	"sell": ("resource_or_class", "gt1"),
	"workshop_speed": ("recipe_or_all", "gt1"),
	"recipe_input": ("recipe_input", "int_lower"),
	"speed": ("route", "gt1"),
	"cargo": ("route", "gt1"),
	"route_length": ("route_only", "lt1"),
	"colonist_bonus": ("raw_or_all", "gt1"),
	"colony_cost": ("none", "lt1"),
	"colonist_cost": ("none", "lt1"),
	"father_cost": ("none", "lt1"),
	"charter_cost": ("none", "lt1"),
	"workshop_cost": ("none", "lt1"),
	"market_glut": ("none", "glut"),
	"market_wanted": ("none", "wanted"),
	"favor_duration": ("none", "gt1"),
	"liberty": ("none", "gt1"),
	"explore": ("none", "gt1"),
	"treasure": ("none", "gt1"),
	"offline_hours": ("none", "positive"),
	"workshop_labour": ("none", "int1"),
	"extra_relic": ("none", "int1"),
}
CURRENT_GLUT = 0.6
CURRENT_WANTED = 1.6

errors = []
def err(msg):
	errors.append(msg)


def main():
	try:
		with open(RESEARCH, encoding="utf-8") as f:
			data = json.load(f)
	except Exception as e:
		print("FAIL: research.json does not parse:", e)
		return 1
	with open(CONTENT, encoding="utf-8") as f:
		content = json.load(f)

	resources = {r["id"]: r for r in content["resources"]}
	raw_ids = {r for r, v in resources.items() if v["kind"] == "raw"}
	recipes = {r["id"]: r for r in content["recipes"]}
	icons = {os.path.splitext(n)[0] for n in os.listdir(ICONS) if n.endswith(".png")}

	branches = data.get("research_branches", [])
	studies = data.get("research", [])
	bmap = {b["id"]: b for b in branches}
	if [b["id"] for b in branches] != BRANCH_IDS:
		err("branches must be exactly %s in order, got %s" % (BRANCH_IDS, [b["id"] for b in branches]))
	for b in branches:
		for k in ("id", "name", "icon", "desc", "path_a", "path_b"):
			if not b.get(k):
				err("branch %s: missing %s" % (b.get("id"), k))
		if b.get("icon") not in icons:
			err("branch %s: icon %r not found" % (b["id"], b.get("icon")))

	# ids unique
	by_id = {}
	for s in studies:
		if s["id"] in by_id:
			err("duplicate id %s" % s["id"])
		by_id[s["id"]] = s

	fields = ["id", "branch", "tier", "path", "name", "year", "hook", "icon", "requires", "requires_any", "excludes", "repeatable", "effect", "desc", "cost"]
	for s in studies:
		sid = s["id"]
		for k in fields:
			if k not in s:
				err("%s: missing field %s" % (sid, k))
		if s["branch"] not in bmap:
			err("%s: unknown branch %s" % (sid, s["branch"]))
			continue
		if not (isinstance(s["tier"], int) and 1 <= s["tier"] <= 6):
			err("%s: bad tier %r" % (sid, s["tier"]))
		p = s["path"]
		if p != "" and (p not in SIDE_PATHS or not bmap[s["branch"]].get("path_" + p)):
			err("%s: path %r is not declared on branch %s" % (sid, p, s["branch"]))
		if not isinstance(s["year"], int) or s["year"] > MAX_YEAR or s["year"] < 1490:
			err("%s: year %r out of range" % (sid, s["year"]))
		if not s["hook"] or len(s["hook"]) > MAX_HOOK:
			err("%s: hook length %d (max %d)" % (sid, len(s["hook"] or ""), MAX_HOOK))
		if s["icon"] not in icons:
			err("%s: icon %r not found" % (sid, s["icon"]))
		if s["excludes"] != "":
			err("%s: excludes must be empty (no either/or studies)" % sid)
		if not s["desc"]:
			err("%s: empty desc" % sid)
		# requirements
		for r in s["requires"] + s["requires_any"]:
			if r not in by_id:
				err("%s: requirement %s does not exist" % (sid, r))
			elif by_id[r]["tier"] >= s["tier"]:
				err("%s (tier %d): requirement %s is tier %d, must be lower" % (sid, s["tier"], r, by_id[r]["tier"]))
		# cost
		cost = s["cost"]
		if not (2 <= len(cost) <= 3):
			err("%s: cost should list 2-3 goods, has %d" % (sid, len(cost)))
		for g, n in cost.items():
			if g not in resources:
				err("%s: cost good %s does not exist" % (sid, g))
			if not (isinstance(n, int) and n > 0):
				err("%s: cost amount %r for %s" % (sid, n, g))
		check_effect(s, resources, raw_ids, recipes)

	# per-branch structure
	per = defaultdict(list)
	for s in studies:
		per[s["branch"]].append(s)
	for bid in BRANCH_IDS:
		check_branch(bid, bmap.get(bid, {}), per[bid], by_id)

	# reachability: fixed point over requires / requires_any
	done = set()
	changed = True
	while changed:
		changed = False
		for s in studies:
			if s["id"] in done:
				continue
			if all(r in done for r in s["requires"]) and (not s["requires_any"] or any(r in done for r in s["requires_any"])):
				done.add(s["id"])
				changed = True
	for s in studies:
		if s["id"] not in done:
			err("%s: unreachable" % s["id"])

	print_summary(branches, per)
	if errors:
		print("\nFAIL: %d problem(s)" % len(errors))
		for e in errors:
			print("  -", e)
		return 1
	print("\nOK: %d studies in %d branches pass all checks." % (len(studies), len(branches)))
	return 0


def check_effect(s, resources, raw_ids, recipes):
	sid = s["id"]
	e = s["effect"]
	t, v, tg = e.get("type"), e.get("value"), e.get("targets")
	if t not in EFFECTS:
		err("%s: unknown effect type %r" % (sid, t))
		return
	if not isinstance(tg, list):
		err("%s: targets must be a list" % sid)
		return
	kind, rule = EFFECTS[t]
	if kind == "none" and tg:
		err("%s: %s takes no targets" % (sid, t))
	elif kind == "raw_or_scope":
		if not tg or not all(x in raw_ids or x in ("all", "land", "sea") for x in tg):
			err("%s: production targets must be raw ids or all/land/sea: %s" % (sid, tg))
	elif kind == "raw_or_all":
		if not tg or not all(x in raw_ids or x == "all" for x in tg):
			err("%s: colonist_bonus targets must be raw ids or all: %s" % (sid, tg))
	elif kind == "resource_or_class":
		if not tg or not all(x in resources or x in ("all", "crafted", "raw") for x in tg):
			err("%s: sell targets invalid: %s" % (sid, tg))
	elif kind == "recipe_or_all":
		if not tg or not all(x in recipes or x == "all" for x in tg):
			err("%s: workshop_speed targets invalid: %s" % (sid, tg))
	elif kind == "route":
		if tg not in (["land"], ["sea"], ["all"]):
			err("%s: %s targets must be [land], [sea] or [all]: %s" % (sid, t, tg))
	elif kind == "route_only":
		if tg not in (["land"], ["sea"]):
			err("%s: route_length targets must be [land] or [sea]: %s" % (sid, tg))
	elif kind == "recipe_input":
		if len(tg) != 2 or tg[0] not in recipes or tg[1] not in recipes[tg[0]]["inputs"]:
			err("%s: recipe_input targets must be [recipe, input]: %s" % (sid, tg))
		else:
			cur = recipes[tg[0]]["inputs"][tg[1]]
			if not (isinstance(v, int) and 1 <= v < cur):
				err("%s: recipe_input value %r must be an int >= 1 and < current %d" % (sid, v, cur))
	# value rules
	if not isinstance(v, (int, float)) or isinstance(v, bool):
		err("%s: value must be a number" % sid)
		return
	if rule == "gt1" and not v > 1:
		err("%s: %s value must be > 1" % (sid, t))
	if rule == "lt1" and not 0 < v < 1:
		err("%s: %s value must be between 0 and 1" % (sid, t))
	if rule == "glut" and not CURRENT_GLUT < v < 1:
		err("%s: market_glut must be between %.1f and 1" % (sid, CURRENT_GLUT))
	if rule == "wanted" and not v > CURRENT_WANTED:
		err("%s: market_wanted must exceed %.1f" % (sid, CURRENT_WANTED))
	if rule == "positive" and not v > 0:
		err("%s: value must be positive" % sid)
	if rule == "int1" and v != 1:
		err("%s: %s value must be 1" % (sid, t))
	if s["repeatable"]:
		if rule == "gt1" and not 1.1 <= v <= 1.5:
			err("%s: repeatable value %.2f outside 1.1-1.5" % (sid, v))
		if rule not in ("gt1",):
			err("%s: repeatable studies must use a multiplier effect" % sid)
	elif rule == "gt1" and v > 4.0 and s["tier"] < 6:
		err("%s: non-keystone multiplier %.2f exceeds 4" % (sid, v))


def check_branch(bid, branch, items, by_id):
	n = len(items)
	if not 14 <= n <= 18:
		err("%s: %d studies (want 14-18)" % (bid, n))
	reps = [s for s in items if s["repeatable"]]
	if len(reps) != 2:
		err("%s: %d repeatables (want 2)" % (bid, len(reps)))
	for s in reps:
		if s["path"] != "":
			err("%s: repeatable %s should be on the main line" % (bid, s["id"]))
	main = [s for s in items if s["path"] == ""]
	main_ids = {s["id"] for s in main}
	tiers = {s["tier"] for s in main}
	for t in range(1, 7):
		if t not in tiers:
			err("%s: main line has no tier-%d study" % (bid, t))
	# main line only requires main line (keystone may add one cross-branch)
	for s in main:
		for r in s["requires"] + s["requires_any"]:
			rs = by_id.get(r)
			if rs is None:
				continue
			if rs["branch"] == bid and rs["path"] != "":
				err("%s: main-line study %s requires side-path study %s" % (bid, s["id"], r))
			if rs["branch"] != bid and s["tier"] != 6:
				err("%s: only the keystone may require another branch (%s -> %s)" % (bid, s["id"], r))
		if s["tier"] > 1 and not s["requires"] and not s["requires_any"]:
			err("%s: main-line study %s (tier %d) has no requirement" % (bid, s["id"], s["tier"]))
	# keystone
	keys = [s for s in items if s["tier"] == 6]
	if len(keys) != 1:
		err("%s: %d tier-6 studies (want 1 keystone)" % (bid, len(keys)))
	for k in keys:
		if k["path"] != "":
			err("%s: keystone %s must be on the main line" % (bid, k["id"]))
		if k["repeatable"]:
			err("%s: keystone cannot be repeatable" % bid)
		reqs = [by_id[r] for r in k["requires"] + k["requires_any"] if r in by_id]
		cross = [r for r in reqs if r["branch"] != bid]
		own = [r for r in reqs if r["branch"] == bid]
		if len(cross) != 1:
			err("%s: keystone needs exactly one cross-branch requirement, has %d" % (bid, len(cross)))
		for c in cross:
			if c["tier"] == 6:
				err("%s: keystone requires another keystone (%s)" % (bid, c["id"]))
		if not own:
			err("%s: keystone requires nothing from its own branch" % bid)
	# side paths
	declared = [p for p in SIDE_PATHS if branch.get("path_" + p)]
	if not 2 <= len(declared) <= 3:
		err("%s: %d side paths declared (want 2-3)" % (bid, len(declared)))
	for p in declared:
		ps = [s for s in items if s["path"] == p]
		pids = {s["id"] for s in ps}
		if not 3 <= len(ps) <= 5:
			err("%s: side path %s has %d studies (want 3-5)" % (bid, p, len(ps)))
		forks = 0
		for s in ps:
			reqs = s["requires"] + s["requires_any"]
			if not reqs:
				err("%s: side study %s has no requirement" % (bid, s["id"]))
			for r in reqs:
				if r in main_ids:
					forks += 1
				elif r not in pids:
					err("%s: side study %s (path %s) requires %s outside its path and the main line" % (bid, s["id"], p, r))
		if forks == 0:
			err("%s: side path %s never forks from the main line" % (bid, p))
		# path must be connected: every non-root study requires something in the path
		roots = [s for s in ps if not any(r in pids for r in s["requires"] + s["requires_any"])]
		if len(roots) != 1:
			err("%s: side path %s should have exactly one root, has %d" % (bid, p, len(roots)))
		# nothing outside the path depends on it (fully optional)
		for other in by_id.values():
			if other["path"] != p or other["branch"] != bid:
				for r in other["requires"] + other["requires_any"]:
					if r in pids and not (other["tier"] == 6 and other["branch"] != bid):
						if other["branch"] == bid:
							err("%s: %s depends on side-path study %s" % (bid, other["id"], r))
	undeclared = {s["path"] for s in items if s["path"] not in [""] + declared}
	if undeclared:
		err("%s: studies on undeclared paths %s" % (bid, sorted(undeclared)))


def fmt_effect(e):
	t = e["effect"]
	tg = ",".join(t["targets"]) if t["targets"] else "-"
	return "%s %s [%s]" % (t["type"], t["value"], tg)


def print_summary(branches, per):
	for b in branches:
		items = sorted(per[b["id"]], key=lambda s: (s["path"] != "", s["path"], s["tier"]))
		paths = ", ".join("%s=%s" % (p, b["path_" + p]) for p in SIDE_PATHS if b.get("path_" + p))
		print("\n== %s (%d studies; %s) ==" % (b["name"], len(items), paths))
		print("  %-4s %-4s %-5s %-30s %-44s %s" % ("tier", "path", "year", "id", "effect", "flags"))
		for s in items:
			flags = []
			if s["repeatable"]:
				flags.append("repeatable")
			if s["tier"] == 6:
				flags.append("KEYSTONE")
			reqs = s["requires"] + s["requires_any"]
			if reqs:
				flags.append("<- " + ", ".join(reqs))
			print("  %-4d %-4s %-5d %-30s %-44s %s" % (s["tier"], s["path"] or "-", s["year"], s["id"], fmt_effect(s), " ".join(flags)))


if __name__ == "__main__":
	sys.exit(main())
