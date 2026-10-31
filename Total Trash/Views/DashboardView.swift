import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject var engine: JunkFileEngine
    @EnvironmentObject var volumeMonitor: VolumeMonitor
    @EnvironmentObject var prefs: PreferencesStore
    @Environment(\.openWindow) private var openWindow

    @State private var ejectErrorMessage: String?

    var totalFilesRemoved: Int { engine.history.reduce(0) { $0 + $1.filesRemoved } }
    var totalBytesReclaimed: Int64 { engine.history.reduce(0) { $0 + $1.bytesReclaimed } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Top stats overview
                HStack(spacing: 16) {
                    StatCard(title: "Volumes Watched", value: "\(volumeMonitor.mountedVolumes.count)", icon: "externaldrive.fill", tint: .blue)
                    StatCard(title: "Files Removed", value: "\(totalFilesRemoved)", icon: "trash.fill", tint: .red)
                    StatCard(title: "Space Reclaimed", value: ByteCountFormatter.string(fromByteCount: totalBytesReclaimed, countStyle: .file), icon: "internaldrive.fill", tint: .green)
                }

                watcherControl

                // Mounted Drives Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mounted Drives")
                        .font(.headline)

                    if volumeMonitor.mountedVolumes.isEmpty {
                        Text("No external drives connected.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(volumeMonitor.mountedVolumes) { volume in
                                DriveRowView(volume: volume, prefs: prefs, engine: engine) {
                                    eject(volume)
                                }
                            }
                        }
                    }
                }

                Divider()

                Text("Recent Activity")
                    .font(.headline)

                if engine.history.isEmpty {
                    Text("No cleaning activity yet. Plug in a drive or hit Clean All Now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.history.prefix(4)) { record in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(record.volumeName).bold()
                                Text("\(record.filesRemoved) files removed · \(record.formattedSize)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(.textBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
        .alert("Couldn't Eject Volume", isPresented: Binding(
            get: { ejectErrorMessage != nil },
            set: { if !$0 { ejectErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { ejectErrorMessage = nil }
        } message: {
            Text(ejectErrorMessage ?? "")
        }
    }

    private var watcherControl: some View {
        HStack(spacing: 12) {
            Image(systemName: prefs.watchDrives ? "eye.fill" : "eye.slash")
                .font(.title2)
                .foregroundStyle(prefs.watchDrives ? Color.green : Color.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text("Drive Watcher")
                    .font(.headline)

                Text("Watcher: \(prefs.watchDrives ? "On" : "Off")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(prefs.watchDrives ? .green : .secondary)

                Text("Watcher removed \(volumeMonitor.watcherRemovedThisSession) items this session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enable drive watcher", isOn: $prefs.watchDrives)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityIdentifier("dashboard-watcher-toggle")
                .help("Start or stop monitoring connected non-Mac drives")
        }
        .padding(12)
        .background(Color(.textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func eject(_ volume: MountedVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: volume.path))
            volumeMonitor.refreshVolumes()
        } catch {
            ejectErrorMessage = error.localizedDescription
        }
    }
}

struct DriveRowView: View {
    let volume: MountedVolume
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var engine: JunkFileEngine
    @Environment(\.openWindow) private var openWindow
    let onEject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(volume.isExcluded ? Color.secondary : Color.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name).bold()
                Text(volume.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if volume.isExcluded {
                    Text("Excluded in Settings")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()

            Menu {
                Button {
                    beginScan()
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                Button {
                    beginClean()
                } label: {
                    Label("Clean", systemImage: "sparkles")
                }
                .disabled(volume.isExcluded)
                Button {
                    beginCleanAndEject()
                } label: {
                    Label("Clean & Eject", systemImage: "eject.fill")
                }
                .disabled(volume.isExcluded)
                Divider()
                Button(role: .destructive, action: onEject) {
                    Label("Eject", systemImage: "eject")
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .disabled(engine.isCleaning || engine.isScanning)
        }
        .padding(10)
        .background(Color(.textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    private func presentProgressWindow() {
        openWindow(id: "clean-progress")
        WindowFocusManager.bringToFront(windowTitle: WindowFocusManager.progressWindowTitle)
    }

    private func beginScan() {
        engine.showProgressWindow = true
        presentProgressWindow()
        Task { await engine.scanOnly(rootPath: volume.path, volumeName: volume.name) }
    }

    private func beginClean() {
        engine.showProgressWindow = true
        presentProgressWindow()
        Task { await engine.clean(rootPath: volume.path, volumeName: volume.name) }
    }

    private func beginCleanAndEject() {
        engine.showProgressWindow = true
        presentProgressWindow()
        Task {
            let record = await engine.clean(rootPath: volume.path, volumeName: volume.name)
            let hasWarnings = record.deletedFilePaths.contains { $0.localizedCaseInsensitiveContains("warning:") || $0.localizedCaseInsensitiveContains("safety skip") || $0.localizedCaseInsensitiveContains("skipped") || $0.localizedCaseInsensitiveContains("could not remove") }
            guard !hasWarnings else { return }
            onEject()
        }
    }

}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2).bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
