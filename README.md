# Droid Bridge

`Droid Bridge` is a Flutter companion app for `android` and `macos`. It is
designed for your own devices on the same local network and currently ships a
practical first milestone:

- manual pairing with IP address + pairing code
- clipboard text sharing
- quick note/message sending
- direct file transfer
- native platform bridge hooks for Android and macOS
- Android screen-capture permission flow scaffold
- macOS native receiver window scaffold

## What is realistic

This project can give Android a useful macOS companion experience, but it
cannot become Apple's private Continuity stack or true iPhone Mirroring.

What works well in a custom app:

- local pairing
- file sharing
- clipboard sync
- notification relay with Android native work
- screen mirroring with Android `MediaProjection` and a low-latency stream

What is blocked by Apple platform boundaries:

- private Continuity APIs
- system-level iPhone Mirroring parity
- making Android appear as a native Apple mobile device to macOS

## Current app flow

1. Launch the app on macOS and Android while both devices are on the same Wi-Fi network.
2. Read the IP address and pairing code from one device.
3. Enter that IP address and code on the other device and press `Connect`.
4. Use `Send clipboard`, `Send note`, or `Send file`.
5. Received files are saved inside the app documents folder under `received`.
6. On Android, use `Request capture permission` to prepare the native mirroring sender.
7. On macOS, use `Open receiver window` to open the native receiver shell.

## Local run

```bash
flutter pub get
flutter run -d macos
flutter run -d android
```

## macOS signing for personal use

This repository includes [Signing.xcconfig](/Users/nomi/Documents/New project/droid_bridge/macos/Runner/Configs/Signing.xcconfig)
for local macOS builds.

- If ad-hoc local signing is enough, leave `PERSONAL_TEAM_ID` blank.
- If Xcode asks for a team, open the macOS target in Xcode and choose your free `Personal Team`.
- GitHub Actions builds the macOS app without code signing, because free personal signing identities cannot be used safely in CI.
- Without a paid Apple Developer account, you should not expect notarization or friction-free distribution on other Macs.

## GitHub Actions

Two workflows are included:

- `ci.yml` runs `flutter analyze` and `flutter test`
- `release.yml` builds release artifacts for Android and macOS on Git tags that start with `v`

The release workflow uploads:

- Android release APK
- macOS release `.app` zipped as an artifact

## Next native milestone

The next serious feature is turning the mirroring scaffold into a live stream:

- Android foreground service
- `MediaProjection` capture pipeline
- socket or WebRTC transport
- macOS player surface
- input forwarding if you want remote control later
