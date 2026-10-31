# TotalTrash — progress and Swift 6 update

## Changes in this update

- Moved `FileManager` directory enumeration into a synchronous, nonisolated worker so `DirectoryEnumerator.makeIterator()` is not used from an async context.
- Replaced mutable arrays captured by the enumerator's concurrent error callback with a lock-protected error collector.
- Added live scan/deletion status, scanned/found/deleted counters, current path, and a scrolling activity log to the progress window.
- Made the Dashboard's per-drive Clean button open the progress window immediately.
- Removed the Refresh and Clean All Now buttons from the main window's upper-right toolbar.
- Disabled Clean for excluded volumes and labels them in the Dashboard.
- Added `scripts/create_appledouble_test_files.py`, a safe test-data generator for `/Volumes/PKGs`.

## Test AppleDouble matching

Run on your Mac:

```bash
python3 scripts/create_appledouble_test_files.py --count 10
```

The script scans the mounted volume for sample filenames, then creates disposable sample payloads and `._` AppleDouble-named files **only** inside `/Volumes/PKGs/TotalTrash-AppleDouble-Test`. It never alters the original sampled files and refuses to overwrite an existing test folder. In TotalTrash, clean that test folder specifically, then confirm the `._*` files are detected and removed.

## Build verification

Open `Total Trash.xcodeproj` in Xcode and build with **Product → Clean Build Folder**, then **⌘B**. This package was syntax-checked, but a full macOS SDK build and runtime test must be performed on macOS.


## Drive workflow and safety update

- Added per-drive **Scan**, **Clean**, **Clean & Eject**, and **Eject** actions in the Dashboard and menu bar.
- Scan is read-only and reports matches without deleting them.
- The progress window now distinguishes scanning from cleaning and retains the completed volume name/status.
- Added a persistent activity log at `~/Library/Logs/TotalTrash/TotalTrash.log`, with a previous-log rollover when the active log exceeds approximately 2 MB.
- Added opt-in FSEvents monitoring for supported non-Mac filesystems (exFAT, FAT/MS-DOS, NTFS, SMB, NFS, WebDAV, and FUSE filesystems). Automatic removal is limited to stable `.DS_Store`, `.apdisk`, `Thumbs.db`, and `desktop.ini` files. AppleDouble `._*` files are detected and logged but never automatically deleted.
- AppleDouble manual cleanup is now separately opt-in because those files can contain resource-fork metadata.
- Added final deletion-time path checks and a refusal to clean the filesystem root or protected volume metadata directories (`.Trashes`, `.Spotlight-V100`, `.fseventsd`, `.DocumentRevisions-V100`, and `.TemporaryItems`).
- FSEvents watching is disabled by default and can be enabled in Settings. Internal APFS/HFS+ volumes are not watched.

## Build and runtime validation

This update was syntax-parsed in the provided environment. A full Xcode/macOS SDK build and hardware validation of FSEvents, file permissions, and eject behavior still need to be run on the Mac before enabling automatic watching on important drives.


## Watcher controls and session counter

- Added a clickable `Watcher: On/Off` control in the menu-bar popover, matching the compact status row shown in the supplied screenshot.
- Added an independent Drive Watcher switch to the Dashboard with a live `Watcher removed N items this session` counter.
- The same persisted `watchDrives` preference drives the menu bar, Dashboard, Settings, and FSEvents monitor.
- Watcher operation is independent of the general automatic-cleanup switch. Turning the watcher off stops active streams and prevents queued delayed watcher-cleanup tasks from removing files.
- Successful FSEvents-driven removals increment a per-app-session counter; manual cleaning does not affect that counter.
