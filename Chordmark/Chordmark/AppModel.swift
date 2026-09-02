import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppModel: NSObject, ObservableObject {
    static let shared = AppModel()

    @Published private(set) var activationShortcut: ShortcutDescriptor
    @Published var launchAtLogin: Bool
    @Published var dismissOnOutsideClick: Bool {
        didSet { defaults.set(dismissOnOutsideClick, forKey: Keys.dismissOnOutsideClick) }
    }
    @Published var hotKeyError: String?
    @Published var loginItemError: String?

    private enum Keys {
        static let activationShortcut = "activationShortcut"
        static let dismissOnOutsideClick = "dismissOnOutsideClick"
    }

    private let defaults = UserDefaults.standard
    private let hotKeyRegistrar = GlobalHotKeyRegistrar()
    private let capturePanelController = CapturePanelController()
    private weak var lastExternalApplication: NSRunningApplication?
    private var isRecordingActivationShortcut = false
    private var hasStarted = false

    private override init() {
        let defaultShortcut = ShortcutDescriptor(
            keyCode: 49,
            modifiers: [.control, .option, .command],
            keyLabel: "Space"
        )

        if
            let data = defaults.data(forKey: Keys.activationShortcut),
            let decoded = try? JSONDecoder().decode(ShortcutDescriptor.self, from: data)
        {
            activationShortcut = decoded
        } else {
            activationShortcut = defaultShortcut
        }

        if defaults.object(forKey: Keys.dismissOnOutsideClick) == nil {
            dismissOnOutsideClick = true
        } else {
            dismissOnOutsideClick = defaults.bool(forKey: Keys.dismissOnOutsideClick)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled

        super.init()
        capturePanelController.dismissWhenClickingOutside = { [weak self] in
            self?.dismissOnOutsideClick ?? true
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(globalHotKeyPressed),
            name: .chordmarkGlobalHotKeyPressed,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        lastExternalApplication = NSWorkspace.shared.frontmostApplication
        do {
            try hotKeyRegistrar.register(activationShortcut)
        } catch {
            hotKeyError = error.localizedDescription
        }
    }

    func showCapture() {
        guard !isRecordingActivationShortcut else { return }
        let current = NSWorkspace.shared.frontmostApplication
        let restoreTarget = current?.bundleIdentifier == Bundle.main.bundleIdentifier
            ? lastExternalApplication
            : current
        capturePanelController.show(restoring: restoreTarget)
    }

    func beginRecordingActivationShortcut() {
        hotKeyError = nil
        isRecordingActivationShortcut = true
        hotKeyRegistrar.unregister()
    }

    func cancelRecordingActivationShortcut() {
        guard isRecordingActivationShortcut else { return }
        isRecordingActivationShortcut = false
        restoreCurrentHotKey()
    }

    @discardableResult
    func finishRecordingActivationShortcut(_ candidate: ShortcutDescriptor) -> Bool {
        guard isRecordingActivationShortcut else { return false }
        isRecordingActivationShortcut = false

        guard candidate.modifiers.hasGlobalHotKeyModifier else {
            hotKeyError = "Include Command, Option, Control, or Shift in the hotkey."
            restoreCurrentHotKey()
            return false
        }

        do {
            try hotKeyRegistrar.register(candidate)
            activationShortcut = candidate
            if let data = try? JSONEncoder().encode(candidate) {
                defaults.set(data, forKey: Keys.activationShortcut)
            }
            hotKeyError = nil
            return true
        } catch {
            hotKeyError = error.localizedDescription
            restoreCurrentHotKey()
            return false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    @objc private func globalHotKeyPressed() {
        showCapture()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            application.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        lastExternalApplication = application
    }

    private func restoreCurrentHotKey() {
        do {
            try hotKeyRegistrar.register(activationShortcut)
        } catch {
            hotKeyError = "The previous hotkey could not be restored: \(error.localizedDescription)"
        }
    }
}
