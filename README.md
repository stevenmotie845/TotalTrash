# TotalTrash v1.0.0 🗑️✨

**TotalTrash** is a lightweight macOS menu bar utility that automatically cleans junk files off your external drives the moment you plug them in — no more `.DS_Store` and `Thumbs.db` clutter showing up on other people's computers, USB sticks, or SD cards.

This is the first public release.

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
