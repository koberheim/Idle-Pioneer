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

Search and replace these in every file before publishing:

| Placeholder | Where | Value |
|---|---|---|
| `{{DEVELOPER_NAME}}` | all HTML | Your name or studio name, exactly as shown on the store listings |
| `{{CONTACT_EMAIL}}` | privacy, support | A support inbox you check |
| `{{EFFECTIVE_DATE}}` | privacy | Date the policy takes effect, e.g. "1 November 2026" |
| `{{WEBSITE}}` | privacy, support | Full URL of the developer website, e.g. `https://example.com` |
| `{{DEVELOPER_COUNTRY}}` | privacy (section 9) | Country you operate from |
| `{{ADMOB_PUBLISHER_ID}}` | app-ads.txt | The digits of your AdMob publisher ID, without the `pub-` prefix (AdMob > Settings > Account information). The final line looks like `google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0` |

Check that none are left: `grep -rn "{{" docs/site`

## Publishing with GitHub Pages

GitHub Pages' "Deploy from a branch" mode only serves a branch's root (`/`) or its `/docs` folder. It **cannot** serve `/docs/site` directly. Pick one of these:

1. **`gh-pages` branch (simplest).** Create a `gh-pages` branch containing only the contents of `docs/site/` at its root, and push it. Then go to repo **Settings > Pages > Build and deployment > Source: Deploy from a branch**, and choose `gh-pages` / `/ (root)`. One way to do this: `git subtree push --prefix docs/site origin gh-pages`.
2. **GitHub Actions.** Settings > Pages > Source: **GitHub Actions**, with a workflow that uploads `docs/site` using `actions/upload-pages-artifact` (`path: docs/site`) and then `actions/deploy-pages`.
3. **Serve `/docs`.** Not recommended: it would publish the design docs and launch plan in `docs/` too.

Add an empty `.nojekyll` file to whatever gets published if you'd rather skip Jekyll processing. It isn't needed for these files.

Pages must be public. On the free plan that means the repository must be public, so it's often easier to use a small separate public repo (e.g. `idle-pioneer-site`) that contains just these files.

The site is then at `https://<user>.github.io/<repo>/`. Use `.../privacy.html` and `.../support.html` as the store URLs.

## Where app-ads.txt must live

AdMob looks for `app-ads.txt` at the **root of the developer website domain** listed in your Play and App Store listings, e.g. `https://example.com/app-ads.txt`. A subpath such as `https://user.github.io/repo/app-ads.txt` is **not** checked.

- If the developer website is a GitHub project page (`user.github.io/repo`), app-ads.txt has to go in your **user site** repo (`<user>.github.io`, served at `https://<user>.github.io/app-ads.txt`), and the store listing's website must be `https://<user>.github.io`.
- Or use a custom domain (Settings > Pages > Custom domain) and put app-ads.txt at its root.
- The website in the store listings must exactly match that domain. AdMob can take up to 24 hours to crawl it. Check the status in AdMob > Apps > app-ads.txt.

## Re-check once the ad plugin and store setup are chosen

The policy describes the planned setup. It is **not** yet true of the current build: `docs/LAUNCH_PLAN.md` still says "no network code, no analytics and no ads". Before publishing, confirm each of these against the actual build:

- **Ad SDK and mediation.** The policy names only Google AdMob. If the Godot plugin adds mediation adapters (Meta, AppLovin, Unity Ads, etc.) or any other SDK such as Firebase Analytics or Crashlytics, add each network to section 3 and update the store data forms.
- **Data types.** Section 3's table follows Google's published disclosures (retrieved Sept 2026): [Android Play data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure) (IP address, product interactions, diagnostics, device/account identifiers) and the [iOS data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure) (IP address, crash logs, performance data, device ID, advertising data, product interactions). Re-read both for the SDK version you ship, and use them for the Play **Data safety** form and App Store **privacy nutrition labels**. Those forms will no longer be "no data collected".
- **"Settings > Privacy choices" button.** The policy and FAQ promise this entry point, which opens the UMP privacy options form. Make sure the in-game button exists and uses that label, or change the text here. UMP requires it when `privacyOptionsRequirementStatus` is REQUIRED. Showing it always is simplest.
- **Consent regions.** The policy says the consent message appears "where the law requires it" (EEA/UK/Switzerland, some US states). Confirm the UMP messages you configure in AdMob (GDPR, US state regulations) match.
- **ATT.** The policy says tracking permission is asked only if tracking is used, and that refusing never limits the game. If you ship without requesting ATT, you may remove that paragraph. The iOS app still needs the SKAdNetwork IDs and the Google SDK's privacy manifest.
- **Child-directed setting.** The policy says ad requests are not marked child-directed. Keep `tagForChildDirectedTreatment` and `tagForUnderAgeOfConsent` unset/false, set the AdMob app and the store age targeting to 13+, and don't opt into the Play Families program. If that changes, the policy must change too.
- **Ad-ID permission (Android).** The Google Mobile Ads SDK adds `com.google.android.gms.permission.AD_ID`. Declare it in Play Console's Advertising ID form.
- **Ad placement and pricing.** The policy and FAQ describe interstitials only between expeditions, never at launch, one optional rewarded ad, and Ad-Free at US$4.99. Update the text if any of that changes.
- **Restore Purchases.** The FAQ points to a Settings > Restore Purchases button. Apple expects one for non-consumables. Make sure it exists.
- **Game version in Settings.** The bug-report FAQ asks players for "the game version shown in Settings". The current Settings sheet (`scripts/ui/main.gd`) doesn't show a version, and `project.godot` has no `application/config/version`. Add both, or change that bullet.
- **Offline progress.** The FAQ's "half pace, up to 4 hours" comes from `data/balance.json` (`offline_efficiency` 0.5, `offline_cap_hours` 4.0). Some relics and research raise the cap. Update the FAQ if balance changes.
- Then set `{{EFFECTIVE_DATE}}` and update it whenever the policy changes.

This is a plain-language draft, not legal advice. If you sell in regions with specific requirements (e.g. a designated EU representative for GDPR Art. 27), consider a legal review.
