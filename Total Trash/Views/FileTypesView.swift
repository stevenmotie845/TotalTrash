import SwiftUI

struct FileTypesView: View {
    @EnvironmentObject var prefs: PreferencesStore

    var body: some View {
        List {
            ForEach($prefs.junkPatterns) { $pattern in
                HStack {
                    VStack(alignment: .leading) {
                        Text(pattern.name)
                        Text(pattern.pattern)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $pattern.isEnabled)
                        .labelsHidden()
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("File Types")
    }
}
