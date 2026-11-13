# Export setup: Android and iOS

How the project becomes a signed Android App Bundle (the `.aab` file Google Play takes) and an iPhone build in TestFlight. For the store listings themselves, see `STORE_READINESS.md`.

`export_presets.cfg` at the repo root holds two presets, **Android** and **iOS**. It is committed and holds no secrets: Godot keeps keystore paths and passwords in `.godot/export_credentials.cfg`, which is not committed.

| Setting | Value | Notes |
|---|---|---|
| App ID (Android "package name", iOS "bundle ID") | `com.koberheim.idlepioneer` | The app's permanent internal name. It can't change after the first upload to either store. |
| Version shown to players | `1.0.0` | `project.godot` and both presets. |
| Android version code / iOS build number | `1` | A counter the stores use to tell uploads apart. It must go up with every upload. |
| Outputs | `build/android/IdlePioneer.aab`, `build/ios/` | `build/` is gitignored. |

## 1. Android: the short version

Everything is installed on this PC (10 Oct 2026): JDK 17 in `E:\Android\jdk-17`, the Android SDK in `E:\Android\Sdk`, the standard Godot 4.7.2 editor at `E:\Godot\Godot_v4.7.2-stable_win64.exe` and its export templates.

1. **Once:** create the upload key.
   ```
   tools\store\make_keystore.cmd
   ```
   It asks you to choose a password and writes `E:\Android\keys\idlepioneer-upload.jks`, outside the project. Back up that file and the password (password manager plus a USB stick). Google keeps the real signing key (Play App Signing); this *upload key* only proves an upload comes from you. If it's ever lost, Play Console can reset it, which takes a few days.
2. **Every release:**
   ```
   tools\store\build_android.cmd -Bump
   ```
   It raises the version code, asks for the key password (never saved), exports `build\android\IdlePioneer.aab` and runs the checker. Leave out `-Bump` only for the very first upload.
3. **Practice run without the key:** `tools\store\build_android.cmd -Trial` builds `IdlePioneer-trial.aab`, signed with Godot's debug key. It proves the build works; Play won't accept it.

`tools\store\check_aab.py` reads the finished bundle and fails the build if it is debuggable, unsigned or signed with the debug key, not aligned for 16 KB memory pages, still carrying Google's sample AdMob app ID, missing the privacy link, or carrying dev files. It warns when the build uses test ads or has no ad unit IDs.

### What the Android preset sets

- **Target and minimum API:** target API **36** (required by Play for new apps since 31 Aug 2026), minimum API 24 (Android 7).
- **Architecture:** arm64-v8a only.
- **Display:** portrait, immersive mode.
- **Backup:** Android's own device backup is on (`user_data_backup/allow`), so a save returns after a reinstall or on a new phone.
- **Export filters:** `addons/gut`, `test`, `tools`, `docs`, `store`, `assets/art`, `*.md`, `*.cmd` are left out. `data/*.json`, the font licenses and the three plugin licenses are included.
- **Permissions:** the game asks for none itself. The ad and billing libraries add these to the final app, none of which shows the player a prompt:

  | Permission | Added by | Why |
  |---|---|---|
  | `INTERNET`, `ACCESS_NETWORK_STATE` | Ads SDK | Fetch ads |
  | `com.google.android.gms.permission.AD_ID` | Ads SDK | Advertising ID (declared in Play Console) |
  | `READ_BASIC_PHONE_STATE` | Ads SDK | Network type, for ad delivery |
  | `com.android.vending.BILLING` | Play Billing | The Ad-Free purchase |
  | `WAKE_LOCK`, `FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED` | Android WorkManager (inside the ads SDK) | Background housekeeping |

### Setting up another machine

1. **Standard Godot 4.7.2 editor, not the .NET build**, plus **Editor > Manage Export Templates > Download and Install**.
2. **JDK 17** (Eclipse Temurin, https://adoptium.net). Set **Editor Settings > Export > Android > Java SDK Path**.
3. **Android SDK:**
   ```
   sdkmanager "platform-tools" "build-tools;36.1.0" "platforms;android-36" "cmdline-tools;latest" "ndk;29.0.14206865"
   ```
   Set **Editor Settings > Export > Android > Android SDK Path**.
4. Point the scripts at your paths with the environment variables `GODOT`, `JAVA_HOME`, `GRADLE_USER_HOME` and `IDLE_PIONEER_KEYSTORE`. The build script reinstalls the Android build template (`android/`, gitignored) on every run, so it always matches the editor version.

Exporting from the editor also works (**Project > Export > Android > Export Project**, with **Export With Debug** off). In that case enter the key under **Keystore > Release** (user `upload`); the editor saves it to `.godot/export_credentials.cfg`, and the script then uses it without asking.

## 2. iOS: built in the cloud, no Mac needed

Apple only accepts apps built with Xcode 26 on a Mac. `codemagic.yaml` at the repo root does that on a rented Mac at codemagic.io (the free tier is enough):

1. downloads Godot 4.7.2 for macOS and its templates,
2. writes your Team ID and a fresh build number into the iOS preset,
3. exports the Xcode project (`--export-release "iOS"`),
4. signs it, builds the `.ipa` and uploads it to TestFlight.

The one-time Codemagic setup is in `STORE_READINESS.md`, section 5B. The workflow hasn't been run yet, because it needs the Apple Developer account first.

What the iOS preset sets:

- iPhone only, minimum iOS 15.0, "Export Project Only" (Godot writes the Xcode project; Codemagic builds it).
- The 1024 px icon `assets/icons/app_icon_1024.png` (opaque, as Apple requires).
- `ITSAppUsesNonExemptEncryption = NO`, so the export-compliance question isn't asked on every upload.
- The StoreKit plugin (`plugins/IOSInAppPurchase`).
- The AdMob plugin adds `GADApplicationIdentifier` (from Project Settings > AdMob) and Google's `SKAdNetworkItems` list by itself at export time.
- Privacy manifest: tracking off; required-reason APIs: file timestamp `C617.1`, system boot time `35F9.1`, disk space `E174.1`, user defaults `CA92.1`. The AdMob SDK ships its own manifest.

**App Privacy in App Store Connect is not "Data Not Collected":** the ad SDK collects data. Use the answers in `store/COPY.md`.

## 3. Before every store upload

- Run the tests: `run_tests.cmd` (80 tests).
- Build with `-Bump` (Android) or start the Codemagic workflow (iOS).
- Check `idle_pioneer/ads/force_test_ads` in `project.godot`: `true` for a build that goes to testers, `false` for production. Settings shows "test ads" next to the version when it's on.
- Install the build on a real phone. Check that the back button closes open sheets, that offline catch-up works after a long break, and that a save survives a force-quit.
