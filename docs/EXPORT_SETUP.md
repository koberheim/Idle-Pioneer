# Export setup: Android and iOS

This guide takes the project from the editor to a signed Android App Bundle (AAB) and an iOS build in TestFlight.

`export_presets.cfg` at the repo root already holds two presets, **Android** and **iOS**. The file is gitignored because the editor can write signing details into it, so keep a private backup.

Values in the presets that you must confirm before the first upload:

| Setting | Current value | Notes |
|---|---|---|
| Package name / bundle id | `com.idlepioneer.game` | **Placeholder.** Choose your own, e.g. `com.<yourname>.idlepioneer`. It can't be changed after the first upload to either store. |
| Version name / short version | `0.9.0` | Visible to players. |
| Version code / build number | `1` | Must increase with every upload. |
| Export paths | `build/android/IdlePioneer.aab`, `build/ios/IdlePioneer.ipa` | Add `build/` to `.gitignore`, or point these outside the repo. |

## 1. One-time editor setup

1. **Use the standard Godot 4.7.2 editor, not the .NET build.** The game has no C# scripts. The standard export templates are smaller and avoid a known 16 KB page-alignment problem in the .NET Android templates.
   - Download the standard Godot 4.7.2 editor from https://godotengine.org/download.
   - Open **Editor > Manage Export Templates** and click **Download and Install** for 4.7.2.
   - Optional: `project.godot` has a leftover `[dotnet]` section (`project/assembly_name="Idle Pioneer"`). The standard editor ignores it. You can delete those lines to tidy up.
2. **Install JDK 17.** Use Eclipse Temurin 17 (https://adoptium.net), then set **Editor Settings > Export > Android > Java SDK Path**.
3. **Install the Android SDK.** The easiest way is Android Studio, or the command-line tools with:
   ```
   sdkmanager "platform-tools" "build-tools;36.1.0" "platforms;android-36" "cmdline-tools;latest" "ndk;29.0.14206865"
   ```
   These are the versions Godot 4.7.2's Gradle template uses (`config.gradle`). Then set **Editor Settings > Export > Android > Android SDK Path**.
4. **Install the Android build template.** Open **Project > Install Android Build Template...**. This creates `android/`, which is already gitignored.
   - The AAB format needs this because the preset has **Use Gradle Build** turned on. Godot can't export an AAB without Gradle.
   - Reinstall the template whenever you upgrade Godot.

## 2. Android: create the upload keystore

Play App Signing keeps the real app signing key. You sign uploads with an **upload key** that you create once:

```
keytool -genkeypair -v -keystore idlepioneer-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

- `keytool` ships with JDK 17, in its `bin` folder.
- It asks for a password, then your name and organization.
- Store the `.jks` file **outside the repo**.
- Back it up offline together with its password. If you lose it you can request a reset through Play Console, but that takes days.

Fill in the keystore in **Project > Export > Android > Keystore**:

- **Release:** the path to `idlepioneer-upload.jks`
- **Release User:** `upload`
- **Release Password:** the password you chose

The editor saves these to `.godot/export_credentials.cfg`, which isn't committed. It doesn't save them to `export_presets.cfg`.

Leave **Debug** empty to use the editor's debug keystore for testing on your own device.

## 3. Android: export the AAB

1. **Project > Export > Android.** Check that the preset shows no red warnings. The icon files in `assets/icons/` must exist.
2. Click **Export Project**, clear **Export With Debug**, and save as `.aab`.
3. **Play Console > your app > Testing > Closed testing > Create release**, then upload the AAB and enroll in Play App Signing when prompted.

What the preset sets:

- **Target and minimum API:** target API **36**, which Play requires for new apps and updates from 31 Aug 2026. The minimum is API 24.
- **Architecture:** arm64-v8a only.
- **Permissions:** none are requested.
- **Display:** immersive mode is on.
- **Export filters:** they exclude `addons/gut`, `test`, `tools`, `docs`, `assets/art`, `*.md`, `run_tests.cmd` and `.gutconfig.json`. They include `data/*.json` and the font license `.txt` files.

**16 KB page-size check:** Google Play requires native libraries aligned for 16 KB memory pages on API 35+ devices. After the upload, open **App bundle explorer** in Play Console, where the 16 KB check should show as compliant. You can also run this locally on an APK built from the bundle:

```
zipalign -c -P 16 -v 4 app.apk
```

The standard 4.7 templates are 16 KB aligned.

Before each later upload, raise **Version > Code**.

## 4. iOS (needs a Mac)

What you need:

- A Mac with **Xcode 26**. Apple requires the iOS 26 SDK for App Store uploads from April 2026.
- An Apple Developer Program membership ($99/yr).
- The same standard Godot 4.7.2 editor and export templates on the Mac.

Steps:

1. Register the bundle id in the Apple Developer portal: **Certificates, IDs & Profiles > Identifiers**. Use the same id as the preset once you've chosen it.
2. In **Project > Export > iOS**, enter your **App Store Team ID**, the 10-character code from the Membership page.
3. The preset already sets:
   - iPhone only;
   - minimum iOS 15.0;
   - "Export Project Only" (it writes an Xcode project and doesn't build an .ipa);
   - the 1024 px icon `assets/icons/app_icon_1024.png`, which must be opaque;
   - the privacy manifest.

   Privacy manifest settings:

   | Setting | Value |
   |---|---|
   | Tracking | off |
   | Collected data | none |
   | File timestamp API | `C617.1` |
   | System boot time API | `35F9.1` |
   | Disk space API | `E174.1` |
   | User defaults API | `CA92.1` |

4. Click **Export Project** and open the generated `.xcodeproj` in Xcode.
5. In Xcode, open the target's **Signing & Capabilities** tab. Turn on **Automatically manage signing** and pick your team.
6. Set the destination to **Any iOS Device (arm64)**, then choose **Product > Archive**.
7. In **Organizer**, choose **Distribute App > App Store Connect > Upload**.
8. In App Store Connect, create the app with the same bundle id. When the build finishes processing, add testers in **TestFlight**.
9. Under App Privacy, answer **Data Not Collected**.

Before each later upload, raise **Version** (the build number).

## 5. Before every store upload

- Raise the version code (Android) and build number (iOS).
- Run the tests: `run_tests.cmd`.
- Install the release build on a real phone. Check:
  - that the back button closes open sheets;
  - offline catch-up after a long break;
  - that a save survives a force-quit.
