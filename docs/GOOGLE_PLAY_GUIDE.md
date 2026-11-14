# Getting Idle Pioneer onto Google Play: step by step

Written 13 Nov 2026. Follow it top to bottom and tick things off. Each step says who does it: **You** or **Claude** (ask Claude in this project and it does that step). Deeper detail and every form answer are in `STORE_READINESS.md` and `store/COPY.md`.

**Words used here**
- **Play Console:** Google's website where you manage your app (play.google.com/console).
- **Bundle (AAB):** the one `.aab` file you upload. Claude builds it.
- **Upload key:** a small file plus a password that proves an upload is really from you. If you lose it you can reset it, but it takes days.
- **Closed test:** a private release only invited people can install. New personal accounts must run one before going public.
- **AdMob:** Google's ad service. It gives you the IDs the game needs to show ads.

**How long it takes:** about 4 weeks from the day your Play account is verified. Most of that is Google's required 14-day closed test.

---

## Phase 1: Set up (Day 1)

### 1. Create the support email  *(You)*
Make a dedicated address for the game (not your personal one). It becomes public on the privacy policy and the store listing.
- Tell Claude the address. Claude fills it into the website pages.

### 2. Create the Google Play Console account  *(You)*
1. Go to play.google.com/console and sign in with the Google account you want to own the game.
2. Choose **Personal** account type. Pay the US$25 one-time fee.
3. Complete identity verification (a photo ID). Google may also ask you to confirm on an Android phone. This takes 1–3 days. You can continue with steps 3–6 while you wait.
4. **Think about your address first.** Because the game earns money, Google shows your name, address, phone and email publicly on listings in the EU. Use an address you are happy to make public.

### 3. Create the AdMob account and IDs  *(You)*
1. Go to admob.google.com and sign in with the same Google account. It is free.
2. **Apps > Add app:** platform Android, "No" to already on a store, name `Idle Pioneer`.
3. **Ad units > Add ad unit:**
   - one **Rewarded**, named `almanac`
   - one **Interstitial**, named `between_expeditions`
4. **Privacy & messaging:** create and publish the **European regulations** message and the **US state regulations** message for this app. (Without these, players in Europe won't see the consent form.)
5. Write down four values and send them to Claude. None are secret:
   - your **publisher ID** (`pub-` followed by 16 digits; Settings > Account information)
   - the **app ID** (looks like `ca-app-pub-…~…`)
   - the two **ad unit IDs** (look like `ca-app-pub-…/…`)

### 4. Create your upload key  *(You)*
1. In the project folder, double-click `tools\store\make_keystore.cmd`.
2. It asks you to choose a password, then your name and country. Nothing shows while you type the password.
3. It saves `E:\Android\keys\idlepioneer-upload.jks`, outside the project on purpose.
4. **Back up that file and the password** in two places (a password manager and a USB stick). Every future update needs them.

### 5. Create the website  *(You, then Claude)*
Google requires a public privacy policy page. Claude has already written it.
1. On github.com click **New repository**. Name it exactly `koberheim.github.io`, set it **Public**, and tick nothing else. Create it.
2. Once you've done steps 1 and 3, tell Claude. Claude fills in the email and publisher ID and runs `tools\store\publish_site.cmd`.
3. Check `https://koberheim.github.io/privacy.html` opens in your browser.

### 6. Claude builds the first real bundle  *(Claude)*
Claude puts your AdMob IDs into the project, turns on test ads for the testers' build, and runs `tools\store\build_android.cmd`. It asks you to type your key password. The result is `build\android\IdlePioneer.aab`, and its checker must say **"Ready to upload"**.

---

## Phase 2: Create the app in Play Console (once your account is verified)

### 7. Create the app  *(You)*
Play Console > **Create app**:
- Name: `Idle Pioneer: Colonial Tycoon`
- Default language: English (United States)
- App or game: **Game**
- Free or paid: **Free**
- Tick the declarations and create it.

### 8. Fill in "App content"  *(You)*
Left menu > **Policy and programs > App content**. Do each item. The answers:

| Item | Answer |
|---|---|
| Privacy policy | `https://koberheim.github.io/privacy.html` |
| Ads | Yes, the app contains ads |
| App access | All functionality is available without special access |
| Content rating | Start the questionnaire, category **Game**. Alcohol and tobacco: references only (rum and tobacco are trade goods). Violence, gambling, user-generated content: No. Digital purchases: Yes. Expect Everyone 10+ |
| Target audience | Tick **13–15, 16–17, 18+** only. **Never tick any under-13 group** (it brings in strict rules for children's apps) |
| Data safety | Yes, data is collected and shared through the ads software. Tick: approximate location, app interactions, crash logs and diagnostics, device or other IDs. Encrypted in transit: Yes. All of it is required for ads to work. No account exists, so no account-deletion link |
| Advertising ID | Yes, used for advertising and analytics |
| Government, financial, health, news apps | No to all |

### 9. Fill in the store listing  *(You)*
**Grow > Store presence > Main store listing.** Copy the text from `store/COPY.md` (the Google Play section).
- **App name, short description, full description:** from `COPY.md`.
- **App icon:** `store/icon_512.png`
- **Feature graphic:** `store/feature_graphic_1024x500.png`
- **Phone screenshots:** all eight files in `store/google_play_phone/`
- **Category:** Games > Simulation
- **Contact email:** your new support address
- **Website:** exactly `https://koberheim.github.io`

---

## Phase 3: Test on your own phone (same day, no review wait)

### 10. Upload to internal testing  *(You)*
1. **Testing > Internal testing > Create new release.**
2. Accept **Play App Signing** when asked.
3. Upload `build\android\IdlePioneer.aab`.
4. Add your own Google account under **Testers**, save, and roll out.
5. Open the opt-in link on your phone and install the game from Google Play.

### 11. Set up the Ad-Free purchase  *(You)*
Google only lets you do this after a bundle has been uploaded.
1. **Setup > Payments profile:** create it (name, address, bank account for payouts).
2. **Monetize > Products > In-app products > Create product:**
   - Product ID: `ad_free` (exactly, lowercase)
   - Name: `Ad-Free`
   - Price: US$4.99, then **Activate**
3. **Setup > License testing:** add your own Google account, so your test purchases cost nothing.

### 12. Check it on your phone  *(You, then tell Claude what you saw)*
Play through these. Report anything odd and Claude fixes it with a new build.
- [ ] A new game starts. Settings shows **Version 1.0.0 · test ads**.
- [ ] If you're in Europe (or use a VPN set there), the privacy consent form appears at first launch.
- [ ] **Consult the Almanac** plays a test ad. The game pauses and goes quiet during it, and the reward arrives afterwards.
- [ ] Settings > **Remove ads** shows the price. Buy it with your license-test account: ads stop and the button says "Ad-Free: thank you!".
- [ ] Uninstall, reinstall, tap **Restore purchases**: Ad-Free comes back.
- [ ] Settings > **Privacy policy** opens the page.
- [ ] The Back button closes open sheets.
- [ ] Close the game, wait a while, reopen: offline earnings arrive.
- [ ] Force-quit the game: progress is still there.

---

## Phase 4: The 14-day closed test

### 13. Gather 12+ testers  *(You)*
Google requires **at least 12 testers who stay signed up for 14 days in a row**. If anyone leaves and rejoins, their count restarts. Ask 15–20 friends or family with Google accounts so a few dropouts don't matter. Easiest: put their emails in one Google Group.

### 14. Start the closed test  *(You)*
1. **Testing > Closed testing > Create track.**
2. Create a release with the same bundle (or a newer one), and add your testers' email list.
3. Submit for review (usually under a day or two). When approved, send testers the opt-in link.
4. Ask them to actually play for the two weeks and send you feedback. Google asks what testers did and said when you apply for production, and can send you back for more testing if they barely used it.

During the 14 days, Claude fixes bugs. Each new upload needs a higher version code: Claude runs `build_android.cmd -Bump`.

---

## Phase 5: Go public

### 15. Apply for production  *(You)*
After 14 days: **Dashboard > Apply for production.** Answer the three sections (about your closed test, about the game, about readiness). Include a few lines of real tester feedback. Review usually takes 7 days or less.

### 16. Build the production bundle  *(Claude)*
Claude switches **test ads off**, runs `build_android.cmd -Bump`, and confirms the checker shows no test-ads warning. This is the build real players get.

### 17. Release  *(You)*
1. **Production > Create new release**, upload the production bundle.
2. Paste the release notes from `store/COPY.md` ("What's New").
3. Choose countries (everywhere is fine; the first release can't be a gradual rollout).
4. **Send for review.** First reviews usually take a few days.

### 18. After it's live  *(You)*
1. In AdMob: **Apps > App settings > App store details**, link the app to its Google Play listing.
2. In AdMob: **Apps > app-ads.txt** should show your site as authorized. This can take up to a day. Ads fill poorly until it does.
3. Real ads may take a day or two to start appearing.

---

## If you don't have an Android phone

You can still publish, but three things normally need a real Android device, and each has a workaround.

| What needs a device | Workaround |
|---|---|
| **Account verification (step 2).** Google may ask you to confirm your identity with the Play Console app on an Android phone. | Borrow a friend's or family member's phone for about 10 minutes. This is the one step where an emulator may not be accepted, so don't rely on one. |
| **Checking the game (steps 10-12).** | Use the **Android emulator** on your PC (below). It runs the Google Play version of Android, so you can sign in, install from internal testing, see test ads and test the purchase. |
| **The 12 closed testers (step 13).** Each tester installs from Google Play on their own Android phone. | They bring their own devices, so choose friends and family who use Android. iPhone-only people can't count. A Chromebook also works. |

**Setting up the emulator (once, about 30 minutes):**
1. Install **Android Studio** (free, developer.android.com/studio). Your SDK is already on `E:\Android\Sdk`, so point it there.
2. **Device Manager > Create device:** pick a Pixel phone and a system image labelled **"Google Play"** (not "Google APIs"). Use Android 15 or 16, and the x86_64 image.
3. Start it, open the Play Store inside it, and sign in with your **license-testing** account (step 11).
4. Open the internal-testing opt-in link inside the emulator and install the game.
5. Your PC needs virtualization turned on (Windows "Windows Hypervisor Platform" feature, and on some machines a BIOS setting). Android Studio tells you if it's missing.

**What the emulator can't tell you:** how the game feels on a real touchscreen, battery use, and the Europe consent form unless you set the emulator's region there. Before going public, get at least one real phone to try it for an evening, even if borrowed. A used budget Android phone costs about US$60-100 if you want your own.

Claude can't run the emulator from here, so you'll do the step 12 checks yourself and report what you saw.

---

## If something goes wrong

- **Play rejects the bundle:** copy the exact error message to Claude.
- **Test ads don't show:** check you're on a build with test ads on, and that you've waited a few minutes after first launch.
- **Purchase button doesn't show a price:** the `ad_free` product must be activated, and you must install the game from Play (not by copying the file to your phone).
- **Lost the upload key:** Play Console > Setup > App signing > request an upload key reset (takes a few days).
- **Testers keep dropping out:** the clock restarts for them only. Add more testers rather than waiting.

## Not covered here

The App Store (iPhone) version is a separate process, covered in `STORE_READINESS.md` section 5. Start it during the closed test.
