import SwiftUI
import Combine

@main
struct TotalTrashApp: App {
    @StateObject private var prefs: PreferencesStore
    @StateObject private var engine: JunkFileEngine
    @StateObject private var volumeMonitor: VolumeMonitor
    @StateObject private var navigation: AppNavigationRouter

    init() {
        let prefs = PreferencesStore()
        let engine = JunkFileEngine(prefs: prefs)
        let monitor = VolumeMonitor(prefs: prefs, engine: engine)
        let navigation = AppNavigationRouter()
        _prefs = StateObject(wrappedValue: prefs)
        _engine = StateObject(wrappedValue: engine)
        _volumeMonitor = StateObject(wrappedValue: monitor)
        _navigation = StateObject(wrappedValue: navigation)
    }

    var body: some Scene {
        // Main App Window
        Window("TotalTrash", id: "main") {
            ContentView()
                .environmentObject(prefs)
                .environmentObject(engine)
                .environmentObject(volumeMonitor)
                .environmentObject(navigation)
        }
        .defaultSize(width: 1080, height: 740)

        // Standalone Cleaning Progress Window
        Window("Cleaning Progress", id: "clean-progress") {
            CleanProgressView()
                .environmentObject(engine)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(prefs)
                .environmentObject(engine)
                .environmentObject(volumeMonitor)
                .environmentObject(navigation)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
