#!/bin/bash
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"

swift_path="$(xcrun --find swift)"
if [[ "$swift_path" == */CommandLineTools/usr/bin/swift ]]; then
    plugin="$(dirname -- "$swift_path")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
    if [[ -f "$plugin" ]]; then
        exec "$swift_path" test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$plugin" "$@"
    fi
fi

exec "$swift_path" test --disable-xctest "$@"
