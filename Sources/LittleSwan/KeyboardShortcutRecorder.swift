import AppKit
import LittleSwanCore
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutConfiguration
    var accessibilityLabel = "Open or hide Little Swan shortcut"
    var accessibilityHelp = "Click, then press a keyboard shortcut with at least one modifier key"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.isEditable = false
        field.isSelectable = false
        field.isBezeled = false
        field.drawsBackground = true
        field.alignment = .center
        field.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        field.placeholderString = "Click and press shortcut"
        field.focusRingType = .none
        field.configureAccessibility(label: accessibilityLabel, help: accessibilityHelp)
        field.onShortcutChange = { shortcut in
            context.coordinator.parent.shortcut = shortcut
        }
        field.updateShortcut(displayString: shortcut.displayString, isValid: shortcut.isValid)
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        context.coordinator.parent = self
        nsView.configureAccessibility(label: accessibilityLabel, help: accessibilityHelp)
        nsView.updateShortcut(displayString: shortcut.displayString, isValid: shortcut.isValid)
    }

    final class Coordinator {
        var parent: KeyboardShortcutRecorder

        init(_ parent: KeyboardShortcutRecorder) {
            self.parent = parent
        }
    }
}

final class ShortcutRecorderField: NSTextField {
    private enum VisualState {
        case idle
        case focused
        case recording
        case invalid
    }

    private static let recordingPrompt = "Press shortcut now…"
    private static let invalidPrompt = "Add a modifier key"

    var onShortcutChange: ((KeyboardShortcutConfiguration) -> Void)?
    private var recordedDisplayString = ""
    private var shortcutIsValid = true
    private var visualState: VisualState = .idle
    private var baseAccessibilityLabel = ""
    private var baseAccessibilityHelp = ""
    private var lastAccessibilityLabel = ""

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    func configureAccessibility(label: String, help: String) {
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        baseAccessibilityLabel = label
        baseAccessibilityHelp = help
        synchronizeAccessibilityDescription()
    }

    func updateShortcut(displayString: String, isValid: Bool) {
        recordedDisplayString = displayString
        shortcutIsValid = isValid

        if visualState != .recording {
            stringValue = isValid ? displayString : Self.invalidPrompt
            visualState = isValid
                ? (window?.firstResponder === self ? .focused : .idle)
                : .invalid
        }

        applyVisualStyle()
        synchronizeAccessibilityDescription()
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            beginRecording()
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            if visualState == .recording {
                stringValue = shortcutIsValid ? recordedDisplayString : Self.invalidPrompt
            }
            visualState = shortcutIsValid ? .idle : .invalid
            applyVisualStyle()
            synchronizeAccessibilityDescription()
        }
        return didResignFirstResponder
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let shortcut = KeyboardShortcutConfiguration(
            keyCode: UInt16(event.keyCode),
            modifierFlags: flags.rawValue
        )
        onShortcutChange?(shortcut)
        if shortcut.isValid {
            recordedDisplayString = shortcut.displayString
            stringValue = shortcut.displayString
            shortcutIsValid = true
            visualState = .focused
        } else {
            shortcutIsValid = false
            stringValue = Self.invalidPrompt
            visualState = .invalid
        }

        applyVisualStyle()
        synchronizeAccessibilityDescription()
    }

    override func accessibilityPerformPress() -> Bool {
        guard let window else { return false }
        if window.firstResponder === self {
            beginRecording()
            return true
        }
        return window.makeFirstResponder(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyVisualStyle()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        notificationCenter.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        if let window {
            notificationCenter.addObserver(
                self,
                selector: #selector(windowKeyStatusDidChange(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(windowKeyStatusDidChange(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }

        applyVisualStyle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureAppearance() {
        wantsLayer = true
        layer?.cornerRadius = LittleSwanTheme.Radius.compact
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        applyVisualStyle()
    }

    private func beginRecording() {
        visualState = .recording
        stringValue = Self.recordingPrompt
        applyVisualStyle()
        synchronizeAccessibilityDescription()
    }

    @objc private func windowKeyStatusDidChange(_ notification: Notification) {
        applyVisualStyle()
    }

    private func applyVisualStyle() {
        let palette = LittleSwanTheme.Palette.self
        let backgroundColor: NSColor
        let borderColor: NSColor
        let foregroundColor: NSColor
        let borderWidth: CGFloat
        let activeVisualState: VisualState

        if window?.isKeyWindow == true {
            activeVisualState = visualState
        } else {
            switch visualState {
            case .focused, .recording:
                activeVisualState = .idle
            case .idle, .invalid:
                activeVisualState = visualState
            }
        }

        switch activeVisualState {
        case .idle:
            backgroundColor = palette.appKitSurface
            borderColor = palette.appKitBorder
            foregroundColor = palette.appKitTextPrimary
            borderWidth = LittleSwanTheme.Stroke.regular
        case .focused:
            backgroundColor = palette.appKitSurface
            borderColor = palette.appKitAccent
            foregroundColor = palette.appKitTextPrimary
            borderWidth = LittleSwanTheme.Stroke.focus
        case .recording:
            backgroundColor = palette.appKitAccent.withAlphaComponent(0.10)
            borderColor = palette.appKitAccent
            foregroundColor = palette.appKitAccent
            borderWidth = LittleSwanTheme.Stroke.focus
        case .invalid:
            backgroundColor = palette.appKitDanger.withAlphaComponent(0.09)
            borderColor = palette.appKitDanger
            foregroundColor = palette.appKitDanger
            borderWidth = window?.isKeyWindow == true && window?.firstResponder === self
                ? LittleSwanTheme.Stroke.focus
                : LittleSwanTheme.Stroke.regular
        }

        self.backgroundColor = backgroundColor
        textColor = foregroundColor
        // CALayer retains a concrete CGColor, so resolve the adaptive border for the active appearance.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = borderColor.cgColor
        }
        layer?.borderWidth = borderWidth
    }

    private func synchronizeAccessibilityDescription() {
        let stateDescription: String
        switch visualState {
        case .recording:
            stateDescription = "Recording. Press shortcut now."
        case .invalid:
            stateDescription = "Invalid shortcut. Include at least one modifier key."
        case .idle, .focused:
            stateDescription = recordedDisplayString.isEmpty
                ? "No shortcut configured."
                : "Current shortcut: \(recordedDisplayString)."
        }

        let accessibilityLabel = "\(baseAccessibilityLabel). \(stateDescription)"
        setAccessibilityLabel(accessibilityLabel)
        setAccessibilityHelp(baseAccessibilityHelp)

        guard accessibilityLabel != lastAccessibilityLabel else { return }
        lastAccessibilityLabel = accessibilityLabel
        guard window != nil else { return }
        NSAccessibility.post(element: self, notification: .titleChanged)
    }
}
