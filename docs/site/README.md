# Idle Pioneer public site

Static pages for the store listings:

| File | Purpose |
|---|---|
| `index.html` | Landing page linking the other two |
| `privacy.html` | Privacy policy URL for Google Play Console and App Store Connect |
| `support.html` | Support URL (App Store requires one; Play shows it on the listing) |
| `app-ads.txt` | AdMob seller verification. It must be served from the **domain root** (see below) |

The HTML files are self-contained: inline CSS, no JavaScript, no external requests. Headings use Libre Baskerville if it happens to be installed, otherwise Georgia. They adapt to dark mode through `prefers-color-scheme`.

## Placeholders to fill

The developer name (Skeemer Games), website (`https://koberheim.github.io`) and country (United States) are filled in. Three placeholders remain:

| Placeholder | Where | Value |
|---|---|---|
| `{{CONTACT_EMAIL}}` | privacy, support | The support inbox, once it exists |
| `{{EFFECTIVE_DATE}}` | privacy | The date the policy takes effect. Filled with today's date when the email is set |
| `{{ADMOB_PUBLISHER_ID}}` | app-ads.txt | The 16 digits after `pub-` in AdMob > Settings > Account information |

Fill them with the script, which also lists anything still open:

```
python tools/store/fill_site.py --email you@example.com --admob-pub 1234567890123456
```

## Publishing with GitHub Pages

The site goes in a **public** repository named exactly `koberheim.github.io` (a GitHub "user site"). GitHub serves it at `https://koberheim.github.io/`, and that is the only free GitHub address where `app-ads.txt` sits at the root of the domain, as AdMob requires.

1. On github.com: **New repository**, name `koberheim.github.io`, Public, no README.
2. From the project folder, run:
   ```
   tools\store\publish_site.cmd
   ```
   It refuses to run while a placeholder is still unfilled. Otherwise it copies the three pages and `app-ads.txt` into a checkout of that repository next to the project (`..\koberheim.github.io`), commits and pushes. Git may ask you to sign in to GitHub the first time.
3. Wait a minute or two, then open `https://koberheim.github.io/privacy.html`.

Run step 2 again whenever the pages change.

The store URLs are then:

| Field | URL |
|---|---|
| Website (Play and App Store) | `https://koberheim.github.io` |
| Privacy policy (both stores, and the in-game button) | `https://koberheim.github.io/privacy.html` |
| Support URL (App Store) | `https://koberheim.github.io/support.html` |

## Where app-ads.txt must live

AdMob looks for `app-ads.txt` at the **root of the developer website** given in the store listings: `https://koberheim.github.io/app-ads.txt`. The website field in both listings must be exactly `https://koberheim.github.io`. AdMob can take up to 24 hours to find the file; check AdMob > Apps > app-ads.txt.

If you later move to a custom domain, put the same file at its root and change the website field in both stores.

## Keep the policy true

The policy was checked against the build on 13 Nov 2026. Re-check these whenever the game changes:

- **Ad SDK and mediation.** The policy names only Google AdMob. No mediation network is enabled (`admob/mediation/*` are all off). If one is ever added, or any other SDK such as analytics or crash reporting, add it to section 3 and to the store data forms.
- **Data types.** Section 3's table follows Google's published disclosures: [Android](https://developers.google.com/admob/android/privacy/play-data-disclosure) and [iOS](https://developers.google.com/admob/ios/privacy/data-disclosure). Re-read them when the ads SDK version changes.
- **Tracking on iOS.** The game shows no App Tracking Transparency prompt. If that changes, update section 5 and Apple's App Privacy answers.
- **Device backups.** Android's device backup is on (`user_data_backup/allow` in the Android preset) and the policy and FAQ say so. Change both if it's switched off.
- **Ad placement and pricing.** The policy and FAQ describe an ad only between expeditions, never at launch, one optional rewarded ad, and Ad-Free at US$4.99.
- **Offline progress.** The FAQ's "half pace, up to 4 hours" comes from `data/balance.json` (`offline_efficiency`, `offline_cap_hours`).
- Update `Effective` on the policy whenever its meaning changes.

This is a plain-language draft, not legal advice. If you sell in regions with specific requirements (for example a designated EU representative under GDPR Art. 27), consider a legal review.
