#!/bin/bash
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"

swift build --configuration release --product YiLiMac
bin_dir="$(swift build --configuration release --show-bin-path)"

dist="$root/dist"
mkdir -p "$dist"
stage="$(mktemp -d "$dist/.build-app.XXXXXX")"
trap 'find "$stage" -depth -delete' EXIT

app="$stage/易历.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$stage/AppIcon.iconset"
install -m 755 "$bin_dir/YiLiMac" "$app/Contents/MacOS/YiLiMac"
install -m 644 "$root/scripts/Info.plist" "$app/Contents/Info.plist"
swift "$root/scripts/make-icon.swift" "$stage/AppIcon.iconset"
iconutil --convert icns --output "$app/Contents/Resources/AppIcon.icns" "$stage/AppIcon.iconset"

codesign --force --sign - "$app"
codesign --verify --strict "$app"

destination="$dist/易历.app"
if [[ -e "$destination" || -L "$destination" ]]; then
    mv "$destination" "$stage/previous.app"
fi
if ! mv "$app" "$destination"; then
    if [[ -e "$stage/previous.app" || -L "$stage/previous.app" ]]; then
        mv "$stage/previous.app" "$destination"
    fi
    exit 1
fi

printf '\n%s\n' "$destination"
