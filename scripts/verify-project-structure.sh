#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGE_DIR="$REPO_ROOT/Packages/AlpenLedgerKit"
readonly PACKAGE_MANIFEST="$PACKAGE_DIR/Package.swift"
readonly PROJECT_FILE="$REPO_ROOT/project.yml"
readonly APP_INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"
readonly WORKSPACE_DATA="$REPO_ROOT/AlpenLedger.xcworkspace/contents.xcworkspacedata"
readonly CI_SCHEME="$REPO_ROOT/AlpenLedgerApp.xcodeproj/xcshareddata/xcschemes/AlpenLedgerAppCI.xcscheme"

failures=()

record_failure() {
    failures+=("$1")
}

require_file() {
    if [[ ! -f "$1" ]]; then
        record_failure "Missing required file: $1"
    fi
}

require_dir() {
    if [[ ! -d "$1" ]]; then
        record_failure "Missing required directory: $1"
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    if [[ -f "$file" ]] && ! grep -Eq "$pattern" "$file"; then
        record_failure "$message"
    fi
}

require_command_output() {
    local command_name="$1"
    local expected_pattern="$2"
    local message="$3"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        record_failure "Missing required command: $command_name"
        return
    fi

    local output
    if ! output="$("$command_name" --version 2>&1)"; then
        record_failure "Failed to read version from $command_name"
        return
    fi

    if ! grep -Eq "$expected_pattern" <<<"$output"; then
        record_failure "$message Found: ${output//$'\n'/ }"
    fi
}

require_file "$WORKSPACE_DATA"
require_file "$REPO_ROOT/AlpenLedgerApp.xcodeproj/project.pbxproj"
require_file "$CI_SCHEME"
require_file "$PROJECT_FILE"
require_file "$PACKAGE_MANIFEST"
require_file "$PACKAGE_DIR/Package.resolved"
require_file "$APP_INFO_PLIST"

require_dir "$REPO_ROOT/App/AlpenLedgerApp"
require_dir "$REPO_ROOT/App/AlpenLedgerAppTests"
require_dir "$REPO_ROOT/App/AlpenLedgerAppUITests"
require_dir "$PACKAGE_DIR/Sources"
require_dir "$PACKAGE_DIR/Tests"
require_dir "$REPO_ROOT/Packages/Vendor/GRDB.swift"

require_pattern "$WORKSPACE_DATA" 'AlpenLedgerApp\.xcodeproj' \
    "Workspace must reference AlpenLedgerApp.xcodeproj."
require_pattern "$PROJECT_FILE" 'minimumXcodeGenVersion:[[:space:]]*2\.45\.2' \
    "project.yml must pin the verified XcodeGen baseline."
require_pattern "$PROJECT_FILE" 'xcodeVersion:[[:space:]]*"26\.3\.0"' \
    "project.yml must pin the verified Xcode baseline."
require_pattern "$PROJECT_FILE" 'path:[[:space:]]*Packages/AlpenLedgerKit' \
    "project.yml must use the local AlpenLedgerKit package."
require_pattern "$PROJECT_FILE" 'ENABLE_HARDENED_RUNTIME:[[:space:]]*YES' \
    "App target must enable hardened runtime."
require_pattern "$PROJECT_FILE" 'MACOSX_DEPLOYMENT_TARGET:[[:space:]]*15\.6' \
    "Project must pin the macOS deployment target."
require_pattern "$PACKAGE_MANIFEST" '^// swift-tools-version:[[:space:]]*6\.2$' \
    "Package.swift must pin the Swift tools version."
require_pattern "$PACKAGE_MANIFEST" '\.macOS\(\.v15\)' \
    "Package.swift must pin the package macOS platform baseline."
require_pattern "$PACKAGE_MANIFEST" '\.package\(path:[[:space:]]*"\.\./Vendor/GRDB\.swift"\)' \
    "Package.swift must use the reviewed local GRDB vendor package."

if [[ -f "$PACKAGE_MANIFEST" ]] && grep -Eq '\.package\(url:' "$PACKAGE_MANIFEST"; then
    record_failure "Package.swift must not add direct remote package URLs; update dependency review before changing dependency sources."
fi

expected_products=(
    ALDomain
    ALAudit
    ALStorage
    ALWorkspace
    ALImports
    ALLedger
    ALDocuments
    ALEvidence
    ALTaxCore
    ALTaxCH
    ALDesignSystem
    ALFeatures
)

for product in "${expected_products[@]}"; do
    require_pattern "$PACKAGE_MANIFEST" "\.library\(name:[[:space:]]*\"${product}\"" \
        "Package.swift must expose product ${product}."
    require_pattern "$PACKAGE_MANIFEST" "name:[[:space:]]*\"${product}\"" \
        "Package.swift must define target ${product}."
done

expected_test_targets=(
    ALDomainTests
    ALStorageTests
    ALImportsTests
    ALLedgerTests
    ALDocumentsTests
    ALEvidenceTests
    ALTaxCoreTests
)

for target in "${expected_test_targets[@]}"; do
    require_pattern "$PACKAGE_MANIFEST" "name:[[:space:]]*\"${target}\"" \
        "Package.swift must define test target ${target}."
done

if [[ -f "$PACKAGE_MANIFEST" && -d "$PACKAGE_DIR/Tests" ]]; then
    dependency_failures_file="$(mktemp)"
    if ! ruby - "$PACKAGE_MANIFEST" "$PACKAGE_DIR/Tests" >"$dependency_failures_file" <<'RUBY'
package_manifest_path, tests_root = ARGV
source = File.read(package_manifest_path)

def extract_test_target_calls(source)
  calls = []
  offset = 0

  while (start = source.index(".testTarget", offset))
    open_paren = source.index("(", start)
    break unless open_paren

    depth = 0
    in_string = false
    escaped = false
    index = open_paren

    while index < source.length
      char = source[index]

      if in_string
        if escaped
          escaped = false
        elsif char == "\\"
          escaped = true
        elsif char == '"'
          in_string = false
        end
      elsif char == '"'
        in_string = true
      elsif char == "("
        depth += 1
      elsif char == ")"
        depth -= 1
        if depth == 0
          calls << source[(open_paren + 1)...index]
          offset = index + 1
          break
        end
      end

      index += 1
    end

    offset = source.length if index >= source.length
  end

  calls
end

declared_dependencies = {}
extract_test_target_calls(source).each do |call|
  name = call[/name:[[:space:]]*"([^"]+)"/, 1]
  dependencies = call[/dependencies:[[:space:]]*\[(.*)\]/m, 1]
  next unless name && dependencies

  declared_dependencies[name] = dependencies.scan(/"([^"]+)"/).flatten.uniq
end

failures = []
Dir.glob(File.join(tests_root, "*Tests")).sort.each do |target_dir|
  target_name = File.basename(target_dir)
  declared = declared_dependencies.fetch(target_name, [])
  imports = Dir.glob(File.join(target_dir, "**", "*.swift")).flat_map do |path|
    File.read(path).scan(/@testable[[:space:]]+import[[:space:]]+(AL[A-Za-z0-9_]+)/).flatten
  end.uniq.sort
  missing = imports - declared

  unless declared_dependencies.key?(target_name)
    failures << "Package.swift must define test target #{target_name}."
  end
  unless missing.empty?
    failures << "Package.swift test target #{target_name} must declare dependencies for imported module(s): #{missing.join(", ")}."
  end
end

puts failures
exit(failures.empty? ? 0 : 1)
RUBY
    then
        while IFS= read -r failure; do
            [[ -n "$failure" ]] && record_failure "$failure"
        done <"$dependency_failures_file"
    fi
    rm -f "$dependency_failures_file"
fi

if [[ -f "$APP_INFO_PLIST" ]]; then
    marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INFO_PLIST" 2>/dev/null || true)"
    build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INFO_PLIST" 2>/dev/null || true)"
    if [[ ! "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        record_failure "Info.plist CFBundleShortVersionString must be MAJOR.MINOR.PATCH; found '${marketing_version}'."
    fi
    if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
        record_failure "Info.plist CFBundleVersion must be an integer build number; found '${build_number}'."
    fi
fi

if command -v xcodebuild >/dev/null 2>&1; then
    xcode_output="$(xcodebuild -version 2>&1 || true)"
    if ! grep -Eq '^Xcode 26\.3$' <<<"$xcode_output"; then
        record_failure "Selected Xcode must match the verified baseline Xcode 26.3. Found: ${xcode_output//$'\n'/ }"
    fi
    if ! grep -Eq '^Build version 17C529$' <<<"$xcode_output"; then
        record_failure "Selected Xcode build must match verified build 17C529. Found: ${xcode_output//$'\n'/ }"
    fi
else
    record_failure "Missing required command: xcodebuild"
fi

if command -v swift >/dev/null 2>&1; then
    swift_output="$(swift --version 2>&1 || true)"
    if ! grep -Eq 'Apple Swift version 6\.2\.4' <<<"$swift_output"; then
        record_failure "Selected Swift toolchain must match verified Swift 6.2.4. Found: ${swift_output//$'\n'/ }"
    fi
else
    record_failure "Missing required command: swift"
fi

require_command_output xcodegen '^Version:[[:space:]]*2\.45\.2$' \
    "XcodeGen must match the verified 2.45.2 baseline."

if [[ -f "$CI_SCHEME" ]]; then
    if ! xmllint --noout "$CI_SCHEME" >/dev/null 2>&1; then
        record_failure "AlpenLedgerAppCI.xcscheme must be valid XML."
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Project structure verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Project structure verification passed."
