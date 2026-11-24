# Google Cloud and signing setup

What Filbert's sign-in and sync need outside the code (m3-design §6.7, §11). Done once per developer setup; everything here is free (Google Cloud needs no billing account for these APIs).

## Google Cloud project

1. At [console.cloud.google.com](https://console.cloud.google.com), create a project named **Filbert**.
2. **APIs & Services → Library**: enable **Google Drive API** and **Photos Picker API**.
3. **Google Auth Platform**:
   - **Branding**: app name Filbert, a support email.
   - **Audience**: External, status **Testing**, with each tester's Google account as a **test user**.
   - **Data access**: add `https://www.googleapis.com/auth/drive.appdata`. T12 adds `photospicker.mediaitems.readonly`.
4. **Google Auth Platform → Clients**, three clients:
   - **Web application**: its id is Android's `serverClientId`.
   - **Android**: package `com.example.filbert` and the SHA-1 of each signing key that runs the app. The debug key's: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` (on this Mac: `A1:AC:3D:CB:E8:ED:A5:24:1E:D7:6C:ED:14:5F:36:A9:31:19:46:7C`). A release key needs its own entry.
   - **iOS**, used by the Mac app: bundle ID `com.example.filbert`.
5. Put the web and iOS ids in `lib/core/auth/google_client_ids.dart`, and the iOS id reversed (`com.googleusercontent.apps.<number>-<hash>`) as `GOOGLE_REVERSED_CLIENT_ID` in `macos/Runner/Configs/AppInfo.xcconfig`. The ids are public identifiers that ship inside the app; these client types have no secret.

**Testing mode**: Google ends a test user's authorization after about 7 days, so sign-in is asked for again weekly. Up to 100 test users.

## Mac signing

Google Sign-In on the Mac keeps its tokens in the keychain, which needs keychain sharing, which needs the app signed by an Apple team. A free personal team is enough to run it locally.

1. **Xcode → Settings → Accounts**: add your Apple ID; it lists "*Name* (Personal Team)".
2. Copy `macos/Runner/Configs/Signing.example.xcconfig` to `Signing.xcconfig` (untracked) and set `DEVELOPMENT_TEAM` to your team id. Find it by picking the team under **Runner → Signing & Capabilities** in `macos/Runner.xcworkspace` and reading `DEVELOPMENT_TEAM` from `git diff macos/Runner.xcodeproj/project.pbxproj`; then discard that diff, since the id lives only in `Signing.xcconfig`.
3. Create the provisioning profile once: build in Xcode (⌘B), or `xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -allowProvisioningUpdates build`. Until then `flutter build macos` fails with "No profiles for 'com.example.filbert' were found".
4. Without `Signing.xcconfig` the Mac app builds unsigned (`CODE_SIGNING_ALLOWED = NO` in `AppInfo.xcconfig`), as on CI: it runs outside the App Sandbox, so its data isn't in the app container, and sign-in fails.

## Scopes and publishing

- `drive.appdata` is **non-sensitive** (Google lists it as recommended): publishing needs only basic brand verification, no security review ([Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)).
- `photospicker.mediaitems.readonly` (T12): Google requires the OAuth verification review for apps using the Photos APIs ([Photos scopes](https://developers.google.com/photos/overview/authorization)); T12 records its classification from the console.
- At the first public release: choose the real app id, create new Android and iOS clients for it (plus the release key's SHA-1), and move the consent screen to **In production**.
