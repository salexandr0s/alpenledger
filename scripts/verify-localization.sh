#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_FILE="$REPO_ROOT/project.yml"
readonly PACKAGE_MANIFEST="$REPO_ROOT/Packages/AlpenLedgerKit/Package.swift"
readonly APP_INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"
readonly APP_STRINGS="$REPO_ROOT/App/AlpenLedgerApp/Resources/en.lproj/Localizable.strings"
readonly CATALOG="$REPO_ROOT/config/localization-catalog.json"
readonly LOCALIZATION_DOC="$REPO_ROOT/docs/localization.md"
readonly CHECKLIST_DOC="$REPO_ROOT/docs/checklist.md"
readonly RELEASE_NOTES_DOC="$REPO_ROOT/docs/release-notes/v0.1.0.md"

fail() {
    echo "Localization verification failed: $*" >&2
    exit 1
}

require_file() {
    local path="$1"
    [[ -f "$path" ]] || fail "missing required file: ${path#$REPO_ROOT/}"
}

require_contains() {
    local path="$1"
    local needle="$2"
    grep -Fq -- "$needle" "$path" || fail "${path#$REPO_ROOT/} missing required text: $needle"
}

require_file "$PROJECT_FILE"
require_file "$PACKAGE_MANIFEST"
require_file "$APP_INFO_PLIST"
require_file "$APP_STRINGS"
require_file "$CATALOG"
require_file "$LOCALIZATION_DOC"
require_file "$CHECKLIST_DOC"
require_file "$RELEASE_NOTES_DOC"

require_contains "$PROJECT_FILE" "CFBundleDevelopmentRegion: en"
require_contains "$PACKAGE_MANIFEST" "defaultLocalization: \"en\""
require_contains "$APP_INFO_PLIST" "<string>en</string>"
require_contains "$APP_STRINGS" "\"app.name\" = \"AlpenLedger\";"
require_contains "$APP_STRINGS" "\"localization.releaseBoundary\" = \"English-first pilot\";"

for section in \
    "## Current Boundary" \
    "## Source Of Truth" \
    "## Resource Layout" \
    "## Release Rules" \
    "## Minimum Readiness Evidence" \
    "## Verification"
do
    require_contains "$LOCALIZATION_DOC" "$section"
done

for anchor in \
    "config/localization-catalog.json" \
    "LocalizationPolicy" \
    "English-first pilot" \
    "German" \
    "French" \
    "planned readiness languages" \
    "scripts/verify-localization.sh"
do
    require_contains "$LOCALIZATION_DOC" "$anchor"
done

require_contains "$CHECKLIST_DOC" "- [x] Localization framework"
require_contains "$CHECKLIST_DOC" "docs/localization.md"
require_contains "$CHECKLIST_DOC" "config/localization-catalog.json"
require_contains "$CHECKLIST_DOC" "scripts/verify-localization.sh"
require_contains "$CHECKLIST_DOC" "localizationPolicyKeepsPilotLanguageClaimsConservative"
require_contains "$CHECKLIST_DOC" "- [ ] German/French/English readiness strategy"
require_contains "$RELEASE_NOTES_DOC" "English-first"
require_contains "$RELEASE_NOTES_DOC" "do not yet include German or"
require_contains "$RELEASE_NOTES_DOC" "French localization"

ruby -rjson -e '
  path = ARGV.fetch(0)
  catalog = JSON.parse(File.read(path))
  failures = []

  failures << "schemaVersion must be 1" unless catalog["schemaVersion"] == 1
  failures << "defaultLanguage must be en" unless catalog["defaultLanguage"] == "en"
  failures << "developmentRegion must be en" unless catalog["developmentRegion"] == "en"

  languages = catalog.fetch("languages", [])
  codes = languages.map { |language| language["code"] }
  failures << "languages must be en, de, fr" unless codes == %w[en de fr]

  statuses = languages.to_h { |language| [language["code"], language["status"]] }
  failures << "English must be release-ready" unless statuses["en"] == "release-ready"
  failures << "German must remain planned" unless statuses["de"] == "planned"
  failures << "French must remain planned" unless statuses["fr"] == "planned"

  terms = catalog.fetch("requiredGlossaryTerms", []).map { |term| term["key"] }
  %w[
    prepared-not-filed
    local-only
    evidence-required
    sanitized-support-bundle
    locked-period
  ].each do |key|
    failures << "missing required glossary term #{key}" unless terms.include?(key)
  end

  unless failures.empty?
    warn "Localization catalog verification failed:"
    failures.each { |failure| warn "  - #{failure}" }
    exit 1
  end
' "$CATALOG"

(
    cd "$REPO_ROOT/Packages/AlpenLedgerKit"
    swift test --filter LocalizationPolicy
)

echo "Localization verification passed."
