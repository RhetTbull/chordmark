import Foundation
import Testing
@testable import Chordmark

@MainActor
struct ShortcutFormatterTests {
    @Test func ordersModifiersUsingAppleConvention() {
        let shortcut = ShortcutDescriptor(
            keyCode: 5,
            modifiers: [.command, .shift],
            keyLabel: "G"
        )
        #expect(shortcut.formatted == "⇧⌘G")
    }

    @Test func rendersEverySupportedModifierInStableOrder() {
        let result = ShortcutFormatter.format(
            modifiers: [.command, .function, .shift, .control, .option],
            keyLabel: "P"
        )
        #expect(result == "fn⌃⌥⇧⌘P")
    }

    @Test func rendersSpecialKeys() {
        #expect(ShortcutFormatter.keyLabel(for: 53) == "⎋")
        #expect(ShortcutFormatter.keyLabel(for: 48) == "⇥")
        #expect(ShortcutFormatter.keyLabel(for: 36) == "↩")
        #expect(ShortcutFormatter.keyLabel(for: 76) == "⌅")
        #expect(ShortcutFormatter.keyLabel(for: 51) == "⌫")
        #expect(ShortcutFormatter.keyLabel(for: 117) == "⌦")
        #expect(ShortcutFormatter.keyLabel(for: 123) == "←")
        #expect(ShortcutFormatter.keyLabel(for: 126) == "↑")
    }

    @Test func usesLayoutAwareEventCharacter() {
        #expect(ShortcutFormatter.keyLabel(for: 0, charactersIgnoringModifiers: "å") == "Å")
    }

    @Test func providesReadableFallbackForUnknownKeys() {
        #expect(ShortcutFormatter.keyLabel(for: 255, charactersIgnoringModifiers: nil) == "Key 255")
    }

    @Test func shortcutRoundTripsThroughPreferencesEncoding() throws {
        let original = ShortcutDescriptor(
            keyCode: 49,
            modifiers: [.control, .option, .command],
            keyLabel: "Space"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutDescriptor.self, from: data)
        #expect(decoded == original)
    }
}
