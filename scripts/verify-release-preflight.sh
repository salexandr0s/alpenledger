#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_PATH="$REPO_ROOT/AlpenLedgerApp.xcodeproj"
readonly APP_SCHEME="AlpenLedgerApp"
readonly INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"

allow_missing_secrets=0

usage() {
    cat <<'USAGE'
Usage: scripts/verify-release-preflight.sh [--allow-missing-secrets]

Verifies local release-signing, packaging, and notarization prerequisites.

By default, missing signing/notary credentials fail the check. Use
--allow-missing-secrets in CI or local readiness passes that can verify project
configuration but cannot access private Apple Developer credentials.
USAGE
}

while (($#)); do
    case "$1" in
        --allow-missing-secrets)
            allow_missing_secrets=1
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

failures=()
warnings=()

record_failure() {
    failures+=("$1")
}

record_secret_gap() {
    if ((allow_missing_secrets)); then
        warnings+=("$1")
    else
        failures+=("$1")
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

require_command xcodebuild
require_command xcrun
require_command plutil
require_command security
require_command codesign
require_command ditto
require_command shasum
require_command spctl

if [[ ! -d "$PROJECT_PATH" ]]; then
    record_failure "Missing Xcode project: $PROJECT_PATH"
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    record_failure "Missing app Info.plist: $INFO_PLIST"
fi

if [[ ${#failures[@]} -eq 0 ]]; then
    release_settings="$(
        xcodebuild \
            -project "$PROJECT_PATH" \
            -scheme "$APP_SCHEME" \
            -configuration Release \
            -showBuildSettings \
            CODE_SIGNING_ALLOWED=NO \
            2>/dev/null
    )"

    build_setting() {
        awk -v key="$1" -F'= ' '
            $0 ~ "^[[:space:]]*" key " = " {
                print $2
                exit
            }
        ' <<<"$release_settings"
    }

    hardened_runtime="$(
        build_setting ENABLE_HARDENED_RUNTIME
    )"
    if [[ "$hardened_runtime" != "YES" ]]; then
        record_failure "Release configuration must enable hardened runtime for notarization."
    fi

    bundle_id="$(
        build_setting PRODUCT_BUNDLE_IDENTIFIER
    )"
    if [[ -z "$bundle_id" ]]; then
        record_failure "Release configuration must declare PRODUCT_BUNDLE_IDENTIFIER."
    fi

    code_sign_style="$(
        build_setting CODE_SIGN_STYLE
    )"
    if [[ "$code_sign_style" != "Manual" ]]; then
        record_failure "Release configuration must use manual signing for Developer ID distribution."
    fi

    info_plist_setting="$(
        build_setting INFOPLIST_FILE
    )"
    if [[ "$info_plist_setting" != "App/AlpenLedgerApp/Info.plist" ]]; then
        record_failure "Release configuration must use App/AlpenLedgerApp/Info.plist."
    fi

    product_name="$(
        build_setting PRODUCT_NAME
    )"
    if [[ -z "$product_name" ]]; then
        record_failure "Release configuration must declare PRODUCT_NAME."
    fi

    wrapper_extension="$(
        build_setting WRAPPER_EXTENSION
    )"
    if [[ "$wrapper_extension" != "app" ]]; then
        record_failure "Release configuration must produce a .app bundle."
    fi

    skip_install="$(
        build_setting SKIP_INSTALL
    )"
    if [[ "$skip_install" != "NO" ]]; then
        record_failure "Release configuration must set SKIP_INSTALL=NO for archiving."
    fi

    deployment_target="$(
        build_setting MACOSX_DEPLOYMENT_TARGET
    )"
    if [[ -z "$deployment_target" ]]; then
        record_failure "Release configuration must declare MACOSX_DEPLOYMENT_TARGET."
    fi
fi

if [[ -f "$INFO_PLIST" ]]; then
    marketing_version="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" 2>/dev/null || true)"
    build_version="$(plutil -extract CFBundleVersion raw "$INFO_PLIST" 2>/dev/null || true)"
    plist_bundle_id="$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST" 2>/dev/null || true)"
    package_type="$(plutil -extract CFBundlePackageType raw "$INFO_PLIST" 2>/dev/null || true)"
    minimum_system_version="$(plutil -extract LSMinimumSystemVersion raw "$INFO_PLIST" 2>/dev/null || true)"

    if [[ -z "$marketing_version" ]]; then
        record_failure "Info.plist must declare CFBundleShortVersionString."
    elif [[ ! "$marketing_version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
        record_failure "CFBundleShortVersionString must use x.y.z release versioning."
    fi

    if [[ -z "$build_version" ]]; then
        record_failure "Info.plist must declare CFBundleVersion."
    elif [[ ! "$build_version" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
        record_failure "CFBundleVersion must be numeric or dot-separated numeric components."
    fi

    if [[ -z "$plist_bundle_id" ]]; then
        record_failure "Info.plist must declare CFBundleIdentifier."
    elif [[ -n "${bundle_id:-}" && "$plist_bundle_id" != "$bundle_id" ]]; then
        record_failure "Info.plist CFBundleIdentifier must match PRODUCT_BUNDLE_IDENTIFIER."
    fi

    if [[ "$package_type" != "APPL" ]]; then
        record_failure "Info.plist CFBundlePackageType must be APPL."
    fi

    if [[ -z "$minimum_system_version" ]]; then
        record_failure "Info.plist must declare LSMinimumSystemVersion."
    elif [[ -n "${deployment_target:-}" && "$minimum_system_version" != "$deployment_target" ]]; then
        record_failure "LSMinimumSystemVersion must match MACOSX_DEPLOYMENT_TARGET."
    fi
fi

if ! xcrun --find notarytool >/dev/null 2>&1; then
    record_failure "xcrun notarytool is required for notarization."
fi

if ! xcrun --find stapler >/dev/null 2>&1; then
    record_failure "xcrun stapler is required for stapling notarization tickets."
fi

signing_identity="${ALPENLEDGER_DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$signing_identity" ]]; then
    record_secret_gap "ALPENLEDGER_DEVELOPER_ID_APPLICATION must name the Developer ID Application signing identity."
elif ! security find-identity -v -p codesigning 2>/dev/null | grep -F -- "$signing_identity" >/dev/null; then
    record_failure "Developer ID Application identity was not found in the keychain: $signing_identity"
fi

if [[ -z "${ALPENLEDGER_RELEASE_TEAM_ID:-}" ]]; then
    record_secret_gap "ALPENLEDGER_RELEASE_TEAM_ID must be set for Developer ID signing and notarization."
fi

if [[ -n "${ALPENLEDGER_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    :
elif [[ -n "${ALPENLEDGER_NOTARY_KEY_ID:-}" &&
        -n "${ALPENLEDGER_NOTARY_ISSUER_ID:-}" &&
        -n "${ALPENLEDGER_NOTARY_KEY_PATH:-}" ]]; then
    if [[ ! -f "${ALPENLEDGER_NOTARY_KEY_PATH}" ]]; then
        record_failure "ALPENLEDGER_NOTARY_KEY_PATH does not exist: ${ALPENLEDGER_NOTARY_KEY_PATH}"
    fi
else
    record_secret_gap "Configure either ALPENLEDGER_NOTARY_KEYCHAIN_PROFILE or the App Store Connect API key trio."
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Release preflight warnings:"
    for warning in "${warnings[@]}"; do
        echo "  - $warning"
    done
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Release preflight failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Release preflight passed."
if [[ -n "${bundle_id:-}" && -n "${marketing_version:-}" && -n "${build_version:-}" ]]; then
    echo "Bundle: $bundle_id"
    echo "Version: $marketing_version ($build_version)"
fi
