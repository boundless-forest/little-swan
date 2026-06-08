import AppKit
import Carbon
import LittleSwanCore

@MainActor
final class GlobalHotKeyController {
    private static let signature: OSType = 0x4C53574E // LSWN

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        installHandler()
    }

    func update(shortcut: KeyboardShortcutConfiguration) {
        unregister()
        guard shortcut.isValid, let keyCode = shortcut.keyCode else { return }

        var nextHotKeyRef: EventHotKeyRef?
        let nextHotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: 1
        )

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers(from: shortcut.modifierFlags),
            nextHotKeyID,
            GetApplicationEventTarget(),
            0,
            &nextHotKeyRef
        )

        if status == noErr {
            hotKeyRef = nextHotKeyRef
        } else {
            LittleSwanLogger.shortcut.error(
                "Failed to register global shortcut: status=\(status, privacy: .public); keyCode=\(keyCode, privacy: .public); modifiers=\(shortcut.modifierFlags, privacy: .public)"
            )
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.action()
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func carbonModifiers(from modifierFlags: UInt) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if modifierFlags & KeyboardShortcutConfiguration.controlModifierFlag != 0 {
            carbonFlags |= UInt32(controlKey)
        }
        if modifierFlags & KeyboardShortcutConfiguration.optionModifierFlag != 0 {
            carbonFlags |= UInt32(optionKey)
        }
        if modifierFlags & KeyboardShortcutConfiguration.shiftModifierFlag != 0 {
            carbonFlags |= UInt32(shiftKey)
        }
        if modifierFlags & KeyboardShortcutConfiguration.commandModifierFlag != 0 {
            carbonFlags |= UInt32(cmdKey)
        }
        return carbonFlags
    }
}
