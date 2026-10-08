#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "MIRA currently supports macOS only."
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift tools are missing. Install Apple's Command Line Tools or Xcode."
    exit 1
fi

swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"

app="build/MIRA.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

cp "$bin_dir/MIRA" "$app/Contents/MacOS/MIRA"
cp Support/Info.plist "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"

# Default: ad-hoc signing, with no personal certificate/private key.
# A development identity is used only when explicitly provided.
identity="${MIRA_SIGN_IDENTITY:--}"
codesign --force --sign "$identity" "$app"
codesign --verify --strict "$app"

if [[ "$identity" == "-" ]]; then
    echo "Local ad-hoc build: no Apple Developer certificate required."
    echo "macOS action permissions may need reapproval after rebuilding."
else
    echo "Signed with the identity explicitly supplied through MIRA_SIGN_IDENTITY."
fi

echo "Built $app"

if [[ "${1:-}" == "--run" ]]; then
    open "$app"
fi
