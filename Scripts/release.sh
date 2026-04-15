#!/bin/bash -x

PROJECT_NAME="Get iPlayer Automator 2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

EXPORT_OPTIONS_PLIST=$(find "$PROJECT_DIR" -name "ExportOptions.plist" -not -path "*/build/*" -not -path "*/DerivedData/*" | head -1)

# ── Populate Binaries/ ────────────────────────────────────────────────────

make binaries

# ── Build ─────────────────────────────────────────────────────────────────

rm -rf Archive/*
rm -rf Product/*

xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -configuration Release -alltargets

xcodebuild archive -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" -archivePath "Archive/$PROJECT_NAME.xcarchive"

xcodebuild -exportArchive -archivePath "Archive/$PROJECT_NAME.xcarchive" -exportPath "Product/$PROJECT_NAME" -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

cd "Product/${PROJECT_NAME}"
CFBundleVersion=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PROJECT_NAME.app/Contents/Info.plist")
CFBundleShortVersionString=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_NAME.app/Contents/Info.plist")

ARCHIVE_NAME="$PROJECT_NAME.v${CFBundleShortVersionString}.b${CFBundleVersion}.zip"
ditto -c -k --keepParent -rsrc "$PROJECT_NAME.app" "../$ARCHIVE_NAME"
cd ..
xcrun notarytool submit "$ARCHIVE_NAME" \
                 --keychain-profile "get-iplayer-automator-notary" \
                 --wait

ditto -x -k "$ARCHIVE_NAME" .

xcrun stapler staple "$PROJECT_NAME.app"

ditto "$PROJECT_NAME.app" tmp-"$PROJECT_NAME.app"
rm -rf "$PROJECT_NAME.app"
mv tmp-"$PROJECT_NAME.app" "$PROJECT_NAME.app"

ditto -c -k --keepParent -rsrc "$PROJECT_NAME.app" "$ARCHIVE_NAME"
