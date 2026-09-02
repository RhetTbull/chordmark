import AppKit
import SwiftUI

@main
struct ChordmarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("Chordmark", systemImage: "command") {
            Button("Capture Shortcut…") {
                model.showCapture()
            }
            .keyboardShortcut("n")

            SettingsLink {
                Text("Configure Hotkey…")
            }

            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchAtLogin },
                set: model.setLaunchAtLogin
            ))

            Divider()

            Button("About Chordmark") {
                model.showAbout()
            }

            Button("Quit Chordmark") {
                model.quit()
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
        .defaultSize(width: 450, height: 280)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.start()

        // Gives UI tests a way to exercise the otherwise menu-bar-initiated panel.
        if ProcessInfo.processInfo.arguments.contains("--show-capture") {
            DispatchQueue.main.async {
                AppModel.shared.showCapture()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
