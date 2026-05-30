#!/usr/bin/env bash
set -euo pipefail

failures=()

record_failure() {
    failures+=("$1")
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    record_failure "macOS UI automation requires Darwin/macOS."
fi

require_command osascript
require_command xcodebuild

ui_scripting_enabled=""
if command -v osascript >/dev/null 2>&1; then
    ui_scripting_enabled="$(
        osascript -e 'tell application "System Events" to get UI elements enabled' 2>/dev/null || true
    )"
    if [[ "$ui_scripting_enabled" != "true" ]]; then
        record_failure "macOS Accessibility UI scripting is disabled for this runner."
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "UI automation preflight failed:" >&2
    for failure in "${failures[@]}"; do
        echo "- $failure" >&2
    done
    cat >&2 <<'EOF'

Grant the terminal, Codex, or Xcode runner permission in:
System Settings > Privacy & Security > Accessibility

Then rerun RUN_UI_TESTS=1 scripts/verify-readiness.sh or
RUN_UI_TESTS=full scripts/verify-readiness.sh.
EOF
    exit 1
fi

echo "UI automation preflight passed."
