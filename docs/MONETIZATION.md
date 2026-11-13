# Ads and the Ad-Free purchase

Business model (owner, Sept 2026): free download, light ads, and a one-time
**Ad-Free** purchase at US$4.99.

## The rules

| Placement | Behaviour |
|---|---|
| Banners, ads at launch or resume | None |
| Between expeditions (interstitial) | After independence is saved, from the 2nd independence onward, at most one every 30 minutes (`interstitial_after_runs`, `interstitial_min_gap_seconds`). Never for Ad-Free owners. |
| "Consult the Almanac" (rewarded) | Optional button on the map: a 30-minute skip at full pace, every 4 hours (`ad_skip_seconds`, `ad_skip_cooldown_seconds`). Ad-Free owners claim it without watching. Paid once per cooldown, so a duplicated ad callback can't pay twice. |
| Royal Favor | Stays free. |
| No connection / no ad available | The game plays normally; the rewarded bonus says it's out of reach. |

**Ad-Free** is a non-consumable product with id `ad_free`:
- Its ownership is stored in `user://entitlements.cfg`, never in the save or in save codes.
- It survives independence and "Reset all progress".
- It is restored from the store with Restore Purchases.

## Code

- `scripts/core/platform.gd` (autoload `Platform`) is the only place game code touches ads, purchases or consent.
- `PlatformBackend` defines the interface. `DesktopBackend` simulates it for desktop play and tests: labelled test ads, and an instant purchase. Run with `-- ads=off` to simulate no fill, or `-- store=fail` to simulate a declined payment.
- `test/unit/test_platform.gd` covers the rewarded payout, purchase persistence and the Ad-Free rules.

## Native backends (added 10 Oct 2026)

`scripts/core/mobile_backend.gd` is the real backend on phones. `Platform` loads it only when the AdMob plugin's singleton exists, so desktop play and the tests never touch the native SDKs.

A phone build **without** the plugins falls back to the base `PlatformBackend`. That backend shows no ads, sells nothing, and hides Remove ads and Restore. It never falls back to the desktop stand-in.

### Plugins in the repo (pinned)

| Purpose | Plugin | Location |
|---|---|---|
| Ads and UMP consent, Android and iOS | Poing Studios AdMob 5.1.0 (Google Next-Gen ads SDK 1.4.0 on Android, GoogleMobileAds 13 on iOS) | `addons/admob/` (C# sources and samples removed), native parts in `addons/admob/android/bin/ads` and `addons/admob/ios/bin/ads` |
| Android billing | GodotGooglePlayBilling 3.3.0 (Play Billing 9.1.0) | `addons/GodotGooglePlayBilling/` |
| iOS StoreKit 2 | hrk4649 `godot_ios_plugin_iap` 0.4.0, singleton `IOSInAppPurchase` | `ios/plugins/ios-in-app-purchase/`, enabled in the iOS preset |

### What the backend does

- **Consent first.**
  - It requests UMP consent information at startup, and shows Google's consent form when the status is REQUIRED.
  - No ad is requested until the status is NOT_REQUIRED or OBTAINED.
  - Settings shows "Privacy choices" whenever UMP reports that privacy options are required.
- **Ad requests.**
  - They are marked not child-directed, with the maximum content rating T.
  - A rewarded ad and an interstitial are each preloaded, and reloaded after every show.
  - A failed load retries after 15 s, 30 s, 60 s, 120 s, then every 300 s.
- **Rewarded ad.** It pays only if the SDK's earned-reward callback fired.
- **Android purchase.**
  - It connects to Play Billing, queries the `ad_free` price, and queries owned purchases at startup and on Restore. The owned-purchases query is a definite answer, so a refund removes Ad-Free.
  - Completed purchases are acknowledged, because Play refunds unacknowledged ones after 3 days. They are never consumed.
  - Pending payments show a message instead of granting Ad-Free.
- **iOS purchase.**
  - It uses StoreKit 2. `transactionCurrentEntitlements` is the definite answer.
  - Restore calls `appStoreSync`, then re-reads the entitlements.

### Configuration at release time

All of these live in `project.godot`, in the `[idle_pioneer]` section:

- **Debug builds** always use Google's test ad units.
- **Release builds** read the real units from Project Settings, and show no ads if they're empty:
  - `idle_pioneer/ads/android_rewarded` and `idle_pioneer/ads/android_interstitial`
  - `idle_pioneer/ads/ios_rewarded` and `idle_pioneer/ads/ios_interstitial`
- **Builds for testers** set `idle_pioneer/ads/force_test_ads=true`. A release build then serves Google's test ads instead of real ones, so testers can't click a live ad (AdMob suspends accounts for that). Settings shows "test ads" next to the version. Set it back to `false` for the production build; `check_aab.py` warns while it's on.
- **`idle_pioneer/urls/privacy_policy`** is the page the "Privacy policy" button in Settings opens. The button is hidden while it's empty.
- **The AdMob app IDs** go in `admob/general/android/app_id` and `admob/general/ios/app_id` (Project Settings > AdMob). Until they're set, Google's sample app IDs are used, which are only valid with test ads.
- **The product ID is `ad_free`** in both Play Console and App Store Connect: a one-time, non-consumable product.

### Still to check on real devices

- The consent form appears in the EEA. Use UMP debug geography, or a VPN.
- Rewarded and interstitial test ads show and close, and the game pauses and mutes while they're up.
- A licence-tester (Play) or Sandbox (Apple) purchase grants Ad-Free, survives a reinstall through Restore, and is acknowledged. In Play Console, the order must not auto-refund after 3 days.
- A refund removes Ad-Free on the next launch.

### Store forms, now that the game has an ad SDK

- **Play:** Data safety, "Contains ads", and the advertising ID declaration.
- **Apple:** App Privacy. No tracking prompt is shown, so nothing is declared as "used for tracking".
- Fill in the placeholders in `docs/site/`.
