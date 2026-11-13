# Store readiness: Google Play and the App Store

Audit of 13 Nov 2026. It replaces the audit of 9 Oct and the open lists in `FINAL_AUDIT.md` and `LAUNCH_PLAN.md`. Store rules were re-checked online the same day; section 7 lists what was checked and where.

Some words used below:

- **App ID:** the app's permanent internal name, `com.koberheim.idlepioneer`. Google calls it the "package name", Apple the "bundle ID".
- **Bundle (AAB):** the single `.aab` file you upload to Google Play.
- **Upload key:** a small file plus a password that proves an upload comes from you.
- **Version code:** a counter (1, 2, 3…) Play uses to tell uploads apart. Players never see it.
- **Closed test:** a private release on Google Play that only people you invite can install.

## 1. Where things stand

**The game is finished and a release build passes every automated check. Nothing has been uploaded anywhere, and nothing has run on a real phone yet.** What's left is almost all yours: accounts, a few IDs, and people to test.

- 80 of 80 tests pass.
- A practice release bundle builds in about 4 minutes (`tools\store\build_android.cmd -Trial`): release mode, target SDK 36, 16 KB aligned, 51 MB.
- Google Play is the priority. The earliest possible public release is about **4 weeks** after the Play account is verified, because Google makes new personal accounts run a 14-day closed test first.

## 2. Audit results

### Fixed in this pass (13 Nov)

| # | Found | Now |
|---|---|---|
| 1 | **No privacy policy link inside the game.** Both stores expect one in the app as well as on the listing. | Settings has a **Privacy policy** button that opens `https://koberheim.github.io/privacy.html` (`idle_pioneer/urls/privacy_policy`). It is hidden while that setting is empty. |
| 2 | **The licenses of the three store plugins weren't shipped.** Their MIT license asks for the notice to travel with the app. | Credits & Licenses lists all three, and the texts are in both export presets. A test checks every listed license file exists. |
| 3 | **No way to build the release bundle** short of clicking through the editor, and no check of the result. | `tools\store\make_keystore.cmd`, `build_android.cmd` and `check_aab.py` (see `EXPORT_SETUP.md`). |
| 4 | **Testers would have seen live ads.** A release build could only use real ad units, and AdMob suspends accounts when friends click live ads. | `idle_pioneer/ads/force_test_ads` makes a release build serve Google's test ads. Settings shows "test ads" beside the version, and the checker warns while it's on. |
| 5 | **Saves were lost on a new phone or a reinstall** unless the player had copied a save code. | Android device backup is on. The privacy policy and support page describe it. |
| 6 | Site placeholders for the website and country. | Filled: `https://koberheim.github.io`, United States. `tools\store\fill_site.py` fills the rest and `publish_site.cmd` publishes. |
| 7 | **No iOS build recipe.** | `codemagic.yaml` builds on a rented Mac and uploads to TestFlight. Not run yet: it needs the Apple account. |
| 8 | **Apple's one required iPhone screenshot size was missing** (6.1″, 1179×2556). | `store/iphone_6.1/` and `store/raw/iphone_6.1/`. |
| 9 | Stale docs: `EXPORT_SETUP.md` said the app requests no permissions, that iOS needs your own Mac, and that App Privacy is "Data Not Collected". | Rewritten. |
| 10 | The export script would hang after finishing, waiting on Gradle's background process. | Fixed in `build_android.ps1`. |
| 11 | **Nine symbols (✓ ✕ ★ → ▲ ▼ ∞ and two heavier marks) weren't in the game's fonts,** so every phone would have drawn them with a font of its own. On Windows the tick on the Congress screen came out as a purple emoji, and it was in the store screenshots. | `assets/fonts/IdlePioneerSymbols.ttf` (made by `tools/gen_symbols_font.py`) is the fallback for both game fonts. A test checks every special character in the game's text has a bundled font. All store screenshots were re-rendered. |

### Checked and fine

- **Android build:** target SDK 36, minimum Android 7, arm64 only, both native libraries aligned for 16 KB pages, not debuggable, Play Billing library 9.1 (accepted until Aug 2028), Google's current ads SDK with the consent form.
- **Size:** 51 MB bundle. Players download roughly 50 MB: 25 MB engine, 8 MB Google libraries, 18 MB game (14 MB of that is music).
- **Permissions:** the game asks for none itself and the player sees no permission prompt. The ad and billing libraries add internet access, the advertising ID and billing (full list in `EXPORT_SETUP.md`).
- **Contents:** no tests, tools, docs or store art in the bundle.
- **Ads and purchase code:** consent is requested before any ad; nothing is requested without it. Failures never remove Ad-Free. Purchases are acknowledged. Covered by tests, but **not yet seen on a phone**.
- **Lifecycle:** saves on pause, focus-out and quit; offline catch-up on resume; Back closes the top sheet and asks before leaving.
- **Store package** (`store/`): 8 captioned screenshots per size, all the right dimensions and without transparency; 512 px and 1024 px icons; feature graphic; every listing field in `store/COPY.md`.
- **iOS preset:** iPhone only, iOS 15+, StoreKit plugin on, encryption question pre-answered. The AdMob plugin adds its own app ID key and ad-network list at export.

### Still open

| # | Item | Who | Needed for |
|---|---|---|---|
| O1 | **Support email address.** Then `python tools/store/fill_site.py --email …`. | You, then Claude | Privacy policy, both listings |
| O2 | **Google Play Console account** (US$25, identity check). | You | Everything on Play |
| O3 | **AdMob account**, the app, two ad units and the consent messages. Send Claude the four IDs. | You, then Claude | Ads; `app-ads.txt` |
| O4 | **Upload key:** run `tools\store\make_keystore.cmd` once and back it up. | You | The first upload |
| O5 | **Website:** create the public repo `koberheim.github.io`, then run `tools\store\publish_site.cmd`. | You | Privacy policy URL |
| O6 | **Push to GitHub.** `main` is ahead of GitHub by the October store work plus this pass. | You (say the word and Claude does it) | iOS cloud build; backup |
| O7 | **A run on a real Android phone:** consent form, test ads, a test purchase, Restore. | You | Closed test |
| O8 | **12 testers** with Google accounts, opted in for 14 days. | You | Production on Play |
| O9 | **Apple Developer account** (US$99 a year) and Codemagic. | You | Everything on iOS |
| O10 | **Your address becomes public.** Because the game earns money, Google and Apple show the developer's name, address, phone and email on listings in the EU (the "trader" rule). Decide what address to use before you fill in the account forms. | You | Both accounts |
| O11 | **US state age laws** (Texas, Utah, Louisiana). Google and Apple say it's the developer's job to decide how these apply. See section 6. | You | Nothing blocks on it |
| O12 | **License watch.** ElevenLabs Music only covers games under US$500k lifetime revenue. | You | Nothing today |

## 3. Plugins in use

| Need | Plugin | Version |
|---|---|---|
| Ads and consent, Android and iOS | Poing Studios `godot-admob-plugin` | 5.1.0 |
| Android purchase | `godot-google-play-billing` (Play Billing 9.1) | 3.3.0 |
| iOS purchase (StoreKit 2) | `hrk4649/godot_ios_plugin_iap` | 0.4.0 |

All three are committed, with their native parts, and pinned for Godot 4.7.2.

## 4. Google Play, step by step

### A. Day 1: accounts and IDs (you, 1–2 hours, then Google's checks)

1. **Create the support email address.** Tell Claude; the site gets filled in.
2. **Open a Google Play Console account** at play.google.com/console.
   - Choose **Personal**. Pay the US$25 one-time fee.
   - Complete identity verification (ID document). Google may also ask you to confirm you own an Android phone through the Play Console app. This usually takes 1–3 days.
   - Read O10 first: the address you enter is shown publicly in the EU once the app earns money.
3. **Open an AdMob account** at admob.google.com (free), with the same Google account.
   - **Apps > Add app:** Android, "not listed on a store yet", name `Idle Pioneer`.
   - **Ad units > Add ad unit:** one **Rewarded** named `almanac`, one **Interstitial** named `between_expeditions`.
   - **Privacy & messaging:** create and publish the **European regulations** message and the **US state regulations** message for this app.
   - Send Claude these four values. None is a secret:
     - publisher ID (`pub-` and 16 digits, under Settings > Account information)
     - app ID (`ca-app-pub-…~…`)
     - the two ad unit IDs (`ca-app-pub-…/…`)
4. **Create the upload key:** run `tools\store\make_keystore.cmd`, choose a password, and back up `E:\Android\keys\idlepioneer-upload.jks` and the password.
5. **Create the website repo:** on github.com, New repository, name `koberheim.github.io`, **Public**.

### B. Day 1: the first real build (Claude, 15 minutes once A is done)

1. Fill in the site (`fill_site.py`) and publish it (`publish_site.cmd`). Check `https://koberheim.github.io/privacy.html` opens.
2. Put the AdMob app ID and unit IDs in `project.godot`, with `force_test_ads=true` for the testers' build.
3. Run `tools\store\build_android.cmd`. You type the key password. The result is `build\android\IdlePioneer.aab`, and the checker must say "Ready to upload".

### C. Create the app (Play Console > Create app)

1. Name `Idle Pioneer: Colonial Tycoon`, default language English (United States), **Game**, **Free**.
2. Accept the declarations.

### D. App content (Policy > App content). Answers are in `store/COPY.md`.

1. **Privacy policy:** `https://koberheim.github.io/privacy.html`
2. **Ads:** Yes, the app contains ads.
3. **App access:** all functionality is available without special access.
4. **Content rating:** start the questionnaire, category Game.
   - Alcohol and tobacco: references only.
   - Violence, gambling, user-generated content: No.
   - Digital purchases: Yes.
   - Expect Everyone 10+ / PEGI 7–12.
5. **Target audience:** 13–15, 16–17 and 18+. Never tick an under-13 group: that brings in the Families policy and its ad restrictions.
6. **Data safety:** data is collected and shared through the ads SDK, encrypted in transit:
   - approximate location (from the IP address)
   - app interactions
   - diagnostics
   - device and advertising IDs

   No account exists, so no account-deletion URL applies.
7. **Advertising ID:** Yes, for advertising and analytics.
8. **Government, financial features, health, news:** No.

### E. Store listing (Grow > Store presence > Main store listing)

1. **Short and full description:** from `store/COPY.md`.
2. **Graphics:**
   - App icon: `store/icon_512.png`
   - Feature graphic: `store/feature_graphic_1024x500.png`
   - Phone screenshots: `store/google_play_phone/01–08`
3. **Store settings:** category Games > Simulation, the tags from `COPY.md`, your support email, and website `https://koberheim.github.io` (it must be exactly this, for `app-ads.txt`).

### F. Internal test: your own phone first (same day, no review)

1. **Testing > Internal testing > Create new release.** Upload the bundle. Accept **Play App Signing** when asked.
2. Add your own Google account as a tester, open the opt-in link on your phone and install from Play.
3. In **App bundle explorer**, confirm the bundle shows 16 KB support and target SDK 36.
4. **Set up the purchase.** Play only lets you create products after a bundle is uploaded.
   - **Setup > Payments profile:** create it (name, address, bank account for payouts).
   - **Monetize > Products > In-app products > Create:** product ID `ad_free` (exactly), name "Ad-Free", US$4.99, then **Activate**.
   - **Setup > License testing:** add your Google account, so your test purchases cost nothing.
5. **Check on the phone (O7):**
   - A new game starts; Settings shows "Version 1.0.0 · test ads".
   - Play to "Consult the Almanac": a test ad plays, the game pauses and goes quiet, and the reward arrives.
   - Settings > **Remove ads** shows the price; buy it with the license-test card; ads stop.
   - Reinstall, tap **Restore purchases**: Ad-Free returns.
   - **Privacy policy** opens the page.
   - Back button, a long break (offline catch-up), and a force-quit (save survives).
6. Report anything odd to Claude; fixes go out as a new bundle (`build_android.cmd -Bump`).

### G. Closed test: the 14-day clock

1. **Testing > Closed testing > Create track.** Promote the tested release, or upload the newest bundle.
2. **Testers:** create an email list (or a Google Group) with at least **12** people. Ask 15–20: all 12 must stay opted in **for 14 days in a row**, and anyone who leaves and rejoins starts again.
3. Send the release for review. When it's approved, send testers the opt-in link.
4. Ask testers to actually play and to send feedback. Google asks what testers did and said when you apply for production, and can send you back for more testing if they barely used the app.
5. Use the 14 days for fixes and for the iOS build.

### H. Production

1. **Dashboard > Apply for production.** Answer the questions about the closed test, the app and its readiness. Review usually takes 7 days or less.
2. **Build the production bundle:** set `force_test_ads=false`, then `tools\store\build_android.cmd -Bump`. The checker must show no test-ads warning.
3. **Production > Create new release:** upload, add the release notes from `COPY.md`, choose countries, and submit. The first review usually takes a few days.
4. **After it's live:**
   - In AdMob, link the app to its Play listing (Apps > App settings > App stores).
   - Check AdMob > Apps > app-ads.txt shows "Authorized". Ads are limited until it does.
   - Real ads can take a day or two to start filling.

## 5. The App Store, step by step

Start this during the Play closed test.

### A. Accounts (you)

1. **Apple Developer Program:** developer.apple.com/programs, US$99 a year, enrol as an individual. Approval takes a day or two.
2. **App Store Connect > Business:** sign the **Paid Apps Agreement** and complete tax and banking. Ad-Free can't be sold until this is done.
3. **Trader status** (EU Digital Services Act): declare yourself a trader, since the app earns money. See O10.
4. **AdMob:** add the iOS app (same account) and create its own Rewarded and Interstitial units. Send Claude the iOS app ID and unit IDs.

### B. The cloud build (you set up, Claude runs and fixes)

1. **Push the project to GitHub** (O6).
2. **developer.apple.com > Certificates, IDs & Profiles > Identifiers:** register the App ID `com.koberheim.idlepioneer`. Tick **In-App Purchase**.
3. **App Store Connect > Users and Access > Integrations > App Store Connect API:** create a key with the **App Manager** role. Download the `.p8` file (one chance only) and note the Key ID and Issuer ID.
4. **codemagic.io:** sign up with GitHub and add the Idle-Pioneer repository. Then, as the header of `codemagic.yaml` describes:
   - add the API key under Integrations, named `idle-pioneer`;
   - generate the distribution certificate and the App Store provisioning profile under Code signing identities;
   - add `APPLE_TEAM_ID` (10 characters, from developer.apple.com > Membership) to a variable group named `apple`.
5. **Create the app record first** (step C), then **Start new build > iOS to TestFlight**.
6. The first run will probably need a fix or two. Send Claude the failing step's log. The likeliest places:
   - the Godot download address;
   - signing (profile and certificate names);
   - the ad SDK being fetched by Xcode (the plugin adds it as a Swift package).
7. The build appears under **TestFlight**. Install it on an iPhone with the TestFlight app and repeat the checks in 4F, using a **Sandbox** tester account for the purchase.

### C. Create the app (App Store Connect > Apps > +)

1. Platform iOS, name `Idle Pioneer`, primary language English (U.S.), the App ID, SKU `idlepioneer`.

### D. App information

1. **Subtitle:** `Colonial Trade Tycoon`
2. **Category:** Games, subcategories Simulation and Strategy.
3. **Age rating questionnaire:**
   - Alcohol, tobacco or drug references: Infrequent/Mild.
   - Everything else: None.
   - In-app purchases and advertising: Yes.
   - Expect 9+ or 13+.
4. **Content rights:** no third-party content you lack rights to.

### E. App Privacy

1. **Privacy policy URL:** `https://koberheim.github.io/privacy.html`
2. **Data collected** (by the ads SDK; full notes in `store/COPY.md`):
   - Coarse Location
   - Device ID
   - Product Interaction and Advertising Data
   - Crash, Performance and Other Diagnostic Data
3. All of it **not linked** to the user; purposes Third-Party Advertising and Analytics.
4. **Used for tracking: No.** The game shows no tracking prompt.

### F. The purchase (Monetization > In-App Purchases)

1. Create a **Non-Consumable**: product ID `ad_free`, reference name "Ad-Free", US$4.99.
2. Add the display name, a description, and a review screenshot of the Settings screen.
3. Attach it to version 1.0. The first purchase product must be submitted together with a build.

### G. The version 1.0 page

1. **Screenshots:**
   - 6.1″ slot (the required one): `store/iphone_6.1/01–08`
   - 6.9″ slot: `store/iphone_6.9/01–08`
   - `store/iphone_6.5/` is only needed if App Store Connect asks for it.
2. **Promotional text, description, keywords:** from `store/COPY.md`. **Support URL:** `https://koberheim.github.io/support.html`.
3. **Build:** pick the TestFlight build.
4. **App Review information:** no sign-in needed. Notes: "Single-player idle game. Ad-Free (non-consumable) is in Settings, with Restore purchases beside it. Ads appear only between expeditions from the second independence onward, and as an optional rewarded 'Consult the Almanac'."
5. Submit for review, usually 1–2 days.

## 6. US state age laws (O11)

Texas, Utah and Louisiana now have laws that make app stores check users' ages and pass an age range to apps. Texas's is in force after an appeals court lifted the block on it in May 2026.

- **Google** offers a "Play Age Signals" tool (still in beta) and says it does not require developers to use it. It also says it's each developer's responsibility to work out how the laws apply to their app. Texas's law may ask for an age rating on in-app products; Play Console has a field for it.
- **Apple** says developers are responsible for their own age restrictions "where legally required", and points to its Declared Age Range tool.
- **Neither store blocks a submission over this.** The game doesn't use either tool today, and neither has a ready-made Godot plugin.
- **What already helps:** no accounts, no chat, no user content, ads marked as not directed at children, and the stores handle parental approval of downloads and purchases themselves.
- **Your call:** this is a legal question, not a technical one. If you want certainty, ask a lawyer whether a single-player game with ads and one purchase has duties under these laws. If the answer is yes, Claude can add the age check.

## 7. Timeline

| When | What |
|---|---|
| Day 1 | Section 4A: email, Play and AdMob accounts, upload key, website repo. Claude fills in the IDs and builds. |
| Days 2–4 | Play verifies your identity. Then 4C–4F: create the app, fill in the forms, internal test on your phone. |
| Days 4–6 | Closed test reviewed; testers opt in. **The 14-day clock starts.** |
| Days 6–20 | Closed test. In parallel: Apple account, Codemagic, TestFlight (section 5). |
| Day 20 | Apply for production on Play (up to 7 days). |
| Days 24–30 | Production release on Play. Submit the App Store version once TestFlight checks out. |

## 8. Rules checked on 13 Nov 2026

| Rule | Status | Source |
|---|---|---|
| New apps must target Android 16 (API 36) | In force since 31 Aug 2026. The preset targets 36. | [Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878) |
| New personal accounts: closed test, 12 testers, 14 days in a row | In force. Review of the production application "usually seven days or less". | [Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Play Billing library version | Version 9 is accepted until 31 Aug 2028. The game uses 9.1. | [Android Developers](https://developer.android.com/google/play/billing/deprecation-faq) |
| Apple uploads must be built with Xcode 26 | In force since 28 Apr 2026. `codemagic.yaml` uses the latest Xcode. | [Apple](https://developer.apple.com/news/upcoming-requirements/) |
| Apple minimum iOS target 13 | In force since 9 Sep 2026. The preset targets 15. | [Apple](https://developer.apple.com/news/upcoming-requirements/) |
| iPhone screenshots | One set is required, at 1179×2556 or 1206×2622. Larger sizes are optional. | [App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) |
| Age laws | See section 6. | [Play Console Help](https://support.google.com/googleplay/android-developer/answer/16569691), [Apple](https://developer.apple.com/support/age-assurance/) |

The Apple screenshot table was read through a summary of the page, so confirm the required slot in App Store Connect when you upload.
