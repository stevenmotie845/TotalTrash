import Foundation

final class PersistentActivityLogger {
    static let shared = PersistentActivityLogger()
    private let queue = DispatchQueue(label: "com.totaltrash.activity-log", qos: .utility)
    private let fileManager = FileManager.default
    private init() {}

    var logURL: URL {
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Logs/TotalTrash/TotalTrash.log")
    }

    /// Creates the log directory and an empty log file when the user opens it
    /// before the first cleanup event has been recorded.
    func prepareLogFile() throws -> URL {
        let directory = logURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        if !fileManager.fileExists(atPath: logURL.path) {
            try Data().write(to: logURL, options: .atomic)
        }

        return logURL
    }

    func write(operation: String, volume: String, lines: [String]) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let directory = self.logURL.deletingLastPathComponent()
                try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let body = (["\n[\(timestamp)] \(operation) — \(volume)"] + lines).joined(separator: "\n") + "\n"
                let data = Data(body.utf8)
                if self.fileManager.fileExists(atPath: self.logURL.path) {
                    let handle = try FileHandle(forWritingTo: self.logURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: self.logURL, options: .atomic)
                }
                let attributes = try self.fileManager.attributesOfItem(atPath: self.logURL.path)
                if let size = attributes[.size] as? NSNumber, size.intValue > 2_000_000 {
                    let archive = directory.appendingPathComponent("TotalTrash-Previous.log")
                    try? self.fileManager.removeItem(at: archive)
                    try self.fileManager.moveItem(at: self.logURL, to: archive)
                }
            } catch {
                NSLog("TotalTrash log write failed: %@", error.localizedDescription)
            }
        }
    }
}
