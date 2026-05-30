#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly EXPECTED_INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"
readonly EXPECTED_APP_NAME="AlpenLedgerApp"
readonly DEFAULT_OUTPUT_DIR="$REPO_ROOT/dist/releases"

app_path=""
output_dir="$DEFAULT_OUTPUT_DIR"
dry_run=0
force=0
skip_final_verification=0

usage() {
    cat <<'USAGE'
Usage: scripts/package-release.sh --app path/to/AlpenLedgerApp.app [options]

Packages a prepared AlpenLedgerApp.app bundle into the release ZIP naming
scheme and records a SHA-256 checksum. By default, the resulting ZIP is also
verified with scripts/verify-release-artifact.sh, so the app must already be
Developer ID signed, notarized, and stapled.

Options:
  --app PATH                    Prepared AlpenLedgerApp.app bundle to package.
  --output-dir PATH             Output directory. Defaults to dist/releases.
  --force                       Replace an existing ZIP/checksum pair.
  --skip-final-verification     Create the ZIP without verifying signing,
                                Gatekeeper, or stapled notarization. This is
                                for local packaging rehearsals only.
  --dry-run                     Validate metadata and print the planned output
                                name without creating a ZIP.
  -h, --help                    Show this help.
USAGE
}

failures=()

record_failure() {
    failures+=("$1")
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

plist_value() {
    local plist_path="$1"
    local key="$2"
    plutil -extract "$key" raw "$plist_path" 2>/dev/null || true
}

while (($#)); do
    case "$1" in
        --app)
            shift
            if [[ $# -eq 0 ]]; then
                echo "--app requires a path." >&2
                exit 2
            fi
            app_path="$1"
            ;;
        --output-dir)
            shift
            if [[ $# -eq 0 ]]; then
                echo "--output-dir requires a path." >&2
                exit 2
            fi
            output_dir="$1"
            ;;
        --force)
            force=1
            ;;
        --skip-final-verification)
            skip_final_verification=1
            ;;
        --dry-run)
            dry_run=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

require_command ditto
require_command plutil
require_command shasum

if [[ ! -f "$EXPECTED_INFO_PLIST" ]]; then
    record_failure "Missing expected app Info.plist: $EXPECTED_INFO_PLIST"
fi

if ((dry_run == 0)) && [[ -z "$app_path" ]]; then
    record_failure "--app is required unless --dry-run is used."
fi

if [[ ${#failures[@]} -eq 0 ]]; then
    expected_bundle_id="$(plist_value "$EXPECTED_INFO_PLIST" CFBundleIdentifier)"
    marketing_version="$(plist_value "$EXPECTED_INFO_PLIST" CFBundleShortVersionString)"
    build_version="$(plist_value "$EXPECTED_INFO_PLIST" CFBundleVersion)"

    if [[ -z "$expected_bundle_id" ]]; then
        record_failure "Info.plist must declare CFBundleIdentifier."
    fi
    if [[ -z "$marketing_version" ]]; then
        record_failure "Info.plist must declare CFBundleShortVersionString."
    fi
    if [[ -z "$build_version" ]]; then
        record_failure "Info.plist must declare CFBundleVersion."
    fi
fi

if [[ ${#failures[@]} -eq 0 ]]; then
    artifact_name="${EXPECTED_APP_NAME}-v${marketing_version}-build${build_version}.zip"
    artifact_path="$output_dir/$artifact_name"
    checksum_path="$artifact_path.sha256"
fi

if [[ -n "$app_path" ]]; then
    if [[ ! -d "$app_path" ]]; then
        record_failure "App bundle does not exist: $app_path"
    elif [[ "$(basename "$app_path")" != "${EXPECTED_APP_NAME}.app" ]]; then
        record_failure "App bundle must be named ${EXPECTED_APP_NAME}.app."
    else
        app_info_plist="$app_path/Contents/Info.plist"
        if [[ ! -f "$app_info_plist" ]]; then
            record_failure "App bundle is missing Contents/Info.plist: $app_info_plist"
        else
            actual_bundle_id="$(plist_value "$app_info_plist" CFBundleIdentifier)"
            actual_marketing_version="$(plist_value "$app_info_plist" CFBundleShortVersionString)"
            actual_build_version="$(plist_value "$app_info_plist" CFBundleVersion)"

            if [[ "$actual_bundle_id" != "${expected_bundle_id:-}" ]]; then
                record_failure "Packaged app bundle identifier must be ${expected_bundle_id:-unknown}; found $actual_bundle_id."
            fi
            if [[ "$actual_marketing_version" != "${marketing_version:-}" ]]; then
                record_failure "Packaged app marketing version must be ${marketing_version:-unknown}; found $actual_marketing_version."
            fi
            if [[ "$actual_build_version" != "${build_version:-}" ]]; then
                record_failure "Packaged app build version must be ${build_version:-unknown}; found $actual_build_version."
            fi
        fi
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Release packaging failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

if ((dry_run)); then
    echo "Release packaging dry run passed."
    echo "Bundle: $expected_bundle_id"
    echo "Version: $marketing_version ($build_version)"
    echo "Planned artifact: $artifact_path"
    exit 0
fi

mkdir -p "$output_dir"

if [[ -e "$artifact_path" || -e "$checksum_path" ]] && ((force == 0)); then
    echo "Release packaging failed:" >&2
    echo "  - Output artifact already exists: $artifact_path" >&2
    echo "  - Use --force to replace the existing ZIP/checksum pair." >&2
    exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/alpenledger-package.XXXXXX")"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

tmp_artifact="$tmpdir/$artifact_name"
tmp_checksum="$tmp_artifact.sha256"
ditto -c -k --keepParent "$app_path" "$tmp_artifact"

checksum="$(shasum -a 256 "$tmp_artifact" | awk '{ print $1 }')"
printf '%s  %s\n' "$checksum" "$(basename "$artifact_path")" > "$tmp_checksum"

if ((skip_final_verification)); then
    echo "Release package created without final artifact verification."
    echo "This ZIP is not release evidence until scripts/verify-release-artifact.sh passes."
else
    "$REPO_ROOT/scripts/verify-release-artifact.sh" "$tmp_artifact"
fi

if [[ -e "$artifact_path" || -e "$checksum_path" ]]; then
    if ((force)); then
        rm -f "$artifact_path" "$checksum_path"
    else
        echo "Release packaging failed:" >&2
        echo "  - Output artifact already exists: $artifact_path" >&2
        echo "  - Use --force to replace the existing ZIP/checksum pair." >&2
        exit 1
    fi
fi

mv "$tmp_artifact" "$artifact_path"
mv "$tmp_checksum" "$checksum_path"

echo "Release package ready."
echo "Artifact: $artifact_path"
echo "Checksum: $checksum_path"
echo "SHA-256: $checksum"
