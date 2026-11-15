#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
xcrun swiftc "$ROOT/Sources/Ring.swift" "$ROOT/Sources/main.swift" -lsqlite3 -o "$ROOT/build/CodexCycle"
for direction in previous next; do
  if [[ "$direction" == previous ]]; then name='Codex 最近聊天－上一条'; else name='Codex 最近聊天－下一条'; fi
  bundle="$ROOT/build/$name.app/Contents"
  mkdir -p "$bundle/MacOS"
  cp "$ROOT/build/CodexCycle" "$bundle/MacOS/CodexCycle"
  cat > "$bundle/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexCycle</string>
<key>CFBundleIdentifier</key><string>local.codex.remote-cycle.$direction</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
  codesign --force --sign - "$ROOT/build/$name.app"
done
printf 'Built two on-demand apps in %s/build\n' "$ROOT"
