import Foundation
import AppKit
import Combine
import Darwin

@MainActor
final class VolumeMonitor: ObservableObject {
    @Published var mountedVolumes: [MountedVolume] = []
    @Published private(set) var watcherRemovedThisSession = 0

    private let prefs: PreferencesStore
    private let engine: JunkFileEngine
    private var observers: [NSObjectProtocol] = []
    private var preferencesCancellable: AnyCancellable?
    private let activityWatcher = VolumeActivityWatcher()

    init(prefs: PreferencesStore, engine: JunkFileEngine) {
        self.prefs = prefs
        self.engine = engine

        activityWatcher.onAutomaticRemoval = { [weak self] in
            Task { @MainActor [weak self] in
                self?.watcherRemovedThisSession += 1
            }
        }

        // Keep the FSEvents watcher synchronized regardless of which view
        // changes the preference (Settings, Dashboard, or menu bar).
        preferencesCancellable = prefs.$watchDrives
            .combineLatest(prefs.$removeAppleDoubleFiles)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshVolumes()
                }
            }

        refreshVolumes()
        registerObservers()
    }

    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        mountedVolumes = urls.compactMap { url in
            let name = (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? url.lastPathComponent
            
            // Exclude the main system startup disk
            if name == "Macintosh HD" || url.path == "/" {
                return nil
            }
            
            var filesystem = statfs()
            let filesystemType: String
            if statfs(url.path, &filesystem) == 0 {
                // Copy the tuple before reading it. Referencing `filesystem` from
                // inside the pointer closure creates an overlapping access to
                // the same struct that is being accessed through the pointer.
                let filesystemName = filesystem.f_fstypename
                filesystemType = withUnsafeBytes(of: filesystemName) { bytes in
                    let nameBytes = bytes.prefix { $0 != 0 }
                    return String(decoding: nameBytes, as: UTF8.self)
                }
            } else {
                filesystemType = "unknown"
            }

            return MountedVolume(
                name: name,
                path: url.path,
                filesystemType: filesystemType,
                isExcluded: prefs.excludedVolumePaths.contains(url.path)
            )
        }
        activityWatcher.update(
            paths: mountedVolumes.filter { !$0.isExcluded && $0.isNonMacStorage }.map(\.path),
            enabled: prefs.watchDrives,
            removeAppleDoubleFiles: prefs.removeAppleDoubleFiles
        )
    }

    private func registerObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        let mountObserver = nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshVolumes()
            }
        }

        let unmountObserver = nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshVolumes()
            }
        }

        observers = [mountObserver, unmountObserver]
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        preferencesCancellable?.cancel()
        activityWatcher.stopAll()
    }
}
