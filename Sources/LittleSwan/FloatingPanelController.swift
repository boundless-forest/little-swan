import AppKit
import Combine
import LittleSwanCore
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel
    private let configStore: ConfigStore
    private let resizeDelegate: PanelResizeDelegate
    private var cancellables = Set<AnyCancellable>()

    init<Content: View>(
        rootView: Content,
        configStore: ConfigStore
    ) {
        self.configStore = configStore
        resizeDelegate = PanelResizeDelegate(configStore: configStore)

        let initialSize = Self.contentSize(
            configuration: configStore.configuration,
            visibleFrame: NSScreen.main?.visibleFrame
        )

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Little Swan"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentMinSize = NSSize(
            width: PanelPresentation.minimumContentWidth,
            height: PanelPresentation.minimumContentHeight
        )
        panel.delegate = resizeDelegate
        panel.contentView = NSHostingView(rootView: rootView)

        observeScreenChanges()
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        applyPreferredFrame(animated: false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func observeScreenChanges() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.applyPreferredFrame(animated: self?.panel.isVisible == true)
            }
            .store(in: &cancellables)
    }

    private func applyPreferredFrame(animated: Bool) {
        guard let screen = panel.screen ?? NSScreen.main else { return }

        // Recompute from the active screen each time because users can move between displays,
        // resize the Dock, or reopen the panel after resizing it manually.
        let contentSize = Self.contentSize(
            configuration: configStore.configuration,
            visibleFrame: screen.visibleFrame
        )

        let frameSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let targetFrame = PanelPlacement.frame(
            frameSize: frameSize,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )

        panel.setFrame(targetFrame, display: true, animate: animated)
    }

    private static func contentSize(
        configuration: AppConfiguration,
        visibleFrame: NSRect?
    ) -> NSSize {
        let availableWidth = visibleFrame.map { Int($0.width) }
        let availableHeight = visibleFrame.map {
            max(PanelPresentation.minimumContentHeight, Int($0.height) - PanelPresentation.windowFrameHeightReserve)
        }
        let clampedSize = PanelPresentation.clampedContentSize(
            configuration.panelContentSize,
            availableWidth: availableWidth,
            availableHeight: availableHeight
        )

        return NSSize(
            width: clampedSize.width,
            height: clampedSize.height
        )
    }
}

@MainActor
private final class PanelResizeDelegate: NSObject, NSWindowDelegate {
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }

        let contentSize = panel.contentRect(forFrameRect: panel.frame).size
        let persistedSize = PanelPresentation.clampedContentSize(
            PanelContentSizeConfiguration(
                width: Int(contentSize.width.rounded()),
                height: Int(contentSize.height.rounded())
            ),
            availableWidth: panel.screen.map { Int($0.visibleFrame.width) },
            availableHeight: panel.screen.map {
                max(PanelPresentation.minimumContentHeight, Int($0.visibleFrame.height) - PanelPresentation.windowFrameHeightReserve)
            }
        )

        guard configStore.configuration.panelContentSize != persistedSize else { return }
        configStore.configuration.panelContentSize = persistedSize
        configStore.save()
    }
}

private enum PanelPlacement {
    static func frame(
        frameSize: NSSize,
        screenFrame: NSRect,
        visibleFrame: NSRect,
        dockConfiguration: DockConfiguration = .current
    ) -> NSRect {
        let margin = CGFloat(PanelPresentation.screenMargin)
        let dockAwareFrame = dockAwareFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            dockConfiguration: dockConfiguration
        )
        let safeFrame = dockAwareFrame.insetBy(dx: margin, dy: margin)

        let preferredX = safeFrame.midX - frameSize.width / 2
        let x = clamped(preferredX, lowerBound: safeFrame.minX, upperBound: safeFrame.maxX - frameSize.width)

        let y = clamped(
            safeFrame.minY,
            lowerBound: dockAwareFrame.minY + margin,
            upperBound: safeFrame.maxY - frameSize.height
        )

        return NSRect(origin: NSPoint(x: x, y: y), size: frameSize)
    }

    private static func dockAwareFrame(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        dockConfiguration: DockConfiguration
    ) -> NSRect {
        var frame = visibleFrame
        let hiddenDockClearance = dockConfiguration.hiddenDockClearance

        switch dockConfiguration.orientation {
        case .bottom:
            // visibleFrame excludes a visible Dock. When auto-hide is enabled AppKit reports almost
            // no inset, so reserve a small strip to avoid placing the panel on top of the Dock reveal zone.
            let visibleDockInset = max(0, visibleFrame.minY - screenFrame.minY)
            let bottomInset = visibleDockInset > 1 ? visibleDockInset : hiddenDockClearance
            frame.origin.y = screenFrame.minY + bottomInset
            frame.size.height = max(0, visibleFrame.maxY - frame.minY)
        case .left:
            // A real left/right Dock already shrinks visibleFrame; only synthesize clearance when
            // the inset is effectively zero, which indicates an auto-hidden Dock.
            let visibleDockInset = max(0, visibleFrame.minX - screenFrame.minX)
            guard visibleDockInset <= 1 else { break }
            frame.origin.x = screenFrame.minX + hiddenDockClearance
            frame.size.width = max(0, visibleFrame.maxX - frame.minX)
        case .right:
            // Keep the right edge away from the hidden Dock without moving the origin, so centered
            // placement continues to use the same coordinate base.
            let visibleDockInset = max(0, screenFrame.maxX - visibleFrame.maxX)
            guard visibleDockInset <= 1 else { break }
            frame.size.width = max(0, screenFrame.maxX - hiddenDockClearance - frame.minX)
        }

        return frame
    }

    private static func clamped(_ value: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> CGFloat {
        guard upperBound >= lowerBound else { return lowerBound }
        return min(max(value, lowerBound), upperBound)
    }
}

private struct DockConfiguration {
    let orientation: DockOrientation
    let tileSize: CGFloat

    static var current: DockConfiguration {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let orientation = DockOrientation(rawValue: defaults?.string(forKey: "orientation") ?? "") ?? .bottom
        let configuredTileSize = defaults?.double(forKey: "tilesize") ?? 0
        let tileSize = configuredTileSize > 0 ? configuredTileSize : 64

        return DockConfiguration(orientation: orientation, tileSize: CGFloat(tileSize))
    }

    var hiddenDockClearance: CGFloat {
        // The Dock can reveal beyond its configured tile size because of padding and magnification.
        // Bound the reserve so tiny and very large Dock settings still produce usable panel space.
        min(max(tileSize + 20, 56), 128)
    }
}

private enum DockOrientation: String {
    case bottom
    case left
    case right
}
