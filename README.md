# Chordmark

Chordmark is a lightweight native macOS menu bar utility for capturing keyboard shortcuts and copying their Apple-style representation as plain Unicode text.

For example, pressing Shift-Command-G produces `⇧⌘G`.

## Features

- Lives entirely in the menu bar with no Dock icon or persistent window.
- Captures letters, numbers, punctuation, function keys, navigation keys, numeric-keypad keys, and standard modifiers.
- Formats modifiers in Apple’s standard Control, Option, Shift, Command order.
- Copies the result as plain text and immediately returns focus to the previous application.
- Provides a configurable global activation hotkey. The default is `⌃⌥⌘Space`.
- Supports launching at login and optionally dismissing when clicking outside the capture panel.
- Requires no Accessibility or Input Monitoring permission.
- Contains no analytics, network access, shortcut history, or other keystroke storage.

## Requirements

- macOS 15.7 or later
- Xcode with the macOS 15.7 SDK or later

## Build and run

1. Open `Chordmark/Chordmark.xcodeproj` in Xcode.
2. Select the Chordmark scheme and your Mac as the destination.
3. Build and run with Command-R.

For launch-at-login behavior, place the built application in `/Applications` before enabling the option.

You can also build from the command line:

```sh
xcodebuild \
  -project Chordmark/Chordmark.xcodeproj \
  -scheme Chordmark \
  -destination 'platform=macOS' \
  build
```

## Usage

1. Click the command-symbol icon in the menu bar and choose **Capture Shortcut…**, or press the configured global hotkey.
2. Press the shortcut you want to represent.
3. Press Return or click **Copy**.

Press Escape to dismiss the panel without changing the clipboard. Opening the capture panel again always begins with a blank shortcut.

Choose **Configure Hotkey…** from the menu to change the activation shortcut or adjust behavior settings. Chordmark asks macOS to register a proposed hotkey before saving it, so combinations already claimed by another application are rejected where the system can detect them.

## Testing

Run the formatter and persistence tests with:

```sh
xcodebuild test \
  -project Chordmark/Chordmark.xcodeproj \
  -scheme Chordmark \
  -destination 'platform=macOS' \
  -only-testing:ChordmarkTests
```

The UI tests require macOS UI-automation support to be available to Xcode. They exercise capture formatting, Return-to-copy dismissal, and Escape dismissal.

## Create a release

The release script archives Chordmark with a Developer ID certificate, verifies
the exported signature and version, notarizes and staples the application,
packages it with an Applications shortcut in a compressed DMG, and then signs,
notarizes, staples, and validates the finished disk image.

Before the first release, install a **Developer ID Application** certificate
for the configured team and save App Store Connect credentials for
`notarytool`:

```sh
xcrun notarytool store-credentials Chordmark-notary \
  --apple-id 'developer@example.com' \
  --team-id K4ZMVP896P \
  --password 'app-specific-password'
```

Create a release with:

```sh
scripts/release_dmg.sh \
  --version 1.0.0 \
  --notary-profile Chordmark-notary
```

By default, the build number is the number of commits reachable from `HEAD`.
Artifacts and notarization logs are written to `dist/<version>/`, and the
finished image is named
`Chordmark-<version>-build-<build-number>.dmg`. Run
`scripts/release_dmg.sh --help` for identity, team, build-number, and output
overrides.

## Implementation

Chordmark uses SwiftUI for its menu and settings, an AppKit `NSPanel` and focused `NSView` for reliable local key capture, Carbon’s system hotkey registration API for global activation, `NSPasteboard` for clipboard writes, and `SMAppService` for launch at login. It has no third-party dependencies.

## License

Chordmark is available under the [MIT License](LICENSE).
