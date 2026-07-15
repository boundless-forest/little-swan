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
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.alignment = .center
        field.font = .systemFont(ofSize: 13, weight: .medium)
        field.placeholderString = "Click and press shortcut"
        field.focusRingType = .exterior
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityHelp(accessibilityHelp)
        field.onShortcutChange = { shortcut in
            context.coordinator.parent.shortcut = shortcut
        }
        field.recordedDisplayString = shortcut.displayString
        field.stringValue = shortcut.displayString
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        context.coordinator.parent = self
        nsView.setAccessibilityLabel(accessibilityLabel)
        nsView.setAccessibilityHelp(accessibilityHelp)
        nsView.recordedDisplayString = shortcut.displayString
        if nsView.window?.firstResponder !== nsView {
            nsView.stringValue = shortcut.displayString
        }
    }

    final class Coordinator {
        var parent: KeyboardShortcutRecorder

        init(_ parent: KeyboardShortcutRecorder) {
            self.parent = parent
        }
    }
}

final class ShortcutRecorderField: NSTextField {
    var onShortcutChange: ((KeyboardShortcutConfiguration) -> Void)?
    var recordedDisplayString = ""

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            stringValue = "Press shortcut now…"
            setAccessibilityValue("Recording. Press shortcut now.")
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder, stringValue == "Press shortcut now…" {
            stringValue = recordedDisplayString
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
        } else {
            stringValue = "Add a modifier key"
        }
    }
}
