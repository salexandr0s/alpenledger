#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCHEMA_CATALOG_PATH="$REPO_ROOT/config/schema-catalog.json"
readonly ECH_CATALOG_PATH="$REPO_ROOT/Schemas/eCH/catalog.xml"
readonly ECH_0217_SCHEMA="$REPO_ROOT/Schemas/eCH/eCH-0217/2.0.0/eCH-0217-2-0-0.xsd"
readonly VAT_EXPORT_FIXTURE="$REPO_ROOT/Fixtures/VAT/eCH-0217-effective-reporting-2026.xml"

if ! command -v ruby >/dev/null 2>&1; then
    echo "Schema verification requires ruby for catalog/hash checks." >&2
    exit 2
fi

if ! command -v xmllint >/dev/null 2>&1; then
    echo "Schema verification requires xmllint for offline XSD validation." >&2
    exit 2
fi

ruby - "$REPO_ROOT" "$SCHEMA_CATALOG_PATH" "$ECH_CATALOG_PATH" <<'RUBY'
require "digest"
require "json"
require "set"

repo_root = ARGV.fetch(0)
catalog_path = ARGV.fetch(1)
ech_catalog_path = ARGV.fetch(2)
failures = []

def fail_with(failures, message)
  failures << message
end

unless File.file?(catalog_path)
  abort("Missing schema catalog: #{catalog_path}")
end

catalog = JSON.parse(File.read(catalog_path))
fail_with(failures, "schema catalog schemaVersion must be 1") unless catalog["schemaVersion"] == 1

%w[reviewedAt reviewedBy policy schemas].each do |key|
  value = catalog[key]
  if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    fail_with(failures, "schema catalog missing #{key}")
  end
end

schemas = catalog.fetch("schemas", [])
seen_paths = Set.new

schemas.each do |schema|
  path = schema["path"]
  source_url = schema["sourceURL"]
  sha256 = schema["sha256"]

  %w[path sourceURL sha256].each do |key|
    value = schema[key]
    if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      fail_with(failures, "schema #{path || source_url || "<unknown>"} missing #{key}")
    end
  end

  unless source_url.to_s.start_with?("http://www.ech.ch/", "https://www.ech.ch/")
    fail_with(failures, "schema #{path} sourceURL must be an eCH URL: #{source_url.inspect}")
  end

  if path.nil? || path.start_with?("Schemas/") == false || path.include?("..")
    fail_with(failures, "schema path must stay under Schemas/: #{path.inspect}")
    next
  end

  fail_with(failures, "duplicate schema path: #{path}") unless seen_paths.add?(path)

  full_path = File.join(repo_root, path)
  unless File.file?(full_path)
    fail_with(failures, "schema file is missing: #{path}")
    next
  end

  fail_with(failures, "schema file is empty: #{path}") if File.size(full_path).zero?
  actual_sha = Digest::SHA256.file(full_path).hexdigest
  if actual_sha != sha256
    fail_with(failures, "schema #{path} hash drifted: expected #{sha256}, got #{actual_sha}")
  end
end

schema_files = Dir.glob(File.join(repo_root, "Schemas", "eCH", "**", "*.xsd"))
  .select { |path| File.file?(path) }
  .map { |path| path.delete_prefix("#{repo_root}/") }
  .sort

unregistered = schema_files - seen_paths.to_a
missing_files = seen_paths.to_a - schema_files
fail_with(failures, "unregistered schema file(s): #{unregistered.join(", ")}") unless unregistered.empty?
fail_with(failures, "catalog references missing schema file(s): #{missing_files.join(", ")}") unless missing_files.empty?

unless File.file?(ech_catalog_path)
  fail_with(failures, "eCH XML catalog is missing: #{ech_catalog_path}")
else
  ech_catalog = File.read(ech_catalog_path)
  fail_with(failures, "eCH XML catalog must not contain absolute repo paths") if ech_catalog.include?(repo_root)
  unless ech_catalog.include?('systemIdStartString="http://www.ech.ch/xmlns/"')
    fail_with(failures, "eCH XML catalog missing system rewrite for eCH xmlns")
  end
  unless ech_catalog.include?('uriStartString="http://www.ech.ch/xmlns/"')
    fail_with(failures, "eCH XML catalog missing URI rewrite for eCH xmlns")
  end
end

if failures.any?
  warn failures.map { |failure| "Schema verification failed: #{failure}" }.join("\n")
  exit 1
end

puts "Schema catalog metadata verification passed."
RUBY

readonly TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alpenledger-schemas.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

readonly GENERATED_CATALOG="$TEMP_DIR/catalog.xml"
cat > "$GENERATED_CATALOG" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
  <rewriteSystem systemIdStartString="http://www.ech.ch/xmlns/" rewritePrefix="$REPO_ROOT/Schemas/eCH/xmlns/"/>
  <rewriteURI uriStartString="http://www.ech.ch/xmlns/" rewritePrefix="$REPO_ROOT/Schemas/eCH/xmlns/"/>
</catalog>
XML

XML_CATALOG_FILES="$GENERATED_CATALOG" xmllint --nonet --noout \
    --schema "$ECH_0217_SCHEMA" \
    "$VAT_EXPORT_FIXTURE"

readonly INVALID_FIXTURE="$TEMP_DIR/eCH-0217-missing-payable-tax.xml"
ruby - "$VAT_EXPORT_FIXTURE" "$INVALID_FIXTURE" <<'RUBY'
xml = File.read(ARGV.fetch(0))
removed = xml.sub!(/\n  <eCH-0217:payableTax>.*?<\/eCH-0217:payableTax>/m, "")
abort("Could not remove payableTax from VAT export fixture") unless removed
File.write(ARGV.fetch(1), xml)
RUBY

if XML_CATALOG_FILES="$GENERATED_CATALOG" xmllint --nonet --noout \
    --schema "$ECH_0217_SCHEMA" \
    "$INVALID_FIXTURE" >/dev/null 2>"$TEMP_DIR/invalid-xmllint.log"; then
    echo "Schema validation unexpectedly accepted a VAT export without payableTax." >&2
    exit 1
fi

echo "Schema catalog verification passed."
