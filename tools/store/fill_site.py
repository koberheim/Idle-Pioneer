"""Fills the last placeholders in docs/site/ and reports any that remain.

  python tools/store/fill_site.py                              # just report what is still open
  python tools/store/fill_site.py --email support@example.com
  python tools/store/fill_site.py --admob-pub 1234567890123456  # the digits after "pub-" in AdMob
  python tools/store/fill_site.py --date "1 December 2026"      # policy effective date (default: today)

Options can be combined. The effective date is only written once the email is
known, since a policy without a contact address isn't ready to publish.
"""
import argparse
import datetime
import glob
import os
import re

SITE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "docs", "site")
FILES = sorted(glob.glob(os.path.join(SITE, "*.html"))) + [os.path.join(SITE, "app-ads.txt")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--email")
    ap.add_argument("--admob-pub")
    ap.add_argument("--date")
    a = ap.parse_args()
    fills = {}
    if a.email:
        if not re.fullmatch(r"[^@\s<>\"]+@[^@\s<>\"]+\.[^@\s<>\"]+", a.email):
            raise SystemExit("That doesn't look like an email address: " + a.email)
        fills["{{CONTACT_EMAIL}}"] = a.email
        today = datetime.date.today()
        fills["{{EFFECTIVE_DATE}}"] = a.date or "%d %s" % (today.day, today.strftime("%B %Y"))
    elif a.date:
        fills["{{EFFECTIVE_DATE}}"] = a.date
    if a.admob_pub:
        digits = a.admob_pub.replace("pub-", "").replace("ca-", "").strip()
        if not re.fullmatch(r"\d{16}", digits):
            raise SystemExit("The AdMob publisher ID is 16 digits (AdMob > Settings > Account information).")
        fills["{{ADMOB_PUBLISHER_ID}}"] = digits

    left = {}
    for path in FILES:
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        new = text
        for k, v in fills.items():
            new = new.replace(k, v)
        if new != text:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(new)
            print("updated", os.path.basename(path))
        for ph in re.findall(r"\{\{[A-Z_]+\}\}", new):
            left.setdefault(ph, set()).add(os.path.basename(path))
    if left:
        print("\nStill to fill:")
        for ph, files in sorted(left.items()):
            print("  %-24s %s" % (ph, ", ".join(sorted(files))))
        raise SystemExit(1)
    print("\nNo placeholders left: the site is ready to publish.")


if __name__ == "__main__":
    main()
