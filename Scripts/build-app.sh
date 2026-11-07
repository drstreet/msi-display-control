#!/bin/sh
# Builds "dist/MSI Display Control.app" and a zip of it for releases.
set -eu
cd "$(dirname "$0")/.."

version="${VERSION:-1.0.0}"
# GitHub "owner/name" used for update checks; taken from the origin remote when not set.
repository="${REPOSITORY:-$(git remote get-url origin 2>/dev/null | sed -E 's#(.*github.com[:/])##; s#\.git$##')}"
app="dist/MSI Display Control.app"

swift build -c release --arch arm64 --arch x86_64
bin="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MSIDisplayControl"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/MSIDisplayControl"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$version/g" -e "s#__REPOSITORY__#$repository#g" Resources/Info.plist > "$app/Contents/Info.plist"
cp -R Resources/Localization/*.lproj "$app/Contents/Resources/"

codesign --force --deep --sign "${SIGNING_IDENTITY:--}" "$app"
(cd dist && rm -f "MSI-Display-Control-$version.zip" && ditto -c -k --keepParent "MSI Display Control.app" "MSI-Display-Control-$version.zip")

echo "Built $app"
