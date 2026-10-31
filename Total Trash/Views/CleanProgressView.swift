import SwiftUI

struct CleanProgressView: View {
    @EnvironmentObject private var engine: JunkFileEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: (engine.isCleaning || engine.isScanning) ? (engine.isScanning ? "magnifyingglass" : "sparkles") : "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle((engine.isCleaning || engine.isScanning) ? .blue : .green)
                    .frame(width: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.currentVolumeName.map { "\(engine.operationTitle) \($0)" } ?? "TotalTrash")
                        .font(.title3.weight(.semibold))
                    Text(engine.progressMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    engine.showProgressWindow = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close progress window; cleaning continues in the background")
            }

            if let fraction = engine.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                Text(engine.isScanning ? "Scan complete · 100%" : "Removing items · \(Int(fraction * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                Text(engine.isScanning ? "Scanning filesystem… progress is indeterminate" : "Scanning filesystem… progress is indeterminate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                metric(value: "\(engine.searchedCount)", label: "Scanned")
                Divider().frame(height: 34)
                metric(value: "\(engine.foundCount)", label: "Junk found")
                Divider().frame(height: 34)
                metric(value: "\(engine.deletedCount)", label: "Removed")
            }
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))

            if !engine.currentItemPath.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT ITEM")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(engine.currentItemPath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Text("ACTIVITY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(engine.currentLogLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 230)
                .background(Color(.textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .onChange(of: engine.currentLogLines.count) { count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }

            HStack {
                if engine.isCleaning || engine.isScanning {
                    Label(engine.isScanning ? "Scan in progress" : "Cleaning in progress", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Hide") {
                        engine.showProgressWindow = false
                        dismiss()
                    }
                } else {
                    Label("Operation finished", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Done") {
                        engine.showProgressWindow = false
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 560)
        .background {
            WindowFocusBridge()
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
