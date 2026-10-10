# Store readiness: Google Play and the App Store

Audit of 9 Oct 2026, on `main` after 316b126. It supersedes the open lists in `FINAL_AUDIT.md` and `LAUNCH_PLAN.md`. Store rules were re-checked online the same day; items marked *(verify)* could not be confirmed from a primary source.

## 1. Verdict

**The game and its store plumbing are built. What's left is your accounts, the real IDs, and a test on real devices.**

The game itself is ready:
- Content, balance, art, audio, saves, offline play and lifecycle handling are finished.
- 76 of 76 tests pass.
- Every Must and Should item in `FINAL_AUDIT.md` was fixed in 8ee79fc and the commits after it.

On 10 Oct 2026 the Android toolchain and the ad/purchase plugins were installed, and the real backend was written. A debug AAB now builds with AdMob, consent and Play Billing inside (target SDK 36, `AD_ID` declared). It hasn't run on a phone yet. Everything else that's left is accounts, forms and uploads, which only the owner can do.

## 2. Audit results

### Fixed in this pass
| # | Was | Now |
|---|---|---|
| 1 | **Blocker:** a phone build had no native backend, so it fell back to the desktop stand-in. Tapping "Remove ads · $4.99" granted Ad-Free for free, and Consult and the between-expedition break showed "test ad" cards. | Mobile builds without the plugins use a storeless backend. It shows no ads and sells nothing, and the Remove ads and Restore buttons are hidden (`platform.gd`, `platform_backend.gd`, `main.gd`). |
| 2 | A store error reported as "not owned" would take away a purchase the player already owned. | Errors never revoke Ad-Free. Only a definite answer from the store does, such as a refund. |
| 3 | The game rendered at a constant 60 fps, which is hard on batteries. | **Map effects: Light** now also caps the game at 30 fps. |
| 4 | The version was 0.9.0. | 1.0.0 in `project.godot` and both presets. |
| 5 | The 61 KB feature graphic shipped inside the app. | Excluded, along with `store/`. |
| 6 | The iOS export compliance question was asked on every upload. | `ITSAppUsesNonExemptEncryption = NO` is in the iOS plist. |
| 7 | `export_presets.cfg` was gitignored, so a cloud Mac build couldn't see it. | Now committed. It holds no secrets: Godot 4 keeps keystore passwords in `.godot/export_credentials.cfg`. |

Tests were added for items 1 and 2.

### Checked and fine
- **Lifecycle:**
  - The game saves on pause, focus-out and quit.
  - Offline catch-up runs on resume.
  - Back closes the topmost sheet first, and asks "press again to leave" at the root.
- **Content:** no cheat keys, no dev menus, no `print()` spam and no TODOs in shipped code. The export filters keep `tools/`, `test/`, `docs/`, `addons/gut` and `store/` out of the app.
- **Size:** about 17 MB of assets (music is 14 MB), so roughly a 30 MB download.
- **Data:** no network code, links or user-generated content. The finger-drawn signature stays in the local save.
- **Settings:** music, sound, tips, map effects, Large text, number style, save code copy/restore, Credits & Licenses, Remove ads, Restore purchases, version and reset are all present. "Privacy choices" appears once the ads backend reports that it's required.
- **Android 16 large screens:** Android 16 ignores orientation locks on tablets, but games are exempt. The preset declares the app category as Game.
- **Store package** (`store/`): 8 captioned screenshots at Play 1080×1920, iPhone 6.9″ and 6.5″, plus the icons, the feature graphic and every listing field (`store/COPY.md`).

### Still open
| # | Item | Who | Blocks |
|---|---|---|---|
| O1 | ~~Native ads and billing backends.~~ **Done:** `scripts/core/mobile_backend.gd`; see `MONETIZATION.md`. Still needs a run on a real phone: consent form, test ads, a licence-tester purchase, Restore. | Owner (device) and Claude (fixes) | Closed test |
| O2 | ~~Android toolchain.~~ **Done:** Temurin JDK 17.0.20.1 in `E:\Android\jdk-17`, the SDK in `E:\Android\Sdk` (platform 36, build-tools 36.1.0, NDK 29.0.14206865), and the standard 4.7.2 export templates. Editor Settings point at all three. **C: has only about 4 GB free,** so export with `GRADLE_USER_HOME=E:\Android\gradle` (see `EXPORT_SETUP.md`). | — | — |
| O8 | **Real AdMob IDs.** The app IDs go in Project Settings > AdMob, and the rewarded and interstitial unit IDs in `idle_pioneer/ads/*`. Release builds show no ads until they're set. | Owner creates them in AdMob; Claude fills them in | Release with ads |
| O9 | **Upload keystore.** Create it with the `keytool` command in section 4B, then enter it in the Android preset's Keystore > Release. | Owner | Release AAB |
| O3 | **Package ID.** `com.idlepioneer.game` is a placeholder and becomes permanent at the first upload. Suggest `com.<yourname>.idlepioneer`. | Owner | First upload |
| O4 | **Developer name.** The credits say "the Idle Pioneer team", and the site has placeholders (`{{DEVELOPER_NAME}}`, `{{CONTACT_EMAIL}}`, `{{WEBSITE}}`, `{{DEVELOPER_COUNTRY}}`, `{{EFFECTIVE_DATE}}`, `{{ADMOB_PUBLISHER_ID}}`). | Owner supplies the values; Claude fills them in | Privacy policy URL |
| O5 | **Host `docs/site`** with `app-ads.txt` at the domain root. See `docs/site/README.md`. | Owner | Both listings, AdMob |
| O6 | **Real-device check.** At least one older Android phone and one iPhone. | Owner and testers | Production |
| O7 | **Licence watch.** ElevenLabs Music only covers games under US$500k lifetime revenue. | Owner | Nothing today |

## 3. Native backends (O1): the plugins in use

These are installed and pinned for Godot 4.7.2:

| Need | Plugin | Version |
|---|---|---|
| Ads and UMP consent, Android and iOS | Poing Studios `godot-admob-plugin` (AssetLib "AdMob"). Install the native parts from Project > Tools > AdMob Manager. | 5.1.0 (tested with 4.7.2) |
| Android billing | `godot-sdk-integrations/godot-google-play-billing` (Play Billing 9.1) | 3.3.0 |
| iOS StoreKit 2 | `hrk4649/godot_ios_plugin_iap` (singleton `IOSInAppPurchase`) | latest; tested with 4.7 and Xcode 26.5 |

All three are in the repo and enabled. Note that the AdMob plugin's own skill and docs files describe an older API; `mobile_backend.gd` follows the plugin's actual source.

## 4. Step by step: the Google Play listing

**A. Accounts (owner, about 1–3 days of verification)**
1. Create a Google Play Console personal developer account (US$25) and complete identity verification.
2. Create an AdMob account (free).
   - Add the app: Android, "not yet published".
   - Create one **Rewarded** unit ("almanac") and one **Interstitial** unit ("between_expeditions").
   - Note the App ID and the publisher ID.
   - Under Privacy & messaging, create the **GDPR** and **US states** messages.
3. Payments profile: Play Console > Setup > Payments profile. This is needed to sell Ad-Free.

**B. Build (Claude with the owner)**
1. ~~Toolchain~~ (done, O2).
2. Set the final package ID in the Android preset. (O3)
3. Create the upload keystore and back it up offline:
   ```
   keytool -genkeypair -v -keystore idlepioneer-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```
4. ~~Plugins and native backends~~ (done, O1). Put the real AdMob IDs in Project Settings. (O8)
5. Export the AAB. Check that the version code goes up with every upload.

**C. Create the app (Play Console > Create app)**
1. Name `Idle Pioneer: Colonial Tycoon`, default language English (US), type **Game**, **Free**.
2. Accept the declarations.

**D. App content (Policy > App content). Answers are in `store/COPY.md`.**
1. **Privacy policy:** the hosted `privacy.html` URL. (O4, O5)
2. **Ads:** Yes, the app contains ads.
3. **App access:** all functionality is available without special access.
4. **Content rating:** IARC questionnaire, category Game.
   - Alcohol and tobacco: references only.
   - Violence, gambling and user-generated content: No.
   - Digital purchases: Yes.
   - Expect E10+ / PEGI 7–12.
5. **Target audience:** 13–15, 16–17 and 18+ only. Never include under-13 age groups; that would bring in the Families policy.
6. **Data safety:** the data is collected and shared through the AdMob SDK and encrypted in transit:
   - approximate location (IP)
   - app interactions
   - diagnostics
   - device and advertising IDs

   No account and no deletion request apply.
7. **Advertising ID:** Yes, for advertising and analytics.
8. **Government, financial features, health, news:** No or None.

**E. Monetize > Products > In-app products**
1. Create `ad_free`, a one-time product called "Ad-Free", priced at US$4.99.
2. Activate it. The ID must match `Platform.AD_FREE`.

**F. Store listing (Grow > Store presence > Main store listing)**
1. **Short and full descriptions:** from `store/COPY.md`.
2. **Graphics:**
   - App icon: `store/icon_512.png`
   - Feature graphic: `store/feature_graphic_1024x500.png`
   - Phone screenshots: `store/google_play_phone/01–08`
3. **Category and contact:** category Games › Simulation, the tags from COPY.md, and the contact email and website. The website must be the domain that serves `app-ads.txt`.

**G. Closed test (required for new personal accounts)**
1. Go to Testing > Closed testing > Create track.
2. Upload the AAB and enroll in **Play App Signing**.
3. In App bundle explorer, check that the **16 KB page size** shows as compliant and that target SDK is 36.
4. Add 12 or more testers (a Google Group is easiest). They opt in from the link, and then **all 12 must stay opted in for 14 days in a row**.
5. Use AdMob test ads in this build, or the owner's device registered as an AdMob test device. Test the purchase with Play **licence testers**: Setup > License testing.

**H. Production**
1. Dashboard > Apply for production, and answer the closed-test questionnaire.
2. Once approved, create a production release:
   - choose the countries;
   - remember the first release can't be a percentage rollout;
   - consider a few countries first.
3. Submit for review, which usually takes 1–7 days.
4. After launch, link the app in AdMob, switch to the real ad unit IDs (a new build), and check that AdMob shows `app-ads.txt` as verified.

## 5. Step by step: the App Store listing

**A. Accounts (owner)**
1. Join the Apple Developer Program (US$99/yr). Enrol as an individual unless you have a company.
2. Sign the **Paid Apps Agreement**, and complete tax and banking in App Store Connect > Business. Ad-Free can't be sold until this is done.
3. **EU Digital Services Act:** declare yourself a **trader**, since the app earns money. Your address, phone and email will be shown on EU listings.
4. In AdMob, add the iOS app and create its own Rewarded and Interstitial units.

**B. Build without a Mac (Codemagic is the recommended route)**
1. Certificates, IDs & Profiles > Identifiers: register the bundle ID. Use the same ID as Android.
2. App Store Connect > Users and Access > Integrations: create an API key with the App Manager role. Keep the `.p8`, the Key ID and the Issuer ID.
3. Set the Team ID in the iOS preset. Use the AdMob Manager to commit the iOS plugin files. Then Claude adds:
   - the SKAdNetwork IDs and the `GADApplicationIdentifier`;
   - `codemagic.yaml`, which downloads Godot 4.7.2 for macOS and its templates, runs `--export-release "iOS"`, then `xcode-project build-ipa` and `app-store-connect publish`.
4. Codemagic's free personal tier has 500 macOS minutes a month, which is plenty. It handles signing through the API key, so you never need a Mac.
5. The build goes to **TestFlight**. Install it on a real iPhone and test the ads, the purchase (with a Sandbox tester) and Restore.

**C. Create the app (App Store Connect > Apps > +)**
1. Platform iOS, name `Idle Pioneer`, primary language English (U.S.), the bundle ID, and an SKU such as `idlepioneer`.

**D. App information**
1. **Subtitle:** `Colonial Trade Tycoon`.
2. **Category:** Games, with subcategories Simulation and Strategy.
3. **Age rating:** the 2026 questionnaire.
   - Alcohol, tobacco or drug references: Infrequent/Mild.
   - Everything else: None.
   - In-app purchases and ads: Yes.
   - Expect 9+, or possibly 13+.
4. **Content rights:** no third-party content you don't hold rights to.

**E. App Privacy**
1. Privacy policy URL.
2. Data types (from Google's iOS disclosure page for the SDK version that ships):
   - Coarse Location
   - Device ID
   - Product Interaction
   - Advertising Data
   - Crash, Performance and Other Diagnostic data
3. All of it is **not linked** to the user, and the purposes are Third-Party Advertising and Analytics.
4. "Used for tracking": **No**, as long as no ATT prompt is shown.

**F. Monetization > In-App Purchases**
1. Create a **Non-Consumable** with product ID `ad_free` and reference name "Ad-Free", price tier US$4.99.
2. Add a display name and description, and a review screenshot of the Settings screen.
3. Attach it to version 1.0. The first IAP must be submitted together with a build.

**G. Version 1.0 page**
1. **Screenshots:** `store/iphone_6.9/01–08` (1290×2796). *(verify)* Apple's help page now lists the 6.1″ "Dynamic Island" size as the required iPhone set. If App Store Connect asks for it, run `build_store.py` with a 1179×2556 size. Claude can add it.
2. **Promotional text, description, keywords and support URL:** from `store/COPY.md`. The support URL is `support.html`.
3. **Build:** pick the TestFlight build.
4. **App Review information:**
   - no sign-in needed;
   - notes: "Single-player idle game. Ad-Free (non-consumable) is in Settings, and Restore purchases is next to it. Ads appear only between expeditions from the second independence onward, and as an optional rewarded 'Consult the Almanac'."
5. Submit for review, which usually takes 1–2 days.

## 6. Order of work

1. **Now (owner):**
   - Choose the package ID and developer name.
   - Approve the toolchain installs.
   - Open the Play Console, AdMob and Apple accounts (they verify in parallel).
2. **Claude:**
   - ~~Install the toolchain and plugins, and write the native backends~~ (done).
   - Fill in the site placeholders and the package ID once chosen.
   - Produce the first signed AAB once the keystore exists.
3. **Owner:**
   - Host the site.
   - Upload to closed testing.
   - Start the 14-day clock with 12+ testers.
4. **In parallel:** the Codemagic iOS build, then TestFlight.
5. **After 14 days:** Play production. Submit the App Store build once TestFlight checks out.

**Estimate:** about 3 weeks to both stores, mostly waiting on the closed-test clock.
