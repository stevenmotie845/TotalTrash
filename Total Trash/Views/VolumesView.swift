import SwiftUI
import AppKit

struct VolumesView: View {
    @EnvironmentObject var volumeMonitor: VolumeMonitor
    @EnvironmentObject var prefs: PreferencesStore
    @EnvironmentObject var engine: JunkFileEngine

    @State private var ejectErrorMessage: String?

    var body: some View {
        List(volumeMonitor.mountedVolumes) { volume in
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(volume.name)
                    Text(volume.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clean") {
                    Task { await engine.clean(rootPath: volume.path, volumeName: volume.name) }
                }
                .buttonStyle(.borderless)

                Button {
                    eject(volume)
                } label: {
                    Label("Eject", systemImage: "eject.fill")
                }
                .buttonStyle(.borderless)
                .help("Eject \(volume.name)")

                Toggle("Exclude", isOn: excludeBinding(for: volume))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("Exclude this volume from the watcher and Clean All")
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Volumes")
        .overlay {
            if volumeMonitor.mountedVolumes.isEmpty {
                ContentUnavailableView("No Volumes Found", systemImage: "externaldrive", description: Text("Plug in a drive to see it here."))
            }
        }
        .alert("Couldn't Eject Volume", isPresented: Binding(
            get: { ejectErrorMessage != nil },
            set: { if !$0 { ejectErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { ejectErrorMessage = nil }
        } message: {
            Text(ejectErrorMessage ?? "")
        }
    }

    private func eject(_ volume: MountedVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: volume.path))
            volumeMonitor.refreshVolumes()
        } catch {
            ejectErrorMessage = error.localizedDescription
        }
    }

    private func excludeBinding(for volume: MountedVolume) -> Binding<Bool> {
        Binding(
            get: { prefs.excludedVolumePaths.contains(volume.path) },
            set: { newValue in
                if newValue {
                    prefs.excludedVolumePaths.insert(volume.path)
                } else {
                    prefs.excludedVolumePaths.remove(volume.path)
                }
                volumeMonitor.refreshVolumes()
            }
        )
    }
}
