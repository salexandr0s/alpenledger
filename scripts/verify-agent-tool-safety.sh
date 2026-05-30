#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGE_DIR="$REPO_ROOT/Packages/AlpenLedgerKit"

run() {
    echo
    echo "==> $*"
    "$@"
}

cd "$REPO_ROOT"

readonly UNSAFE_DECLARATION_PATTERN='allows(UnrestrictedFileAccess|RawSQL|ShellExecution):[[:space:]]*true'
unsafe_declarations="$(
    rg --glob '*.swift' --line-number --color never \
        "$UNSAFE_DECLARATION_PATTERN" \
        App/AlpenLedgerApp \
        Packages/AlpenLedgerKit/Sources || true
)"

if [[ -n "$unsafe_declarations" ]]; then
    printf '%s\n' "$unsafe_declarations"
    cat >&2 <<'EOF'
Agent tool safety verification failed.

Production app/package sources must not declare tools that allow unrestricted
file access, raw SQL, or shell execution. Route new behavior through typed
domain tools and add a narrow scope plus reviewable tests instead.
EOF
    exit 1
fi

readonly AGENT_FILE_ACCESS_PATTERN='FileManager|URL[[:space:]]*\([[:space:]]*fileURLWithPath|Process[[:space:]]*\(|NSOpenPanel|NSSavePanel'
agent_file_access="$(
    rg --glob 'Agent*.swift' \
        --glob 'WorkspaceAgentToolService.swift' \
        --line-number \
        --color never \
        "$AGENT_FILE_ACCESS_PATTERN" \
        Packages/AlpenLedgerKit/Sources || true
)"

if [[ -n "$agent_file_access" ]]; then
    printf '%s\n' "$agent_file_access"
    cat >&2 <<'EOF'
Agent tool safety verification failed.

Agent-facing source files must not perform direct filesystem, shell, or native
file-picker access. Use typed document, export, storage, or workspace services
that return provenance instead.
EOF
    exit 1
fi

direct_app_issue_writes="$(
    rg --line-number --color never \
        'issueService[.]syncIssue' \
        App/AlpenLedgerApp/Root/WorkspaceAppModel.swift || true
)"

if [[ -n "$direct_app_issue_writes" ]]; then
    printf '%s\n' "$direct_app_issue_writes"
    cat >&2 <<'EOF'
Agent tool safety verification failed.

Copilot/app-model issue writes must route through the typed agent tool executor
so scope checks, provenance, and agent-tool audit events are preserved.
EOF
    exit 1
fi

if ! rg --quiet 'toolName:[[:space:]]*"issues[.]open_or_update"' \
    App/AlpenLedgerApp/Root/WorkspaceAppModel.swift; then
    cat >&2 <<'EOF'
Agent tool safety verification failed.

WorkspaceAppModel must route Copilot task creation through
issues.open_or_update instead of writing review issues directly.
EOF
    exit 1
fi

(
    cd "$PACKAGE_DIR"
    run swift test --filter AgentToolPolicy
)

echo
echo "Agent tool safety verification passed."
