import SwiftUI

@available(macOS 13.0, *)
@MainActor
class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: SettingsView())
        window.contentView = hostingView

        self.init(window: window)
    }
}

@available(macOS 13.0, *)
@MainActor
class SettingsManager: ObservableObject {
    private var windowController: SettingsWindowController?

    func showSettings() {
        if windowController == nil {
            windowController = SettingsWindowController()
        }

        guard let window = windowController?.window else { return }

        NSApp.activate(ignoringOtherApps: true)

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
            window.makeFirstResponder(window.contentView)
        }
    }
}
