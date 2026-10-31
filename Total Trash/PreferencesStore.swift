import Foundation
import ServiceManagement
import Combine

final class PreferencesStore: ObservableObject {
    @Published var junkPatterns: [JunkPattern] {
        didSet { save(junkPatterns, key: "junkPatterns") }
    }
    @Published var excludedVolumePaths: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedVolumePaths), forKey: "excludedVolumePaths") }
    }
    @Published var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "showNotifications") }
    }
    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin(launchAtLogin) }
    }
    @Published var removeAppleDoubleFiles: Bool {
        didSet { UserDefaults.standard.set(removeAppleDoubleFiles, forKey: "removeAppleDoubleFiles") }
    }
    @Published var watchDrives: Bool {
        didSet { UserDefaults.standard.set(watchDrives, forKey: "watchDrives") }
    }

    init() {
        self.junkPatterns = PreferencesStore.load(key: "junkPatterns") ?? JunkPattern.defaults
        self.excludedVolumePaths = Set(UserDefaults.standard.stringArray(forKey: "excludedVolumePaths") ?? [])
        self.showNotifications = UserDefaults.standard.object(forKey: "showNotifications") as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.watchDrives = UserDefaults.standard.object(forKey: "watchDrives") as? Bool ?? false
        self.removeAppleDoubleFiles = UserDefaults.standard.object(forKey: "removeAppleDoubleFiles") as? Bool ?? true
        // Remove the retired app-wide automatic-clean toggle from older installs.
        UserDefaults.standard.removeObject(forKey: "isEnabled")
    }

    private func save<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Codable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch-at-login: \(error)")
        }
    }
}
