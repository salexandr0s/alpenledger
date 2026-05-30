#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly POLICY_FILE="$REPO_ROOT/config/dependency-review.json"
readonly PACKAGE_RESOLVED="$REPO_ROOT/Packages/AlpenLedgerKit/Package.resolved"
readonly PACKAGE_SWIFT="$REPO_ROOT/Packages/AlpenLedgerKit/Package.swift"

ruby - "$REPO_ROOT" "$POLICY_FILE" "$PACKAGE_RESOLVED" "$PACKAGE_SWIFT" <<'RUBY'
require "json"

repo_root, policy_path, package_resolved_path, package_swift_path = ARGV

def fail!(message)
  warn(message)
  exit(1)
end

def require_file!(repo_root, relative_path, label)
  path = File.join(repo_root, relative_path)
  fail!("#{label} is missing: #{relative_path}") unless File.file?(path)
  path
end

def require_directory!(repo_root, relative_path, label)
  path = File.join(repo_root, relative_path)
  fail!("#{label} is missing: #{relative_path}") unless File.directory?(path)
  path
end

policy = JSON.parse(File.read(policy_path))
resolved = JSON.parse(File.read(package_resolved_path))
package_swift = File.read(package_swift_path)

fail!("Unsupported dependency review schema version.") unless policy["schemaVersion"] == 1
fail!("Dependency policy reviewer is missing.") if policy["reviewedBy"].to_s.strip.empty?
fail!("Dependency policy review date is missing.") if policy["reviewedAt"].to_s.strip.empty?

policy_doc = policy["policy"].to_s
require_file!(repo_root, policy_doc, "Dependency review policy document")

resolution = policy.fetch("swiftPackageResolution")
expected_resolved_path = resolution.fetch("path")
actual_resolved_path = package_resolved_path.delete_prefix("#{repo_root}/")
fail!("Policy points at #{expected_resolved_path}, but verifier read #{actual_resolved_path}.") unless expected_resolved_path == actual_resolved_path
fail!("Package.resolved originHash drifted. Review dependency changes and update config/dependency-review.json.") unless resolved["originHash"] == resolution.fetch("originHash")
fail!("Package.resolved version must be 3.") unless resolved["version"] == 3

allowed_pins = policy.fetch("swiftPackagePins")
allowed_identities = allowed_pins.map { |pin| pin.fetch("identity") }
fail!("Duplicate dependency identities in dependency review policy.") unless allowed_identities.uniq == allowed_identities

resolved_pins = resolved.fetch("pins")
resolved_identities = resolved_pins.map { |pin| pin.fetch("identity") }
unless resolved_identities.sort == allowed_identities.sort
  fail!("Package.resolved contains unreviewed dependency pins. Expected #{allowed_identities.sort.join(", ")}, got #{resolved_identities.sort.join(", ")}.")
end

allowed_by_identity = allowed_pins.to_h { |pin| [pin.fetch("identity"), pin] }
resolved_pins.each do |pin|
  expected = allowed_by_identity.fetch(pin.fetch("identity"))
  state = pin.fetch("state")

  fail!("Dependency #{pin["identity"]} kind drifted.") unless pin["kind"] == expected.fetch("kind")
  fail!("Dependency #{pin["identity"]} location drifted.") unless pin["location"] == expected.fetch("location")
  fail!("Dependency #{pin["identity"]} version drifted.") unless state["version"] == expected.fetch("version")
  fail!("Dependency #{pin["identity"]} revision drifted.") unless state["revision"] == expected.fetch("revision")
  fail!("Dependency #{pin["identity"]} is not pinned by exact version.") if state.key?("branch")
  fail!("Dependency #{pin["identity"]} purpose is missing from review policy.") if expected["purpose"].to_s.strip.empty?
  fail!("Dependency #{pin["identity"]} risk is missing from review policy.") if expected["risk"].to_s.strip.empty?
  require_file!(repo_root, expected.fetch("review").split("#", 2).first, "Dependency review notes for #{pin["identity"]}")
end

vendored_dependencies = policy.fetch("vendoredDependencies")
vendored_names = vendored_dependencies.map { |dependency| dependency.fetch("name") }
fail!("Duplicate vendored dependency names in dependency review policy.") unless vendored_names.uniq == vendored_names

package_declarations = package_swift.scan(/\.package\s*\(/).length
package_path_declarations = package_swift.scan(/\.package\s*\(\s*path:\s*"([^"]+)"\s*\)/).flatten
fail!("Main package must not declare remote SwiftPM dependencies directly.") if package_swift.match?(/\.package\s*\(\s*url:/)
fail!("Main package has unsupported package declarations.") unless package_declarations == package_path_declarations.length

expected_package_paths = vendored_dependencies.map { |dependency| dependency.fetch("packageManifestPath") }.sort
unless package_path_declarations.sort == expected_package_paths
  fail!("Main package vendored dependency paths drifted. Expected #{expected_package_paths.join(", ")}, got #{package_path_declarations.sort.join(", ")}.")
end

vendored_dependencies.each do |dependency|
  vendor_path = require_directory!(repo_root, dependency.fetch("path"), "Vendored dependency #{dependency["name"]}")
  require_file!(repo_root, dependency.fetch("patch"), "Patch file for #{dependency["name"]}")
  require_file!(repo_root, dependency.fetch("review").split("#", 2).first, "Review notes for #{dependency["name"]}")

  fail!("Vendored dependency #{dependency["name"]} upstream is missing.") if dependency["upstream"].to_s.strip.empty?
  fail!("Vendored dependency #{dependency["name"]} tag is missing.") if dependency["tag"].to_s.strip.empty?
  fail!("Vendored dependency #{dependency["name"]} commit is missing.") if dependency["commit"].to_s.strip.empty?
  fail!("Vendored dependency #{dependency["name"]} purpose is missing.") if dependency["purpose"].to_s.strip.empty?
  fail!("Vendored dependency #{dependency["name"]} risk is missing.") if dependency["risk"].to_s.strip.empty?

  [".git", ".gitmodules"].each do |forbidden|
    forbidden_path = File.join(vendor_path, forbidden)
    fail!("Forbidden vendored metadata is present: #{forbidden_path}") if File.exist?(forbidden_path)
  end
end
RUBY

echo "Dependency review policy passed."
