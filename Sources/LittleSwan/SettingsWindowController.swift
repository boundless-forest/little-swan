import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init<Content: View>(rootView: Content) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Little Swan Settings"
        window.backgroundColor = LittleSwanTheme.Palette.appKitWindowCanvas
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 760, height: 500)
        window.setFrameAutosaveName("LittleSwanSettingsWindow")
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
