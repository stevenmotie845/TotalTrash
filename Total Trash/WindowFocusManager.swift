import AppKit
import SwiftUI

/// Brings TotalTrash windows to the foreground when opened from the menu bar.
@MainActor
enum WindowFocusManager {
    static let mainWindowTitle = "TotalTrash"
    static let progressWindowTitle = "Cleaning Progress"

    static func activateApplication() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func activate(_ window: NSWindow) {
        activateApplication()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    /// The openWindow action can schedule window creation for a later run-loop pass.
    /// Looking up the explicitly titled scene on the next main-queue turn avoids
    /// accidentally focusing the menu-bar popover itself.
    static func bringToFront(windowTitle: String) {
        activateApplication()

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: {
                $0.title == windowTitle && !($0 is NSPanel)
            }) else {
                return
            }

            activate(window)
        }
    }
}

/// Reports the actual hosting NSWindow when a SwiftUI scene is attached to it.
/// This is a second, event-driven focus path for first presentation/reopening.
struct WindowFocusBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowFocusReportingView {
        let view = WindowFocusReportingView()
        view.onWindowAttached = { window in
            WindowFocusManager.activate(window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowFocusReportingView, context: Context) {}
}

@MainActor
final class WindowFocusReportingView: NSView {
    var onWindowAttached: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let attachedWindow = window else {
            return
        }

        DispatchQueue.main.async { [weak self, weak attachedWindow] in
            guard let self,
                  let attachedWindow,
                  self.window === attachedWindow else {
                return
            }

            self.onWindowAttached?(attachedWindow)
        }
    }
}
