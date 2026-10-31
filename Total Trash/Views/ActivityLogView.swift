import SwiftUI
import AppKit

struct ActivityLogView: View {
    @EnvironmentObject private var engine: JunkFileEngine
    @State private var selectedRecordID: CleanRecord.ID?
    @State private var logOpenError: String?

    private var selectedRecord: CleanRecord? {
        if let selectedRecordID {
            return engine.history.first { $0.id == selectedRecordID }
        }
        return engine.history.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleaning History")
                        .font(.headline)
                    Text("Persistent log: ~/Library/Logs/TotalTrash/TotalTrash.log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: openPersistentLog) {
                    Label("Open Log File", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("activity-open-log")

                if !engine.history.isEmpty {
                    Button(role: .destructive) {
                        engine.clearHistory()
                        selectedRecordID = nil
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)

            Divider()

            if engine.history.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock",
                    description: Text("Cleaning sessions will appear here. You can still open the persistent log file.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                activityContent
            }
        }
        .alert("Couldn't Open Activity Log", isPresented: Binding(
            get: { logOpenError != nil },
            set: { if !$0 { logOpenError = nil } }
        )) {
            Button("OK", role: .cancel) { logOpenError = nil }
        } message: {
            Text(logOpenError ?? "")
        }
    }

    private var activityContent: some View {
        VStack(spacing: 0) {
            List(engine.history, selection: $selectedRecordID) { record in
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.volumeName).bold()
                        Text("\(record.filesRemoved) files · \(record.formattedSize)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(record.formattedTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button {
                            engine.deleteRecord(id: record.id)
                            if selectedRecordID == record.id {
                                selectedRecordID = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Delete this session")
                    }
                }
                .tag(record.id)
            }
            .frame(minHeight: 150, idealHeight: 190, maxHeight: 220)

            Divider()

            if let record = selectedRecord {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Activity for \(record.volumeName):")
                            .font(.headline)
                        Spacer()
                        Text(record.formattedTimestamp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if record.deletedFilePaths.isEmpty {
                                Text("No files were erased during this session.")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            } else {
                                ForEach(record.deletedFilePaths, id: \.self) { line in
                                    Text(line)
                                        .font(.system(.body, design: .default))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, idealHeight: 180)
                    .padding(10)
                    .background(
                        Color(.textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                    Text("Total: \(record.filesRemoved) file\(record.filesRemoved == 1 ? "" : "s") removed.")
                        .font(.subheadline)
                        .bold()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Choose a cleaning session above to view its details.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func openPersistentLog() {
        do {
            let url = try PersistentActivityLogger.shared.prepareLogFile()
            guard NSWorkspace.shared.open(url) else {
                logOpenError = "macOS could not find an application to open the log file."
                return
            }
        } catch {
            logOpenError = error.localizedDescription
        }
    }
}
