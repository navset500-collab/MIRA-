#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"
swift build -c release

app="build/MIRA.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/MIRA "$app/Contents/MacOS/MIRA"
cp Support/Info.plist "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
if [[ -n "${MIRA_SIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$MIRA_SIGN_IDENTITY" "$app"
else
    echo "Warning: using a local ad-hoc signature. Recheck privacy permissions after changing builds."
    codesign --force --sign - "$app"
fi
echo "Built $app"

if [[ "${1:-}" == "--run" ]]; then
    open "$app"
fi