# Releasing SmartBroker (Android)

## 1. Create the release key (once)

Run in a terminal (any folder **outside** the repository, e.g. `C:\Users\<you>\keys`):

```bash
keytool -genkey -v -keystore smartbroker-release.jks -alias smartbroker \
  -keyalg RSA -keysize 2048 -validity 10000
```

`keytool` ships with Android Studio's JDK (`<Android Studio>\jbr\bin\keytool.exe`).

**Keep two offline copies of the `.jks` file and its passwords** (e.g. a USB stick and a
password manager). If the key is lost, installed copies of the app can never be updated —
users would have to uninstall (and lose their data) to install a new build.

## 2. Point the build at it

Copy `android/key.properties.example` to `android/key.properties` and fill it in.
`key.properties`, `*.jks` and `*.keystore` are gitignored — never commit them.

Without `key.properties`, release builds are signed with the debug key so
`flutter run --release` keeps working. Never share such a build.

## 3. Build

```bash
flutter clean
flutter pub get
flutter test
flutter build apk --release          # sideloading: build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release    # Play Store: build/app/outputs/bundle/release/app-release.aab
```

Bump `version:` in `pubspec.yaml` first (`1.0.1+3` → name `1.0.1`, build number `3`).
The build number must increase with every release.

Check the signature:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

It must show the SmartBroker certificate, not `CN=Android Debug`.

## 4. Smoke-test the release build on a phone

Release builds are minified (R8). Before handing a build out, check on a real device:

- [ ] App opens; launcher label is "SmartBroker"
- [ ] Settings → Developer Tools → Simulate Call shows the overlay
- [ ] A reminder notification fires and opens the reminder
- [ ] AI Review works with a real key
- [ ] Call detection logs a real call

If something only breaks in release, add a `-keep` rule to `android/app/proguard-rules.pro`.

## Switching a phone from a debug build to the release build

A debug-signed install cannot be updated by a release-signed APK (different
certificate): Android requires an uninstall, which **deletes the app's data**.
Before the first release install, back up the data (Settings → Backup, once
available) or keep using debug builds on that phone until then.

## Backups

`android:allowBackup` is on with explicit rules (`res/xml/backup_rules.xml`,
`res/xml/data_extraction_rules.xml`): the database and settings go to the user's
Google backup; API keys (secure storage) and overlay drafts don't. After restoring
on a new phone the AI key has to be entered again.
