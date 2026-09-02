import AppKit
import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    var focusToken: UUID
    let onCapture: (ShortcutDescriptor) -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let hasCapture: () -> Bool

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        ShortcutCaptureNSView(
            onCapture: onCapture,
            onConfirm: onConfirm,
            onCancel: onCancel,
            hasCapture: hasCapture
        )
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onConfirm = onConfirm
        nsView.onCancel = onCancel
        nsView.hasCapture = hasCapture
        nsView.requestFocus(token: focusToken)
    }
}

final class ShortcutCaptureNSView: NSView {
    var onCapture: (ShortcutDescriptor) -> Void
    var onConfirm: () -> Void
    var onCancel: () -> Void
    var hasCapture: () -> Bool

    private var functionKeyDown = false
    private var lastFocusToken: UUID?

    init(
        onCapture: @escaping (ShortcutDescriptor) -> Void,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        hasCapture: @escaping () -> Bool
    ) {
        self.onCapture = onCapture
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.hasCapture = hasCapture
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focus()
    }

    func requestFocus(token: UUID) {
        guard token != lastFocusToken else { return }
        lastFocusToken = token
        functionKeyDown = false
        focus()
    }

    private func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if event.keyCode == 63 {
            functionKeyDown = event.modifierFlags.contains(.function)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }

        let modifiers = ShortcutModifiers(
            eventFlags: event.modifierFlags,
            functionKeyDown: functionKeyDown
        )

        if event.keyCode == 53 && modifiers.isEmpty {
            onCancel()
            return
        }

        if (event.keyCode == 36 || event.keyCode == 76), modifiers.isEmpty, hasCapture() {
            onConfirm()
            return
        }

        onCapture(
            ShortcutFormatter.descriptor(
                keyCode: event.keyCode,
                modifiers: modifiers,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers
            )
        )
    }
}
