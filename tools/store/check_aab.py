"""Checks a built Android App Bundle before it goes to Google Play.

  python tools/store/check_aab.py build/android/IdlePioneer.aab
  python tools/store/check_aab.py some.aab --allow-test     # a local trial build

It reads the bundle itself, so what it reports is what Play will receive:
  * release build, not debuggable
  * signed, and not with the debug key
  * native libraries aligned for 16 KB memory pages (a Play requirement)
  * package name, version, target SDK
  * the AdMob app ID and ad unit IDs are the real ones (or the build is
    marked as a test-ads build for testers)
  * the privacy policy link is set
  * nothing from the dev tree (tests, tools, docs, store art) slipped in

Exit code 1 if anything would be refused by Play or is unfit to upload.
With --allow-test, the items that only matter for a real upload are warnings.
"""
import os
import re
import struct
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAMPLE_APP_IDS = (b"ca-app-pub-3940256099942544~3347511713", b"ca-app-pub-3940256099942544~1458002511")
PAGE_16K = 16384
DEV_TREE = re.compile(r"assets/(test|tools|docs|store|addons/gut)/|\.md$|feature_graphic", re.I)

fails, warns = [], []


def ok(msg):
    print("  ok    " + msg)


def fail(msg, soft=False):
    (warns if soft else fails).append(msg)
    print(("  WARN  " if soft else "  FAIL  ") + msg)


def load_alignments(data):
    """p_align of every PT_LOAD segment in an ELF file."""
    if data[:4] != b"\x7fELF":
        return None
    is64 = data[4] == 2
    end = "<" if data[5] == 1 else ">"
    if is64:
        phoff, = struct.unpack_from(end + "Q", data, 0x20)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 0x36)
    else:
        phoff, = struct.unpack_from(end + "I", data, 0x1C)
        phentsize, phnum = struct.unpack_from(end + "HH", data, 0x2A)
    out = []
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type, = struct.unpack_from(end + "I", data, off)
        if p_type != 1:  # PT_LOAD
            continue
        if is64:
            align, = struct.unpack_from(end + "Q", data, off + 0x30)
        else:
            align, = struct.unpack_from(end + "I", data, off + 0x1C)
        out.append(align)
    return out


def project_setting(text, section, key):
    sec = re.search(r"(?ms)^\[%s\]\s*$(.*?)(?=^\[|\Z)" % re.escape(section), text)
    if not sec:
        return None
    m = re.search(r"(?m)^%s=(.*)$" % re.escape(key), sec.group(1))
    return m.group(1).strip().strip('"') if m else None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    allow_test = "--allow-test" in sys.argv
    if len(args) != 1:
        raise SystemExit(__doc__)
    path = args[0]
    z = zipfile.ZipFile(path)
    names = z.namelist()
    manifest = z.read("base/manifest/AndroidManifest.xml")
    print("%s  (%.1f MB)" % (path, os.path.getsize(path) / 1e6))

    # --- release, signed -------------------------------------------------------
    if b"debuggable" in manifest:
        fail("this is a debug build (debuggable). Play only accepts release builds.")
    else:
        ok("release build, not debuggable")
    sigs = [n for n in names if n.startswith("META-INF/") and n.rsplit(".", 1)[-1] in ("RSA", "EC", "DSA")]
    if not sigs:
        fail("the bundle is not signed")
    elif any(b"Android Debug" in z.read(n) for n in sigs):
        fail("signed with the debug key, not your upload key", soft=allow_test)
    else:
        ok("signed with an upload key")

    # --- native libraries --------------------------------------------------------
    libs = [n for n in names if n.startswith("base/lib/") and n.endswith(".so")]
    abis = sorted({n.split("/")[2] for n in libs})
    if abis != ["arm64-v8a"]:
        fail("expected arm64-v8a libraries only, found %s" % abis, soft="arm64-v8a" in abis)
    bad = []
    for n in libs:
        al = load_alignments(z.read(n))
        if not al or min(al) < PAGE_16K:
            bad.append("%s (%s)" % (os.path.basename(n), al))
    if bad:
        fail("not aligned for 16 KB pages: " + ", ".join(bad))
    else:
        ok("%d native libraries, all aligned for 16 KB pages" % len(libs))

    # --- identity ------------------------------------------------------------------
    presets = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    pkg = re.search(r'(?m)^package/unique_name="([^"]*)"', presets).group(1)
    code = re.search(r"(?m)^version/code=(\d+)", presets).group(1)
    vname = re.search(r'(?m)^version/name="([^"]*)"', presets).group(1)
    target = re.search(r'(?m)^gradle_build/target_sdk="(\d+)"', presets).group(1)
    if pkg.encode() in manifest and vname.encode() in manifest:
        ok("package %s, version %s (code %s), target SDK %s" % (pkg, vname, code, target))
    else:
        fail("the bundle doesn't match export_presets.cfg (%s %s): rebuild it" % (pkg, vname))
    if int(target) < 36:
        fail("target SDK %s: Play requires 36 for new apps" % target)

    # --- ads and privacy -------------------------------------------------------------
    project = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    test_ads = project_setting(project, "idle_pioneer", "ads/force_test_ads") == "true"
    if any(s in manifest for s in SAMPLE_APP_IDS):
        fail("AdMob app ID is Google's sample ID. Set admob/general/android/app_id "
             "(Project Settings > AdMob) to your own.", soft=allow_test)
    else:
        ok("AdMob app ID is your own")
    units = [project_setting(project, "idle_pioneer", "ads/android_" + k) for k in ("rewarded", "interstitial")]
    if test_ads:
        fail("TEST-ADS build (idle_pioneer/ads/force_test_ads=true): right for the closed test, "
             "must be switched off for production.", soft=True)
    elif not all(units):
        fail("no real ad unit IDs (idle_pioneer/ads/android_*): this build shows no ads at all.", soft=True)
    else:
        ok("real ad unit IDs set")
    if not (project_setting(project, "idle_pioneer", "urls/privacy_policy") or "").startswith("https://"):
        fail("no privacy policy link (idle_pioneer/urls/privacy_policy): Play expects it inside the app too.",
             soft=allow_test)
    else:
        ok("privacy policy link set")

    # --- contents ------------------------------------------------------------------------
    stray = [n for n in names if DEV_TREE.search(n)]
    if stray:
        fail("dev files in the bundle: " + ", ".join(stray[:5]))
    else:
        ok("no tests, tools, docs or store art inside")
    need = ["assets/addons/admob/LICENSE", "assets/addons/GodotGooglePlayBilling/LICENSE"]
    missing = [n for n in need if not any(x.endswith(n) for x in names)]
    if missing:
        fail("license texts missing from the bundle: " + ", ".join(missing))
    else:
        ok("plugin license texts included")

    print()
    if fails:
        print("NOT ready to upload: %d problem(s), %d warning(s)." % (len(fails), len(warns)))
        sys.exit(1)
    print("Ready%s. %d warning(s)." % (" (trial build)" if allow_test else " to upload", len(warns)))


if __name__ == "__main__":
    main()
