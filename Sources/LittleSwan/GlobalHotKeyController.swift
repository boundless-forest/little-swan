import AppKit
import Carbon
import LittleSwanCore

@MainActor
final class GlobalHotKeyController {
    private static let signature: OSType = 0x4C53574E // LSWN

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let identifier: UInt32
    private let action: () -> Void

    init(identifier: UInt32, action: @escaping () -> Void) {
        self.identifier = identifier
        self.action = action
        installHandler()
    }

    func update(shortcut: KeyboardShortcutConfiguration) {
        unregister()
        guard shortcut.isValid, let keyCode = shortcut.keyCode else { return }

        var nextHotKeyRef: EventHotKeyRef?
        let nextHotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: identifier
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
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID(signature: 0, id: 0)
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr,
                      hotKeyID.signature == GlobalHotKeyController.signature,
                      hotKeyID.id == controller.identifier else {
                    return OSStatus(eventNotHandledErr)
                }

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
