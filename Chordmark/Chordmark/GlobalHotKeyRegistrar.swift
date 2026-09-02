import Carbon
import Foundation

extension Notification.Name {
    static let chordmarkGlobalHotKeyPressed = Notification.Name("ChordmarkGlobalHotKeyPressed")
}

@MainActor
final class GlobalHotKeyRegistrar {
    enum RegistrationError: LocalizedError {
        case unavailable
        case alreadyInUse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "The global hotkey could not be registered."
            case .alreadyInUse:
                "That hotkey is already in use. Try another combination."
            }
        }
    }

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .chordmarkGlobalHotKeyPressed, object: nil)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        if status != noErr {
            eventHandler = nil
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func register(_ shortcut: ShortcutDescriptor) throws {
        unregister()
        guard eventHandler != nil else { throw RegistrationError.unavailable }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: fourCharacterCode("CHMK"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers.carbonFlags,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            throw RegistrationError.alreadyInUse
        }
        hotKey = reference
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
