import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var volumeMonitor: VolumeMonitor

    var body: some View {
        Form {
            Section("Drive Watcher") {
                Toggle("Watch connected drives for junk files", isOn: $prefs.watchDrives)
                Text("When enabled, TotalTrash watches supported non-Mac filesystems and removes eligible stable metadata files as they appear. Manual Scan and Clean actions remain available when the watcher is off. Protected macOS volume databases are never touched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Cleanup Rules") {
                ForEach($prefs.junkPatterns) { $pattern in
                    Toggle(isOn: $pattern.isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pattern.name)
                            Text(pattern.pattern)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("AppleDouble Safety") {
                Toggle("Automatically remove AppleDouble files (._*)", isOn: $prefs.removeAppleDoubleFiles)
                Text("When enabled, TotalTrash removes stable ._ companion files during manual cleaning and automatic drive watching. These files can contain resource-fork metadata used by some fonts, graphics, and legacy Mac files. Enable this only when that metadata is not needed on your drives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("Notify when cleanup finishes", isOn: $prefs.showNotifications)
                Toggle("Launch TotalTrash at login", isOn: $prefs.launchAtLogin)
            }
            Section("Activity Log") {
                LabeledContent("Log file", value: "~/Library/Logs/TotalTrash/TotalTrash.log")
                    .font(.caption)
                Button("Open Log Folder") {
                    NSWorkspace.shared.open(PersistentActivityLogger.shared.logURL.deletingLastPathComponent())
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle("Settings")
    }
}
