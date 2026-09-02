import AppKit
import Carbon

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let control = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let shift = Self(rawValue: 1 << 2)
    static let command = Self(rawValue: 1 << 3)
    static let function = Self(rawValue: 1 << 4)

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags, functionKeyDown: Bool = false) {
        var value: ShortcutModifiers = []
        let flags = eventFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.shift) { value.insert(.shift) }
        if flags.contains(.command) { value.insert(.command) }
        if functionKeyDown { value.insert(.function) }
        self = value
    }

    var carbonFlags: UInt32 {
        var result: UInt32 = 0
        if contains(.control) { result |= UInt32(controlKey) }
        if contains(.option) { result |= UInt32(optionKey) }
        if contains(.shift) { result |= UInt32(shiftKey) }
        if contains(.command) { result |= UInt32(cmdKey) }
        if contains(.function) { result |= UInt32(kEventKeyModifierFnMask) }
        return result
    }

    var hasGlobalHotKeyModifier: Bool {
        !intersection([.control, .option, .shift, .command]).isEmpty
    }
}

struct ShortcutDescriptor: Codable, Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: ShortcutModifiers
    let keyLabel: String

    var formatted: String {
        ShortcutFormatter.format(modifiers: modifiers, keyLabel: keyLabel)
    }
}

enum ShortcutFormatter {
    static func descriptor(
        keyCode: UInt16,
        modifiers: ShortcutModifiers,
        charactersIgnoringModifiers: String?
    ) -> ShortcutDescriptor {
        ShortcutDescriptor(
            keyCode: keyCode,
            modifiers: modifiers,
            keyLabel: keyLabel(for: keyCode, charactersIgnoringModifiers: charactersIgnoringModifiers)
        )
    }

    static func format(modifiers: ShortcutModifiers, keyLabel: String) -> String {
        var result = ""
        if modifiers.contains(.function) { result += "fn" }
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyLabel
    }

    static func keyLabel(for keyCode: UInt16, charactersIgnoringModifiers: String? = nil) -> String {
        if let special = specialKeyLabels[keyCode] {
            return special
        }

        if let charactersIgnoringModifiers {
            let printable = charactersIgnoringModifiers
                .unicodeScalars
                .filter { !CharacterSet.controlCharacters.contains($0) }
                .map(String.init)
                .joined()
            if !printable.isEmpty {
                return printable.uppercased()
            }
        }

        return fallbackKeyLabels[keyCode] ?? "Key \(keyCode)"
    }

    // Hardware-independent labels and conventional macOS symbols live in one place.
    static let specialKeyLabels: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        64: "F17", 65: "Num .", 67: "Num ×", 69: "Num +", 71: "Clear",
        75: "Num ÷", 76: "⌅", 78: "Num −", 79: "F18", 80: "F19",
        81: "Num =", 82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3",
        86: "Num 4", 87: "Num 5", 88: "Num 6", 89: "Num 7", 90: "F20",
        91: "Num 8", 92: "Num 9", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
        106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "Page Up", 117: "⌦", 118: "F4",
        119: "End", 120: "F2", 121: "Page Down", 122: "F1", 123: "←",
        124: "→", 125: "↓", 126: "↑"
    ]

    // Used when an event cannot provide a layout-aware printable character, such as
    // when displaying a saved activation shortcut after relaunch.
    static let fallbackKeyLabels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
        7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
        15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "−", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'",
        40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 50: "`"
    ]
}
