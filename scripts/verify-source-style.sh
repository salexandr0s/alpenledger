#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT"

failures=0

record_failure() {
    printf '%s\n' "$1" >&2
    failures=$((failures + 1))
}

is_checked_text_file() {
    local file="$1"
    case "$file" in
        Packages/Vendor/* | */.DS_Store)
            return 1
            ;;
        *.swift | *.sh | *.md | *.json | *.yml | *.yaml | *.plist | *.xml | *.txt)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

collect_files_with_find() {
    local candidate
    local candidates=(
        .editorconfig
        .github
        App
        Packages/AlpenLedgerKit
        config
        docs
        scripts
        agents.md
        claude.md
        project.yml
    )

    for candidate in "${candidates[@]}"; do
        [[ -e "$candidate" ]] || continue

        if [[ -d "$candidate" ]]; then
            find "$candidate" \
                \( \
                    -path 'Packages/AlpenLedgerKit/.build' -o \
                    -path 'Packages/AlpenLedgerKit/.swiftpm' -o \
                    -path 'Packages/AlpenLedgerKit/build' \
                \) -prune -o \
                -type f -print0
        else
            printf '%s\0' "$candidate"
        fi
    done
}

has_final_newline() {
    local file="$1"
    [[ ! -s "$file" ]] && return 0
    [[ "$(tail -c 1 "$file" | wc -l | tr -d '[:space:]')" == "1" ]]
}

files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git ls-files -z --cached --others --exclude-standard -- \
            .editorconfig \
            .github \
            App \
            Packages/AlpenLedgerKit \
            config \
            docs \
            scripts \
            agents.md \
            claude.md \
            project.yml
    else
        collect_files_with_find
    fi
)

for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    is_checked_text_file "$file" || continue
    LC_ALL=C grep -Iq . "$file" || continue

    if LC_ALL=C grep -n $'\r' "$file" >/dev/null; then
        record_failure "$file contains CRLF or stray carriage-return characters."
    fi

    if LC_ALL=C grep -nE '[[:blank:]]$' "$file" >/dev/null; then
        record_failure "$file contains trailing whitespace."
    fi

    if LC_ALL=C grep -nE '^(<<<<<<<|=======|>>>>>>>)($| )' "$file" >/dev/null; then
        record_failure "$file contains unresolved merge-conflict markers."
    fi

    if ! has_final_newline "$file"; then
        record_failure "$file is missing a final newline."
    fi

    case "$file" in
        *.swift | *.sh | *.md | *.json | *.yml | *.yaml)
            if LC_ALL=C grep -n $'^\t' "$file" >/dev/null; then
                record_failure "$file uses leading tabs; use spaces for hand-edited source and docs."
            fi
            ;;
    esac

    if [[ "$file" == scripts/*.sh ]]; then
        if [[ ! -x "$file" ]]; then
            record_failure "$file must be executable."
        fi
        unsupported_bash_pattern='(^|[[:space:]])(map''file|read''array)([[:space:]]|$)|declare[[:space:]]+-A|local[[:space:]]+-n'
        if LC_ALL=C grep -nE "$unsupported_bash_pattern" "$file" >/dev/null; then
            record_failure "$file uses Bash 4+ shell features; release scripts must run under macOS system Bash 3.2."
        fi
        if ! bash -n "$file"; then
            record_failure "$file failed bash syntax validation."
        fi
    fi
done

if ((failures > 0)); then
    printf 'Source style verification failed with %d issue(s).\n' "$failures" >&2
    exit 1
fi

printf 'Source style verification passed.\n'
