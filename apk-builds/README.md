# APK builds

Debug builds of AluVis for Android, stored with Git LFS (APKs exceed
GitHub's 100 MB regular-file limit).

## Current file

| File | What it is |
|------|------------|
| `aluvis-debug.apk` | Debug build — for testing on a phone/tablet. **Not** a signed release build |

## Install on an Android device

1. Copy the `.apk` to the device (USB, Bluetooth, file share, …).
2. Open it on the device with a file manager.
3. Allow *“Install unknown apps”* when Android asks.
4. Open **AluVis** from the app drawer.

## Notes

- A debug APK is large (~150 MB) and slower than a release build.
  It is meant for testing, not distribution.
- For a PC (Windows/Linux), an APK does **not** work — build a
  desktop target instead (see `docs/WINDOWS_BUILD.md` for Windows).
- To make a fresh APK: `flutter build apk --debug` (or `--release`
  for a signed, optimized build), then copy
  `build/app/outputs/flutter-apk/app-debug.apk` here, replacing the
  old file.
