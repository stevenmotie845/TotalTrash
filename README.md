# TotalTrash v2.0.0 🗑️✨

**TotalTrash** is a lightweight macOS menu bar utility that automatically cleans junk files off your external drives/usb drive no more`.DS_Store` and `Thumbs.db` clutter showing up on external drives, USB sticks, or SD cards.

This is the first public release.

## Screenshots ##

<img width="1012" height="744" alt="TotalTrash_settings" src="https://github.com/user-attachments/assets/bd9e234e-67d1-4fb6-af68-eff14071752a" />
<img width="376" height="630" alt="TotalTrash_menubar" src="https://github.com/user-attachments/assets/52a65dce-a64f-4655-bc5f-b19c08b67ded" />
<img width="1012" height="744" alt="TotalTrash_Dashboard" src="https://github.com/user-attachments/assets/9902f16b-9b48-4e05-b918-513c36d40cbe" />
<img width="1012" height="744" alt="TotalTrash_activity_log" src="https://github.com/user-attachments/assets/2eafe65f-ba4c-4512-902c-30717fda9804" />
<img width="1012" height="744" alt="TotalTrash_about" src="https://github.com/user-attachments/assets/22f9e930-f010-4854-9192-8b055d44dacc" />


---

## ✨ Features

- 🔌 **Auto-clean on connect** — watches for newly mounted volumes and instantly cleans them
- 🧹 **Clean Now** — trigger a manual scan on one volume or every mounted volume at once
- 🎯 **10 built-in junk file patterns**, each individually toggleable:
  - `.DS_Store`, `._*` (AppleDouble), `.Spotlight-V100`, `.Trashes`, `.fseventsd`, `.TemporaryItems`, `.apdisk`, `__MACOSX`, `Thumbs.db`, `desktop.ini`
- 🚫 **Per-volume exclude list** — skip specific drives from auto-clean
- ⏏️ **Eject button** — safely eject a volume right from the app
- 📊 **Activity log** — full history of every clean, with files removed and space reclaimed
- 🚀 **Launch at login**
- 🔔 **Native notifications** after each clean
- 🖥️ **Menu bar app** with a quick-access dropdown, plus a full sidebar-based dashboard window
- ℹ️ **About panel** with app info and version

## 📋 Requirements

- macOS 13 (Ventura) or later

## 📦 Installation

1. Download `TotalTrash.app.zip` below
2. Unzip it and drag `TotalTrash.app` into your `/Applications` folder
3. On first launch, right-click the app and choose **Open** (it's not notarized yet, so Gatekeeper will otherwise block it)
4. Grant it access to removable volumes if prompted, so it can clean external drives

## ⚠️ Known Limitations

- Not yet notarized by Apple — expect a Gatekeeper warning on first launch
- Network volume support is untested beyond standard SMB/AFP mounts

## 🙏 Credits

Created by **Steven Motie**, 2026.

---

**Full Changelog**: Initial release
