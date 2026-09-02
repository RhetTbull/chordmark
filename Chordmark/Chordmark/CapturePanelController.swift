import AppKit
import Combine
import SwiftUI

@MainActor
final class CaptureSession: ObservableObject {
    @Published var shortcut: ShortcutDescriptor?
    @Published var focusToken = UUID()

    var formattedShortcut: String { shortcut?.formatted ?? "" }

    func reset() {
        shortcut = nil
        focusToken = UUID()
    }
}

@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate {
    private let session = CaptureSession()
    private var panel: CapturePanel?
    private weak var applicationToRestore: NSRunningApplication?
    private var isDismissing = false

    var dismissWhenClickingOutside: () -> Bool = { true }

    var isVisible: Bool { panel?.isVisible == true }

    func show(restoring application: NSRunningApplication?) {
        if isVisible {
            panel?.makeKeyAndOrderFront(nil)
            return
        }

        applicationToRestore = application
        isDismissing = false
        session.reset()

        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func copyAndDismiss() {
        guard let shortcut = session.shortcut else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shortcut.formatted, forType: .string)
        dismiss()
    }

    func dismiss() {
        guard isVisible, !isDismissing else { return }
        isDismissing = true
        panel?.orderOut(nil)

        let application = applicationToRestore
        applicationToRestore = nil
        DispatchQueue.main.async {
            application?.activate(options: [])
            self.isDismissing = false
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isDismissing, dismissWhenClickingOutside() else { return }
        dismiss()
    }

    private func makePanel() -> CapturePanel {
        let panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 176),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false

        let rootView = CapturePanelView(
            session: session,
            onCopy: { [weak self] in self?.copyAndDismiss() },
            onCancel: { [weak self] in self?.dismiss() }
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.setAccessibilityTitle("Capture Shortcut")
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2 + visibleFrame.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }
}

final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CapturePanelView: View {
    @ObservedObject var session: CaptureSession
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Capture Shortcut")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel")
                .accessibilityLabel("Cancel")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.65))

                if session.shortcut == nil {
                    Text("Press a keyboard shortcut")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                } else {
                    Text(session.formattedShortcut)
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .accessibilityLabel("Captured shortcut \(session.formattedShortcut)")
                }

                KeyCaptureView(
                    focusToken: session.focusToken,
                    onCapture: { session.shortcut = $0 },
                    onConfirm: onCopy,
                    onCancel: onCancel,
                    hasCapture: { session.shortcut != nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            }
            .frame(height: 68)

            HStack {
                Text("Return to copy · Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Copy", action: onCopy)
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.shortcut == nil)
                    .accessibilityIdentifier("copyShortcutButton")
            }
        }
        .padding(18)
        .frame(width: 360, height: 176)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 0.5)
        }
    }
}
