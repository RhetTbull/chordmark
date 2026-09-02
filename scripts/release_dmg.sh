#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build, Developer ID sign, notarize, and package Chordmark as a DMG.

Usage:
  scripts/release_dmg.sh --version <version> --notary-profile <profile> [options]

Required:
  --version <version>              CFBundleShortVersionString (for example, 1.0.0).
  --notary-profile <profile>       notarytool keychain profile name.

Options:
  --project <path>                 Xcode project path.
                                   Default: <repo>/Chordmark/Chordmark.xcodeproj
  --scheme <name>                  Xcode scheme. Default: Chordmark
  --configuration <name>           Build configuration. Default: Release
  --team-id <team>                 Apple Developer Team ID. Default: K4ZMVP896P
  --build-number <number>          CFBundleVersion.
                                   Default: commit count of HEAD
  --build-root <path>              Working and output directory.
                                   Default: <repo>/dist/<version>
  --codesign-identity <identity>   Developer ID Application certificate name.
                                   Default: the installed identity for --team-id
  -h, --help                       Show this help text.

The output is named Chordmark-<version>-build-<build-number>.dmg.

Example:
  scripts/release_dmg.sh \
    --version 1.0.0 \
    --notary-profile Chordmark-notary
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

safe_remove() {
  local path
  for path in "$@"; do
    case "$path" in
      "$BUILD_ROOT"/*) rm -rf -- "$path" ;;
      *) die "refusing to remove path outside build root: $path" ;;
    esac
  done
}

# Retry transport and service failures, but surface definitive rejections
# immediately because resubmitting identical bits cannot change the verdict.
notarize_with_retry() {
  local artifact="$1"
  local label="$2"
  local attempt=1
  local status=0
  local delay=0
  local submission_id=""
  local log_file="$BUILD_ROOT/notarytool-$label.log"

  while true; do
    echo "Submitting $label to Apple (attempt $attempt/$MAX_NOTARY_ATTEMPTS)..."
    set +e
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait 2>&1 | tee "$log_file"
    status=${PIPESTATUS[0]}
    set -e

    if [[ $status -eq 0 ]] && grep -q "status: Accepted" "$log_file"; then
      echo "Notarization accepted."
      return 0
    fi

    if grep -qE "status: (Invalid|Rejected)" "$log_file"; then
      submission_id="$(awk '/^[[:space:]]*id: /{print $2; exit}' "$log_file")"
      echo "Apple rejected the $label notarization submission." >&2
      if [[ -n "$submission_id" ]]; then
        xcrun notarytool log "$submission_id" \
          --keychain-profile "$NOTARY_PROFILE" >&2 || true
      fi
      return 1
    fi

    if (( attempt >= MAX_NOTARY_ATTEMPTS )); then
      echo "Notarization failed after $MAX_NOTARY_ATTEMPTS attempts." >&2
      echo "See $log_file" >&2
      return 1
    fi

    delay=$((attempt * 30))
    echo "Transient notarization failure; retrying in ${delay}s..." >&2
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="Chordmark"
DMG_NAME="Chordmark"
SCHEME="Chordmark"
CONFIGURATION="Release"
TEAM_ID="K4ZMVP896P"
MAX_NOTARY_ATTEMPTS=3
VERSION=""
BUILD_NUMBER=""
NOTARY_PROFILE=""
CODESIGN_IDENTITY=""
BUILD_ROOT=""
PROJECT_PATH="$REPO_ROOT/Chordmark/Chordmark.xcodeproj"
DMG_VERIFY_MOUNT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || die "--notary-profile requires a value"
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --project)
      [[ $# -ge 2 ]] || die "--project requires a value"
      PROJECT_PATH="$2"
      shift 2
      ;;
    --scheme)
      [[ $# -ge 2 ]] || die "--scheme requires a value"
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      [[ $# -ge 2 ]] || die "--configuration requires a value"
      CONFIGURATION="$2"
      shift 2
      ;;
    --team-id)
      [[ $# -ge 2 ]] || die "--team-id requires a value"
      TEAM_ID="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || die "--build-number requires a value"
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --build-root)
      [[ $# -ge 2 ]] || die "--build-root requires a value"
      BUILD_ROOT="$2"
      shift 2
      ;;
    --codesign-identity)
      [[ $# -ge 2 ]] || die "--codesign-identity requires a value"
      CODESIGN_IDENTITY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$VERSION" ]] || {
  usage >&2
  die "--version is required"
}
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ||
  die "version must contain one to three dot-separated integers: $VERSION"

[[ -n "$NOTARY_PROFILE" ]] || {
  usage >&2
  die "--notary-profile is required"
}
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] ||
  die "team ID must be 10 uppercase letters or digits: $TEAM_ID"

[[ -d "$PROJECT_PATH" ]] || die "Xcode project not found: $PROJECT_PATH"
PROJECT_PATH="$(cd "$(dirname "$PROJECT_PATH")" && pwd -P)/$(basename "$PROJECT_PATH")"

if [[ -z "$BUILD_NUMBER" ]]; then
  [[ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" != "true" ]] ||
    die "cannot derive a reliable build number from a shallow clone"
  BUILD_NUMBER="$(git -C "$REPO_ROOT" rev-list --count HEAD)"
fi
[[ "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ||
  die "build number must contain one to three dot-separated integers: $BUILD_NUMBER"

if [[ -z "$BUILD_ROOT" ]]; then
  BUILD_ROOT="$REPO_ROOT/dist/$VERSION"
fi
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
[[ "$BUILD_ROOT" != "/" && "$BUILD_ROOT" != "$REPO_ROOT" ]] ||
  die "build root is too broad: $BUILD_ROOT"
[[ -z "${HOME:-}" || "$BUILD_ROOT" != "$HOME" ]] ||
  die "build root cannot be your home directory"

for command in xcodebuild xcrun security codesign ditto hdiutil spctl plutil git; do
  require_cmd "$command"
done

if [[ -z "$CODESIGN_IDENTITY" ]]; then
  CODESIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
      | grep -F "($TEAM_ID)" \
      | sed -n '1p' \
      || true
  )"
fi
[[ -n "$CODESIGN_IDENTITY" ]] ||
  die "no Developer ID Application identity found for team $TEAM_ID"

BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD)"
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "warning: building from a working tree with uncommitted changes." >&2
  BUILD_COMMIT="${BUILD_COMMIT}+"
fi

ARCHIVE_PATH="$BUILD_ROOT/$DMG_NAME.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
APP_ZIP="$BUILD_ROOT/$DMG_NAME-app.zip"
DMG_STAGING_DIR="$BUILD_ROOT/dmg-source"
DMG_PATH="$BUILD_ROOT/${DMG_NAME}-${VERSION}-build-${BUILD_NUMBER}.dmg"
EXPORT_OPTIONS_PLIST="$BUILD_ROOT/ExportOptions.plist"
DMG_VERIFY_MOUNT="$BUILD_ROOT/dmg-verify"

cleanup() {
  if [[ -n "$DMG_VERIFY_MOUNT" ]] &&
    mount | grep -F " on $DMG_VERIFY_MOUNT " >/dev/null; then
    hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

safe_remove \
  "$ARCHIVE_PATH" \
  "$EXPORT_PATH" \
  "$APP_ZIP" \
  "$DMG_STAGING_DIR" \
  "$DMG_PATH" \
  "$DMG_VERIFY_MOUNT"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

echo "Project:            $PROJECT_PATH"
echo "Scheme:             $SCHEME"
echo "Configuration:      $CONFIGURATION"
echo "Version:            $VERSION"
echo "Build number:       $BUILD_NUMBER"
echo "Commit:             $BUILD_COMMIT"
echo "Team ID:            $TEAM_ID"
echo "Codesign identity:  $CODESIGN_IDENTITY"
echo "Notary profile:     $NOTARY_PROFILE"
echo "Build root:         $BUILD_ROOT"
echo

echo "Archiving Chordmark..."
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "Exporting Developer ID application..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

[[ -d "$APP_PATH" ]] || die "exported application not found: $APP_PATH"

echo "Verifying application signature and version..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
grep -Fq "Authority=$CODESIGN_IDENTITY" <<<"$SIGNATURE_DETAILS" ||
  die "exported application was not signed by the requested identity"

EXPORTED_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist")"
EXPORTED_BUILD="$(plutil -extract CFBundleVersion raw "$APP_PATH/Contents/Info.plist")"
[[ "$EXPORTED_VERSION" == "$VERSION" ]] ||
  die "exported version is $EXPORTED_VERSION; expected $VERSION"
[[ "$EXPORTED_BUILD" == "$BUILD_NUMBER" ]] ||
  die "exported build is $EXPORTED_BUILD; expected $BUILD_NUMBER"

echo "Notarizing application bundle..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
notarize_with_retry "$APP_ZIP" "app"
safe_remove "$APP_ZIP"

echo "Stapling and validating application ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Staging drag-and-drop disk image..."
mkdir -p "$DMG_STAGING_DIR"
ditto "$APP_PATH" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo "Creating and signing disk image..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH"
codesign --force --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

echo "Notarizing disk image..."
notarize_with_retry "$DMG_PATH" "dmg"

echo "Stapling and validating disk image ticket..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "Verifying the packaged application ticket..."
mkdir -p "$DMG_VERIFY_MOUNT"
hdiutil attach \
  "$DMG_PATH" \
  -nobrowse \
  -readonly \
  -mountpoint "$DMG_VERIFY_MOUNT" >/dev/null
xcrun stapler validate "$DMG_VERIFY_MOUNT/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$DMG_VERIFY_MOUNT/$APP_NAME.app"
hdiutil detach "$DMG_VERIFY_MOUNT" >/dev/null
safe_remove "$DMG_VERIFY_MOUNT"
DMG_VERIFY_MOUNT=""

echo
echo "Release complete."
echo "Application: $APP_PATH"
echo "Disk image:  $DMG_PATH"
echo "Version:     $EXPORTED_VERSION ($EXPORTED_BUILD)"
echo "Commit:      $BUILD_COMMIT"
