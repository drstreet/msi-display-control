#!/bin/sh
# Installs or updates MSI Display Control from the latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/drstreet/msi-display-control/main/Scripts/install.sh | sh
#
# Files downloaded with curl are not marked as quarantined, so macOS opens the app
# without the "unidentified developer" warning that a browser download gets.
set -eu

repository="${REPOSITORY:-drstreet/msi-display-control}"
destination="/Applications/MSI Display Control.app"

url=$(curl -fsSL "https://api.github.com/repos/$repository/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -n 1 | sed 's/.*"\(http[^"]*\)"/\1/')
[ -n "$url" ] || { echo "No release found for $repository." >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
echo "Downloading $url"
curl -fsSL "$url" -o "$work/app.zip"
ditto -x -k "$work/app.zip" "$work"

pkill -x MSIDisplayControl 2>/dev/null || true
rm -rf "$destination"
mv "$work/MSI Display Control.app" "$destination"
echo "Installed $destination"
open "$destination"
