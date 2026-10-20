# iPhone Continuity Bridge for macOS & Android

`Continuity Bridge` is a companion experience bringing iPhone-style macOS Continuity and iPhone Mirroring features to Android and Mac.

## Features

- 📱 **iPhone Mirroring**: Realistic iPhone mockup frame with live stream surface, notch/dynamic island, status bar, and native AppKit receiver window.
- 🔗 **Direct USB Connection**: Connect directly via USB cable (ADB loopback) without any Wi-Fi router or external network dependency.
- 📲 **AirDrop & File Transfer**: Instant local file sharing between phone and Mac.
- 📋 **Universal Clipboard**: Copy on phone, paste on Mac automatically with real-time auto-sync.
- 💬 **Continuity Messaging**: Quick iMessage-style messaging thread across paired devices.
- ⚙️ **AirDrop Discovery**: Automatic network discovery and 1-click pairing requests.

---

## macOS First-Run Guide ("Apple could not verify...")

When opening `Droid Bridge.app` for the first time on macOS after downloading from GitHub, macOS Gatekeeper may show:
> *"Apple could not verify 'Droid Bridge' is free of malware that may harm your Mac..."*

This occurs because open-source releases built on GitHub Actions use ad-hoc local code signing without a paid $99/year Apple Developer notarization certificate.

### 🚀 Easy 1-Click Installer Script
In the downloaded DMG disk image or release folder, double-click or run `./install.sh`:
```bash
./install.sh
```
This automatically moves `Droid Bridge.app` to `/Applications` and removes the web download quarantine attribute.

---

### 🛠️ Manual 1-Click Fixes:

#### Option 1: System Settings (Recommended by Apple)
1. Open **System Settings** on your Mac.
2. Go to **Privacy & Security**.
3. Scroll down to the **Security** section.
4. Click **Open Anyway** next to *Droid Bridge*.
5. Enter your Mac administrator password and confirm **Open**.

#### Option 2: Finder Control-Click
1. Open **Finder** and navigate to `Droid Bridge.app` in `/Applications`.
2. **Control-click** (or Right-click) the app icon and select **Open** from the context menu.
3. Click **Open** in the confirmation dialog.

#### Option 3: Terminal Command
Run this command in Terminal to clear the download quarantine attribute:
```bash
xattr -cr /Applications/"Droid Bridge.app"
```

---

## Local Development

```bash
flutter pub get
flutter run -d macos
flutter run -d android
```

## macOS Local Signing

For personal local builds:
- Edit [Signing.xcconfig](macos/Runner/Configs/Signing.xcconfig) to set your Personal Team ID if using Xcode.
- Ad-hoc signing (`CODE_SIGN_IDENTITY = -`) is configured by default for local development.

## Automated Builds

GitHub Actions automatically builds release artifacts on Git commits to `main`:
- Dynamic semantic versioning (`v1.0.x`) and build numbers.
- Android release APK.
- macOS release DMG installer and `.app` ZIP archive with executable permissions and installer script.
