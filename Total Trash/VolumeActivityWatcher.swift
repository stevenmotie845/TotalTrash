import Foundation
import CoreServices

private final class FSEventContextBox {
    let handler: ([String]) -> Void

    init(handler: @escaping ([String]) -> Void) {
        self.handler = handler
    }
}

final class VolumeActivityWatcher {

    // MARK: - Properties

    private let queue = DispatchQueue(
        label: "com.totaltrash.volume-watcher",
        qos: .utility
    )

    private let queueKey = DispatchSpecificKey<UInt8>()

    private var streams: [String: FSEventStreamRef] = [:]
    private var removeAppleDoubleFiles = true
    private var watchingEnabled = false

    /// Called on the watcher queue after an automatic removal succeeds.
    var onAutomaticRemoval: (() -> Void)?

    // MARK: - Initialization

    init() {
        queue.setSpecific(key: queueKey, value: 1)
    }

    // MARK: - Public API

    func update(
        paths: [String],
        enabled: Bool,
        removeAppleDoubleFiles: Bool
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            self.removeAppleDoubleFiles = removeAppleDoubleFiles
            self.watchingEnabled = enabled

            let desired = enabled ? Set(paths) : Set<String>()
            let existing = Set(self.streams.keys)

            // Stop watching volumes that are no longer enabled or mounted.
            for path in existing.subtracting(desired) {
                self.stop(path: path)
            }

            // Start watching newly enabled volumes.
            for path in desired.subtracting(existing) {
                self.start(path: path)
            }
        }
    }

    func stopAll() {
        // Avoid synchronously dispatching onto this queue from itself.
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            for path in Array(streams.keys) {
                stop(path: path)
            }
        } else {
            queue.sync {
                for path in Array(streams.keys) {
                    stop(path: path)
                }
            }
        }
    }

    // MARK: - FSEvents Setup

    private func start(path: String) {
        guard streams[path] == nil else {
            return
        }

        let box = FSEventContextBox { [weak self] changedPaths in
            self?.handle(
                changedPaths: changedPaths,
                volumeRoot: path
            )
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(box).toOpaque(),
            retain: nil,

            // IMPORTANT:
            // Unwrap info here since it is passed as an optional pointer.
            release: { info in
                guard let info else {
                    return
                }
                Unmanaged<FSEventContextBox>
                    .fromOpaque(info)
                    .release()
            },

            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagWatchRoot
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,

            // MARK: FSEvents Callback

            { _, info, count, eventPaths, _, _ in

                // Unwrap the callback's info parameter.
                guard let info else {
                    return
                }

                let box = Unmanaged<FSEventContextBox>
                    .fromOpaque(info)
                    .takeUnretainedValue()

                // eventPaths is a non-optional UnsafeMutableRawPointer in this SDK
                let pathPointers = eventPaths.bindMemory(
                    to: UnsafePointer<CChar>.self,
                    capacity: count
                )

                var changedPaths: [String] = []
                changedPaths.reserveCapacity(count)

                for index in 0..<count {
                    let path = String(
                        cString: pathPointers[index]
                    )

                    changedPaths.append(path)
                }

                box.handler(changedPaths)
            },

            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.75,
            flags

        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)

        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return
        }

        streams[path] = stream
    }

    // MARK: - Stop FSEvents

    private func stop(path: String) {
        guard let stream = streams.removeValue(forKey: path) else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    // MARK: - Path Validation

    private func isInsideVolume(
        _ fileURL: URL,
        rootURL: URL
    ) -> Bool {
        let filePath = fileURL.standardizedFileURL.path
        let rootPath = rootURL.standardizedFileURL.path

        guard filePath != rootPath else {
            return false
        }

        let prefix = rootPath.hasSuffix("/")
            ? rootPath
            : rootPath + "/"

        return filePath.hasPrefix(prefix)
    }

    private func containsProtectedDirectory(
        _ url: URL
    ) -> Bool {
        let protected: Set<String> = [
            ".Trashes",
            ".Spotlight-V100",
            ".fseventsd",
            ".DocumentRevisions-V100",
            ".TemporaryItems"
        ]

        return url.pathComponents.contains { component in
            protected.contains(component)
        }
    }

    // MARK: - Event Handling

    private func handle(
        changedPaths: [String],
        volumeRoot: String
    ) {
        guard watchingEnabled else { return }

        let root = URL(
            fileURLWithPath: volumeRoot,
            isDirectory: true
        ).standardizedFileURL

        let safeNames: Set<String> = [
            ".DS_Store",
            ".apdisk",
            "Thumbs.db",
            "desktop.ini"
        ]

        for path in changedPaths {
            let url = URL(
                fileURLWithPath: path
            ).standardizedFileURL

            // Never process the volume root itself.
            guard isInsideVolume(url, rootURL: root) else {
                continue
            }

            // Never process protected macOS system directories.
            guard !containsProtectedDirectory(url) else {
                continue
            }

            let isAppleDouble =
                url.lastPathComponent.hasPrefix("._")

            // Retain AppleDouble files when automatic removal is disabled.
            if isAppleDouble && !removeAppleDoubleFiles {
                PersistentActivityLogger.shared.write(
                    operation: "AppleDouble Detected",
                    volume: root.lastPathComponent,
                    lines: [
                        "Detected and retained because automatic AppleDouble removal is disabled: \(url.path)"
                    ]
                )

                continue
            }

            // Only handle the supported metadata filenames.
            guard safeNames.contains(url.lastPathComponent)
                    || isAppleDouble else {
                continue
            }

            // Read initial file properties.
            guard let initialValues = try? url.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isSymbolicLinkKey,
                    .isDirectoryKey
                ]
            ) else {
                continue
            }

            // Never remove symbolic links.
            guard initialValues.isSymbolicLink != true else {
                continue
            }

            // Only process files, not directories.
            guard initialValues.isDirectory != true else {
                continue
            }

            let initialSize = initialValues.fileSize
            let initialModified = initialValues.contentModificationDate

            // Wait briefly to allow copying or writing to finish.
            queue.asyncAfter(
                deadline: .now() + 1.25
            ) { [weak self] in

                guard let self, self.watchingEnabled else {
                    return
                }

                // Confirm that the file is still within the watched volume.
                guard self.isInsideVolume(url, rootURL: root) else {
                    return
                }

                // Recheck protected directory exclusions.
                guard !self.containsProtectedDirectory(url) else {
                    return
                }

                // Re-read the file properties.
                guard let currentValues = try? url.resourceValues(
                    forKeys: [
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isSymbolicLinkKey,
                        .isDirectoryKey
                    ]
                ) else {
                    return
                }

                // Do not remove symbolic links or directories.
                guard currentValues.isSymbolicLink != true,
                      currentValues.isDirectory != true else {
                    return
                }

                // Only remove the file if its size and modification
                // date have remained unchanged.
                guard currentValues.fileSize == initialSize,
                      currentValues.contentModificationDate == initialModified else {
                    return
                }

                // Recheck the AppleDouble preference at deletion time.
                if isAppleDouble && !self.removeAppleDoubleFiles {
                    return
                }

                // Perform cleanup.
                do {
                    try FileManager.default.removeItem(at: url)
                    self.onAutomaticRemoval?()

                    PersistentActivityLogger.shared.write(
                        operation: "Automatic Watch Cleanup",
                        volume: root.lastPathComponent,
                        lines: [
                            "Removed stable \(isAppleDouble ? "AppleDouble" : "metadata") file: \(url.path)"
                        ]
                    )

                } catch {
                    PersistentActivityLogger.shared.write(
                        operation: "Automatic Watch Cleanup",
                        volume: root.lastPathComponent,
                        lines: [
                            "Could not remove \(url.path): \(error.localizedDescription)"
                        ]
                    )
                }
            }
        }
    }

    // MARK: - Deinitialization

    deinit {
        stopAll()
    }
}
