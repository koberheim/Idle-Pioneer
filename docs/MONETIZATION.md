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

## Adding the native backends (next step, needs a working Android build)

1. Choose and pin plugins that match the exact Godot version:
   - Ads and consent: the Godot SDK Integrations AdMob plugin (includes Google UMP) or an equivalent.
   - Billing: Google Play Billing (Android) and StoreKit (iOS).

   Confirm that each is compatible with 16 KB page sizes and the current SDKs in a real exported build.
2. Write `AndroidBackend` / `IosBackend` extending `PlatformBackend`:
   - `start()`: request consent through UMP, initialise ads, load one interstitial and one rewarded ad, and query purchases (acknowledging any unacknowledged ones).
   - `ads_allowed()`: true only once UMP allows ad requests. Ad requests are not child-directed.
   - `buy()` / `restore()`: handle pending purchases (no grant until the purchase completes), cancellations, refunds and revocations. Report every outcome through `purchase_result`.
   - `privacy_options_required()` / `show_privacy_options()`: map to UMP's privacy options entry point.
3. Select the backend in `Platform._make_backend()` by checking for the plugin singleton.
4. Use test ad unit ids and store sandbox or licence testers until release. Real ad units go in export-time configuration, not in the repo.
5. Update the store forms, since the game now has an ad SDK:
   - Play: Data safety, "Contains ads", and the ad ID declaration.
   - Apple: App Privacy, and the tracking prompt only if tracking is enabled.

   Also fill in the placeholders in `docs/site/`.
