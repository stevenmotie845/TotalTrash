import Foundation
import Combine
import UserNotifications

/// Progress snapshots cross from the background file worker to the main actor.
private struct CleanProgressSnapshot: Sendable {
    let message: String
    let scanned: Int
    let found: Int
    let deleted: Int
    let currentPath: String
    let fraction: Double?
    let logs: [String]
}

private struct CleanOperationResult: Sendable {
    let removed: Int
    let reclaimed: Int64
    let logs: [String]
    let scanned: Int
    let found: Int
    let errors: [String]
}

/// FileManager's enumeration error callback is @Sendable in newer SDKs.
/// This collector safely records errors without capturing a mutable local array.
private final class LockedStringCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

@MainActor
final class JunkFileEngine: ObservableObject {
    @Published var isCleaning = false
    @Published var isScanning = false
    @Published var operationTitle = "Cleaning"
    @Published var history: [CleanRecord] = []
    @Published var currentVolumeName: String?
    @Published var progressMessage: String = "Ready"
    @Published var currentLogLines: [String] = []
    @Published var searchedCount: Int = 0
    @Published var foundCount: Int = 0
    @Published var deletedCount: Int = 0
    @Published var currentItemPath: String = ""
    /// nil means scanning with indeterminate progress; a value means deletion progress.
    @Published var progressFraction: Double?
    @Published var showProgressWindow: Bool = false

    private let prefs: PreferencesStore

    init(prefs: PreferencesStore) {
        self.prefs = prefs
        self.history = Self.loadHistory()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Scanning & Cleaning

    @discardableResult
    func clean(rootPath: String, volumeName: String) async -> CleanRecord {
        guard !isCleaning, !isScanning else {
            return CleanRecord(date: Date(), volumeName: volumeName, filesRemoved: 0, bytesReclaimed: 0,
                               deletedFilePaths: ["Another cleaning operation is already running."])
        }

        let patterns = prefs.junkPatterns.filter { $0.name != "AppleDouble Files" || prefs.removeAppleDoubleFiles }
        operationTitle = "Cleaning"
        currentVolumeName = volumeName
        isCleaning = true
        showProgressWindow = true
        progressMessage = "Scanning \(volumeName)…"
        currentLogLines = ["Preparing to scan \(rootPath)"]
        searchedCount = 0
        foundCount = 0
        deletedCount = 0
        currentItemPath = rootPath
        progressFraction = nil

        let result = await Task.detached(priority: .userInitiated) { [rootPath, patterns] in
            Self.performClean(rootPath: rootPath, patterns: patterns) { snapshot in
                Task { @MainActor [weak self] in
                    guard let self, self.isCleaning else { return }
                    self.progressMessage = snapshot.message
                    self.searchedCount = snapshot.scanned
                    self.foundCount = snapshot.found
                    self.deletedCount = snapshot.deleted
                    self.currentItemPath = snapshot.currentPath
                    self.progressFraction = snapshot.fraction
                    self.currentLogLines = snapshot.logs
                }
            }
        }.value

        searchedCount = result.scanned
        foundCount = result.found
        deletedCount = result.removed
        currentItemPath = ""
        currentLogLines = result.logs
        progressFraction = 1
        progressMessage = result.errors.isEmpty
            ? (result.removed == 0 ? "Scan complete — no matching files removed." : "Cleaning complete.")
            : "Completed with \(result.errors.count) warning(s)."

        let record = CleanRecord(
            date: Date(), volumeName: volumeName, filesRemoved: result.removed,
            bytesReclaimed: result.reclaimed, deletedFilePaths: result.logs
        )
        history.insert(record, at: 0)
        saveHistory()
        PersistentActivityLogger.shared.write(operation: "Clean", volume: volumeName, lines: result.logs)
        isCleaning = false
        operationTitle = "Finished"
        if prefs.showNotifications && result.removed > 0 { notify(record: record) }
        return record
    }

    /// Synchronous worker: keeping FileManager enumeration outside an async context
    /// avoids Swift 6's unavailable makeIterator diagnostic for DirectoryEnumerator.
    nonisolated private static func performClean(
        rootPath: String,
        patterns: [JunkPattern],
        onProgress: @escaping @Sendable (CleanProgressSnapshot) -> Void
    ) -> CleanOperationResult {
        let enabledPatterns = patterns.filter { $0.isEnabled }
        guard !enabledPatterns.isEmpty else {
            return CleanOperationResult(removed: 0, reclaimed: 0,
                logs: ["No junk categories are enabled."], scanned: 0, found: 0, errors: [])
        }

        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        let protectedFolders: Set<String> = [".Trashes", ".Spotlight-V100", ".fseventsd", ".DocumentRevisions-V100", ".TemporaryItems", ".VolumeIcon.icns"]
        guard rootURL.path != "/", !protectedFolders.contains(rootURL.lastPathComponent) else {
            return CleanOperationResult(removed: 0, reclaimed: 0, logs: ["Safety stop: refusing to clean a protected system location: \(rootURL.path)"], scanned: 0, found: 0, errors: ["Protected location."])
        }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return CleanOperationResult(removed: 0, reclaimed: 0,
                logs: ["Cannot access selected folder or volume: \(rootURL.path)",
                       "Check that the drive is mounted and TotalTrash has permission to access it."],
                scanned: 0, found: 0, errors: ["Root is unavailable or is not a directory."])
        }
        guard fm.isReadableFile(atPath: rootURL.path) else {
            return CleanOperationResult(removed: 0, reclaimed: 0,
                logs: ["Permission denied while opening \(rootURL.path).",
                       "Grant TotalTrash access to this drive in macOS Privacy & Security settings."],
                scanned: 0, found: 0, errors: ["Root is not readable."])
        }

        let enumerationErrors = LockedStringCollector()
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { url, error in
                enumerationErrors.append("Skipped \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            return CleanOperationResult(removed: 0, reclaimed: 0,
                logs: ["Could not start scanning \(rootURL.path).", "Check drive permissions and available space."],
                scanned: 0, found: 0, errors: ["File enumerator could not be created."])
        }

        var foundItems: [URL] = []
        var scanned = 0
        var liveLogs: [String] = ["Scanning \(rootURL.path)"]

        for case let fileURL as URL in enumerator {
            scanned += 1
            let name = fileURL.lastPathComponent
            if protectedFolders.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if (try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                continue
            }
            for pattern in enabledPatterns where matchesPattern(name: name, pattern: pattern.pattern) {
                foundItems.append(fileURL)
                liveLogs.append("Found [\(pattern.name)]: \(fileURL.path)")
                if pattern.isFolder { enumerator.skipDescendants() }
                break
            }
            if scanned % 25 == 0 {
                onProgress(CleanProgressSnapshot(message: "Scanning…", scanned: scanned, found: foundItems.count,
                    deleted: 0, currentPath: fileURL.path, fraction: nil, logs: Array(liveLogs.suffix(400))))
            }
        }

        onProgress(CleanProgressSnapshot(message: "Scan complete — preparing cleanup…", scanned: scanned,
            found: foundItems.count, deleted: 0, currentPath: rootURL.path, fraction: nil,
            logs: Array(liveLogs.suffix(400))))

        var removedCount = 0
        var reclaimedBytes: Int64 = 0
        var deletedLogs: [String] = []
        let totalToDelete = foundItems.count
        if totalToDelete > 0 {
            onProgress(CleanProgressSnapshot(message: "Removing matching items…", scanned: scanned, found: totalToDelete,
                deleted: 0, currentPath: foundItems[0].path, fraction: 0, logs: Array(liveLogs.suffix(400))))
        }

        for (index, url) in foundItems.enumerated() {
            do {
                let relativeComponents = url.pathComponents.dropFirst(rootURL.pathComponents.count)
                let protectedNames: Set<String> = [".Trashes", ".Spotlight-V100", ".fseventsd", ".DocumentRevisions-V100", ".TemporaryItems"]
                guard !relativeComponents.contains(where: { protectedNames.contains($0) }),
                      url.standardizedFileURL.path.hasPrefix(rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/") else {
                    deletedLogs.append("Safety skip: protected or out-of-scope path \(url.path)")
                    continue
                }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true else {
                    deletedLogs.append("Skipped symbolic link: \(url.path)")
                    continue
                }
                let size = Int64(values.fileSize ?? 0)
                try fm.removeItem(at: url)
                removedCount += 1
                reclaimedBytes += size
                deletedLogs.append("Deleted \(url.path.replacingOccurrences(of: rootURL.path + "/", with: ""))")
            } catch {
                let message = "Could not remove \(url.path): \(error.localizedDescription)"
                enumerationErrors.append(message)
                deletedLogs.append("Skipped \(url.lastPathComponent): \(error.localizedDescription)")
            }
            onProgress(CleanProgressSnapshot(message: "Removing matching items…", scanned: scanned,
                found: totalToDelete, deleted: removedCount, currentPath: url.path,
                fraction: Double(index + 1) / Double(max(totalToDelete, 1)),
                logs: Array((liveLogs + deletedLogs).suffix(400))))
        }

        var errors = enumerationErrors.values
        if scanned == 0 && errors.isEmpty {
            errors.append("No filesystem entries were enumerated; macOS may be restricting access.")
        }
        var finalLogs = liveLogs + deletedLogs
        if totalToDelete == 0 && errors.isEmpty {
            finalLogs.append("Scan complete — no matching junk files found.")
        }
        if !errors.isEmpty {
            finalLogs.append(contentsOf: errors.prefix(100).map { "Warning: \($0)" })
        }
        onProgress(CleanProgressSnapshot(message: "Finishing…", scanned: scanned, found: totalToDelete,
            deleted: removedCount, currentPath: "", fraction: 1, logs: Array(finalLogs.suffix(400))))
        return CleanOperationResult(removed: removedCount, reclaimed: reclaimedBytes,
            logs: Array(finalLogs.suffix(1000)), scanned: scanned, found: totalToDelete, errors: errors)
    }

    func scanOnly(rootPath: String, volumeName: String) async {
        guard !isCleaning, !isScanning else { return }
        operationTitle = "Scanning"
        currentVolumeName = volumeName
        isScanning = true
        showProgressWindow = true
        progressMessage = "Scanning \(volumeName)…"
        currentLogLines = ["Read-only scan started: \(rootPath)"]
        searchedCount = 0
        foundCount = 0
        deletedCount = 0
        currentItemPath = rootPath
        progressFraction = nil
        let patterns = prefs.junkPatterns.filter { $0.name != "AppleDouble Files" || prefs.removeAppleDoubleFiles }
        let results = await Task.detached(priority: .userInitiated) {
            Self.scan(rootPath: rootPath, patterns: patterns)
        }.value
        foundCount = results.count
        searchedCount = results.count
        currentItemPath = ""
        currentLogLines = results.map { "Found: \(String($0.path.dropFirst(rootPath.count + 1)))" }
        if currentLogLines.isEmpty { currentLogLines = ["Scan complete — no matching items found."] }
        progressFraction = 1
        progressMessage = "Scan complete — \(results.count) matching item(s) found. Nothing was deleted."
        PersistentActivityLogger.shared.write(operation: "Scan", volume: volumeName, lines: currentLogLines)
        isScanning = false
        operationTitle = "Scan complete"
    }

    func cleanAll(volumes: [MountedVolume]) async {
        guard !isCleaning, !isScanning else { return }
        let eligibleVolumes = volumes.filter { !$0.isExcluded }
        for volume in eligibleVolumes {
            // clean() resets its state after each volume; open the progress window once and
            // let it remain visible while cleanAll moves through the selected volumes.
            await clean(rootPath: volume.path, volumeName: volume.name)
        }
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func deleteRecord(id: CleanRecord.ID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    /// Read-only preview used by the menu bar's Get Info action.
    nonisolated static func scan(rootPath: String, patterns: [JunkPattern]) -> [URL] {
        let enabledPatterns = patterns.filter { $0.isEnabled }
        guard !enabledPatterns.isEmpty else { return [] }
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        guard FileManager.default.isReadableFile(atPath: rootURL.path),
              let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [],
                errorHandler: { _, _ in true }
              ) else { return [] }
        var found: [URL] = []
        let protectedFolders: Set<String> = [".Trashes", ".Spotlight-V100", ".fseventsd", ".DocumentRevisions-V100", ".TemporaryItems"]
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if protectedFolders.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { continue }
            for pattern in enabledPatterns where matchesPattern(name: name, pattern: pattern.pattern) {
                found.append(url)
                if pattern.isFolder { enumerator.skipDescendants() }
                break
            }
        }
        return found
    }

    nonisolated private static func matchesPattern(name: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasPrefix("*") && pattern.hasSuffix("*") {
            let middle = String(pattern.dropFirst().dropLast())
            return name.localizedStandardContains(middle)
        } else if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return name.hasPrefix(prefix)
        } else if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return name.hasSuffix(suffix)
        }
        return name.caseInsensitiveCompare(pattern) == .orderedSame
    }

    private func notify(record: CleanRecord) {
        let content = UNMutableNotificationContent()
        content.title = "TotalTrash cleaned \(record.volumeName)"
        content.body = "Removed \(record.filesRemoved) junk file(s), freed \(record.formattedSize)."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "cleanHistory")
        }
    }

    private static func loadHistory() -> [CleanRecord] {
        guard let data = UserDefaults.standard.data(forKey: "cleanHistory"),
              let decoded = try? JSONDecoder().decode([CleanRecord].self, from: data) else { return [] }
        return decoded
    }
}
