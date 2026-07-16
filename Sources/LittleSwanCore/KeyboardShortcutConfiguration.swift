import Foundation

public struct KeyboardShortcutConfiguration: Codable, Equatable, Sendable {
    public static let shiftModifierFlag: UInt = 1 << 17
    public static let controlModifierFlag: UInt = 1 << 18
    public static let optionModifierFlag: UInt = 1 << 19
    public static let commandModifierFlag: UInt = 1 << 20

    public static let aKeyCode: UInt16 = 0
    public static let zeroKeyCode: UInt16 = 29
    public static let returnKeyCode: UInt16 = 36
    public static let spaceKeyCode: UInt16 = 49

    public static let defaultToggleShortcut = KeyboardShortcutConfiguration(
        keyCode: aKeyCode,
        modifierFlags: controlModifierFlag
    )

    public static let defaultResetWindowShortcut = KeyboardShortcutConfiguration(
        keyCode: zeroKeyCode,
        modifierFlags: controlModifierFlag
    )

    public static let fallbackResetWindowShortcut = KeyboardShortcutConfiguration(
        keyCode: zeroKeyCode,
        modifierFlags: controlModifierFlag | shiftModifierFlag
    )

    public static let defaultGenerateTranslationShortcut = KeyboardShortcutConfiguration(
        keyCode: returnKeyCode,
        modifierFlags: commandModifierFlag
    )

    public static let fallbackGenerateTranslationShortcut = KeyboardShortcutConfiguration(
        keyCode: returnKeyCode,
        modifierFlags: commandModifierFlag | shiftModifierFlag
    )

    public var keyCode: UInt16?
    public var modifierFlags: UInt

    public init(keyCode: UInt16?, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags & Self.supportedModifierMask
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode)
        let decodedModifierFlags = try container.decodeIfPresent(UInt.self, forKey: .modifierFlags) ?? 0
        self.init(keyCode: decodedKeyCode, modifierFlags: decodedModifierFlags)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(keyCode, forKey: .keyCode)
        try container.encode(modifierFlags, forKey: .modifierFlags)
    }

    public var isValid: Bool {
        keyCode != nil && modifierFlags & Self.supportedModifierMask != 0
    }

    public func conflicts(with other: KeyboardShortcutConfiguration) -> Bool {
        isValid && other.isValid && self == other
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }

    public var displayString: String {
        guard let keyCode else { return "Record shortcut" }

        let modifierDisplay = Self.modifierDisplayString(modifierFlags)
        let keyDisplay = Self.keyDisplayString(for: keyCode)
        guard !modifierDisplay.isEmpty else { return keyDisplay }
        return modifierDisplay + keyDisplay
    }

    public var menuKeyEquivalent: String? {
        guard isValid, let keyCode else { return nil }
        return Self.menuKeyEquivalentNames[keyCode]
    }

    public var menuModifierFlags: UInt? {
        guard isValid, menuKeyEquivalent != nil else { return nil }
        return modifierFlags
    }

    public static let supportedModifierMask = shiftModifierFlag
        | controlModifierFlag
        | optionModifierFlag
        | commandModifierFlag

    private static func modifierDisplayString(_ flags: UInt) -> String {
        var display = ""
        if flags & controlModifierFlag != 0 { display += "⌃" }
        if flags & optionModifierFlag != 0 { display += "⌥" }
        if flags & shiftModifierFlag != 0 { display += "⇧" }
        if flags & commandModifierFlag != 0 { display += "⌘" }
        return display
    }

    private static func keyDisplayString(for keyCode: UInt16) -> String {
        keyDisplayNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyDisplayNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc", 65: ".", 67: "*",
        69: "+", 71: "Clear", 75: "/", 76: "Enter", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2",
        85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6",
        98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    private static let menuKeyEquivalentNames: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "\r", 37: "l",
        38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m",
        47: ".", 48: "\t", 49: " ", 50: "`", 51: "\u{8}", 53: "\u{1b}", 65: ".", 67: "*",
        69: "+", 71: "\u{3}", 75: "/", 76: "\r", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2",
        85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        96: functionKeyEquivalent(0xF708), 97: functionKeyEquivalent(0xF709),
        98: functionKeyEquivalent(0xF70A), 99: functionKeyEquivalent(0xF706),
        100: functionKeyEquivalent(0xF70B), 101: functionKeyEquivalent(0xF70C),
        103: functionKeyEquivalent(0xF70E), 105: functionKeyEquivalent(0xF710),
        107: functionKeyEquivalent(0xF711), 109: functionKeyEquivalent(0xF70D),
        111: functionKeyEquivalent(0xF70F), 113: functionKeyEquivalent(0xF712),
        114: functionKeyEquivalent(0xF746), 115: functionKeyEquivalent(0xF729),
        116: functionKeyEquivalent(0xF72C), 117: functionKeyEquivalent(0xF728),
        118: functionKeyEquivalent(0xF707), 119: functionKeyEquivalent(0xF72B),
        120: functionKeyEquivalent(0xF705), 121: functionKeyEquivalent(0xF72D),
        122: functionKeyEquivalent(0xF704), 123: functionKeyEquivalent(0xF702),
        124: functionKeyEquivalent(0xF703), 125: functionKeyEquivalent(0xF701),
        126: functionKeyEquivalent(0xF700)
    ]

    private static func functionKeyEquivalent(_ scalar: UInt32) -> String {
        String(UnicodeScalar(scalar)!)
    }
}
