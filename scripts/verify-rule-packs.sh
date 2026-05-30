#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CATALOG_PATH="$REPO_ROOT/config/rule-pack-catalog.json"
readonly FIXTURE_CATALOG_PATH="$REPO_ROOT/config/fixture-catalog.json"

ruby - "$REPO_ROOT" "$CATALOG_PATH" "$FIXTURE_CATALOG_PATH" <<'RUBY'
require "json"
require "set"

repo_root = ARGV.fetch(0)
catalog_path = ARGV.fetch(1)
fixture_catalog_path = ARGV.fetch(2)
failures = []

def fail_with(failures, message)
  failures << message
end

def valid_concept_code?(code)
  code.is_a?(String) && code.match?(/\A[a-z0-9_]+(\.[a-z0-9_]+)*\z/)
end

unless File.file?(catalog_path)
  abort("Missing rule-pack catalog: #{catalog_path}")
end

unless File.file?(fixture_catalog_path)
  abort("Missing fixture catalog: #{fixture_catalog_path}")
end

catalog = JSON.parse(File.read(catalog_path))
fixture_catalog = JSON.parse(File.read(fixture_catalog_path))

unless catalog["schemaVersion"] == 1
  fail_with(failures, "rule-pack catalog schemaVersion must be 1")
end

%w[reviewedAt reviewedBy policyDoc rulePacks].each do |key|
  value = catalog[key]
  if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    fail_with(failures, "rule-pack catalog missing #{key}")
  end
end

policy_doc = File.join(repo_root, catalog.fetch("policyDoc", ""))
fail_with(failures, "rule-pack policy doc is missing: #{catalog["policyDoc"]}") unless File.file?(policy_doc)

fixture_packs = fixture_catalog.fetch("fixtures", []).map { |fixture| fixture["pack"] }.to_set
fixture_paths = fixture_catalog.fetch("fixtures", []).map { |fixture| fixture["path"] }.to_set
seen_ids = Set.new
seen_keys = Set.new

catalog.fetch("rulePacks", []).each do |rule_pack|
  id = rule_pack["id"]
  key = [rule_pack["jurisdictionCode"], rule_pack["rulesetVersion"]].join(":")

  %w[
    id adapterType jurisdictionCode rulesetVersion taxYear appliesToEntityKinds
    fixturePack goldenExpectedFactsPath expectedConceptCodesByEntityKind coverageTests
  ].each do |required_key|
    value = rule_pack[required_key]
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      fail_with(failures, "rule pack #{id || "<unknown>"} missing #{required_key}")
    end
  end

  fail_with(failures, "duplicate rule-pack id: #{id}") unless seen_ids.add?(id)
  fail_with(failures, "duplicate rule-pack key: #{key}") unless seen_keys.add?(key)

  unless rule_pack["jurisdictionCode"].to_s.match?(/\ACH-[A-Z]{2}\z/)
    fail_with(failures, "rule pack #{id} has invalid jurisdictionCode: #{rule_pack["jurisdictionCode"]}")
  end

  unless rule_pack["taxYear"].is_a?(Integer) && rule_pack["taxYear"] >= 2000
    fail_with(failures, "rule pack #{id} taxYear must be an integer year")
  end

  unless fixture_packs.include?(rule_pack["fixturePack"])
    fail_with(failures, "rule pack #{id} references unknown fixture pack: #{rule_pack["fixturePack"]}")
  end

  expected_path = rule_pack["goldenExpectedFactsPath"]
  if expected_path.to_s.start_with?("Fixtures/") == false || expected_path.to_s.include?("..")
    fail_with(failures, "rule pack #{id} goldenExpectedFactsPath must stay under Fixtures/: #{expected_path.inspect}")
  elsif fixture_paths.include?(expected_path) == false
    fail_with(failures, "rule pack #{id} goldenExpectedFactsPath is not cataloged as a fixture: #{expected_path}")
  end

  unless File.file?(File.join(repo_root, expected_path.to_s))
    fail_with(failures, "rule pack #{id} golden expected facts file is missing: #{expected_path}")
  end

  concept_map = rule_pack.fetch("expectedConceptCodesByEntityKind", {})
  rule_pack.fetch("appliesToEntityKinds", []).each do |entity_kind|
    concepts = concept_map[entity_kind]
    unless concepts.is_a?(Array) && concepts.any?
      fail_with(failures, "rule pack #{id} missing expected concepts for #{entity_kind}")
      next
    end
    if concepts != concepts.sort
      fail_with(failures, "rule pack #{id} concepts for #{entity_kind} must be sorted")
    end
    if concepts.uniq.length != concepts.length
      fail_with(failures, "rule pack #{id} concepts for #{entity_kind} contain duplicates")
    end
    concepts.each do |concept|
      fail_with(failures, "rule pack #{id} has invalid concept code: #{concept}") unless valid_concept_code?(concept)
    end
  end

  golden_facts_path = File.join(repo_root, expected_path.to_s)
  if File.file?(golden_facts_path)
    golden_concepts = JSON.parse(File.read(golden_facts_path)).map { |fact| fact["conceptCode"] }
    natural_person_concepts = concept_map.fetch("naturalPerson", [])
    missing_from_catalog = golden_concepts - natural_person_concepts
    fail_with(failures, "rule pack #{id} golden facts include concepts absent from catalog: #{missing_from_catalog.join(", ")}") unless missing_from_catalog.empty?
  end
end

if failures.any?
  warn failures.map { |failure| "Rule-pack verification failed: #{failure}" }.join("\n")
  exit 1
end
RUBY

(
  cd "$REPO_ROOT/Packages/AlpenLedgerKit"
  swift test --filter RulePackValidation
)
