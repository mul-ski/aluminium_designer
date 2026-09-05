# AluVis on Windows — setup, build, and data transfer

This guide takes you from a fresh Windows PC to a working AluVis app,
including your existing projects. Follow it top to bottom; each step
depends on the previous one.

> You cannot run the Android `.apk` on Windows. A Windows PC needs its
> own build (an `.exe`). That is what this guide produces.

---

## 1. What you need (install once)

| # | Item | Where to get it | Notes |
|---|------|-----------------|-------|
| 1 | Windows 10 or 11, 64-bit | — | — |
| 2 | Git for Windows | https://git-scm.com/download/win | Accept all defaults during install |
| 3 | Flutter SDK (stable channel) | https://docs.flutter.dev/get-started/install/windows | Unzip to `C:\flutter` (no spaces in the path). Then add `C:\flutter\bin` to your PATH (see step 2) |
| 4 | Visual Studio 2022 Community (free) | https://visualstudio.microsoft.com | During install, tick the **"Desktop development with C++"** workload. This is mandatory — without it the build fails |
| 5 | Developer Mode | Windows Settings → Privacy & security → For developers → turn **Developer Mode ON** | Required by Flutter on Windows |

---

## 2. Check the installation

Open **PowerShell** (or CMD) and run:

```bat
flutter --version
flutter config --enable-windows-desktop
flutter doctor
```

What you want to see:

- `flutter --version` prints a stable version (e.g. `3.44.x`).
- `flutter doctor` shows a check mark `[✓]` next to **"Visual Studio"** and **"Connected device (Windows)"**.
- If `flutter doctor` complains about the Visual Studio workload or
  about Windows desktop being disabled, fix that before continuing —
  the build in step 4 will fail otherwise.

---

## 3. Get the AluVis code

In PowerShell:

```bat
cd %USERPROFILE%\Documents
git clone https://github.com/mul-ski/aluminium_designer
cd aluminium_designer
flutter pub get
```

Later, to update to the newest version at any time:

```bat
cd %USERPROFILE%\Documents\aluminium_designer
git pull
flutter pub get
```

Then repeat step 4 to rebuild.

---

## 4. Build the app

In PowerShell, inside the `aluminium_designer` folder:

```bat
flutter build windows --release
```

This takes a few minutes the first time. When it finishes you will see:

```text
✓ Built build\windows\x64\runner\Release\aluminium_designer.exe
```

> Use `--release` (not `--debug`) for daily use: it is faster and
> smaller. Debug builds are for developers only.

---

## 5. Run the app

**Option A — run it in place** (simplest, recommended):

Double-click:

```text
Documents\aluminium_designer\build\windows\x64\runner\Release\aluminium_designer.exe
```

**Option B — move it somewhere nicer** (e.g. Desktop):

Copy the **entire `Release` folder** — not just the `.exe`. The exe
needs the DLLs and the `data` folder sitting next to it or it will
not start.

**Option C — from a USB stick** (another PC without internet/Git):

1. On the PC where you built it, copy the whole `Release` folder
   onto the USB stick.
2. On the target PC, copy the folder off the stick (e.g. to Desktop).
3. Double-click `aluminium_designer.exe` inside it.
4. If Windows SmartScreen warns that the app is from an unknown
   publisher: click *More info* → *Run anyway*. (The exe is
   unsigned — that warning is normal for a self-built app, not a
   sign of a problem.)
5. If the exe fails to start at all on the target PC, install the
   **Microsoft Visual C++ Redistributable (x64)** from Microsoft's
   site and try again.

---

## 6. First launch — what to expect

- The app opens on your projects list (empty on a fresh PC — normal).
- Open or create a construction, go to the **General** tab, open the
  **Fabricant** dropdown: you will see **Maghreb Extrusion (ME)**
  (Série 14600 / 14800 / 14700) and **Sepalumic** (Série 4200).
  These are seeded automatically on first launch — no setup needed.
- If a manufacturer entry ever looks wrong or outdated, just restart
  the app: it re-checks the built-in catalog on every launch and
  repairs itself. Your own created manufacturers and systems are
  never touched by this.

---

## 7. Bring your existing projects from Linux

Your Linux projects live in `~/Documents/aluvis/` (files like
`projects/*.json` plus `catalog.json`). The format is identical on
Windows, so you can copy them over:

**On the Linux machine** (copy to USB):

```bash
cp -r ~/Documents/aluvis /media/$USER/<your-usb-stick>/
```

(Replace `<your-usb-stick>` with the stick's actual mount name. Run
`ls /media/$USER/` to see it.)

**On the Windows PC** (before the first AluVis launch if possible):

1. Make sure AluVis is **closed**.
2. Copy the `aluvis` folder from the USB stick to:
   ```text
   C:\Users\<YourName>\Documents\aluvis\
   ```
   so that it contains `catalog.json`, `.catalog_seeded`, and a
   `projects` folder — exactly like on Linux.
3. Start AluVis. Your projects are there.

If you copy the files *after* the first launch, it still works:
restart the app once and it will merge everything (missing built-in
systems are added, your projects are read as-is).

> Never copy these files while AluVis is running on either machine —
> close the app first on both ends, then copy.

---

## 8. Troubleshooting

| Problem | Cause / fix |
|---------|-------------|
| `flutter build windows` says Visual Studio is missing / no Windows device | The C++ workload isn't installed, or Windows desktop isn't enabled. Re-run the Visual Studio installer → Modify → tick **Desktop development with C++**. Then `flutter config --enable-windows-desktop` and `flutter doctor` again |
| Build fails with CMake / ninja errors | Usually the VS workload. If it persists, delete the `build/` folder inside `aluminium_designer` and rebuild |
| `aluminium_designer.exe` does nothing on double-click (other PC) | You copied only the `.exe`. Copy the **whole `Release` folder**. If it still fails, install the VC++ Redistributable (see step 5, option C) |
| SmartScreen blocks the exe | Normal for unsigned self-built apps: *More info* → *Run anyway* |
| Manufacturer list is empty / looks wrong | Close the app completely and reopen it — the catalog self-repairs on launch. If it persists, delete `%USERPROFILE%\Documents\aluvis\catalog.json` and `%USERPROFILE%\Documents\aluvis\.catalog_seeded` while the app is closed, then relaunch (your projects live in `projects\` and are not affected — but back that folder up first anyway) |
| `git clone` asks for a password | The repo is public — use the `https://` URL above, no login needed. If you forked it privately, log in via GitHub CLI (`gh auth login`) or use an SSH URL instead |
| Build is slow the first time | Normal — the first build compiles the Flutter engine embedder. Later builds reuse it and take ~1 minute |

---

## 9. Quick reference (cheat sheet)

```bat
:: update + rebuild
cd %USERPROFILE%\Documents\aluminium_designer
git pull
flutter pub get
flutter build windows --release

:: run
build\windows\x64\runner\Release\aluminium_designer.exe

:: where your data lives on Windows
%USERPROFILE%\Documents\aluvis\          (catalog.json + projects\)
```

Repo: <https://github.com/mul-ski/aluminium_designer> (branch `main`).
