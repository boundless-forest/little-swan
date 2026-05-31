import AppKit
import Combine
import SaywiseCore
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel
    private let configStore: ConfigStore
    private let viewModel: TranslationViewModel
    private var cancellables = Set<AnyCancellable>()

    init<Content: View>(
        rootView: Content,
        configStore: ConfigStore,
        viewModel: TranslationViewModel
    ) {
        self.configStore = configStore
        self.viewModel = viewModel

        let initialSize = Self.contentSize(
            configuration: configStore.configuration,
            isExpanded: viewModel.isPanelExpanded,
            visibleFrame: NSScreen.main?.visibleFrame
        )
        viewModel.updatePanelContentSize(initialSize)

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Saywise"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: rootView)

        observePanelPreferences()
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

    private func observePanelPreferences() {
        configStore.$configuration
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyPreferredFrame(animated: self?.panel.isVisible == true)
            }
            .store(in: &cancellables)

        viewModel.$isPanelExpanded
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyPreferredFrame(animated: self?.panel.isVisible == true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.applyPreferredFrame(animated: self?.panel.isVisible == true)
            }
            .store(in: &cancellables)
    }

    private func applyPreferredFrame(animated: Bool) {
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let contentSize = Self.contentSize(
            configuration: configStore.configuration,
            isExpanded: viewModel.isPanelExpanded,
            visibleFrame: screen.visibleFrame
        )
        viewModel.updatePanelContentSize(contentSize)

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
        isExpanded: Bool,
        visibleFrame: NSRect?
    ) -> NSSize {
        let availableWidth = visibleFrame.map { Int($0.width) }
        let availableHeight = visibleFrame.map { max(160, Int($0.height) - PanelPresentation.screenMargin * 2) }
        let preferredHeight = PanelPresentation.height(
            layout: configuration.panelLayout,
            isExpanded: isExpanded
        )

        return NSSize(
            width: PanelPresentation.clampedWidth(configuration.panelWidth, availableWidth: availableWidth),
            height: min(preferredHeight, availableHeight ?? preferredHeight)
        )
    }
}

private enum PanelPlacement {
    static func frame(frameSize: NSSize, screenFrame: NSRect, visibleFrame: NSRect) -> NSRect {
        let margin = CGFloat(PanelPresentation.screenMargin)
        let safeFrame = visibleFrame.insetBy(dx: margin, dy: margin)
        let x = clamped(
            safeFrame.midX - frameSize.width / 2,
            lowerBound: safeFrame.minX,
            upperBound: safeFrame.maxX - frameSize.width
        )

        // AppKit's visibleFrame already accounts for a visible Dock. When the Dock is hidden,
        // the same calculation naturally falls back to the physical screen edge plus margin.
        let y = clamped(
            safeFrame.minY,
            lowerBound: screenFrame.minY + margin,
            upperBound: safeFrame.maxY - frameSize.height
        )

        return NSRect(origin: NSPoint(x: x, y: y), size: frameSize)
    }

    private static func clamped(_ value: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> CGFloat {
        guard upperBound >= lowerBound else { return lowerBound }
        return min(max(value, lowerBound), upperBound)
    }
}
