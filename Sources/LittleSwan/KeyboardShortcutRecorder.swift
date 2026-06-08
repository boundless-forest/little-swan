import AppKit
import LittleSwanCore
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutConfiguration

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
        field.onShortcutChange = { shortcut in
            context.coordinator.parent.shortcut = shortcut
        }
        field.stringValue = shortcut.displayString
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        context.coordinator.parent = self
        nsView.stringValue = shortcut.displayString
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

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            stringValue = "Press shortcut"
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder, stringValue == "Press shortcut" {
            stringValue = "Record shortcut"
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
    }
}
