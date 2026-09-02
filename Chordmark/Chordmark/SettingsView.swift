import SwiftUI

struct SettingsView: View {
    @ObservedObject private var model = AppModel.shared
    @State private var isRecording = false
    @State private var focusToken = UUID()

    var body: some View {
        Form {
            Section("Activation") {
                LabeledContent("Global hotkey") {
                    HStack(spacing: 10) {
                        Text(isRecording ? "Press a shortcut…" : model.activationShortcut.formatted)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .frame(minWidth: 110)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

                        Button(isRecording ? "Cancel" : "Record New Hotkey") {
                            if isRecording {
                                stopRecording()
                            } else {
                                model.beginRecordingActivationShortcut()
                                isRecording = true
                                focusToken = UUID()
                            }
                        }
                    }
                }

                if let error = model.hotKeyError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Choose a key with Command, Option, Control, or Shift. Chordmark checks whether macOS can register it before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: model.setLaunchAtLogin
                ))
                Toggle("Dismiss capture when clicking outside", isOn: $model.dismissOnOutsideClick)

                if let error = model.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
        .overlay {
            if isRecording {
                KeyCaptureView(
                    focusToken: focusToken,
                    onCapture: record,
                    onConfirm: {},
                    onCancel: stopRecording,
                    hasCapture: { false }
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
            }
        }
        .onDisappear {
            if isRecording { stopRecording() }
        }
    }

    private func record(_ shortcut: ShortcutDescriptor) {
        guard isRecording else { return }
        if model.finishRecordingActivationShortcut(shortcut) {
            isRecording = false
        } else {
            // Registration failed and the prior hotkey was restored. Let the user
            // explicitly begin another attempt so ordinary typing is not captured.
            isRecording = false
        }
    }

    private func stopRecording() {
        model.cancelRecordingActivationShortcut()
        isRecording = false
    }
}
