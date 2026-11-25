#!/bin/bash
# Runs unit tests. Command Line Tools ship swift-testing outside the default search paths.
set -euo pipefail
cd "$(dirname "$0")"
D="$(xcode-select -p)"
swift test \
  -Xswiftc -plugin-path -Xswiftc "$D/usr/lib/swift/host/plugins/testing" \
  -Xlinker -rpath -Xlinker "$D/Library/Developer/Frameworks" \
  -Xlinker -rpath -Xlinker "$D/Library/Developer/usr/lib"
