import Foundation

/// A single "type of junk" TotalTrash knows how to find, e.g. .DS_Store files.
struct JunkPattern: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var pattern: String       // exact filename, or wildcard like "._*", ".nfs*", "*.crash"
    var isFolder: Bool        // true for whole folders to remove
    var isEnabled: Bool

    static let defaults: [JunkPattern] = [
        JunkPattern(name: "macOS Finder Files", pattern: ".DS_Store", isFolder: false, isEnabled: true),
        JunkPattern(name: "AppleDouble Files", pattern: "._*", isFolder: false, isEnabled: true),
        // Keep system-managed volume databases and Trash folders intact.
        JunkPattern(name: "Temporary Items", pattern: ".TemporaryItems", isFolder: true, isEnabled: false),
        JunkPattern(name: "Disk Image Info", pattern: ".apdisk", isFolder: false, isEnabled: true),
        JunkPattern(name: "Zip Archive Junk", pattern: "__MACOSX", isFolder: true, isEnabled: true),
        JunkPattern(name: "Windows Thumbnail Cache", pattern: "Thumbs.db", isFolder: false, isEnabled: true),
        JunkPattern(name: "Windows Folder Settings", pattern: "desktop.ini", isFolder: false, isEnabled: true),
        JunkPattern(name: "NFS Lock Files", pattern: ".nfs*", isFolder: false, isEnabled: false),
        JunkPattern(name: "Crash Log Files", pattern: "*.crash", isFolder: false, isEnabled: false)
    ]
}

/// One completed cleaning run, kept for the Activity Log.
struct CleanRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var volumeName: String
    var filesRemoved: Int
    var bytesReclaimed: Int64
    var deletedFilePaths: [String] = []

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytesReclaimed, countStyle: .file)
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

/// A currently mounted disk (USB stick, SD card, network share, disk image...).
struct MountedVolume: Identifiable, Equatable {
    var id: String { path }
    var name: String
    var path: String
    var filesystemType: String = "unknown"
    var isExcluded: Bool = false

    var isNonMacStorage: Bool {
        let type = filesystemType.lowercased()
        return ["exfat", "msdos", "ntfs", "smbfs", "nfs", "webdav", "ftp", "fusefs"].contains(type)
    }
}

