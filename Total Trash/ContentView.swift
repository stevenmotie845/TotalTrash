import SwiftUI
import Combine

/// The destinations displayed in the main TotalTrash window.
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case fileTypes = "File Types"
    case activity = "Activity Log"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .fileTypes: return "doc.badge.gearshape"
        case .activity: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

/// Shared navigation state used by the sidebar and menu-bar shortcuts.
@MainActor
final class AppNavigationRouter: ObservableObject {
    @Published var selectedSection: SidebarSection = .dashboard

    func navigate(to section: SidebarSection) {
        selectedSection = section
    }
}

struct ContentView: View {
    @EnvironmentObject private var navigation: AppNavigationRouter

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                pageHeader

                Divider()

                destination
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 880, minHeight: 600)
        .background {
            WindowFocusBridge()
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("TotalTrash")
                    .font(.system(size: 17, weight: .semibold))
            } icon: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 18)

            ForEach(SidebarSection.allCases) { section in
                sidebarButton(for: section)
            }

            Spacer(minLength: 12)

            Text("External drive cleaner")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .padding(12)
        .frame(width: 205)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.055))
    }

    private func sidebarButton(for section: SidebarSection) -> some View {
        let isSelected = navigation.selectedSection == section

        return Button {
            navigation.navigate(to: section)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)

                Text(section.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.rawValue)
        .accessibilityIdentifier("sidebar-\(section.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .help("Show \(section.rawValue)")
    }

    // MARK: - Detail

    private var pageHeader: some View {
        HStack {
            Text(navigation.selectedSection.rawValue)
                .font(.system(size: 19, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.025))
    }

    @ViewBuilder
    private var destination: some View {
        switch navigation.selectedSection {
        case .dashboard:
            DashboardView()
        case .fileTypes:
            FileTypesView()
        case .activity:
            ActivityLogView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}
