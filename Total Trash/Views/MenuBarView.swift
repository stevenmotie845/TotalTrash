//
//  MenuBarView.swift
//  Total Trash
//
//  Created by Steven Motie on 10/30/26.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var engine: JunkFileEngine
    @EnvironmentObject private var volumeMonitor: VolumeMonitor
    @EnvironmentObject private var navigation: AppNavigationRouter
    @Environment(\.openWindow) private var openWindow

    @State private var ejectError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            watcherStatusRow

            Divider()

            actionsSection

            Divider()

            drivesSection

            if !engine.history.isEmpty {
                Divider()
                recentActivitySection
            }

            if let ejectError {
                Label(ejectError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 330)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 35))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("TotalTrash")
                    .font(.headline)

                statusLine
            }

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if engine.isCleaning {
            Label(
                engine.currentVolumeName.map { "Cleaning \($0)…" }
                    ?? "Cleaning in progress…",
                systemImage: "trash.circle.fill"
            )
            .foregroundStyle(.blue)
        } else {
            Label("Ready to clean", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    // MARK: - Drive Watcher

    private var watcherStatusRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                prefs.watchDrives.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: prefs.watchDrives ? "checkmark" : "pause.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(prefs.watchDrives ? Color.green : Color.secondary)

                    Text("Watcher: \(prefs.watchDrives ? "On" : "Off")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "switch.2")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(prefs.watchDrives ? "Turn off drive watcher" : "Turn on drive watcher")
            .accessibilityLabel(prefs.watchDrives ? "Turn off drive watcher" : "Turn on drive watcher")

            Text("Watcher removed \(volumeMonitor.watcherRemovedThisSession) items this session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 5) {
            actionRow(
                title: "Clean a Folder…",
                subtitle: "Choose a folder or drive",
                symbol: "folder"
            ) {
                selectAndCleanFolder()
            }

            actionRow(
                title: "Clean All Drives",
                subtitle: "Clean connected, included drives",
                symbol: "externaldrive.fill"
            ) {
                confirmCleanAll()
            }
            .disabled(engine.isCleaning || volumeMonitor.mountedVolumes.isEmpty)

        }
    }

    private func actionRow(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(.blue)
                    .frame(width: 25)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Folder Selection

    private func selectAndCleanFolder() {
        let panel = NSOpenPanel()

        panel.title = "Choose a Folder to Clean"
        panel.message = "Select the folder or mounted drive to scan."
        panel.prompt = "Clean"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        WindowFocusManager.activateApplication()
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            openProgressWindow()
            Task {
                await engine.clean(
                    rootPath: url.path,
                    volumeName: url.lastPathComponent
                )
            }
        }
    }

    // MARK: - Clean All

    private func confirmCleanAll() {
        let eligibleVolumes = volumeMonitor.mountedVolumes.filter {
            !$0.isExcluded
        }

        guard !eligibleVolumes.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Eligible Drives"
            alert.informativeText =
                "There are no eligible connected drives. Check your drive exclusions and try again."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Clean All Connected Drives?"
        alert.informativeText =
            "TotalTrash will scan \(eligibleVolumes.count) drive(s) and remove files matching your enabled cleanup rules. Review your cleanup settings before continuing."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clean Drives")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        openProgressWindow()
        Task {
            await engine.cleanAll(volumes: eligibleVolumes)
        }
    }

    // MARK: - Drives

    private var drivesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("CONNECTED DRIVES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(volumeMonitor.mountedVolumes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if volumeMonitor.mountedVolumes.isEmpty {
                ContentUnavailableView(
                    "No Drives Found",
                    systemImage: "externaldrive",
                    description: Text("Connect a drive to get started.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                ForEach(volumeMonitor.mountedVolumes) { volume in
                    driveRow(volume)
                }
            }
        }
    }

    private func driveRow(_ volume: MountedVolume) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 18))
                .foregroundStyle(
                    volume.isExcluded ? Color.secondary : Color.blue
                )
                .frame(width: 25)

            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(volume.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if volume.isExcluded {
                    Text("Excluded from Watcher and Clean All")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 2)

            Menu {
                Button {
                    openProgressWindow()
                    Task { await engine.scanOnly(rootPath: volume.path, volumeName: volume.name) }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                Button {
                    openProgressWindow()
                    Task { await engine.clean(rootPath: volume.path, volumeName: volume.name) }
                } label: {
                    Label("Clean", systemImage: "trash.circle.fill")
                }
                .disabled(volume.isExcluded)
                Button {
                    openProgressWindow()
                    Task {
                        let record = await engine.clean(rootPath: volume.path, volumeName: volume.name)
                        let hasWarnings = record.deletedFilePaths.contains { $0.localizedCaseInsensitiveContains("warning:") || $0.localizedCaseInsensitiveContains("safety skip") || $0.localizedCaseInsensitiveContains("skipped") || $0.localizedCaseInsensitiveContains("could not remove") }
                        if !hasWarnings { eject(volume) }
                    }
                } label: {
                    Label("Clean & Eject", systemImage: "eject.fill")
                }
                .disabled(volume.isExcluded)
                Divider()
                Button {
                    eject(volume)
                } label: {
                    Label("Eject", systemImage: "eject")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.blue)
            }
            .menuStyle(.borderlessButton)
            .help("Actions for \(volume.name)")
            .disabled(engine.isCleaning || engine.isScanning)

        }
        .padding(.vertical, 4)
    }

    private func openProgressWindow() {
        engine.showProgressWindow = true
        openWindow(id: "clean-progress")
        WindowFocusManager.bringToFront(windowTitle: WindowFocusManager.progressWindowTitle)
    }

    private func eject(_ volume: MountedVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(
                at: URL(fileURLWithPath: volume.path)
            )

            ejectError = nil
            volumeMonitor.refreshVolumes()
        } catch {
            ejectError =
                "Couldn't eject \(volume.name): \(error.localizedDescription)"
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("RECENT ACTIVITY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Last \(min(engine.history.count, 3))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            ForEach(engine.history.prefix(3)) { record in
                HStack(alignment: .top, spacing: 9) {
                    Image(
                        systemName: record.filesRemoved > 0
                            ? "checkmark.circle.fill"
                            : "info.circle"
                    )
                    .foregroundStyle(
                        record.filesRemoved > 0 ? Color.green : Color.secondary
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.volumeName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        Text(
                            "\(record.filesRemoved) items · \(record.formattedSize)"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Text(record.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openPersistentLog) {
                Label("Open Activity Log", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("menubar-open-log")

            HStack {
                Button {
                    openMainWindow(section: .dashboard)
                } label: {
                    Label("Open TotalTrash", systemImage: "macwindow")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func openPersistentLog() {
        do {
            let url = try PersistentActivityLogger.shared.prepareLogFile()
            NSWorkspace.shared.open(url)
        } catch {
            ejectError = "Couldn't open activity log: \(error.localizedDescription)"
        }
    }

    // MARK: - Window Management

    private func openMainWindow(section: SidebarSection = .dashboard) {
        // Update navigation before opening so an existing or newly-created
        // main window always displays the requested destination.
        navigation.navigate(to: section)
        openWindow(id: "main")
        WindowFocusManager.bringToFront(windowTitle: WindowFocusManager.mainWindowTitle)
    }
}
