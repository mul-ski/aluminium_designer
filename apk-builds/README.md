# APK builds

Debug builds of AluVis for Android, stored with Git LFS (APKs exceed
GitHub's 100 MB regular-file limit).

## Current files

| File | What it is |
|------|------------|
| `aluvis-release.apk` | ✅ **Use this one.** Release build (v1.0.0+2) — small (~52 MB), fast, no debug banner. Single file, installs on any Android device (arm64 + 32-bit ARM) |
| `aluvis-debug.apk` | Debug build — for developers only (large, slow, shows debug banner). Kept for reference |

## Install on an Android device

1. Copy the `.apk` to the device (USB, Bluetooth, file share, …).
2. Open it on the device with a file manager.
3. Allow *“Install unknown apps”* when Android asks.
4. Open **AluVis** from the app drawer.

## Notes

- The release APK is signed with the default debug key (no Play Store
  signing set up yet) — your phone will ask you to allow *“Install
  unknown apps”* once. That is the 1-click flow: tap the file, allow,
  install, open.
- To make a fresh APK: `flutter build apk --release`, then copy
  `build/app/outputs/flutter-apk/app-release.apk` here (replacing the
  old file) and bump `version:` in `pubspec.yaml` so devices
  recognize it as newer.
